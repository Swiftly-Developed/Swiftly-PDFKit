import Foundation

// MARK: - PaymentReceiptLabels

/// Every rendered string the payment-receipt family emits that is *not* data.
///
/// Deliberately **not** a `LabelSet`: the family-neutral captions it also
/// needs (page numbering, continuation marker, supplier identity captions) are
/// carried beside it on ``PaymentReceiptDocument/common`` as a
/// ``CommonDocumentLabels`` value, so this type holds only what is specific to
/// a payment receipt.
///
/// The stored members are load-bearing in count and order: one per key of the
/// receipt's PDF string catalog, member = key with its first character
/// lower-cased. A server-side byte-twin is checked against this shape by
/// reflection, so a member is never added, removed or renamed without the
/// catalog and the twin moving in the same change. The helpers below are
/// functions, not stored members, so reflection does not see them.
///
/// Templated members use named `{token}` placeholders (`{last4}`, `{rate}`,
/// `{reason}`), never positional format specifiers, so translations can
/// reorder them freely.
public struct PaymentReceiptLabels: Sendable {

    // MARK: Masthead and header grid

    /// Document title.
    public var paymentReceiptTitle: String
    /// Caption of the receipt number in the header grid.
    public var receiptNumberLabel: String
    /// Caption of the receipt date in the header grid.
    public var receiptDateLabel: String
    /// Header of the payer block.
    public var receivedFromLabel: String
    /// Caption of the payer's customer reference.
    public var customerReferenceLabel: String

    // MARK: Payment facts

    /// Caption of the date the payment was made.
    public var paymentDateLabel: String
    /// Caption of the bank value date.
    public var valueDateLabel: String
    /// Caption of the bank booking date.
    public var bookingDateLabel: String
    /// Caption of the amount received.
    public var amountReceivedLabel: String
    /// Caption of the payment method.
    public var paymentMethodLabel: String
    /// Caption of the bank's own reference.
    public var bankReferenceLabel: String
    /// Caption of the SEPA end-to-end identifier.
    public var endToEndIdLabel: String
    /// Caption of the check number.
    public var checkNumberLabel: String
    /// Caption of the structured creditor reference.
    public var structuredReferenceLabel: String
    /// Caption of the free-text remittance information.
    public var remittanceInformationLabel: String
    /// Card value template. Supports the `{last4}` token; expand through ``cardEnding(last4:)``.
    public var cardEndingFormat: String
    /// Caption of the debtor's account.
    public var debtorAccountLabel: String
    /// Caption of the direct-debit mandate reference.
    public var mandateReferenceLabel: String

    // MARK: Payment means (UNCL 4461)

    /// Payment means `10`.
    public var paymentMeansCash: String
    /// Payment means `20`.
    public var paymentMeansCheck: String
    /// Payment means `30`.
    public var paymentMeansCreditTransfer: String
    /// Payment means `42`.
    public var paymentMeansOnlinePayment: String
    /// Payment means `48`.
    public var paymentMeansCard: String
    /// Payment means `49`.
    public var paymentMeansDirectDebit: String
    /// Payment means `58`.
    public var paymentMeansSEPACreditTransfer: String
    /// Payment means `59`.
    public var paymentMeansSEPADirectDebit: String

    // MARK: Allocation table

    /// Title above the allocation table.
    public var allocationSectionTitle: String
    /// Header of the document-number column.
    public var allocationColumnDocument: String
    /// Header of the document-date column.
    public var allocationColumnDocumentDate: String
    /// Header of the document-total column. Kept short: table headers are single-line.
    public var allocationColumnDocumentTotal: String
    /// Header of the paid-by-other-payments column. Kept short: table headers are single-line.
    public var allocationColumnOtherPayments: String
    /// Header of the amount-applied-by-this-payment column.
    public var allocationColumnApplied: String
    /// Header of the amount-still-open column.
    public var allocationColumnRemaining: String
    /// Shown in the remaining column when the document is settled.
    public var allocationSettledMarker: String
    /// The explicit empty state of the allocation table.
    public var allocationEmptyRow: String
    /// Exchange-rate sub-row template. Supports the `{rate}` token; expand through ``exchangeRate(_:)``.
    public var exchangeRateFormat: String

