import Foundation
import Testing
@testable import SwiftlyPDFKit
#if canImport(PDFKit)
import PDFKit
#endif

// MARK: - Stacked document cell wrap and receipt equivalence

/// `-249`: the remittance advice's stacked document cell wraps inside its
/// column on both render paths. The CoreGraphics leg reads the **drawn**
/// layout back — it renders the advice to PDF bytes, opens them with PDFKit
/// and takes the drawn box of each cell's text (a text selection's bounds) —
/// and the same reader run over the kit's single-line hairline `Table` with
/// the atom's widths is the red control.
///
/// `-250`: reusing the receipt's six-column atom left the receipt unchanged —
/// the stacked table with one line per cell renders the receipt's table byte
/// for byte (PRINT03 phase 00 D13).
extension RemittanceAdviceDocumentLayoutTests {

    /// A long payee number wider than the document column, and a long reference.
    static let unbrokenToken = "INVOICE-GASKETKIT-STAINLESS-316L-ANTWERP-0000004"
    static let longReference = "VBILL00031-LONG-REFERENCE"
    static let wrapDate = "2026-09-15"

    static let wrapRow = RemittanceAdviceDetailRow(
        theirNumber: unbrokenToken, theirDate: wrapDate, ourReference: longReference,
        documentCurrencyCode: "EUR", gross: 2_500, paidByOtherPayments: 0,
        applied: 2_450, appliedCurrencyCode: "EUR", remaining: 50, isSettled: false)

    #if canImport(PDFKit)
    /// The drawn box of `needle` on `page` — every line it occupies — matched
    /// with whitespace ignored (a wrapped cell carries a line break inside it).
    /// `nil` when the needle is absent or occurs more than once.
    static func drawnBounds(of needle: String, on page: PDFPage) -> CGRect? {
        let text = (page.string ?? "") as NSString
        var compact: [unichar] = []
        var indices: [Int] = []
        for index in 0..<text.length {
            let unit = text.character(at: index)
            if let scalar = Unicode.Scalar(unit), CharacterSet.whitespacesAndNewlines.contains(scalar) {
                continue
            }
            compact.append(unit)
            indices.append(index)
        }
        let target = Array(needle.filter { !$0.isWhitespace }.utf16)
        var matches: [Int] = []
        if target.count <= compact.count {
            for start in 0...(compact.count - target.count)
            where Array(compact[start..<start + target.count]) == target {
                matches.append(start)
            }
        }
        guard matches.count == 1, let start = matches.first else { return nil }
        // `characterBounds(at:)` is not indexed like `page.string`; a selection
        // over the string's own range is.
        let first = indices[start], last = indices[start + target.count - 1]
        return page.selection(for: NSRange(location: first, length: last - first + 1))?
            .bounds(for: page)
    }

    /// The union box of each cell's needles.
    static func cellBoxes(_ cells: [[String]], on page: PDFPage) throws -> [CGRect] {
        try cells.map { needles in
            try needles.reduce(CGRect.null) { box, needle in
                box.union(try #require(drawnBounds(of: needle, on: page), "\(needle) not drawn once"))
            }
        }
    }

    static func firstPage(_ pdf: PDF) throws -> PDFPage {
        let document = try #require(PDFDocument(data: try pdf.render()))
        return try #require(document.page(at: 0))
    }
    #endif

    // MARK: Test -249

    /// `QA-UNIT06-DOCUMENTS-249`
    @Test("-249 the stacked document cell wraps inside its column on both paths")
    func documentCellWrapsInsideItsColumn() throws {
        // The gutter the atom guarantees, less glyph side-bearing slack.
        let minimumClearance: CGFloat = 4
        let pdf = RemittanceAdviceLayout.build(Self.singleForm(details: [Self.wrapRow]))

        #if canImport(PDFKit)
        let page = try Self.firstPage(pdf)
        let boxes = try Self.cellBoxes([[Self.unbrokenToken, Self.longReference], [Self.wrapDate]], on: page)
        #expect(boxes[0].height > PaymentDocumentBlocks.allocationCellFontSize * 1.5, "the document cell did not wrap")
        let clearance = boxes[1].minX - boxes[0].maxX
        #expect(clearance >= minimumClearance, "document → date: \(clearance) pt")
        #endif

        // HTML: every cell may wrap, none is clipped or held on one line. The
        // slice stops at the totals — or at the next page box, whichever comes
        // first, because every page div itself carries `overflow:hidden`.
        let labels = Self.labels
        let html = pdf.renderHTML()
        let section = try #require(html.components(separatedBy: ">" + labels.settledDocumentsTitle + "<").dropFirst().first)
            .components(separatedBy: ">" + labels.totalTransferredLabel + "<")[0]
            .components(separatedBy: "<div class=\"page\"")[0]
        #expect(section.contains("word-wrap:break-word"))
        #expect(!section.contains("white-space:nowrap"))
        #expect(!section.contains("overflow:hidden"))
        for needle in [Self.unbrokenToken, Self.longReference, Self.wrapDate] {
            #expect(section.contains(needle), "\(needle) missing from the detail section")
        }

        // Page-fit accounting grows with every stacked line.
        let width = PageSize.a4.width - InvoiceTheme.standard.pageMargins * 2
        let oneLine = PaymentDocumentBlocks.allocationRowHeight(
            stacked: [["INV-1"], [""], [""], [""], [""], [""]], contentWidth: width)
        let stacked = PaymentDocumentBlocks.allocationRowHeight(
            stacked: [["INV-1", "Invoice", "VBILL1", "VPMT1"], [""], [""], [""], [""], [""]], contentWidth: width)
        #expect(stacked >= oneLine + PaymentDocumentBlocks.allocationSubLineFontSize * 1.25)

        #if canImport(PDFKit)
        try Self.controlTableOverprints(minimumClearance: minimumClearance, contentWidth: width)
        #endif
    }

    #if canImport(PDFKit)
    /// Red control for `-249`: the same reader over the kit's single-line
    /// hairline table, with the atom's six widths, finds the long token
    /// reaching the date cell.
    static func controlTableOverprints(minimumClearance: CGFloat, contentWidth: CGFloat) throws {
        let widths = PaymentDocumentBlocks.allocationColumnWidths(contentWidth: contentWidth)
        let control = try Self.firstPage(PDF(pages: [Page {
            Table(data: [[Self.unbrokenToken, Self.wrapDate, "", "", "", ""]],
                  style: DocumentLayoutKit.hairlineTableStyle(
                    theme: .standard, headerFontSize: 9, cellFontSize: 9),
                  showHeader: true) {
                Column("Document", width: .fixed(widths[0]))
                Column("Date", width: .fixed(widths[1]))
                Column("Total", width: .fixed(widths[2]), alignment: .trailing)
                Column("Other", width: .fixed(widths[3]), alignment: .trailing)
                Column("Applied", width: .fixed(widths[4]), alignment: .trailing)
                Column("Remaining", width: .fixed(widths[5]), alignment: .trailing)
            }
        }]))
        // PDFKit partitions abutting runs, so an overprint reads as a ~0 pt
        // clearance, not a negative one — the threshold, not the sign, is what
        // separates the two layouts.
        let boxes = try Self.cellBoxes([[Self.unbrokenToken], [Self.wrapDate]], on: control)
        #expect(boxes[1].minX - boxes[0].maxX < minimumClearance,
                "the token cleared the date: \(boxes[1].minX - boxes[0].maxX) pt")
    }
    #endif

