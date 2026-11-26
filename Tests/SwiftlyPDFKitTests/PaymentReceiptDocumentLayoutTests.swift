import Foundation
import Testing
@testable import SwiftlyPDFKit

/// `QA-UNIT06-DOCUMENTS-164` … `-169` — the payment-receipt family `PRINT02`
/// phase 00 authored: its label set, its model and `PaymentReceiptLayout`;
/// `-184` is phase 00b's (the optional allocation cells).
///
/// Authoring rules carried from `DocumentLayoutKitTests`: assert the
/// **rendered output** of both paths, never the construction, and assert the
/// **omissions** (no VAT surface, no watermark on an unreversed payment, no
/// charge rows when there are none), not only the positives. HTML assertions
/// count **delimited** forms (`>caption<`), because several captions are
/// substrings of others (`Applied to` ⊂ `Applied to documents`, `Total` ⊂
/// `Total received`).
///
/// The type name deliberately carries the token `Document` so the suite
/// manifest's §2 grep reaches it.
@Suite("Payment receipt document layout")
struct PaymentReceiptDocumentLayoutTests {

    // MARK: Fixtures

    static let supplier = InvoiceSupplier(
        name: "Swiftly Business Consulting",
        street: "Posthofbrug 34",
        city: "2600 Antwerpen",
        country: "Belgium",
        vatNumber: "BE0778405303",
        email: "billing@example.com",
        iban: "BE68 5390 0754 7034",
        bic: "GEBABEBB"
    )

    static let payer = PaymentReceiptPayer(
        party: InvoiceParty(
            name: "Nordwind Logistics NV",
            street: "Havenlaan 12",
            city: "1000 Brussel",
            country: "Belgium",
            vatNumber: "BE0123456789"),
        registerNumber: "0123.456.789",
        customerReference: "C-042")

    static let header = PaymentReceiptHeader(receiptNumber: "RCPT-2026-0007", receiptDate: "Feb 19, 2026")

    static let facts = [
        PaymentReceiptFact(caption: "Payment date", value: "Feb 18, 2026"),
        PaymentReceiptFact(caption: "Payment method", value: "SEPA credit transfer"),
        PaymentReceiptFact(caption: "Bank reference", value: "BNK-88231"),
        PaymentReceiptFact(caption: "End-to-end ID", value: "E2E-2026-0007"),
    ]

    /// One settled, one partial, one in a foreign currency (with its rate sub-row).
    static let allocations = [
        PaymentReceiptAllocationRow(
            documentNumber: "INV-2026-0101", documentDate: "Jan 10, 2026",
            documentCurrencyCode: "EUR", documentTotal: 1_210, paidByOtherPayments: 0,
            appliedAmount: 1_210, remaining: 0, isSettled: true),
        PaymentReceiptAllocationRow(
            documentNumber: "INV-2026-0102", documentDate: "Jan 14, 2026",
            documentCurrencyCode: "EUR", documentTotal: 2_420, paidByOtherPayments: 400,
            appliedAmount: 1_000, remaining: 1_020, isSettled: false),
        PaymentReceiptAllocationRow(
            documentNumber: "INV-2026-0103", documentDate: "Jan 20, 2026",
            documentCurrencyCode: "USD", documentTotal: 650, paidByOtherPayments: 0,
            appliedAmount: 552.60, appliedInDocumentCurrency: 600, exchangeRate: 1.0858,
            remaining: 50, isSettled: false),
    ]

    static let totals = PaymentReceiptTotals(
        currencyCode: "EUR", received: 3_000, allocated: 2_762.60, unallocated: 237.40,
        charges: [PaymentReceiptCharge(amount: 2.50, currencyCode: "EUR")])

    static func document(
        allocations: [PaymentReceiptAllocationRow] = allocations,
        totals: PaymentReceiptTotals = totals,
        reversal: PaymentReceiptReversal? = nil,
        notes: String? = "Thank you for your payment.",
        common: CommonDocumentLabels = .english
    ) -> PaymentReceiptDocument {
        PaymentReceiptDocument(
            supplier: supplier, payer: payer, header: header, paymentFacts: facts,
            allocations: allocations, totals: totals, reversal: reversal, notes: notes,
            labels: .english, common: common)
    }

    static let labels = PaymentReceiptLabels.english

    static let reasonCodes = [
        "MD01", "MD02", "MD06", "MD07", "AC01", "AC04", "AC06", "AC13",
        "AM05", "MS02", "MS03", "RR01", "RR02", "RR03", "RR04", "FF01",
    ]

