import Foundation
import Testing
@testable import SwiftlyPDFKit
#if canImport(PDFKit)
import PDFKit
#endif

/// `QA-UNIT06-DOCUMENTS-242` … `-251` — the remittance-advice family `PRINT03`
/// phase 00 authored: its label set, its model and `RemittanceAdviceLayout`,
/// single and batch form; `-249` / `-250` live in
/// `RemittanceAdviceDocumentCellOverflowTests.swift`.
///
/// Authoring rules carried from the receipt and purchase-order suites: assert
/// the **rendered output** of both paths, assert every omission with a
/// positive control on the same fixture, count **delimited** forms
/// (`>caption<`), read page counts off `pdf.pages.count`, and stop every HTML
/// slice that can cross a page break at the next page box.
///
/// The type name deliberately carries the token `Document` so the suite
/// manifest's §2 grep reaches it.
@Suite("Remittance advice document layout")
struct RemittanceAdviceDocumentLayoutTests {

    // MARK: Fixtures

    static let issuer = InvoiceSupplier(
        name: "Swiftly Business Consulting",
        street: "Posthofbrug 34",
        city: "2600 Antwerpen",
        country: "Belgium",
        vatNumber: "BE0778405303",
        email: "billing@example.com",
        iban: "BE68 5390 0754 7034",
        bic: "GEBABEBB"
    )

    static let payee = RemittanceAdvicePayee(
        party: InvoiceParty(
            name: "Bosch Industrial Supply GmbH",
            street: "Robert-Bosch-Platz 1",
            city: "70839 Gerlingen",
            country: "Germany",
            vatNumber: "DE811128135"),
        registerNumber: "HRB 14000",
        supplierNumber: "V-00017",
        yourReferenceForUs: "CUST-88213",
        paidToAccount: "•••• 3000",
        paidToBIC: "DEUTDEFF")

    static let labels = RemittanceAdviceLabels.english
    static let payment = PaymentReceiptLabels.english
    static let common = CommonDocumentLabels.english
    static let email = "accounts@example.com"

    static func facts(amountPaid: String) -> [RemittanceAdviceFact] {
        [
            RemittanceAdviceFact(caption: labels.executionDateLabel, value: "2026-10-30"),
            RemittanceAdviceFact(caption: payment.paymentMethodLabel, value: payment.paymentMeansSEPACreditTransfer),
            RemittanceAdviceFact(caption: labels.amountPaidLabel, value: amountPaid),
            RemittanceAdviceFact(caption: labels.ourBankAccountLabel, value: "•••• 9163"),
        ]
    }

    /// An EUR invoice with a discount, a USD invoice with the rate sub-row and
    /// a credit note — each carrying a paying member the single form must ignore.
    static let singleDetails = [
        RemittanceAdviceDetailRow(
            kind: .invoice, theirNumber: "INV-DE-77812", theirDate: "2026-09-15", ourReference: "VBILL00031",
            documentCurrencyCode: "EUR", gross: 2_500, paidByOtherPayments: 0,
            applied: 2_450, appliedCurrencyCode: "EUR", remaining: 0, isSettled: true,
            discount: RemittanceAdviceAmount(value: 50, currencyCode: "EUR"),
            paidByPaymentNumber: "VPMT-SENTINEL"),
        RemittanceAdviceDetailRow(
            kind: .invoice, theirNumber: "INV-DE-77840", theirDate: "2026-09-22", ourReference: "VBILL00034",
            documentCurrencyCode: "USD", gross: 1_000, paidByOtherPayments: 0,
            applied: 862.50, appliedCurrencyCode: "EUR", appliedInDocumentCurrency: 1_000, exchangeRate: 1.15942,
            remaining: 0, isSettled: true, paidByPaymentNumber: "VPMT-SENTINEL"),
        RemittanceAdviceDetailRow(
            kind: .creditNote, theirNumber: "CN-DE-0907", theirDate: "2026-10-05", ourReference: "VCRN00007",
            documentCurrencyCode: "EUR", gross: 300, paidByOtherPayments: 0,
            applied: 300, appliedCurrencyCode: "EUR", remaining: 0, isSettled: true,
            paidByPaymentNumber: "VPMT-SENTINEL"),
    ]

    static let singleTotals = RemittanceAdviceTotals(
        currencyCode: "EUR", bills: 3_312.50, discount: 50, credits: 300, transferred: 2_962.50, onAccount: 0)

    static func singleForm(
        details: [RemittanceAdviceDetailRow] = singleDetails,
        totals: [RemittanceAdviceTotals] = [singleTotals],
        watermark: RemittanceAdviceWatermark = .none,
        labels: RemittanceAdviceLabels = labels,
        payment: PaymentReceiptLabels = payment,
        common: CommonDocumentLabels = common
    ) -> RemittanceAdviceDocument {
        RemittanceAdviceDocument(
            issuer: issuer, payee: payee,
            header: RemittanceAdviceHeader(adviceNumber: "VPMT00041", adviceDate: "2026-10-30"),
            paymentFacts: facts(amountPaid: "2,962.50 EUR"), memberPayments: nil, details: details, totals: totals,
            remittanceLines: [RemittanceAdviceTextLine(text: "RF18 5390 0754 7034", asSent: false)],
            watermark: watermark, notes: "Thank you.", contactEmail: email,
            labels: labels, payment: payment, common: common)
    }