    // MARK: Test -250

    /// `QA-UNIT06-DOCUMENTS-250`
    @Test("-250 the stacked atom with one line per cell renders the receipt's allocation table byte for byte")
    func stackedAtomEqualsTheReceiptAtom() throws {
        let labels = PaymentReceiptLabels.english
        let common = CommonDocumentLabels.english
        // Demo16's three allocation rows, through the receipt's own row builder.
        let receiptRows = [
            PaymentReceiptAllocationRow(
                documentNumber: "INV-2026-001", documentDate: "2026-01-10",
                documentCurrencyCode: "EUR", documentTotal: 1_210, paidByOtherPayments: 0,
                appliedAmount: 1_210, remaining: 0, isSettled: true),
            PaymentReceiptAllocationRow(
                documentNumber: "INV-2026-ANTWERP-HQ-000004", documentDate: "2026-01-14",
                documentCurrencyCode: "EUR", documentTotal: 2_420, paidByOtherPayments: 400,
                appliedAmount: 1_000, remaining: 1_020, isSettled: false),
            PaymentReceiptAllocationRow(
                documentNumber: "INV-2026-007", documentDate: "2026-01-20",
                documentCurrencyCode: "USD", documentTotal: 650, paidByOtherPayments: nil,
                appliedAmount: 552.60, appliedInDocumentCurrency: 600, exchangeRate: 1.0858,
                remaining: nil, isSettled: false),
        ]
        let rows = PaymentDocumentBlocks.allocationDisplayRows(
            receiptRows, paymentCurrencyCode: "EUR", labels: labels, locale: Locale(identifier: "en_US"))
            .flatMap { $0 }
        #expect(rows.count == 4)
        let header = [
            labels.allocationColumnDocument, labels.allocationColumnDocumentDate,
            labels.allocationColumnDocumentTotal, labels.allocationColumnOtherPayments,
            labels.allocationColumnApplied, labels.allocationColumnRemaining,
        ].map { [$0] }

        func receipt(_ rows: [[String]], continued: Bool) -> PDF {
            PDF(pages: [Page {
                for item in PaymentDocumentBlocks.allocationTable(
                    rows, labels: labels, common: common, theme: .standard, continued: continued) { item }
            }])
        }
        func stacked(_ rows: [[[String]]], continued: Bool) -> PDF {
            PDF(pages: [Page {
                for item in PaymentDocumentBlocks.allocationTable(
                    stackedRows: rows, title: labels.allocationSectionTitle, header: header,
                    emptyRow: labels.allocationEmptyRow, common: common, theme: .standard,
                    continued: continued) { item }
            }])
        }

        for subject in [rows, []] {
            for continued in [false, true] {
                let lhs = receipt(subject, continued: continued)
                let rhs = stacked(subject.map { $0.map { [$0] } }, continued: continued)
                #expect(lhs.renderHTML() == rhs.renderHTML(), "rows \(subject.count), continued \(continued)")
                #if canImport(PDFKit)
                let lhsText = try Self.firstPage(lhs).string
                let rhsText = try Self.firstPage(rhs).string
                #expect(lhsText != nil && lhsText == rhsText, "CG text, rows \(subject.count), continued \(continued)")
                #endif
            }
        }

        // Positive control: a second line in one cell is not the receipt's table.
        var twoLines = rows.map { $0.map { [$0] } }
        twoLines[0][0].append("Invoice")
        #expect(receipt(rows, continued: false).renderHTML() != stacked(twoLines, continued: false).renderHTML())
    }
}