    // MARK: Totals

    /// Caption of the amount-received totals row.
    public var totalReceivedLabel: String
    /// Caption of the allocated totals row.
    public var totalAllocatedLabel: String
    /// Caption of the unallocated totals row, which is always rendered.
    public var totalUnallocatedLabel: String
    /// Caption of an informational bank-charge row.
    public var bankChargesLabel: String

    // MARK: Reversal, notes, footer

    /// Full-bleed watermark text on a reversed payment.
    public var reversedWatermark: String
    /// Reversal notice template. Supports the `{reason}` token; expand through ``reversedNotice(reason:)``.
    public var reversedNoticeFormat: String
    /// Caption above the receipt notes.
    public var notesLabel: String
    /// Footer line on every page.
    public var notAnInvoiceFooter: String

    // MARK: Reversal reasons (one per R-transaction reason code, in enum declaration order)

    /// Reversal reason `MD01`.
    public var reversalReasonMD01: String
    /// Reversal reason `MD02`.
    public var reversalReasonMD02: String
    /// Reversal reason `MD06`.
    public var reversalReasonMD06: String
    /// Reversal reason `MD07`.
    public var reversalReasonMD07: String
    /// Reversal reason `AC01`.
    public var reversalReasonAC01: String
    /// Reversal reason `AC04`.
    public var reversalReasonAC04: String
    /// Reversal reason `AC06`.
    public var reversalReasonAC06: String
    /// Reversal reason `AC13`.
    public var reversalReasonAC13: String
    /// Reversal reason `AM05`.
    public var reversalReasonAM05: String
    /// Reversal reason `MS02`.
    public var reversalReasonMS02: String
    /// Reversal reason `MS03`.
    public var reversalReasonMS03: String
    /// Reversal reason `RR01`.
    public var reversalReasonRR01: String
    /// Reversal reason `RR02`.
    public var reversalReasonRR02: String
    /// Reversal reason `RR03`.
    public var reversalReasonRR03: String
    /// Reversal reason `RR04`.
    public var reversalReasonRR04: String
    /// Reversal reason `FF01`.
    public var reversalReasonFF01: String

    // MARK: - English default

    /// The built-in English label set — the package-standalone default.
    public static let english = PaymentReceiptLabels()

    // MARK: - Init