    static let members = [
        RemittanceAdviceMemberPayment(
            paymentNumber: "VPMT00041", endToEndId: "E2E-7f3a2c10-55b1-4e0b-9d2a-1c3e",
            paymentInfoId: "PMTINF-20261030-01", amount: 3_312.50, currencyCode: "EUR"),
        RemittanceAdviceMemberPayment(
            paymentNumber: "VPMT00042", endToEndId: "E2E-0b9e44d2-7a6c-4f21-8e03-a4d1",
            paymentInfoId: "PMTINF-20261030-01", amount: 1_000, currencyCode: "EUR"),
    ]

    static let batchDetails = [
        RemittanceAdviceDetailRow(
            kind: .invoice, theirNumber: "INV-DE-77812", theirDate: "2026-09-15", ourReference: "VBILL00031",
            documentCurrencyCode: "EUR", gross: 2_500, paidByOtherPayments: 0,
            applied: 2_450, appliedCurrencyCode: "EUR", remaining: 0, isSettled: true,
            discount: RemittanceAdviceAmount(value: 50, currencyCode: "EUR"), paidByPaymentNumber: "VPMT00041"),
        RemittanceAdviceDetailRow(
            kind: .invoice, theirNumber: "INV-DE-77840", theirDate: "2026-09-22", ourReference: "VBILL00034",
            documentCurrencyCode: "USD", gross: 1_000, paidByOtherPayments: 0,
            applied: 862.50, appliedCurrencyCode: "EUR", appliedInDocumentCurrency: 1_000, exchangeRate: 1.15942,
            remaining: 0, isSettled: true, paidByPaymentNumber: "VPMT00041"),
        RemittanceAdviceDetailRow(
            kind: .invoice, theirNumber: "INV-DE-77901", theirDate: "2026-10-02", ourReference: "VBILL00040",
            documentCurrencyCode: "EUR", gross: 1_200, paidByOtherPayments: 0,
            applied: 1_175, appliedCurrencyCode: "EUR", remaining: 0, isSettled: true,
            adjustment: RemittanceAdviceAmount(value: 25, currencyCode: "EUR"), adjustmentReason: "Short delivery",
            paidByPaymentNumber: "VPMT00042"),
        RemittanceAdviceDetailRow(
            kind: .creditNote, theirNumber: "CN-DE-0907", theirDate: "2026-10-05", ourReference: "VCRN00007",
            documentCurrencyCode: "EUR", gross: 300, paidByOtherPayments: 0,
            applied: 300, appliedCurrencyCode: "EUR", remaining: 0, isSettled: true,
            paidByPaymentNumber: "VPMT00042"),
    ]

    static let longRemittance = String((
        "Payment of invoices INV-DE-77812 and INV-DE-77840 for September deliveries under framework "
            + "agreement FA-2026-03, net of the agreed cash discount and the short-delivery adjustment").prefix(140))

    static let batchLines = [
        RemittanceAdviceTextLine(text: longRemittance, asSent: true, truncated: true, paymentNumber: "VPMT00041"),
        RemittanceAdviceTextLine(text: "RF18 5390 0754 7034", asSent: true, truncated: false, paymentNumber: "VPMT00042"),
    ]

    /// The §6.1 fixture: the batch form, not yet submitted.
    static func batchForm(
        members: [RemittanceAdviceMemberPayment] = members,
        details: [RemittanceAdviceDetailRow] = batchDetails,
        lines: [RemittanceAdviceTextLine] = batchLines,
        labels: RemittanceAdviceLabels = labels,
        common: CommonDocumentLabels = common
    ) -> RemittanceAdviceDocument {
        RemittanceAdviceDocument(
            issuer: issuer, payee: payee,
            header: RemittanceAdviceHeader(
                batchReference: "MSG-20261028-001 / V-00017", adviceDate: "2026-10-30",
                generatedOn: "2026-10-28 15:10"),
            paymentFacts: facts(amountPaid: "4,312.50 EUR"), memberPayments: members, details: details,
            totals: [RemittanceAdviceTotals(
                currencyCode: "EUR", bills: 4_487.50, discount: 50, adjustments: 25, credits: 300,
                transferred: 4_312.50, onAccount: 125)],
            remittanceLines: lines, watermark: .notYetSubmitted,
            notes: "Thank you for the September deliveries.", contactEmail: email,
            labels: labels, payment: payment, common: common)
    }

    /// `n` EUR invoices `THEIR-0001` …, zero-padded — a multi-page single form.
    static func longDetails(_ count: Int) -> [RemittanceAdviceDetailRow] {
        (1...count).map { index in
            RemittanceAdviceDetailRow(
                theirNumber: "THEIR-" + String(repeating: "0", count: 4 - String(index).count) + String(index),
                theirDate: "2026-09-01", ourReference: "VBILL\(10_000 + index)",
                documentCurrencyCode: "EUR", gross: 100, paidByOtherPayments: 0,
                applied: 50, appliedCurrencyCode: "EUR", remaining: 50, isSettled: false)
        }
    }