    /// `>text<` occurrences — the delimited form of a rendered caption or cell.
    static func count(_ text: String, in html: String) -> Int {
        html.components(separatedBy: ">" + text + "<").count - 1
    }

    /// The HTML of each page, split on the page-box marker `Page.renderHTML` emits.
    static func pageSegments(_ html: String) -> [String] {
        Array(html.components(separatedBy: "<div class=\"page\"").dropFirst())
    }

    // MARK: Test -164

    /// `QA-UNIT06-DOCUMENTS-164`
    @Test("-164 the label set has exactly 60 non-empty members and its helpers expand / resolve")
    func labelSetShapeAndHelpers() {
        let children = Mirror(reflecting: Self.labels).children
        #expect(children.count == 60)
        for child in children {
            let value = child.value as? String
            #expect(value != nil, "\(child.label ?? "?") is not a String")
            #expect(value?.isEmpty == false, "\(child.label ?? "?") is empty")
        }

        #expect(Self.labels.cardEnding(last4: "4242") == "Card ending in 4242")
        #expect(Self.labels.exchangeRate("1.0858") == "Rate 1.0858")
        #expect(Self.labels.reversedNotice(reason: "X") == "This payment was reversed: X")
        var reordered = PaymentReceiptLabels()
        reordered.cardEndingFormat = "{last4} (card)"
        reordered.exchangeRateFormat = "{rate} = rate"
        reordered.reversedNoticeFormat = "{reason} — reversed"
        #expect(reordered.cardEnding(last4: "4242") == "4242 (card)")
        #expect(reordered.exchangeRate("2") == "2 = rate")
        #expect(reordered.reversedNotice(reason: "X") == "X — reversed")

        let byLabel = Dictionary(uniqueKeysWithValues: children.compactMap { child in
            child.label.map { ($0, child.value as? String ?? "") }
        })
        var resolved: Set<String> = []
        for code in Self.reasonCodes {
            let value = Self.labels.reversalReason(forCode: code)
            #expect(value == byLabel["reversalReason" + code], "code \(code)")
            resolved.insert(value)
        }
        #expect(resolved.count == 16)
        #expect(Self.labels.reversalReason(forCode: "md01") == Self.labels.reversalReasonMD01)
        #expect(Self.labels.reversalReason(forCode: " MD01 ") == Self.labels.reversalReasonMD01)
        #expect(Self.labels.reversalReason(forCode: "ZZ99") == "ZZ99")

        let means: [(String, String)] = [
            ("10", Self.labels.paymentMeansCash),
            ("20", Self.labels.paymentMeansCheck),
            ("30", Self.labels.paymentMeansCreditTransfer),
            ("42", Self.labels.paymentMeansOnlinePayment),
            ("48", Self.labels.paymentMeansCard),
            ("49", Self.labels.paymentMeansDirectDebit),
            ("58", Self.labels.paymentMeansSEPACreditTransfer),
            ("59", Self.labels.paymentMeansSEPADirectDebit),
        ]
        for (code, expected) in means {
            #expect(Self.labels.paymentMeansLabel(forCode: code) == expected, "code \(code)")
        }
        #expect(Set(means.map(\.1)).count == 8)
        #expect(Self.labels.paymentMeansLabel(forCode: "31") == nil)
        #expect(Self.labels.paymentMeansLabel(forCode: "") == nil)
        #expect(Self.labels.paymentMeansLabel(forCode: nil) == nil)
    }

    // MARK: Test -165

    /// `QA-UNIT06-DOCUMENTS-165`
    @Test("-165 the full receipt renders through both paths with every block present")
    func fullReceiptRendersBothPaths() throws {
        let pdf = PaymentReceiptLayout.build(Self.document())
        let floor = try PDF(pages: [Page {}]).render()
        let cgBytes = try pdf.render()
        let html = pdf.renderHTML()

        #expect(cgBytes.count > floor.count)
        #expect(!html.isEmpty)
        #expect(pdf.pages.count == 1)

        let labels = Self.labels
        for text in [
            labels.paymentReceiptTitle, Self.header.receiptNumber, Self.payer.party.name,
            "INV-2026-0101", "INV-2026-0102", "INV-2026-0103",
            labels.exchangeRate("1.0858"),
            labels.totalReceivedLabel, labels.totalAllocatedLabel, labels.totalUnallocatedLabel,
            labels.allocationSettledMarker, labels.notAnInvoiceFooter,
            CommonDocumentLabels.english.pageNumber(1, of: 1),
        ] {
            #expect(Self.count(text, in: html) >= 1, "missing \(text)")
        }
        // The foreign-currency row prints its own code, the sub-row the amount
        // applied in that currency.
        #expect(Self.count("600.00 USD", in: html) == 1)
        #expect(Self.count("552.60 EUR", in: html) == 1)
    }

