import Foundation
import Testing
@testable import SwiftlyPDFKit
#if canImport(PDFKit)
import PDFKit
#endif

// MARK: - Stacked description cell wrap

/// The purchase order's description column stacks the description, the line's
/// own expected-delivery date and its note, and every one of them wraps inside
/// the column on both render paths (`PRINT08` phase 00).
///
/// The CoreGraphics leg reads the **drawn** layout back: it renders the order
/// to PDF bytes, opens them with PDFKit and takes the drawn box of each cell's
/// text (a text selection's bounds), then requires every two adjacent cells of
/// the row to stand apart. The same reader run over the kit's single-line
/// hairline `Table` with the same widths is the red control: it must find the
/// overprint the stacked cells exist to prevent.
extension PurchaseOrderDocumentLayoutTests {

    /// A run with no break opportunity at all, wider than the description column.
    static let unbrokenToken = "PUMPHOUSINGGASKETKITSTAINLESS316L"

    static let wrapDescription = serviceDescription + " " + unbrokenToken

    static let wrapLine = PurchaseOrderDocumentLine(
        itemSKU: "PMP-4410", itemName: "Centrifugal pump",
        description: wrapDescription, quantity: 7, unitOfMeasure: "pcs", unitCost: 680,
        taxRatePercent: 21, lineTotal: 4_760, expectedDelivery: "2026-11-20", note: serviceNote)

    /// Per column: the needles whose glyphs make up that cell.
    static let wrapRowNeedles: [[String]] = [
        ["PMP-4410", "Centrifugal pump"],
        [wrapDescription, "Expected 2026-11-20", serviceNote],
        ["7 pcs"],
    ]

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

    /// For each pair of adjacent cells, the horizontal clearance between them
    /// (negative = overlap), in reading order.
    static func clearances(_ cells: [[String]], on page: PDFPage) throws -> [CGFloat] {
        let boxes = try cellBoxes(cells, on: page)
        return zip(boxes, boxes.dropFirst()).map { $1.minX - $0.maxX }
    }

    static func firstPage(_ pdf: PDF) throws -> PDFPage {
        let document = try #require(PDFDocument(data: try pdf.render()))
        return try #require(document.page(at: 0))
    }
    #endif

    // MARK: Test -221

    /// `QA-UNIT06-DOCUMENTS-221`
    @Test("-221 the stacked description cell wraps inside its column on both paths")
    func descriptionCellWrapsInsideItsColumn() throws {
        // The gutter the layout guarantees, less glyph side-bearing slack.
        let minimumClearance: CGFloat = 4
        let pdf = PurchaseOrderLayout.build(Self.document(lines: [Self.wrapLine], watermark: .none))

        #if canImport(PDFKit)
        let page = try Self.firstPage(pdf)
        for (index, clearance) in try Self.clearances(Self.wrapRowNeedles, on: page).enumerated() {
            #expect(clearance >= minimumClearance,
                    "\(Self.wrapRowNeedles[index]) → \(Self.wrapRowNeedles[index + 1]): \(clearance) pt")
        }
        let description = try #require(Self.drawnBounds(of: Self.wrapDescription, on: page))
        #expect(description.height > PurchaseOrderLayout.lineCellFontSize * 1.5, "the description did not wrap")
        #endif

        // HTML: every cell may wrap, none is clipped or held on one line. The
        // slice stops before the tax breakdown — or at the next page box, when
        // the closing blocks moved to a page of their own — because every page
        // div itself carries `overflow:hidden`.
        let labels = Self.labels
        let html = pdf.renderHTML()
        let section = try #require(html.components(separatedBy: ">" + labels.linesColumnItem + "<").last)
            .components(separatedBy: ">" + labels.taxBreakdownHeader + "<")[0]
            .components(separatedBy: "<div class=\"page\"")[0]
        #expect(section.contains("word-wrap:break-word"))
        #expect(!section.contains("white-space:nowrap"))
        #expect(!section.contains("overflow:hidden"))
        for needle in Self.wrapRowNeedles.flatMap({ $0 }) {
            #expect(section.contains(needle), "\(needle) missing from the lines section")
        }

        // Page-fit accounting grows with the wrap.
        let width = PageSize.a4.width - InvoiceTheme.standard.pageMargins * 2
        let fmt = DocumentFormatter(theme: .standard)
        let locale = Locale(identifier: "en_US")
        let long = PurchaseOrderLayout.lineRowHeight(
            PurchaseOrderLayout.lineCells(Self.wrapLine, labels: labels, fmt: fmt, locale: locale),
            contentWidth: width)
        let short = PurchaseOrderLayout.lineRowHeight(
            PurchaseOrderLayout.lineCells(
                PurchaseOrderDocumentLine(description: "Gasket", quantity: 1, unitCost: 1, lineTotal: 1),
                labels: labels, fmt: fmt, locale: locale),
            contentWidth: width)
        #expect(long >= short + PurchaseOrderLayout.lineCellFontSize * 1.25)

        #if canImport(PDFKit)
        try Self.controlTableOverprints(minimumClearance: minimumClearance, contentWidth: width)
        #endif
    }

    #if canImport(PDFKit)
    /// Red control for `-221`: the same reader over the kit's single-line
    /// hairline table, with the same seven widths, finds the unbroken token
    /// reaching the quantity cell.
    static func controlTableOverprints(minimumClearance: CGFloat, contentWidth: CGFloat) throws {
        let widths = PurchaseOrderLayout.lineColumnWidths(contentWidth: contentWidth)
        let control = try Self.firstPage(PDF(pages: [Page {
            Table(data: [["PMP-4410", Self.unbrokenToken, "7 pcs", "680.00", "", "21%", "4,760.00"]],
                  style: DocumentLayoutKit.hairlineTableStyle(
                    theme: .standard, headerFontSize: 9, cellFontSize: 9),
                  showHeader: true) {
                Column("Item", width: .fixed(widths[0]))
                Column("Description", width: .fixed(widths[1]))
                Column("Qty", width: .fixed(widths[2]), alignment: .trailing)
                Column("Unit price", width: .fixed(widths[3]), alignment: .trailing)
                Column("Discount", width: .fixed(widths[4]), alignment: .trailing)
                Column("VAT %", width: .fixed(widths[5]), alignment: .trailing)
                Column("Amount", width: .fixed(widths[6]), alignment: .trailing)
            }
        }]))
        // PDFKit partitions abutting runs, so an overprint reads as a ~0 pt
        // clearance, not a negative one — the threshold, not the sign, is what
        // separates the two layouts.
        let controlRow = try Self.clearances([["PMP-4410"], [Self.unbrokenToken], ["7 pcs"]], on: control)
        #expect(controlRow[1] < minimumClearance, "the token cleared the quantity: \(controlRow[1]) pt")
    }
    #endif
}