    static func longForm(
        _ count: Int,
        watermark: RemittanceAdviceWatermark = .none,
        labels: RemittanceAdviceLabels = labels,
        payment: PaymentReceiptLabels = payment,
        common: CommonDocumentLabels = common
    ) -> RemittanceAdviceDocument {
        singleForm(details: longDetails(count), watermark: watermark, labels: labels, payment: payment, common: common)
    }

    /// `>text<` occurrences — the delimited form of a rendered caption or cell.
    static func count(_ text: String, in html: String) -> Int {
        html.components(separatedBy: ">" + text + "<").count - 1
    }

    /// The HTML of each page, split on the page-box marker `Page.renderHTML` emits.
    static func pageSegments(_ html: String) -> [String] {
        Array(html.components(separatedBy: "<div class=\"page\"").dropFirst())
    }

    static func html(_ document: RemittanceAdviceDocument) -> String {
        RemittanceAdviceLayout.build(document).renderHTML()
    }

    // MARK: Test -242

    /// `QA-UNIT06-DOCUMENTS-242`
    @Test("-242 the label set has exactly 39 non-empty remittance-only members and its helper expands")
    func labelSetShapeAndPartition() {
        let children = Mirror(reflecting: Self.labels).children
        #expect(children.count == 39)
        for child in children {
            let value = child.value as? String
            #expect(value != nil, "\(child.label ?? "?") is not a String")
            #expect(value?.isEmpty == false, "\(child.label ?? "?") is empty")
            #expect(value?.contains("%@") == false && value?.contains("%lld") == false,
                    "\(child.label ?? "?") carries a positional specifier")
        }

        #expect(Self.labels.adjustmentReason("X") == "Adjustment: X")
        var reordered = RemittanceAdviceLabels()
        reordered.adjustmentReasonFormat = "{reason} — Adjustment"
        #expect(reordered.adjustmentReason("X") == "X — Adjustment")