    // MARK: Test -166

    /// `QA-UNIT06-DOCUMENTS-166`
    @Test("-166 empty allocations, a zero remainder and charges render as stated")
    func emptyAndZeroStates() {
        let zero = PaymentReceiptTotals(currencyCode: "EUR", received: 500, allocated: 500, unallocated: 0)
        let html = PaymentReceiptLayout.build(Self.document(allocations: [], totals: zero)).renderHTML()
        let labels = Self.labels

        #expect(Self.count(labels.allocationEmptyRow, in: html) == 1)
        for caption in [
            labels.allocationColumnDocument, labels.allocationColumnDocumentDate,
            labels.allocationColumnDocumentTotal, labels.allocationColumnOtherPayments,
            labels.allocationColumnApplied, labels.allocationColumnRemaining,
        ] {
            #expect(Self.count(caption, in: html) >= 1, "missing column \(caption)")
        }
        let fmt = DocumentFormatter(theme: .standard, locale: Locale(identifier: "en_US"), currencyCode: "EUR")
        #expect(Self.count(labels.totalUnallocatedLabel, in: html) == 1)
        #expect(Self.count(fmt.money(0), in: html) == 1)
        #expect(Self.count(labels.bankChargesLabel, in: html) == 0)

        let twoCharges = PaymentReceiptTotals(
            currencyCode: "EUR", received: 500, allocated: 500, unallocated: 0,
            charges: [PaymentReceiptCharge(amount: 2.5, currencyCode: "EUR"),
                      PaymentReceiptCharge(amount: 3, currencyCode: "USD")])
        let charged = PaymentReceiptLayout.build(Self.document(totals: twoCharges)).renderHTML()
        #expect(Self.count(labels.bankChargesLabel, in: charged) == 2)
        // A charge prints in its own currency.
        let usd = DocumentFormatter(theme: .standard, locale: Locale(identifier: "en_US"), currencyCode: "USD")
        #expect(Self.count(usd.money(3), in: charged) == 1)
    }

    // MARK: Test -167

    /// `QA-UNIT06-DOCUMENTS-167`
    @Test("-167 the watermark and notice appear iff the payment was reversed")
    func reversalWatermarkAndNotice() {
        let labels = Self.labels
        let notice = labels.reversedNotice(reason: labels.reversalReasonMD06)

        let reversed = PaymentReceiptLayout.build(
            Self.document(reversal: PaymentReceiptReversal(reasonCode: "MD06"))).renderHTML()
        #expect(reversed.contains("class=\"watermark\""))
        #expect(Self.count(labels.reversedWatermark, in: reversed) >= 1)
        #expect(Self.count(notice, in: reversed) == 1)

        let plain = PaymentReceiptLayout.build(Self.document()).renderHTML()
        #expect(!plain.contains("class=\"watermark\""))
        #expect(Self.count(labels.reversedWatermark, in: plain) == 0)
        #expect(Self.count(notice, in: plain) == 0)

        let noReason = PaymentReceiptLayout.build(
            Self.document(reversal: PaymentReceiptReversal(reasonCode: nil))).renderHTML()
        #expect(noReason.contains("class=\"watermark\""))
        #expect(Self.count(labels.reversedWatermark, in: noReason) >= 1)
        #expect(!noReason.contains(labels.reversedNotice(reason: "")))
    }

    // MARK: Test -168

    /// `QA-UNIT06-DOCUMENTS-168`
    @Test("-168 no VAT surface: the shared totals captions never reach the receipt")
    func noVATSurface() {
        let sentinels = CommonDocumentLabels(
            totalsSubtotalLabel: "SENTINEL-SUBTOTAL",
            totalsTaxLabel: "SENTINEL-TAX",
            totalsTotalLabel: "SENTINEL-TOTAL")
        let html = PaymentReceiptLayout.build(Self.document(common: sentinels)).renderHTML()
        for sentinel in ["SENTINEL-SUBTOTAL", "SENTINEL-TAX", "SENTINEL-TOTAL"] {
            #expect(!html.contains(sentinel), "\(sentinel) leaked into the receipt")
        }

        // Positive control: the kit's ladder renders the same sentinels, so the
        // absence above is not vacuous.
        let ladder = DocumentLayoutKit.totalsBlock(
            totals: InvoiceTotals(subtotalExcl: 100, totalVat: 21, totalIncl: 121),
            labels: sentinels,
            formatter: DocumentFormatter(theme: .standard),
            theme: .standard)
        let control = PDF(pages: [Page { for item in ladder { item } }]).renderHTML()
        #expect(control.contains("SENTINEL-TAX"))
    }

