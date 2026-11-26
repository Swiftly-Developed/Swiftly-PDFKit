import Foundation
import Testing
@testable import SwiftlyPDFKit
#if canImport(PDFKit)
import PDFKit
#endif

// MARK: - Phase 00c

/// `QA-UNIT06-DOCUMENTS-185` — PRINT02 phase 00c: no allocation-table cell
/// reaches its neighbour on the CoreGraphics path, and none is clipped or held
/// on one line on the HTML path.
///
/// The CoreGraphics leg reads the **drawn** layout back: it renders the
/// receipt to PDF bytes, opens them with PDFKit and takes the drawn box of
/// each cell's text (a text selection's bounds), then requires every two adjacent
/// cells of a row to stand apart. The same reader run over the hairline
/// `Table` the allocation section used before this phase is the red control:
/// it must find the overlap the phase-02 smoke saw.
extension PaymentReceiptDocumentLayoutTests {

    /// The nl and de catalog headers (`SharedPaymentPDF.xcstrings`), the two
    /// locales whose "Total" / "Other payments" headers nearly touched.
    static func labels(isDutch: Bool) -> PaymentReceiptLabels {
        var labels = PaymentReceiptLabels.english
        labels.allocationColumnDocument = "Document"
        labels.allocationColumnDocumentDate = "Datum"
        labels.allocationColumnDocumentTotal = isDutch ? "Totaal" : "Gesamtbetrag"
        labels.allocationColumnOtherPayments = isDutch ? "Overige betalingen" : "Weitere Zahlungen"
        labels.allocationColumnApplied = isDutch ? "Toegewezen" : "Zugeordnet"
        labels.allocationColumnRemaining = isDutch ? "Openstaand" : "Offen"
        return labels
    }

    /// The phase-02 smoke's 24-character number, and a run with no break
    /// opportunity at all (wider than the column on its own).
    static let longNumber = "INV-QA-UI05-FINALIZED-BE"
    static let unbrokenNumber = "INVQAUIFINALIZEDBEXWZ20260001"

    static let overflowRows = [
        PaymentReceiptAllocationRow(
            documentNumber: longNumber, documentDate: "Mar 2, 2026",
            documentCurrencyCode: "EUR", documentTotal: 242, paidByOtherPayments: 11,
            appliedAmount: 133, remaining: 98, isSettled: false),
        PaymentReceiptAllocationRow(
            documentNumber: unbrokenNumber, documentDate: "Oct 12, 2026",
            documentCurrencyCode: "EUR", documentTotal: 484, paidByOtherPayments: 0,
            appliedAmount: 200, remaining: 284, isSettled: false),
    ]

    /// Per row, per column: the needles whose glyphs make up that cell.
    static func headerNeedles(isDutch: Bool) -> [[String]] {
        isDutch
            ? [["Document"], ["Datum"], ["Totaal"], ["Overige", "betalingen"], ["Toegewezen"], ["Openstaand"]]
            : [["Document"], ["Datum"], ["Gesamtbetrag"], ["Weitere", "Zahlungen"], ["Zugeordnet"], ["Offen"]]
    }

    static let longRowNeedles: [[String]] = [
        [longNumber], ["Mar 2, 2026"], ["242.00 EUR"], ["11.00 EUR"], ["133.00 EUR"], ["98.00 EUR"],
    ]