        // §25 #25: the remittance set holds only the keys the receipt and the
        // common set do not.
        let names = Set(children.compactMap(\.label))
        let receiptNames = Set(Mirror(reflecting: PaymentReceiptLabels.english).children.compactMap(\.label))
        let commonNames = Set(Mirror(reflecting: CommonDocumentLabels.english).children.compactMap(\.label))
        #expect(!receiptNames.isEmpty && !commonNames.isEmpty)
        #expect(names.isDisjoint(with: receiptNames), "shared with the receipt: \(names.intersection(receiptNames))")
        #expect(names.isDisjoint(with: commonNames), "shared with common: \(names.intersection(commonNames))")
        for retired in ["totalDiscountLabel", "mandateReferenceLabel", "remittanceAdviceNoun"] {
            #expect(!names.contains(retired), "\(retired) is not a remittance-only key")
        }
    }

    // MARK: Test -243

    /// `QA-UNIT06-DOCUMENTS-243`
    @Test("-243 the single form renders through both paths with every block present")
    func singleFormRendersBothPaths() throws {
        let pdf = RemittanceAdviceLayout.build(Self.singleForm())
        let floor = try PDF(pages: [Page {}]).render()
        let cgBytes = try pdf.render()
        let html = pdf.renderHTML()
        #expect(cgBytes.count > floor.count)
        #expect(!html.isEmpty)

        let labels = Self.labels, payment = Self.payment, common = Self.common
        for text in [
            labels.remittanceAdviceTitle, labels.adviceNumberLabel, "VPMT00041", labels.adviceDateLabel,
            labels.paidToLabel, Self.payee.party.name,
            "\(labels.supplierNumberLabel) V-00017", "\(labels.yourReferenceForUsLabel) CUST-88213",
            "\(labels.paidToAccountLabel) •••• 3000", "\(common.bicLabel) DEUTDEFF",
            labels.settledDocumentsTitle,
            labels.yourReferenceColumn, labels.documentTypeColumn, labels.ourReferenceColumn,
            payment.allocationColumnDocumentDate, payment.allocationColumnDocumentTotal,
            payment.allocationColumnOtherPayments, payment.allocationColumnApplied,
            payment.allocationColumnRemaining,
            "INV-DE-77812", "INV-DE-77840", "CN-DE-0907", "VBILL00031", "VBILL00034", "VCRN00007",
            labels.documentTypeInvoice, labels.documentTypeCreditNote,
            payment.remittanceInformationLabel, labels.fundsSubjectToProcessingNotice,
            "\(labels.queriesContactLabel) \(Self.email)",
            common.pageNumber(1, of: pdf.pages.count),
        ] + Self.facts(amountPaid: "").map(\.caption) {
            #expect(Self.count(text, in: html) >= 1, "missing \(text)")
        }
        // The issuer's bank line is printed: the account the payment leaves from.
        #expect(html.contains("\(common.ibanLabel) \(Self.issuer.iban ?? "")"))

        #expect(Self.count(labels.batchReferenceLabel, in: html) == 0)
        #expect(Self.count(labels.paymentsInBatchTitle, in: html) == 0)
        #expect(Self.count(labels.paidByPaymentColumn, in: html) == 0)
        #expect(!html.contains("VPMT-SENTINEL"), "the single form printed a paying member")
    }

    // MARK: Test -244

    /// `QA-UNIT06-DOCUMENTS-244`
    @Test("-244 discount, adjustment and rate sub-rows appear only when they apply")
    func subRows() {
        var sentinels = RemittanceAdviceLabels()
        sentinels.discountColumn = "SENTINEL-DISCOUNT"
        sentinels.adjustmentColumn = "SENTINEL-ADJUSTMENT"
        let payment = Self.payment
        func row(
            currency: String = "EUR",
            inDocument: Double? = nil, rate: Double? = nil,
            remaining: Double? = 0, settled: Bool = true,
            kind: RemittanceAdviceDocumentKind = .invoice,
            discount: Double? = nil, adjustment: Double? = nil, reason: String? = nil
        ) -> String {
            let detail = RemittanceAdviceDetailRow(
                kind: kind, theirNumber: "INV-DE-77812", theirDate: "2026-09-15", ourReference: "VBILL00031",
                documentCurrencyCode: currency, gross: 2_500, paidByOtherPayments: 0,
                applied: 2_450, appliedCurrencyCode: "EUR", appliedInDocumentCurrency: inDocument,
                exchangeRate: rate, remaining: remaining, isSettled: settled,
                discount: discount.map { RemittanceAdviceAmount(value: $0, currencyCode: "EUR") },
                adjustment: adjustment.map { RemittanceAdviceAmount(value: $0, currencyCode: "EUR") },
                adjustmentReason: reason)
            return Self.html(Self.singleForm(details: [detail], labels: sentinels))
        }

        #expect(Self.count("SENTINEL-DISCOUNT", in: row(discount: nil)) == 0)
        #expect(Self.count("SENTINEL-DISCOUNT", in: row(discount: 0)) == 0)
        let discounted = row(discount: 12.5)
        #expect(Self.count("SENTINEL-DISCOUNT", in: discounted) == 1)
        #expect(Self.count("12.50 EUR", in: discounted) == 1)

        let reasoned = row(adjustment: 25, reason: "Short delivery")
        #expect(Self.count("Adjustment: Short delivery", in: reasoned) == 1)
        #expect(Self.count("SENTINEL-ADJUSTMENT", in: reasoned) == 0)
        let blank = row(adjustment: 25, reason: "  ")
        #expect(Self.count("SENTINEL-ADJUSTMENT", in: blank) == 1)
        #expect(!blank.contains("Adjustment: "))
        let zero = row(adjustment: 0, reason: "Short delivery")
        #expect(Self.count("SENTINEL-ADJUSTMENT", in: zero) == 0)
        #expect(!zero.contains("Adjustment: "))

        let rateText = payment.exchangeRate("1.15942")
        #expect(Self.count(rateText, in: row(currency: "USD", inDocument: 1_000, rate: 1.15942)) == 1)
        #expect(Self.count(rateText, in: row()) == 0)

        let credit = row(kind: .creditNote)
        #expect(Self.count(Self.labels.documentTypeCreditNote, in: credit) == 1)
        #expect(Self.count(Self.labels.documentTypeInvoice, in: credit) == 0)

        let settled = row()
        #expect(Self.count(payment.allocationSettledMarker, in: settled) == 1)
        let unknown = row(remaining: nil, settled: true)
        #expect(Self.count(payment.allocationSettledMarker, in: unknown) == 0)
        #expect(Self.count("—", in: unknown) == 1)
        // D1: the payee's date prints in the date column, once.
        #expect(Self.count("2026-09-15", in: settled) == 1)
    }

    // MARK: Test -245

    /// `QA-UNIT06-DOCUMENTS-245`
    @Test("-245 the status watermark is on every page and its notice once, on the last page")
    func watermarksAndNotices() throws {
        let labels = Self.labels
        var payment = PaymentReceiptLabels()
        payment.reversedNoticeFormat = "SENTINEL-REV {reason}"

        let pending = RemittanceAdviceLayout.build(Self.longForm(60, watermark: .notYetSubmitted, payment: payment))
        let pendingHTML = pending.renderHTML()
        let pendingPages = Self.pageSegments(pendingHTML)
        #expect(pending.pages.count > 1)
        #expect(pendingPages.count == pending.pages.count)
        #expect(pendingHTML.components(separatedBy: "class=\"watermark\"").count - 1 == pending.pages.count)
        for (index, page) in pendingPages.enumerated() {
            #expect(Self.count(labels.notYetSubmittedWatermark, in: page) == 1, "page \(index + 1)")
        }
        #expect(Self.count(labels.notYetSubmittedNotice, in: pendingHTML) == 1)
        #expect(Self.count(labels.notYetSubmittedNotice, in: try #require(pendingPages.last)) == 1)
        #expect(Self.count(payment.reversedWatermark, in: pendingHTML) == 0)

        let reversed = RemittanceAdviceLayout.build(Self.longForm(60, watermark: .reversed(reasonCode: "MD06"),
                                                                 payment: payment))
        let reversedHTML = reversed.renderHTML()
        let reversedPages = Self.pageSegments(reversedHTML)
        for (index, page) in reversedPages.enumerated() {
            #expect(Self.count(payment.reversedWatermark, in: page) == 1, "page \(index + 1)")
        }
        let notice = payment.reversedNotice(reason: payment.reversalReason(forCode: "MD06"))
        #expect(Self.count(notice, in: reversedHTML) == 1)
        #expect(Self.count(notice, in: try #require(reversedPages.last)) == 1)
        #expect(Self.count(labels.notYetSubmittedNotice, in: reversedHTML) == 0)

        for code in [nil, "  "] as [String?] {
            let html = Self.html(Self.longForm(60, watermark: .reversed(reasonCode: code), payment: payment))
            #expect(Self.count(payment.reversedWatermark, in: html) >= 1, "code \(code ?? "nil")")
            #expect(!html.contains("SENTINEL-REV"), "code \(code ?? "nil") printed a notice")
        }

        let plain = Self.html(Self.longForm(60, payment: payment))
        #expect(!plain.contains("class=\"watermark\""))
        for word in [labels.notYetSubmittedWatermark, payment.reversedWatermark, labels.notYetSubmittedNotice] {
            #expect(Self.count(word, in: plain) == 0, "\(word)")
        }
        #expect(!plain.contains("SENTINEL-REV"))
    }

    // MARK: Test -246

    /// `QA-UNIT06-DOCUMENTS-246`
    @Test("-246 one totals stack per currency; on account always; optional rows only when they apply")
    func totalsPerCurrency() {
        var labels = RemittanceAdviceLabels()
        labels.totalTransferredLabel = "SENTINEL-TRANSFERRED"
        labels.totalAdjustmentsLabel = "SENTINEL-ADJUSTMENTS"
        labels.totalCreditsLabel = "SENTINEL-CREDITS"
        var common = CommonDocumentLabels()
        common.totalsDiscountLabel = "SENTINEL-DISCOUNT-TOTAL"
        let detail = RemittanceAdviceDetailRow(
            theirNumber: "INV-1", theirDate: "2026-09-01", ourReference: "VBILL1",
            documentCurrencyCode: "EUR", gross: 10, paidByOtherPayments: 1,
            applied: 9, appliedCurrencyCode: "EUR", remaining: 1, isSettled: false)
        func html(_ totals: [RemittanceAdviceTotals]) -> String {
            Self.html(Self.singleForm(details: [detail], totals: totals, labels: labels, common: common))
        }
        func eur(
            discount: Double? = nil, adjustments: Double? = nil, credits: Double? = nil, onAccount: Double = 0,
            charges: [RemittanceAdviceAmount] = []
        ) -> RemittanceAdviceTotals {
            RemittanceAdviceTotals(
                currencyCode: "EUR", bills: 4_400, discount: discount, adjustments: adjustments,
                credits: credits, transferred: 4_312.50, onAccount: onAccount, charges: charges)
        }
        // Bills ≠ transferred, so each USD figure occurs once and the count below names one row.
        let usd = RemittanceAdviceTotals(currencyCode: "USD", bills: 1_200, transferred: 1_000, onAccount: 0)

        let two = html([eur(), usd])
        #expect(Self.count("SENTINEL-TRANSFERRED", in: two) == 2)
        #expect(Self.count("4,312.50 EUR", in: two) == 1)
        #expect(Self.count("1,000.00 USD", in: two) == 1)
        #expect(!two.contains(">5,312.50"))

        #expect(Self.count(Self.labels.totalOnAccountLabel, in: html([eur()])) == 1)
        #expect(Self.count("0.00 EUR", in: html([eur()])) == 1)
        #expect(Self.count("125.00 EUR", in: html([eur(onAccount: 125)])) == 1)

        #expect(Self.count("SENTINEL-DISCOUNT-TOTAL", in: html([eur(discount: nil)])) == 0)
        #expect(Self.count("SENTINEL-DISCOUNT-TOTAL", in: html([eur(discount: 0)])) == 0)
        #expect(Self.count("SENTINEL-DISCOUNT-TOTAL", in: html([eur(discount: 50)])) == 1)
        #expect(Self.count("SENTINEL-ADJUSTMENTS", in: html([eur(adjustments: nil)])) == 0)
        #expect(Self.count("SENTINEL-ADJUSTMENTS", in: html([eur(adjustments: 0)])) == 0)
        #expect(Self.count("SENTINEL-ADJUSTMENTS", in: html([eur(adjustments: 25)])) == 1)
        #expect(Self.count("SENTINEL-CREDITS", in: html([eur(credits: nil)])) == 0)
        #expect(Self.count("SENTINEL-CREDITS", in: html([eur(credits: 0)])) == 1)

        let charged = html([eur(charges: [RemittanceAdviceAmount(value: 3, currencyCode: "GBP")])])
        #expect(Self.count(Self.payment.bankChargesLabel, in: charged) == 1)
        #expect(Self.count("3.00 GBP", in: charged) == 1)
        #expect(Self.count(Self.payment.bankChargesLabel, in: html([eur()])) == 0)
    }

}

