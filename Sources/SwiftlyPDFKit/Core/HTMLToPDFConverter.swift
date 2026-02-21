import Foundation

// MARK: - HTMLToPDFConverter

/// Converts an HTML string to PDF data by invoking an external tool (Linux only).
/// On Darwin, PDF rendering uses CoreGraphics directly and this type is not needed.
#if !canImport(CoreGraphics)
enum HTMLToPDFConverter {

    /// Path to the `wkhtmltopdf` binary.
    /// Set the `WKHTMLTOPDF_PATH` environment variable to override the default location.
    static let toolPath: String = ProcessInfo.processInfo.environment["WKHTMLTOPDF_PATH"] ?? "/usr/bin/wkhtmltopdf"

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

        // Convert points to millimetres: 1pt = 0.3528mm
        let widthMM = Int(round(pageWidth * 0.3528))
        let heightMM = Int(round(pageHeight * 0.3528))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        process.arguments = [
            "--page-width", "\(widthMM)",
            "--page-height", "\(heightMM)",
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
}
#endif
