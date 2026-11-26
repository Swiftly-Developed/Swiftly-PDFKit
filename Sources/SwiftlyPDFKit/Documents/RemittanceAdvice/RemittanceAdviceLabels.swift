import Foundation

// MARK: - RemittanceAdviceLabels

/// Every rendered string the remittance-advice family emits that is *not*
/// data and that the payment receipt does not already carry.
///
/// Deliberately **not** a `LabelSet`: the captions it shares with the payment
/// receipt (the allocation column headers, the settled marker, the empty row,
/// the rate template, the reversal watermark, notice and reasons, the notes,
/// bank-charges and remittance-information captions) are read from
/// ``RemittanceAdviceDocument/payment`` as a ``PaymentReceiptLabels`` value,
/// and the family-neutral ones (page numbering, continuation marker, supplier
/// identity captions, the discount totals caption) from
/// ``RemittanceAdviceDocument/common`` as a ``CommonDocumentLabels`` value. Both
/// travel beside this set on the document, so this type holds **only** the
/// remittance-only keys of the shared payment PDF catalog.
///
/// The stored members are load-bearing in count and order: one per
/// remittance-only key of that catalog, member = key with its first character
/// lower-cased. A server-side byte-twin is checked against this shape by
/// reflection, so a member is never added, removed or renamed without the
/// catalog and the twin moving in the same change. The helper below is a
/// function, not a stored member, so reflection does not see it.
///
/// Templated members use named `{token}` placeholders (`{reason}`), never
/// positional format specifiers, so translations can reorder them freely.
public struct RemittanceAdviceLabels: Sendable {

    // MARK: Masthead and header grid

    /// Document title.
    public var remittanceAdviceTitle: String
    /// Caption of the advice number (single form) in the header grid.
    public var adviceNumberLabel: String
    /// Caption of the advice date in the header grid.
    public var adviceDateLabel: String
    /// Caption of the batch reference (batch form) in the header grid.
    public var batchReferenceLabel: String
    /// Caption of the SEPA payment-information identifier.
    public var paymentInfoIdLabel: String

    // MARK: Payee

    /// Header of the payee block.
    public var paidToLabel: String
    /// Caption of our supplier number for the payee.
    public var supplierNumberLabel: String
    /// Caption of the payee's customer number for us.
    public var yourReferenceForUsLabel: String
    /// Caption of the (masked) account the payment went to.
    public var paidToAccountLabel: String

    // MARK: Payment facts

    /// Caption of the requested execution date.
    public var executionDateLabel: String
    /// Caption of the date the batch was submitted to the bank.
    public var submittedToBankLabel: String
    /// Caption of the amount paid — a payment fact, not the invoice ladder's "already paid".
    public var amountPaidLabel: String
    /// Caption of the wire reference.
    public var wireReferenceLabel: String
    /// Caption of the (masked) account the payment left from.
    public var ourBankAccountLabel: String
    /// Caption of the ISO 20022 purpose code.
    public var purposeCodeLabel: String

    // MARK: Member payments (batch form)

    /// Title above the batch form's member-payment list.
    public var paymentsInBatchTitle: String
    /// Header of the member list's payment column.
    public var paymentColumnLabel: String

    // MARK: Detail table

    /// Title above the detail table.
    public var settledDocumentsTitle: String
    /// Second line of the stacked document header: the document type.
    public var documentTypeColumn: String
    /// Document type of a bill.
    public var documentTypeInvoice: String
    /// Document type of a vendor credit note.
    public var documentTypeCreditNote: String
    /// First line of the stacked document header: the payee's own number.
    public var yourReferenceColumn: String
    /// Third line of the stacked document header: our document number.
    public var ourReferenceColumn: String
    /// Caption of a cash-discount sub-row.
    public var discountColumn: String
    /// Caption of an adjustment sub-row without a reason.
    public var adjustmentColumn: String
    /// Adjustment sub-row template. Supports the `{reason}` token; expand through ``adjustmentReason(_:)``.
    public var adjustmentReasonFormat: String
    /// Fourth line of the stacked document header in the batch form: the paying member payment.
    public var paidByPaymentColumn: String
    /// Marker on a member payment, or a document it paid, that was reversed.
    public var reversedRowMarker: String

    // MARK: Totals

    /// Caption of the bills totals row.
    public var totalBillsLabel: String
    /// Caption of the adjustments totals row.
    public var totalAdjustmentsLabel: String
    /// Caption of the credit-notes totals row.
    public var totalCreditsLabel: String
    /// Caption of the emphasised amount-transferred totals row.
    public var totalTransferredLabel: String
    /// Caption of the on-account totals row, which is always rendered.
    public var totalOnAccountLabel: String

    // MARK: Remittance information, status, footer

    /// Caption of the remittance block when every line is the text the bank received.
    public var remittanceTextAsSentLabel: String
    /// Notice under a remittance line the builder shortened.
    public var remittanceTruncatedNotice: String
    /// Full-bleed watermark text on an advice whose batch is not submitted yet.
    public var notYetSubmittedWatermark: String
    /// Status notice on an advice whose batch is not submitted yet.
    public var notYetSubmittedNotice: String
    /// Footer line on every page.
    public var fundsSubjectToProcessingNotice: String
    /// Caption before the queries e-mail address in the footer.
    public var queriesContactLabel: String