// A same-suite extension: keeps the struct body under `type_body_length`.
extension RemittanceAdviceDocumentLayoutTests {

    // MARK: Test -247

    /// `QA-UNIT06-DOCUMENTS-247`
    @Test("-247 the batch form lists its members, names the paying member per document and states the remittance as sent")
    func batchFormVersusSingleForm() {
        var labels = RemittanceAdviceLabels()
        labels.reversedRowMarker = "SENTINEL-REVERSED-ROW"
        let batch = Self.html(Self.batchForm(labels: labels))
        #expect(Self.count(labels.paymentsInBatchTitle, in: batch) == 1)
        for text in [
            labels.paymentColumnLabel, labels.paymentInfoIdLabel, Self.payment.endToEndIdLabel,
            "E2E-7f3a2c10-55b1-4e0b-9d2a-1c3e", "E2E-0b9e44d2-7a6c-4f21-8e03-a4d1", labels.paidByPaymentColumn,
        ] {
            #expect(Self.count(text, in: batch) >= 1, "missing \(text)")
        }
        // Each member number: once in the member list, then once per document it paid.
        #expect(Self.count("VPMT00041", in: batch) == 3)
        #expect(Self.count("VPMT00042", in: batch) == 3)
        #expect(Self.count("SENTINEL-REVERSED-ROW", in: batch) == 0)

        var members = Self.members
        members[1].isReversed = true
        var details = Self.batchDetails
        details[3].isReversed = true
        let reversed = Self.html(Self.batchForm(members: members, details: details, labels: labels))
        #expect(Self.count("SENTINEL-REVERSED-ROW", in: reversed) == 2)

        #expect(Self.count(labels.remittanceTextAsSentLabel, in: batch) == 1)
        #expect(Self.count(Self.payment.remittanceInformationLabel, in: batch) == 0)
        #expect(Self.count(labels.remittanceTruncatedNotice, in: batch) == 1)
        #expect(Self.count("VPMT00042 · RF18 5390 0754 7034", in: batch) == 1)
        #expect(Self.count("VPMT00041 · " + Self.longRemittance, in: batch) == 1)
        let untruncated = Self.batchLines.map {
            RemittanceAdviceTextLine(text: $0.text, asSent: true, truncated: false, paymentNumber: $0.paymentNumber)
        }
        let whole = Self.html(Self.batchForm(lines: untruncated, labels: labels))
        #expect(Self.count(labels.remittanceTruncatedNotice, in: whole) == 0)

        let single = Self.html(Self.singleForm())
        #expect(Self.count(labels.paymentsInBatchTitle, in: single) == 0)
        #expect(Self.count(labels.paidByPaymentColumn, in: single) == 0)
        #expect(!single.contains("VPMT-SENTINEL"))
        #expect(Self.count(Self.payment.remittanceInformationLabel, in: single) == 1)
        #expect(Self.count(labels.remittanceTextAsSentLabel, in: single) == 0)
    }

