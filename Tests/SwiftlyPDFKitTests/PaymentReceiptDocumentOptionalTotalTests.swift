import Foundation
import Testing
@testable import SwiftlyPDFKit
#if canImport(PDFKit)
import PDFKit
#endif

// MARK: - Phase 00d

/// `QA-UNIT06-DOCUMENTS-186` — PRINT02 phase 00d (§25 #31): a withheld
/// document total is `nil` and prints "—" in the Total cell; a withheld
/// document date is passed as the string "—" and prints in the Date cell; a
/// `nil` date stays an empty cell. Nothing else on the receipt changes.
extension PaymentReceiptDocumentLayoutTests {

    static func withheldRow(total: Double?, date: String?) -> PaymentReceiptAllocationRow {
        PaymentReceiptAllocationRow(
            documentNumber: "INV-2026-0102", documentDate: date,
            documentCurrencyCode: "EUR", documentTotal: total, paidByOtherPayments: 400,
            appliedAmount: 1_000, remaining: 1_020, isSettled: false)
    }

    static func html(_ row: PaymentReceiptAllocationRow) -> String {
        PaymentReceiptLayout.build(Self.document(allocations: [row])).renderHTML()
    }

    // MARK: Test -186

    /// `QA-UNIT06-DOCUMENTS-186`
    @Test("-186 a withheld document total or date prints a dash in that cell only, on both paths")
    func withheldTotalAndDatePrintADash() throws {
        let dash = "—"
        let total = "2,420.00 EUR", date = "Jan 14, 2026"
        let control = Self.html(Self.withheldRow(total: 2_420, date: date))

        // Red control: the row with every value prints no dash, so a dash
        // counted below is the withheld cell's.
        #expect(Self.count(dash, in: control) == 0)
        #expect(Self.count(total, in: control) == 1)
        #expect(Self.count(date, in: control) == 1)

        // A nil total: exactly the Total cell changes — the HTML is the
        // control's with that one cell's text swapped.
        let noTotal = Self.html(Self.withheldRow(total: nil, date: date))
        #expect(Self.count(dash, in: noTotal) == 1)
        #expect(Self.count(total, in: noTotal) == 0)
        #expect(noTotal.replacingOccurrences(of: ">\(dash)<", with: ">\(total)<") == control)

        // A withheld date ("—"): exactly the Date cell changes.
        let noDate = Self.html(Self.withheldRow(total: 2_420, date: dash))
        #expect(Self.count(dash, in: noDate) == 1)
        #expect(noDate.replacingOccurrences(of: ">\(dash)<", with: ">\(date)<") == control)

        // A nil date is a genuinely undated document: an empty cell, no dash.
        let undated = Self.html(Self.withheldRow(total: 2_420, date: nil))
        #expect(Self.count(dash, in: undated) == 0)
        #expect(Self.count(date, in: undated) == 0)

        #if canImport(PDFKit)
        try Self.drawnDashSitsInItsColumn(dash: dash)
        #endif
    }

    #if canImport(PDFKit)
    /// The CoreGraphics leg of `-186`: the dash is drawn once, between the
    /// neighbouring cells of the column it stands for, and the row's other
    /// cells still draw their values.
    static func drawnDashSitsInItsColumn(dash: String) throws {
        // The nl headers (as in `-185`): "Datum" / "Totaal" / "Overige" are
        // each drawn once, where the English "Total" also heads the totals stack.
        let labels = Self.labels(isDutch: true)
        let both = PaymentReceiptLayout.build(PaymentReceiptDocument(
            supplier: Self.supplier, payer: Self.payer, header: Self.header,
            paymentFacts: Self.facts,
            allocations: [withheldRow(total: nil, date: "Jan 14, 2026"), withheldRow(total: 2_420, date: dash)],
            totals: Self.totals, reversal: nil, notes: nil, labels: labels, common: .english))
        let page = try Self.firstPage(both)
        let text = page.string ?? ""
        #expect(text.components(separatedBy: dash).count - 1 == 2)

        let control = try Self.firstPage(PaymentReceiptLayout.build(
            Self.document(allocations: [withheldRow(total: 2_420, date: "Jan 14, 2026")])))
        #expect(!(control.string ?? "").contains(dash))

        // Column bands, read from the header: the Total cell sits between the
        // Date and Other-payments headers, the Date cell between Document and Total.
        func header(_ caption: String) throws -> CGRect {
            try #require(drawnBounds(of: caption, on: page), "\(caption) not drawn once")
        }
        let dateHeader = try header(labels.allocationColumnDocumentDate)
        let totalHeader = try header(labels.allocationColumnDocumentTotal)
        let otherHeader = try header("Overige")

        let dashes = dashBoxes(dash, on: page)
        try #require(dashes.count == 2)
        // Rows draw top-down; PDF y grows upward, so the first row is the higher box.
        let sorted = dashes.sorted { $0.midY > $1.midY }
        let totalDash = sorted[0], dateDash = sorted[1]
        #expect(totalDash.minX > dateHeader.maxX && totalDash.maxX <= totalHeader.maxX + 1,
                "total dash at \(totalDash) outside the Total column")
        #expect(totalDash.maxX < otherHeader.minX)
        #expect(dateDash.minX >= dateHeader.minX - 1 && dateDash.maxX < totalHeader.minX,
                "date dash at \(dateDash) outside the Date column")
    }

    /// The drawn box of every occurrence of `needle` on `page`.
    static func dashBoxes(_ needle: String, on page: PDFPage) -> [CGRect] {
        let text = (page.string ?? "") as NSString
        var boxes: [CGRect] = []
        var range = text.range(of: needle)
        while range.location != NSNotFound {
            if let box = page.selection(for: range)?.bounds(for: page) { boxes.append(box) }
            let next = range.location + range.length
            range = text.range(of: needle, range: NSRange(location: next, length: text.length - next))
        }
        return boxes
    }
    #endif
}