    /// Memberwise initialiser. Every parameter defaults to its English value, so
    /// `PaymentReceiptLabels()` equals ``PaymentReceiptLabels/english`` and a
    /// host overrides only the entries it localizes.
    public init(
        paymentReceiptTitle: String = "Payment Receipt",
        receiptNumberLabel: String = "Receipt No.",
        receiptDateLabel: String = "Receipt date",
        receivedFromLabel: String = "Received from",
        customerReferenceLabel: String = "Customer reference",
        paymentDateLabel: String = "Payment date",
        valueDateLabel: String = "Value date",
        bookingDateLabel: String = "Booking date",
        amountReceivedLabel: String = "Amount received",
        paymentMethodLabel: String = "Payment method",
        bankReferenceLabel: String = "Bank reference",
        endToEndIdLabel: String = "End-to-end ID",
        checkNumberLabel: String = "Check number",
        structuredReferenceLabel: String = "Structured reference",
        remittanceInformationLabel: String = "Remittance information",
        cardEndingFormat: String = "Card ending in {last4}",
        debtorAccountLabel: String = "Debtor account",
        mandateReferenceLabel: String = "Mandate reference",
        paymentMeansCash: String = "Cash",
        paymentMeansCheck: String = "Check",
        paymentMeansCreditTransfer: String = "Credit transfer",
        paymentMeansOnlinePayment: String = "Online payment",
        paymentMeansCard: String = "Card",
        paymentMeansDirectDebit: String = "Direct debit",
        paymentMeansSEPACreditTransfer: String = "SEPA credit transfer",
        paymentMeansSEPADirectDebit: String = "SEPA direct debit",
        allocationSectionTitle: String = "Applied to",
        allocationColumnDocument: String = "Document",
        allocationColumnDocumentDate: String = "Date",
        allocationColumnDocumentTotal: String = "Total",
        allocationColumnOtherPayments: String = "Other credits",
        allocationColumnApplied: String = "Applied",
        allocationColumnRemaining: String = "Remaining",
        allocationSettledMarker: String = "Settled",
        allocationEmptyRow: String = "Not applied to any document — the full amount is held on account.",
        exchangeRateFormat: String = "Rate {rate}",
        totalReceivedLabel: String = "Total received",
        totalAllocatedLabel: String = "Applied to documents",
        totalUnallocatedLabel: String = "Unallocated (on account)",
        bankChargesLabel: String = "Bank charges",
        reversedWatermark: String = "REVERSED",
        reversedNoticeFormat: String = "This payment was reversed: {reason}",
        notesLabel: String = "Notes",
        notAnInvoiceFooter: String = "This receipt is not an invoice. VAT is stated on the underlying invoices.",
        reversalReasonMD01: String = "MD01 — No valid mandate",
        reversalReasonMD02: String = "MD02 — Missing mandate info",
        reversalReasonMD06: String = "MD06 — Refund request by debtor",
        reversalReasonMD07: String = "MD07 — Account closed (debtor)",
        reversalReasonAC01: String = "AC01 — Incorrect account number",
        reversalReasonAC04: String = "AC04 — Closed account number",
        reversalReasonAC06: String = "AC06 — Blocked account",
        reversalReasonAC13: String = "AC13 — Debtor account type invalid",
        reversalReasonAM05: String = "AM05 — Duplicate",
        reversalReasonMS02: String = "MS02 — Reason given by customer",
        reversalReasonMS03: String = "MS03 — Reason not specified",
        reversalReasonRR01: String = "RR01 — Regulatory: missing debtor info",
        reversalReasonRR02: String = "RR02 — Regulatory: missing debtor name/address",
        reversalReasonRR03: String = "RR03 — Regulatory: missing creditor info",
        reversalReasonRR04: String = "RR04 — Regulatory reason",
        reversalReasonFF01: String = "FF01 — Invalid file format"
    ) {
        self.paymentReceiptTitle = paymentReceiptTitle
        self.receiptNumberLabel = receiptNumberLabel
        self.receiptDateLabel = receiptDateLabel
        self.receivedFromLabel = receivedFromLabel
        self.customerReferenceLabel = customerReferenceLabel
        self.paymentDateLabel = paymentDateLabel
        self.valueDateLabel = valueDateLabel
        self.bookingDateLabel = bookingDateLabel
        self.amountReceivedLabel = amountReceivedLabel
        self.paymentMethodLabel = paymentMethodLabel
        self.bankReferenceLabel = bankReferenceLabel
        self.endToEndIdLabel = endToEndIdLabel
        self.checkNumberLabel = checkNumberLabel
        self.structuredReferenceLabel = structuredReferenceLabel
        self.remittanceInformationLabel = remittanceInformationLabel
        self.cardEndingFormat = cardEndingFormat
        self.debtorAccountLabel = debtorAccountLabel
        self.mandateReferenceLabel = mandateReferenceLabel
        self.paymentMeansCash = paymentMeansCash
        self.paymentMeansCheck = paymentMeansCheck
        self.paymentMeansCreditTransfer = paymentMeansCreditTransfer
        self.paymentMeansOnlinePayment = paymentMeansOnlinePayment
        self.paymentMeansCard = paymentMeansCard
        self.paymentMeansDirectDebit = paymentMeansDirectDebit
        self.paymentMeansSEPACreditTransfer = paymentMeansSEPACreditTransfer
        self.paymentMeansSEPADirectDebit = paymentMeansSEPADirectDebit
        self.allocationSectionTitle = allocationSectionTitle
        self.allocationColumnDocument = allocationColumnDocument
        self.allocationColumnDocumentDate = allocationColumnDocumentDate
        self.allocationColumnDocumentTotal = allocationColumnDocumentTotal
        self.allocationColumnOtherPayments = allocationColumnOtherPayments
        self.allocationColumnApplied = allocationColumnApplied
        self.allocationColumnRemaining = allocationColumnRemaining
        self.allocationSettledMarker = allocationSettledMarker
        self.allocationEmptyRow = allocationEmptyRow
        self.exchangeRateFormat = exchangeRateFormat
        self.totalReceivedLabel = totalReceivedLabel
        self.totalAllocatedLabel = totalAllocatedLabel
        self.totalUnallocatedLabel = totalUnallocatedLabel
        self.bankChargesLabel = bankChargesLabel
        self.reversedWatermark = reversedWatermark
        self.reversedNoticeFormat = reversedNoticeFormat
        self.notesLabel = notesLabel
        self.notAnInvoiceFooter = notAnInvoiceFooter
        self.reversalReasonMD01 = reversalReasonMD01
        self.reversalReasonMD02 = reversalReasonMD02
        self.reversalReasonMD06 = reversalReasonMD06
        self.reversalReasonMD07 = reversalReasonMD07
        self.reversalReasonAC01 = reversalReasonAC01
        self.reversalReasonAC04 = reversalReasonAC04
        self.reversalReasonAC06 = reversalReasonAC06
        self.reversalReasonAC13 = reversalReasonAC13
        self.reversalReasonAM05 = reversalReasonAM05
        self.reversalReasonMS02 = reversalReasonMS02
        self.reversalReasonMS03 = reversalReasonMS03
        self.reversalReasonRR01 = reversalReasonRR01
        self.reversalReasonRR02 = reversalReasonRR02
        self.reversalReasonRR03 = reversalReasonRR03
        self.reversalReasonRR04 = reversalReasonRR04
        self.reversalReasonFF01 = reversalReasonFF01
    }