    // MARK: Test -248

    /// `QA-UNIT06-DOCUMENTS-248`
    @Test("-248 an empty advice states it; a long one paginates with a repeated header and the totals last")
    func emptyAndPagination() throws {
        let payment = Self.payment
        let empty = Self.html(Self.singleForm(details: []))
        #expect(Self.count(payment.allocationEmptyRow, in: empty) == 1)
        for caption in [Self.labels.yourReferenceColumn, payment.allocationColumnDocumentDate,
                        payment.allocationColumnApplied, payment.allocationColumnRemaining] {
            #expect(Self.count(caption, in: empty) == 1, "\(caption)")
        }

        var labels = RemittanceAdviceLabels()
        labels.yourReferenceColumn = "SENTINEL-YOUR-REFERENCE"
        labels.totalTransferredLabel = "SENTINEL-TRANSFERRED"
        var common = CommonDocumentLabels()
        common.pageNumberTemplate = "Blz {page}/{pages}"
        let pdf = RemittanceAdviceLayout.build(Self.longForm(60, labels: labels, common: common))
        let html = pdf.renderHTML()
        let pages = Self.pageSegments(html)
        let pageCount = pages.count
        #expect(pageCount > 1)
        #expect(pageCount == pdf.pages.count)
        #expect(Self.count("Blz 1/\(pageCount)", in: html) == 1)
        #expect(Self.count("Blz \(pageCount)/\(pageCount)", in: html) == 1)
        #expect(html.contains(common.continuedLabel))
        #expect(Self.count(payment.allocationEmptyRow, in: html) == 0)

        for (index, page) in pages.enumerated() {
            let carriesRows = page.contains(">THEIR-0")
            #expect(Self.count("SENTINEL-YOUR-REFERENCE", in: page) == (carriesRows ? 1 : 0), "page \(index + 1)")
        }
        let last = try #require(pages.last)
        #expect(Self.count("SENTINEL-TRANSFERRED", in: html) == 1)
        #expect(Self.count("SENTINEL-TRANSFERRED", in: last) == 1)
        for row in Self.longDetails(60) {
            let number = try #require(row.theirNumber)
            #expect(Self.count(number, in: html) == 1, "\(number) lost")
        }
    }

