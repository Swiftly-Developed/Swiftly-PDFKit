import Foundation
import Testing

/// `QA-UNIT06-DOCUMENTS-112` … `-115` — the zero-occurrence drift guard over the
/// package's OWN projection docs (`CLAUDE.md`, `README.md`), shipped in the same
/// commit as the `PRINT01` Step-10 retirements it pins.
///
/// 💀 **WHY IT EXISTS.** `SwiftlyPDFKit/CLAUDE.md` and `README.md` documented five
/// `InvoiceLayoutType` cases as live API for the whole window between `DOCUMENTS03`
/// (which cut the enum to three) and `2026-09-09` — four spellings that do not
/// compile, one of them in a copy-pasteable `PDF(layout: .minimal, …)` example. Over
/// the same window the `DemoPDFKit` file map named four files that do not exist. Both
/// survived every lessons-writeback pass, because writeback asks *what should we add*
/// and nothing asked *what did this make false*. Prose cannot be trusted to stay true;
/// this file makes it fail instead.
///
/// ⚠️ **Every doc matcher strips block HTML comments first, and that is load-bearing.**
/// A retirement records the superseded spelling inside an HTML comment (stripped from
/// agent context, visible on `Read`). Without the strip, either the guard reds on its
/// own supersession record, or an author deletes the record to make it green. `-115`
/// self-tests the stripper.
///
/// The type name deliberately carries the token `Document` so the suite manifest's §2
/// grep reaches it.
@Suite("Document package doc drift")
struct DocumentPackageDocDriftTests {

    // MARK: - Locating the package

    enum GuardError: Error, CustomStringConvertible {
        case packageRootNotFound(from: String)
        case fileUnreadable(path: String)

        var description: String {
            switch self {
            case .packageRootNotFound(let from):
                "QA-UNIT06-DOCUMENTS: could not walk up from \(from) to a directory holding "
                    + "Package.swift + CLAUDE.md + README.md. The guard measured nothing."
            case .fileUnreadable(let path):
                "QA-UNIT06-DOCUMENTS: \(path) is unreadable. The guard measured nothing."
            }
        }
    }