    // MARK: - Template expansion

    /// Expands ``cardEndingFormat`` with the card's last four digits.
    public func cardEnding(last4: String) -> String {
        cardEndingFormat.replacingOccurrences(of: "{last4}", with: last4)
    }

    /// Expands ``exchangeRateFormat`` with an already-formatted rate.
    public func exchangeRate(_ rate: String) -> String {
        exchangeRateFormat.replacingOccurrences(of: "{rate}", with: rate)
    }

    /// Expands ``reversedNoticeFormat`` with an already-resolved reason.
    public func reversedNotice(reason: String) -> String {
        reversedNoticeFormat.replacingOccurrences(of: "{reason}", with: reason)
    }

    // MARK: - Code lookups

    /// The display text of an R-transaction reason code.
    ///
    /// Matches on the trimmed, upper-cased code. An unknown non-blank code is
    /// returned as given (trimmed): a reason the bank sent that this release
    /// does not know is still printed rather than dropped.
    public func reversalReason(forCode code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.uppercased() {
        case "MD01": return reversalReasonMD01
        case "MD02": return reversalReasonMD02
        case "MD06": return reversalReasonMD06
        case "MD07": return reversalReasonMD07
        case "AC01": return reversalReasonAC01
        case "AC04": return reversalReasonAC04
        case "AC06": return reversalReasonAC06
        case "AC13": return reversalReasonAC13
        case "AM05": return reversalReasonAM05
        case "MS02": return reversalReasonMS02
        case "MS03": return reversalReasonMS03
        case "RR01": return reversalReasonRR01
        case "RR02": return reversalReasonRR02
        case "RR03": return reversalReasonRR03
        case "RR04": return reversalReasonRR04
        case "FF01": return reversalReasonFF01
        default: return trimmed
        }
    }

    /// The display label of a UNCL 4461 payment-means code, or `nil` for a code
    /// this set does not name — the caller then falls back to its own wording.
    public func paymentMeansLabel(forCode code: String?) -> String? {
        guard let code else { return nil }
        switch code.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "10": return paymentMeansCash
        case "20": return paymentMeansCheck
        case "30": return paymentMeansCreditTransfer
        case "42": return paymentMeansOnlinePayment
        case "48": return paymentMeansCard
        case "49": return paymentMeansDirectDebit
        case "58": return paymentMeansSEPACreditTransfer
        case "59": return paymentMeansSEPADirectDebit
        default: return nil
        }
    }
}