    // MARK: Test -169

    /// `QA-UNIT06-DOCUMENTS-169`
    @Test("-169 the footer reads common, and a long receipt paginates with a repeated header")
    func footerAndPagination() throws {
        var common = CommonDocumentLabels()
        common.pageNumberTemplate = "Blz {page}/{pages}"
        let many = (1...60).map { index in
            PaymentReceiptAllocationRow(
                documentNumber: "INV-" + String(repeating: "0", count: 4 - String(index).count) + String(index),
                documentDate: "Jan 10, 2026", documentCurrencyCode: "EUR",
                documentTotal: 100, paidByOtherPayments: 0, appliedAmount: 50,
                remaining: 50, isSettled: false)
        }
        let pdf = PaymentReceiptLayout.build(Self.document(allocations: many, common: common))
        let html = pdf.renderHTML()
        let pages = Self.pageSegments(html)
        let pageCount = pages.count
        let labels = Self.labels

        #expect(pageCount > 1)
        #expect(pageCount == pdf.pages.count)
        #expect(Self.count("Blz 1/\(pageCount)", in: html) == 1)
        #expect(Self.count("Blz \(pageCount)/\(pageCount)", in: html) == 1)
        #expect(Self.count(labels.allocationSectionTitle + " — " + common.continuedLabel, in: html) >= 1)

        for (index, page) in pages.enumerated() {
            let carriesRows = page.contains(">INV-0")
            #expect(Self.count(labels.allocationColumnDocument, in: page) == (carriesRows ? 1 : 0),
                    "page \(index + 1)")
        }
        let last = try #require(pages.last)
        for caption in [labels.totalReceivedLabel, labels.totalAllocatedLabel, labels.totalUnallocatedLabel] {
            #expect(Self.count(caption, in: html) == 1, "\(caption)")
            #expect(Self.count(caption, in: last) == 1, "\(caption) not on the last page")
        }
        for row in many {
            #expect(Self.count(row.documentNumber, in: html) == 1, "\(row.documentNumber) lost")
        }
    }
}

// MARK: - Phase 00b

/// The optional allocation cells sit in an extension of the same `@Suite`, so
/// the struct body stays inside `type_body_length`.
extension PaymentReceiptDocumentLayoutTests {

    // MARK: Test -184

    /// `QA-UNIT06-DOCUMENTS-184` — PRINT02 phase 00b (§25 #27): a figure the
    /// mapper cannot state in the document's currency is `nil` and prints "—";
    /// a `nil` remaining figure never prints the settled marker.
    @Test("-184 a row with no other-payments or remaining figure prints a dash in both cells and no settled marker")
    func unavailableFiguresPrintADash() throws {
        let dash = "—"
        let labels = Self.labels

        // Arming: the fixture's rows all carry figures, so a dash counted below
        // belongs to the subject row, not to the fixture.
        let fixture = PaymentReceiptLayout.build(Self.document()).renderHTML()
        #expect(Self.count(dash, in: fixture) == 0)

        func row(paidByOtherPayments: Double?, remaining: Double?) -> PaymentReceiptAllocationRow {
            PaymentReceiptAllocationRow(
                documentNumber: "INV-2026-0103", documentDate: "Jan 20, 2026",
                documentCurrencyCode: "USD", documentTotal: 650,
                paidByOtherPayments: paidByOtherPayments,
                appliedAmount: 552.60, appliedInDocumentCurrency: 600, exchangeRate: 1.0858,
                remaining: remaining, isSettled: true)
        }

        // `isSettled: true` is deliberate: a nil remaining suppresses the marker.
        let subject = Self.document(allocations: [row(paidByOtherPayments: nil, remaining: nil)])
        let html = PaymentReceiptLayout.build(subject).renderHTML()
        #expect(Self.count(dash, in: html) == 2)
        #expect(Self.count(labels.allocationSettledMarker, in: html) == 0)
        #expect(Self.count(labels.exchangeRate("1.0858"), in: html) == 1)

        // Control: the same row with figures prints no dash and the marker.
        let control = Self.document(allocations: [row(paidByOtherPayments: 0, remaining: 0)])
        let controlHTML = PaymentReceiptLayout.build(control).renderHTML()
        #expect(Self.count(dash, in: controlHTML) == 0)
        #expect(Self.count(labels.allocationSettledMarker, in: controlHTML) == 1)

        let bytes = try PaymentReceiptLayout.build(subject).render()
        #expect(bytes.starts(with: Data("%PDF".utf8)))
    }
}