    // MARK: Test -251

    /// `QA-UNIT06-DOCUMENTS-251`
    @Test("-251 a long member list paginates, repeats its header and never reaches the footer")
    func memberListPaginates() throws {
        var labels = RemittanceAdviceLabels()
        labels.paymentColumnLabel = "SENTINEL-PAYMENT"
        let numbers = (10_001...10_030).map { "VPMT\($0)" }
        let members = numbers.map {
            RemittanceAdviceMemberPayment(
                paymentNumber: $0, endToEndId: "E2E-" + String($0.dropFirst(4)), paymentInfoId: "PMTINF-20261030-01",
                amount: 100, currencyCode: "EUR")
        }
        let document = Self.batchForm(members: members, labels: labels)
        let pdf = RemittanceAdviceLayout.build(document)
        let html = pdf.renderHTML()
        let pages = Self.pageSegments(html)
        #expect(pdf.pages.count >= 2)
        #expect(pages.count == pdf.pages.count)
        #expect(html.contains(">" + labels.paymentsInBatchTitle + " — " + Self.common.continuedLabel + "<"))
        for number in numbers {
            #expect(Self.count(number, in: html) == 1, "\(number)")
        }
        for (index, page) in pages.enumerated() where page.contains(">VPMT100") {
            #expect(Self.count("SENTINEL-PAYMENT", in: page) == 1, "page \(index + 1)")
        }

        #if canImport(PDFKit)
        let reader = try #require(PDFDocument(data: try pdf.render()))
        let theme = InvoiceTheme.standard
        let contentWidth = PageSize.a4.width - theme.pageMargins * 2
        let footerTop = theme.pageMargins + PaymentDocumentBlocks.footerHeight(
            lines: RemittanceAdviceLayout.footerLines(document), contentWidth: contentWidth)
        var drawn = Set<String>()
        for pageIndex in 0..<reader.pageCount {
            let page = try #require(reader.page(at: pageIndex))
            for number in numbers {
                guard let box = Self.drawnBounds(of: number, on: page) else { continue }
                drawn.insert(number)
                #expect(box.minY > footerTop, "\(number) on page \(pageIndex + 1) at \(box.minY) pt")
            }
        }
        // Positive anchor: the reader found every member, so the bound above is not vacuous.
        #expect(drawn.count == numbers.count)
        #endif
    }

    // MARK: Phase 07d fixtures — the Step 9 served one-member, one-bill batch (`batch-one-member-one-bill.pdf`)

    /// The two-line note the Step 9 served oracle printed, verbatim.
    static let servedNotes = "VPMT00001: Thank you for your invoice. This remittance settles the bill named below "
        + "in full; the notes block is long on purpose so a clipped render would be visible — line two carries "
        + "the sentinel NOTES-END-SENTINEL at its very end."

    /// `batch-one-member-one-bill.pdf`: the served batch advice (one member, one
    /// bill, not yet submitted) with `notes`.
    static func servedBatch(notes: String) -> RemittanceAdviceDocument {
        RemittanceAdviceDocument(
            issuer: InvoiceSupplier(
                name: "QA Test Co [print03-s9-oracle-093416]", street: "1 QA Way", city: "Testville", country: "BE",
                vatNumber: "QA-print03-s9-oracle-093416", phone: "000"),
            payee: RemittanceAdvicePayee(
                party: InvoiceParty(name: "PRINT03 Served Oracle Payee NV", vatNumber: "BE0111222333"),
                registerNumber: "0111.222.333", paidToAccount: "•••• 7034", paidToBIC: "GEBABEBB"),
            header: RemittanceAdviceHeader(
                batchReference: "PI-5E5CA0E49A4247C0A999E5E752867FC4 / 37866425", adviceDate: "Nov 1, 2026",
                generatedOn: "Oct 31, 2026 at 10:34 AM (Europe/Brussels)"),
            paymentFacts: [
                RemittanceAdviceFact(caption: labels.executionDateLabel, value: "Nov 1, 2026"),
                RemittanceAdviceFact(caption: labels.amountPaidLabel, value: "€100.00"),
                RemittanceAdviceFact(
                    caption: payment.paymentMethodLabel, value: payment.paymentMeansSEPACreditTransfer),
            ],
            memberPayments: [
                RemittanceAdviceMemberPayment(
                    paymentNumber: "VPMT00001", endToEndId: "S9-ORACLE-ONE",
                    paymentInfoId: "PMT-B0B7B9D80B1949E39490DF7D1221973", amount: 100, currencyCode: "EUR"),
            ],
            details: [
                RemittanceAdviceDetailRow(
                    kind: .invoice, theirNumber: "ORACLE-BILL-ONE", theirDate: "Oct 31, 2026",
                    ourReference: "PINV00001", documentCurrencyCode: "EUR", gross: 121, paidByOtherPayments: 0,
                    applied: 100, appliedCurrencyCode: "EUR", remaining: 21, isSettled: false,
                    paidByPaymentNumber: "VPMT00001"),
            ],
            totals: [RemittanceAdviceTotals(currencyCode: "EUR", bills: 100, transferred: 100, onAccount: 0)],
            remittanceLines: [
                RemittanceAdviceTextLine(
                    text: "Invoice ORACLE-BILL-ONE", asSent: true, truncated: false, paymentNumber: "VPMT00001"),
            ],
            watermark: .notYetSubmitted, notes: notes, contactEmail: nil,
            labels: labels, payment: payment, common: common)
    }

