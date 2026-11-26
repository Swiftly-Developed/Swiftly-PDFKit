import Foundation

// MARK: - HTMLToPDFConverter

/// Converts an HTML string to PDF data by invoking an external tool (Linux only).
/// On Darwin, PDF rendering uses CoreGraphics directly and the `Process`-spawning
/// half of this type is not compiled; the pure parts (the argument vector, the
/// Qt-build detection and the compensation constant) compile everywhere so they
/// can be tested from a macOS `swift test`.
enum HTMLToPDFConverter {

    // MARK: Pure (every platform)

    /// `true` iff `wkhtmltopdf --version` identifies an official patched-Qt build
    /// (e.g. `wkhtmltopdf 0.12.6.1 (with patched qt)`). The distro apt build prints
    /// exactly `wkhtmltopdf 0.12.6` and is unpatched: it IGNORES
    /// `--disable-smart-shrinking` (stating so on stderr) and shrinks the document
    /// to fit the paper instead of honouring the fixed-`pt` page box.
    static func isPatchedQt(versionOutput: String) -> Bool {
        versionOutput.lowercased().contains("with patched qt")
    }

    /// CSS `zoom` applied to `<body>` when the engine is an unpatched-Qt build.
    ///
    /// Measured 2026-09-03 (see `docs/fixes/2026-09-03-invoice-pdf-linux-smart-shrinking-offcenter.md`):
    /// unpatched Qt lays the document out at ≈1.305× the paper width and fits
    /// `max(viewport, document width)` to the paper, so a fixed 595pt page box lands
    /// at 0.768 scale, top-left. A body zoom inside the band 1.305 < Z < ≈2.08 makes
    /// the document wider than the viewport, turning the fit into an exact page-box →
    /// paper mapping; below the floor the box stays under-scaled, above the cap the
    /// engine stops shrinking and content overflows. 1.6 sits near the band's
    /// geometric midpoint, ≈20 % of margin to both edges.
    static let smartShrinkingCompensationZoom: CGFloat = 1.6

    /// The exact `wkhtmltopdf` argument vector for a paper of `pageWidth` × `pageHeight`.
    ///
    /// The paper size is passed in exact **points** (`595pt`), not integer-rounded
    /// millimetres: `wkhtmltopdf` accepts a `pt` suffix, and the exact value yields a
    /// `MediaBox [0 0 595 842]` byte-equal to the CoreGraphics output, whereas
    /// `210mm × 297mm` gave 595.28 × 841.89 and Letter's `216mm × 279mm` gave
    /// 612.3 × 790.9 — 1.1pt *shorter* than the 792pt page box it has to hold.
    /// Dimensions are numeric only (an interpolated `CGFloat` + a fixed suffix), so
    /// no caller-controlled text reaches the argument vector.
    /// `--disable-smart-shrinking` stays: patched-Qt builds honour it.
    static func arguments(pageWidth: CGFloat, pageHeight: CGFloat) -> [String] {
        [
            "--page-width", "\(pageWidth)pt",
            "--page-height", "\(pageHeight)pt",
            "--margin-top", "0",
            "--margin-bottom", "0",
            "--margin-left", "0",
            "--margin-right", "0",
            "--disable-smart-shrinking",
            "--dpi", "96",
            "--encoding", "utf-8",
            "--quiet",
            "-", "-"  // stdin → stdout
        ]
    }

    // MARK: Process-spawning (Linux only)

    #if !canImport(CoreGraphics)
    /// Path to the `wkhtmltopdf` binary.
    /// Set the `WKHTMLTOPDF_PATH` environment variable to override the default location.
    static let toolPath: String = ProcessInfo.processInfo.environment["WKHTMLTOPDF_PATH"] ?? "/usr/bin/wkhtmltopdf"

    /// Whether the installed `wkhtmltopdf` is an unpatched-Qt build, probed ONCE per
    /// process by running `toolPath --version` (stdout captured, stderr discarded).
    /// If the tool cannot be launched at all this is `true` — the conservative
    /// default; `convert` throws `externalToolNotFound` on that path anyway.
    static let usesUnpatchedQt: Bool = {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        process.arguments = ["--version"]
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return true
        }
        let output = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let versionOutput = String(data: output, encoding: .utf8) ?? ""
        return !isPatchedQt(versionOutput: versionOutput)
    }()

    /// The `<body>` zoom the emitted HTML must carry for the installed engine:
    /// `smartShrinkingCompensationZoom` on an unpatched-Qt build, `1` (no
    /// compensation — the 1:1 `pt` contract holds) on a patched one.
    static var compensationZoom: CGFloat {
        usesUnpatchedQt ? smartShrinkingCompensationZoom : 1
    }

    /// Converts the given HTML to PDF data using wkhtmltopdf.
    ///
    /// - Parameters:
    ///   - html: Complete HTML document string.
    ///   - pageWidth: Page width in points (1pt = 1/72 inch).
    ///   - pageHeight: Page height in points.
    /// - Returns: Raw PDF `Data`.
    static func convert(html: String, pageWidth: CGFloat, pageHeight: CGFloat) throws -> Data {
        guard FileManager.default.fileExists(atPath: toolPath) else {
            throw PDFRenderError.externalToolNotFound(
                "wkhtmltopdf not found at \(toolPath). Install it with: apt-get install wkhtmltopdf"
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        process.arguments = arguments(pageWidth: pageWidth, pageHeight: pageHeight)

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        if let inputData = html.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(inputData)
        }
        stdinPipe.fileHandleForWriting.closeFile()

        let pdfData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0, !pdfData.isEmpty else {
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if !stderr.isEmpty {
                throw PDFRenderError.externalToolNotFound("wkhtmltopdf failed: \(stderr)")
            }
            throw PDFRenderError.htmlConversionFailed
        }

        return pdfData
    }
    #endif
}