    static let unbrokenRowNeedles: [[String]] = [[unbrokenNumber], ["Oct 12, 2026"]]

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
        // `characterBounds(at:)` is NOT indexed like `page.string` (measured:
        // its boxes drift by several glyphs per line); a selection over the
        // string's own range is.
        let first = indices[start], last = indices[start + target.count - 1]
        return page.selection(for: NSRange(location: first, length: last - first + 1))?
            .bounds(for: page)
    }

    /// For each pair of adjacent cells that share a band of the page, the
    /// horizontal clearance between them (negative = overlap), in reading
    /// order. Every needle must be found exactly once.
    static func clearances(_ cells: [[String]], on page: PDFPage) throws -> [CGFloat] {
        let boxes: [CGRect] = try cells.map { needles in
            try needles.reduce(CGRect.null) { box, needle in
                box.union(try #require(drawnBounds(of: needle, on: page), "\(needle) not drawn once"))
            }
        }
        return zip(boxes, boxes.dropFirst()).map { $1.minX - $0.maxX }
    }

    static func firstPage(_ pdf: PDF) throws -> PDFPage {
        let document = try #require(PDFDocument(data: try pdf.render()))
        return try #require(document.page(at: 0))
    }
    #endif

    // MARK: Test -185

    /// `QA-UNIT06-DOCUMENTS-185`
    @Test("-185 a long document number and the nl / de headers wrap inside their columns on both paths")
    func allocationCellsNeverReachTheirNeighbour() throws {
        // The gutter the fix guarantees, less glyph side-bearing slack.
        let minimumClearance: CGFloat = 4

        for isDutch in [true, false] {
            let labels = Self.labels(isDutch: isDutch)
            let document = PaymentReceiptDocument(
                supplier: Self.supplier, payer: Self.payer, header: Self.header,
                paymentFacts: Self.facts, allocations: Self.overflowRows, totals: Self.totals,
                reversal: nil, notes: nil, labels: labels, common: .english)
            let pdf = PaymentReceiptLayout.build(document)

            #if canImport(PDFKit)
            let page = try Self.firstPage(pdf)
            for row in [Self.headerNeedles(isDutch: isDutch), Self.longRowNeedles, Self.unbrokenRowNeedles] {
                for (index, clearance) in try Self.clearances(row, on: page).enumerated() {
                    #expect(clearance >= minimumClearance,
                            "\(isDutch ? "nl" : "de") \(row[index]) → \(row[index + 1]): \(clearance) pt")
                }
            }
            // The long numbers wrapped (taller than one line) rather than ran on.
            for number in [Self.longNumber, Self.unbrokenNumber] {
                let box = try #require(Self.drawnBounds(of: number, on: page))
                #expect(box.height > PaymentDocumentBlocks.allocationCellFontSize * 1.5, "\(number) did not wrap")
            }
            #endif

            // HTML: every cell may wrap, none is clipped or held on one line.
            let html = pdf.renderHTML()
            let section = try #require(html.components(separatedBy: ">" + labels.allocationSectionTitle + "<").last)
                .components(separatedBy: ">" + labels.totalReceivedLabel + "<")[0]
            #expect(!section.contains("white-space:nowrap"))
            #expect(!section.contains("overflow:hidden"))
            #expect(section.components(separatedBy: "word-wrap:break-word").count - 1 == 6 * 3)
            for needles in Self.longRowNeedles + Self.headerNeedles(isDutch: isDutch) {
                #expect(needles.allSatisfy { section.contains($0) })
            }
        }

        // Page-fit accounting grows with the wrap: a long-number row is
        // estimated taller than a short one, and never shorter than drawn.
        let width = PageSize.a4.width - InvoiceTheme.standard.pageMargins * 2
        let long = PaymentDocumentBlocks.allocationRowHeight(
            [Self.longNumber, "Mar 2, 2026", "242.00 EUR"], contentWidth: width)
        let short = PaymentDocumentBlocks.allocationRowHeight(
            ["INV-0001", "Mar 2, 2026", "242.00 EUR"], contentWidth: width)
        #expect(long >= short + PaymentDocumentBlocks.allocationCellFontSize * 1.25)
        let docWidth = PaymentDocumentBlocks.allocationColumnWidths(contentWidth: width)[0]
        for number in [Self.longNumber, Self.unbrokenNumber] {
            #expect(PaymentDocumentBlocks.estimatedLineCount(number, width: docWidth, fontSize: 9) >= 2)
        }

        #if canImport(PDFKit)
        try Self.controlTableOverprints(minimumClearance: minimumClearance)
        #endif
    }

    #if canImport(PDFKit)
    /// Red control for `-185`: the same reader over the single-line hairline
    /// table the section drew before this phase finds the overlap.
    static func controlTableOverprints(minimumClearance: CGFloat) throws {
        let control = try Self.firstPage(PDF(pages: [Page {
            Table(data: [[Self.longNumber, "Mar 2, 2026", "242.00 EUR", "11.00 EUR", "133.00 EUR", "98.00 EUR"]],
                  style: DocumentLayoutKit.hairlineTableStyle(
                    theme: .standard, headerFontSize: 9, cellFontSize: 9),
                  showHeader: true) {
                Column("Document", width: .flex)
                Column("Datum", width: .fixed(66))
                Column("Totaal", width: .fixed(84), alignment: .trailing)
                Column("Overige betalingen", width: .fixed(84), alignment: .trailing)
                Column("Toegewezen", width: .fixed(84), alignment: .trailing)
                Column("Openstaand", width: .fixed(84), alignment: .trailing)
            }
        }]))
        // PDFKit partitions abutting runs, so an overprint reads as a 0 pt
        // clearance, not a negative one (measured: the number's box ends
        // exactly where the date's begins) — the threshold, not the sign,
        // is what separates the two layouts.
        let controlRow = try Self.clearances(Self.longRowNeedles, on: control)
        #expect(controlRow[0] < minimumClearance, "the number cleared the date: \(controlRow[0]) pt")
        let controlHeader = try Self.clearances(Self.headerNeedles(isDutch: true), on: control)
        #expect(controlHeader[2] < minimumClearance, "Totaal / Overige: \(controlHeader[2]) pt")
    }
    #endif
}