    // MARK: - English default

    /// The built-in English label set — the package-standalone default.
    public static let english = RemittanceAdviceLabels()

    // MARK: - Init

    /// Memberwise initialiser. Every parameter defaults to its English value, so
    /// `RemittanceAdviceLabels()` equals ``RemittanceAdviceLabels/english`` and a
    /// host overrides only the entries it localizes.
    public init(
        remittanceAdviceTitle: String = "Remittance advice",
        adviceNumberLabel: String = "Advice no.",
        adviceDateLabel: String = "Advice date",
        batchReferenceLabel: String = "Batch reference",
        paymentInfoIdLabel: String = "Payment information ID",
        paidToLabel: String = "Paid to",
        supplierNumberLabel: String = "Supplier no.",
        yourReferenceForUsLabel: String = "Your reference for us",
        paidToAccountLabel: String = "Paid to account",
        executionDateLabel: String = "Requested execution date",
        submittedToBankLabel: String = "Submitted to bank",
        amountPaidLabel: String = "Amount paid",
        wireReferenceLabel: String = "Wire reference",
        ourBankAccountLabel: String = "Our bank account",
        purposeCodeLabel: String = "Purpose code",
        paymentsInBatchTitle: String = "Payments in this batch",
        paymentColumnLabel: String = "Payment",
        settledDocumentsTitle: String = "Documents settled",
        documentTypeColumn: String = "Type",
        documentTypeInvoice: String = "Invoice",
        documentTypeCreditNote: String = "Credit note",
        yourReferenceColumn: String = "Your reference",
        ourReferenceColumn: String = "Our reference",
        discountColumn: String = "Cash discount",
        adjustmentColumn: String = "Adjustment",
        adjustmentReasonFormat: String = "Adjustment: {reason}",
        paidByPaymentColumn: String = "Paid by",
        reversedRowMarker: String = "Reversed",
        totalBillsLabel: String = "Total of bills",
        totalAdjustmentsLabel: String = "Adjustments",
        totalCreditsLabel: String = "Credit notes applied",
        totalTransferredLabel: String = "Amount transferred",
        totalOnAccountLabel: String = "Held on account",
        remittanceTextAsSentLabel: String = "Remittance information as sent to the bank",
        remittanceTruncatedNotice: String = "Shortened to the 140 characters the bank transmits.",
        notYetSubmittedWatermark: String = "NOT YET SUBMITTED",
        notYetSubmittedNotice: String = "This batch has not been submitted to the bank yet. Treat this advice as a preview.",
        fundsSubjectToProcessingNotice: String = "Execution is subject to bank processing; this advice is an announcement, not a payment.",
        queriesContactLabel: String = "Questions about this payment:"
    ) {
        self.remittanceAdviceTitle = remittanceAdviceTitle
        self.adviceNumberLabel = adviceNumberLabel
        self.adviceDateLabel = adviceDateLabel
        self.batchReferenceLabel = batchReferenceLabel
        self.paymentInfoIdLabel = paymentInfoIdLabel
        self.paidToLabel = paidToLabel
        self.supplierNumberLabel = supplierNumberLabel
        self.yourReferenceForUsLabel = yourReferenceForUsLabel
        self.paidToAccountLabel = paidToAccountLabel
        self.executionDateLabel = executionDateLabel
        self.submittedToBankLabel = submittedToBankLabel
        self.amountPaidLabel = amountPaidLabel
        self.wireReferenceLabel = wireReferenceLabel
        self.ourBankAccountLabel = ourBankAccountLabel
        self.purposeCodeLabel = purposeCodeLabel
        self.paymentsInBatchTitle = paymentsInBatchTitle
        self.paymentColumnLabel = paymentColumnLabel
        self.settledDocumentsTitle = settledDocumentsTitle
        self.documentTypeColumn = documentTypeColumn
        self.documentTypeInvoice = documentTypeInvoice
        self.documentTypeCreditNote = documentTypeCreditNote
        self.yourReferenceColumn = yourReferenceColumn
        self.ourReferenceColumn = ourReferenceColumn
        self.discountColumn = discountColumn
        self.adjustmentColumn = adjustmentColumn
        self.adjustmentReasonFormat = adjustmentReasonFormat
        self.paidByPaymentColumn = paidByPaymentColumn
        self.reversedRowMarker = reversedRowMarker
        self.totalBillsLabel = totalBillsLabel
        self.totalAdjustmentsLabel = totalAdjustmentsLabel
        self.totalCreditsLabel = totalCreditsLabel
        self.totalTransferredLabel = totalTransferredLabel
        self.totalOnAccountLabel = totalOnAccountLabel
        self.remittanceTextAsSentLabel = remittanceTextAsSentLabel
        self.remittanceTruncatedNotice = remittanceTruncatedNotice
        self.notYetSubmittedWatermark = notYetSubmittedWatermark
        self.notYetSubmittedNotice = notYetSubmittedNotice
        self.fundsSubjectToProcessingNotice = fundsSubjectToProcessingNotice
        self.queriesContactLabel = queriesContactLabel
    }

    // MARK: - Template expansion

    /// Expands ``adjustmentReasonFormat`` with an already-resolved reason.
    public func adjustmentReason(_ reason: String) -> String {
        adjustmentReasonFormat.replacingOccurrences(of: "{reason}", with: reason)
    }
}