    // MARK: Test -294

    /// `QA-UNIT06-DOCUMENTS-294`
    @Test("-294 the served one-member, one-bill batch keeps a two-line note on page 1, on both paths")
    func servedBatchKeepsAShortNoteOnPageOne() throws {
        // The note is the served paragraph: two drawn lines, one text cell (no hard break).
        do {
            let notes = Self.servedNotes
            let document = Self.servedBatch(notes: notes)
            let pdf = RemittanceAdviceLayout.build(document)
            let html = pdf.renderHTML()
            let pages = Self.pageSegments(html)
            #expect(pdf.pages.count == 1)
            #expect(pages.count == 1)
            for text in [Self.payment.notesLabel, notes, Self.labels.notYetSubmittedNotice,
                         Self.labels.remittanceTextAsSentLabel, Self.common.pageNumber(1, of: 1)] {
                #expect(Self.count(text, in: html) == 1, "\(text)")
            }
            // The batch reference stays one unbroken line (§25 #48 is kept).
            let reference = "PI-5E5CA0E49A4247C0A999E5E752867FC4 / 37866425"
            #expect(Self.count(reference, in: html) == 1)
            #expect(try Self.columnWidth(before: reference, in: html) == "515.0pt")

            #if canImport(PDFKit)
            // Drawn: the note's last word sits on page 1, above the footer, under the notice.
            let page = try Self.firstPage(pdf)
            let sentinel = try #require(Self.drawnBounds(of: "NOTES-END-SENTINEL", on: page))
            let notice = try #require(Self.drawnBounds(of: Self.labels.notYetSubmittedNotice, on: page))
            #expect(sentinel.minY > Self.footerTop(document), "the note reaches the footer: \(sentinel.minY) pt")
            #expect(sentinel.maxY < notice.minY, "the note is not under the notice")
            // The totals still sit under the last row on the same page (§25 #48).
            let totals = try #require(Self.drawnBounds(of: Self.labels.totalTransferredLabel, on: page))
            let lastRow = try #require(Self.drawnBounds(of: "PINV00001", on: page))
            #expect(totals.maxY < lastRow.minY)
            #endif
        }
    }

    // MARK: Test -295

    /// `QA-UNIT06-DOCUMENTS-295`
    @Test("-295 a note too long for page 1 still moves whole to page 2, caption with text, nothing clipped")
    func servedBatchSpillsALongNoteWhole() throws {
        let paragraph = "This paragraph is here to make the note taller than the room left under the notice, "
            + "so the whole block must move to the next page instead of being cut at the footer."
        let notes = (1...8).map { "Line \($0): " + paragraph }.joined(separator: "\n") + "\nNOTES-END-SENTINEL"
        let document = Self.servedBatch(notes: notes)
        let pdf = RemittanceAdviceLayout.build(document)
        let html = pdf.renderHTML()
        let pages = Self.pageSegments(html)
        #expect(pdf.pages.count == 2)
        #expect(pages.count == 2)
        // Page 1 keeps the totals, the remittance line and the notice; page 2 carries the caption AND the
        // whole text (one cell, every line and the sentinel, so nothing was cut).
        #expect(try Self.pageIndex(of: Self.labels.totalTransferredLabel, in: pages) == 0)
        #expect(try Self.pageIndex(of: Self.labels.notYetSubmittedNotice, in: pages) == 0)
        #expect(try Self.pageIndex(of: Self.payment.notesLabel, in: pages) == 1)
        #expect(try Self.pageIndex(of: notes, in: pages) == 1)
        #expect(Self.count(notes, in: html) == 1)
        #expect(!pages[0].contains("Line 1: "))
        #expect(Self.count(Self.common.pageNumber(2, of: 2), in: html) == 1)

        #if canImport(PDFKit)
        let reader = try #require(PDFDocument(data: try pdf.render()))
        let top = Self.footerTop(document)
        for needle in [Self.payment.notesLabel, "Line 1: " + paragraph, "NOTES-END-SENTINEL"] {
            let drawn = try Self.drawnBox(of: needle, in: reader)
            #expect(drawn.page == 1, "\(needle) drawn on page \(drawn.page + 1)")
            #expect(drawn.box.minY > top, "\(needle) at \(drawn.box.minY) pt")
        }
        let notice = try Self.drawnBox(of: Self.labels.notYetSubmittedNotice, in: reader)
        #expect(notice.page == 0)
        #endif
    }
}