    /// Walk up from this source file to the `SwiftlyPDFKit` package root. Anchored on
    /// three markers, not one, so a future nested package cannot silently win.
    static func packageRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            let fm = FileManager.default
            if fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path),
               fm.fileExists(atPath: dir.appendingPathComponent("CLAUDE.md").path),
               fm.fileExists(atPath: dir.appendingPathComponent("README.md").path) {
                return dir
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        throw GuardError.packageRootNotFound(from: #filePath)
    }

    static func read(_ relative: String) throws -> String {
        let url = try packageRoot().appendingPathComponent(relative)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw GuardError.fileUnreadable(path: url.path)
        }
        return text
    }

    // MARK: - The matchers (pure, so `-115` can drive them on synthetic text)

    /// Remove every `<!-- … -->` block. A supersession record is history, not a claim.
    static func strippingHTMLComments(_ text: String) -> String {
        var out = ""
        var rest = Substring(text)
        while let open = rest.range(of: "<!--") {
            out += rest[rest.startIndex..<open.lowerBound]
            guard let close = rest.range(of: "-->", range: open.upperBound..<rest.endIndex) else {
                // Unterminated: drop the remainder rather than silently re-enabling
                // matching on it. Asserted in `-115`.
                return out
            }
            rest = rest[close.upperBound...]
        }
        out += rest
        return out
    }

    static func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var idx = text.startIndex
        while let r = text.range(of: needle, range: idx..<text.endIndex) {
            count += 1
            idx = r.upperBound
        }
        return count
    }

    /// The `NN` in every "`NN` demo(s)" / "`NN` demo configurations" figure.
    static func demoCountFigures(in text: String) -> [Int] {
        var found: [Int] = []
        let scanner = text
        var idx = scanner.startIndex
        while let r = scanner.range(of: " demo", range: idx..<scanner.endIndex) {
            idx = r.upperBound
            // Walk backwards over the digits immediately preceding " demo".
            var j = r.lowerBound
            var digits = ""
            while j > scanner.startIndex {
                let prev = scanner.index(before: j)
                guard scanner[prev].isNumber else { break }
                digits.insert(scanner[prev], at: digits.startIndex)
                j = prev
            }
            if let n = Int(digits) { found.append(n) }
        }
        return found
    }

    /// Every spelling that no enum in this package declares any more.
    static let retiredSpellings = [
        "classicWithSidebar",   // InvoiceLayoutType, retired by DOCUMENTS03
        "summaryFirst",         // InvoiceLayoutType, retired by DOCUMENTS03
        "ShipmentLayout",       // the shipment / dispatch-advice family, retired by PRINT01 P00
        "ShipmentSupplement",
        "carrierBlock",
        "Demo15",
        "InvoiceFormatter(",    // renamed to DocumentFormatter; only the typealias may survive
    ]

    // MARK: - -112

    @Test("-112 no retired layout / shipment / formatter spelling survives in the package or its docs")
    func retiredSpellingsAreGone() throws {
        let root = try Self.packageRoot()

        // Sources first — a retired spelling that still compiles is a live case.
        var swiftFiles: [URL] = []
        let sourcesRoot = root.appendingPathComponent("Sources")
        if let walker = FileManager.default.enumerator(at: sourcesRoot,
                                                      includingPropertiesForKeys: nil) {
            for case let url as URL in walker where url.pathExtension == "swift" {
                swiftFiles.append(url)
            }
        }
        #expect(swiftFiles.count > 20, """
        QA-UNIT06-DOCUMENTS-112: walked \(swiftFiles.count) Swift files under Sources/. The         corpus is implausibly small — the guard measured nothing.
        """)

        for url in swiftFiles {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                throw GuardError.fileUnreadable(path: url.path)
            }
            for needle in Self.retiredSpellings {
                #expect(Self.occurrences(of: needle, in: text) == 0, """
                QA-UNIT06-DOCUMENTS-112: `\(needle)` survives in \(url.lastPathComponent).                 Retired by DOCUMENTS03 (the five-case InvoiceLayoutType) and PRINT01 phase 00                 (the shipment / dispatch-advice family; `InvoiceFormatter` -> `DocumentFormatter`,                 whose only legal survivor is the typealias DECLARATION, which carries no `(`).
                """)
            }
        }

        // Then the two projection docs, comment-stripped so a supersession record
        // neither reds this guard nor gets deleted to make it green.
        for doc in ["CLAUDE.md", "README.md"] {
            let text = Self.strippingHTMLComments(try Self.read(doc))
            #expect(text.count > 2000, """
            QA-UNIT06-DOCUMENTS-112: \(doc) stripped to \(text.count) characters. Non-vacuity             floor breached — the guard measured nothing.
            """)
            for needle in Self.retiredSpellings {
                #expect(Self.occurrences(of: needle, in: text) == 0, """
                QA-UNIT06-DOCUMENTS-112: `\(needle)` is documented as live API in \(doc).                 Four such spellings stood in these two files as a five-case `InvoiceLayoutType`                 table — including a copy-pasteable `PDF(layout: .minimal, ...)` example that does                 not compile — from DOCUMENTS03 until 2026-09-09. Record a retirement inside an                 HTML comment; do not re-state it as prose.
                """)
            }
        }
    }

    // MARK: - -113

    @Test("-113 the demo count agrees across four independent sources")
    func demoCountIsConsistent() throws {
        let root = try Self.packageRoot()
        let fm = FileManager.default

        let demoFiles = try fm.contentsOfDirectory(atPath: root.appendingPathComponent("Sources/DemoPDFKit").path)
            .filter { $0.hasPrefix("Demo") && $0.hasSuffix(".swift") }
            .sorted()
        let demoPDFs = try fm.contentsOfDirectory(atPath: root.appendingPathComponent("DemoPDFs").path)
            .filter { $0.hasPrefix("Demo") && $0.hasSuffix(".pdf") }
            .sorted()

        #expect(!demoFiles.isEmpty, """
        QA-UNIT06-DOCUMENTS-113: Sources/DemoPDFKit holds zero Demo*.swift files. The guard \
        measured nothing — a zero here is a broken instrument, not a clean tree.
        """)
        #expect(demoFiles.count == demoPDFs.count, """
        QA-UNIT06-DOCUMENTS-113: \(demoFiles.count) Demo*.swift but \(demoPDFs.count) committed \
        DemoPDFs/*.pdf. Adding or retiring a demo re-renders the artifacts in the same commit \
        (`swift run GenerateDemos`).
        """)

        let generator = try Self.read("Sources/GenerateDemos/main.swift")
        #expect(Self.occurrences(of: "\\n\(demoFiles.count) PDFs written", in: generator) == 1, """
        QA-UNIT06-DOCUMENTS-113: GenerateDemos' trailing message does not say \
        "\(demoFiles.count) PDFs written". There are \(demoFiles.count) demos on disk; the tool \
        reports its own hardcoded number, and that number is what a reader believes.
        """)

        for doc in ["CLAUDE.md", "README.md"] {
            let text = Self.strippingHTMLComments(try Self.read(doc))
            let figures = Set(Self.demoCountFigures(in: text))
            #expect(!figures.isEmpty, """
            QA-UNIT06-DOCUMENTS-113: \(doc) states no demo count at all. If the count was \
            deliberately removed, delete this clause; a silent zero is not a pass.
            """)
            #expect(figures == [demoFiles.count], """
            QA-UNIT06-DOCUMENTS-113: \(doc) states demo count(s) \(figures.sorted()) but \
            \(demoFiles.count) demos exist. This exact drift stood for the whole window between \
            the shipment family's retirement and 2026-09-09, across eight occurrences.
            """)
        }
    }

    // MARK: - -114

    @Test("-114 CLAUDE.md's demo file map and layout list name what the source declares")
    func docsNameTheRealSymbols() throws {
        let root = try Self.packageRoot()
        let claude = Self.strippingHTMLComments(try Self.read("CLAUDE.md"))

        let demoFiles = try FileManager.default
            .contentsOfDirectory(atPath: root.appendingPathComponent("Sources/DemoPDFKit").path)
            .filter { $0.hasPrefix("Demo") && $0.hasSuffix(".swift") }
            .sorted()
        for file in demoFiles {
            #expect(Self.occurrences(of: file, in: claude) >= 1, """
            QA-UNIT06-DOCUMENTS-114: Sources/DemoPDFKit/\(file) exists but CLAUDE.md's file map \
            never names it. Four wrong basenames stood in that map from DOCUMENTS03 until \
            2026-09-09 — a reader following the map opened files that were not there.
            """)
        }

        // Every `InvoiceLayoutType` case the source declares must be documented.
        let layoutSource = try Self.read("Sources/SwiftlyPDFKit/Documents/Invoice/InvoiceLayout.swift")
        let declared = Self.declaredCases(inEnum: "InvoiceLayoutType", source: layoutSource)
        #expect(declared.count >= 2, """
        QA-UNIT06-DOCUMENTS-114: parsed \(declared.count) InvoiceLayoutType cases out of \
        InvoiceLayout.swift. The parser found nothing to check — a broken instrument.
        """)
        for name in declared {
            #expect(Self.occurrences(of: "`.\(name)`", in: claude) >= 1, """
            QA-UNIT06-DOCUMENTS-114: InvoiceLayoutType declares `.\(name)` but CLAUDE.md's layout \
            list does not carry it. The list is the API a reader copies from.
            """)
        }
    }

    /// Case names declared by `enum <name>` in `source`, up to its closing brace.
    static func declaredCases(inEnum name: String, source: String) -> [String] {
        guard let start = source.range(of: "enum \(name)") else { return [] }
        var depth = 0
        var body = ""
        var i = start.upperBound
        var started = false
        while i < source.endIndex {
            let c = source[i]
            if c == "{" { depth += 1; started = true }
            if started { body.append(c) }
            if c == "}" { depth -= 1; if depth == 0 { break } }
            i = source.index(after: i)
        }
        var names: [String] = []
        for rawLine in body.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("case "), !line.hasPrefix("//") else { continue }
            let tail = line.dropFirst("case ".count)
            let ident = tail.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
            if !ident.isEmpty { names.append(String(ident)) }
        }
        return names
    }

    // MARK: - -115

    @Test("-115 the instrument controls — every matcher detects the historical defect")
    func instrumentControls() {
        // (a) The comment stripper. Code survives; a commented claim does not; an
        //     unterminated block does not silently re-enable matching.
        let mixed = "live `.classic`\n<!-- SUPERSEDED: `.classicWithSidebar` -->\nmore `.receipt`"
        let stripped = Self.strippingHTMLComments(mixed)
        #expect(Self.occurrences(of: "classicWithSidebar", in: stripped) == 0)
        #expect(Self.occurrences(of: ".classic`", in: stripped) == 1)
        #expect(Self.occurrences(of: ".receipt", in: stripped) == 1)
        #expect(Self.strippingHTMLComments("a <!-- b `.summaryFirst`") == "a ")

        // (b) The retired-spelling matcher, driven against the text that actually
        //     shipped in README.md until 2026-09-09.
        let historicalReadme = """
        | `.classicWithSidebar` | Classic layout with a full-height accent-colored bar |
        | `.summaryFirst` | Page 1 shows totals and payment only |
        """
        for needle in ["classicWithSidebar", "summaryFirst"] {
            #expect(Self.occurrences(of: needle, in: historicalReadme) > 0, """
            QA-UNIT06-DOCUMENTS-115: the retired-spelling matcher does NOT detect \(needle) in the \
            historical defect text. A guard that can only pass is not coverage.
            """)
        }

        // (c) The demo-count figure parser, against the historical "15 demo" prose.
        let historicalCounts = "The project includes 15 demo configurations covering every layout."
        #expect(Self.demoCountFigures(in: historicalCounts) == [15], """
        QA-UNIT06-DOCUMENTS-115: the demo-count parser does not read 15 out of the prose that \
        actually shipped. It would have passed the drift it exists to catch.
        """)
        #expect(Self.demoCountFigures(in: "no figure here") == [])

        // (d) The enum-case parser, against a synthetic three-case enum.
        let synthetic = """
        public enum InvoiceLayoutType: Sendable {
            /// doc
            case modern
            case classic
            case receipt
        }
        """
        #expect(Self.declaredCases(inEnum: "InvoiceLayoutType", source: synthetic)
                == ["modern", "classic", "receipt"])
        #expect(Self.declaredCases(inEnum: "NoSuchEnum", source: synthetic) == [])
    }
}
