import Foundation

// MARK: - RemittanceAdviceDocument

/// Everything the remittance-advice family renders: one outgoing vendor
/// payment — or one batch of them — the bills and credit notes it settled,
/// and what it leaves on account.
///
/// The advice is the payer's own announcement to the payee, so the issuer is
/// **our** company (its bank line printed: it is the account the money leaves
/// from) and the counter-party is the payee. Two forms share one model: the
/// single form (`memberPayments == nil`) and the batch form, which lists the
/// batch's member payments and states, per settled document, which member
/// paid it.
///
/// Mappers hand the package **resolved display values** and do every sum: dates
/// arrive formatted (the mapper owns the timezone rule), the payment facts
/// arrive ordered and captioned, the paid-to account arrives already masked,
/// the remittance text arrives exactly as the payment builder emitted it, and
/// every gross / other / applied / remaining figure and every total arrives
/// computed. The layout does no arithmetic. Money stays a number plus an ISO
/// 4217 code and is printed as `amount + " " + code`, because one advice can
/// carry several currencies.
public struct RemittanceAdviceDocument: Sendable {
    /// Our company — the letterhead (its `logoPath` included). Its bank line is
    /// printed.
    public var issuer: InvoiceSupplier
    /// Who was paid.
    public var payee: RemittanceAdvicePayee
    /// Advice number or batch reference, and dates.
    public var header: RemittanceAdviceHeader
    /// The payment's own facts, ordered and already captioned. Absent facts are
    /// simply not in the list.
    public var paymentFacts: [RemittanceAdviceFact]
    /// The batch's member payments; `nil` ⇔ the single form.
    public var memberPayments: [RemittanceAdviceMemberPayment]?
    /// One row per settled document, already summed per document and ordered.
    public var details: [RemittanceAdviceDetailRow]
    /// One totals block per currency, ordered.
    public var totals: [RemittanceAdviceTotals]
    /// The remittance information, one line per payment (batch: per member).
    public var remittanceLines: [RemittanceAdviceTextLine]
    /// The status watermark and its notice.
    public var watermark: RemittanceAdviceWatermark
    /// The payment's own notes; never its internal notes.
    public var notes: String?
    /// The address the footer's queries line names; `nil` or blank ⇒ no line.
    public var contactEmail: String?
    /// The remittance-only captions.
    public var labels: RemittanceAdviceLabels
    /// The captions shared with the payment receipt.
    public var payment: PaymentReceiptLabels
    /// The family-neutral captions the shared blocks and the footer read.
    public var common: CommonDocumentLabels

    public init(
        issuer: InvoiceSupplier,
        payee: RemittanceAdvicePayee,
        header: RemittanceAdviceHeader,
        paymentFacts: [RemittanceAdviceFact] = [],
        memberPayments: [RemittanceAdviceMemberPayment]? = nil,
        details: [RemittanceAdviceDetailRow] = [],
        totals: [RemittanceAdviceTotals],
        remittanceLines: [RemittanceAdviceTextLine] = [],
        watermark: RemittanceAdviceWatermark = .none,
        notes: String? = nil,
        contactEmail: String? = nil,
        labels: RemittanceAdviceLabels = .english,
        payment: PaymentReceiptLabels = .english,
        common: CommonDocumentLabels = .english
    ) {
        self.issuer = issuer
        self.payee = payee
        self.header = header
        self.paymentFacts = paymentFacts
        self.memberPayments = memberPayments
        self.details = details
        self.totals = totals
        self.remittanceLines = remittanceLines
        self.watermark = watermark
        self.notes = notes
        self.contactEmail = contactEmail
        self.labels = labels
        self.payment = payment
        self.common = common
    }
}

// MARK: - RemittanceAdvicePayee

/// The paid party, with the identifiers an advice prints beside it.
public struct RemittanceAdvicePayee: Sendable {
    public var party: InvoiceParty
    /// The payee's company-register number.
    public var registerNumber: String?
    /// Our supplier number for the payee.
    public var supplierNumber: String?
    /// The payee's customer number for us.
    public var yourReferenceForUs: String?
    /// The account the payment went to — already masked by the mapper.
    public var paidToAccount: String?
    /// The BIC of that account.
    public var paidToBIC: String?

    public init(
        party: InvoiceParty,
        registerNumber: String? = nil,
        supplierNumber: String? = nil,
        yourReferenceForUs: String? = nil,
        paidToAccount: String? = nil,
        paidToBIC: String? = nil
    ) {
        self.party = party
        self.registerNumber = registerNumber
        self.supplierNumber = supplierNumber
        self.yourReferenceForUs = yourReferenceForUs
        self.paidToAccount = paidToAccount
        self.paidToBIC = paidToBIC
    }
}

// MARK: - RemittanceAdviceHeader

/// The advice number (single form) or the batch reference (batch form), and
/// the dates — already formatted.
public struct RemittanceAdviceHeader: Sendable {
    public var adviceNumber: String?
    public var batchReference: String?
    public var adviceDate: String
    /// Printed only when the host stamps one.
    public var generatedOn: String?

    public init(
        adviceNumber: String? = nil,
        batchReference: String? = nil,
        adviceDate: String,
        generatedOn: String? = nil
    ) {
        self.adviceNumber = adviceNumber
        self.batchReference = batchReference
        self.adviceDate = adviceDate
        self.generatedOn = generatedOn
    }
}

// MARK: - RemittanceAdviceFact

/// One captioned payment fact, already formatted.
public struct RemittanceAdviceFact: Sendable {
    public var caption: String
    public var value: String

    public init(caption: String, value: String) {
        self.caption = caption
        self.value = value
    }
}

// MARK: - RemittanceAdviceMemberPayment

/// One member payment of a batch.
public struct RemittanceAdviceMemberPayment: Sendable {
    public var paymentNumber: String
    public var endToEndId: String?
    public var paymentInfoId: String?
    public var amount: Double
    public var currencyCode: String
    public var isReversed: Bool

    public init(
        paymentNumber: String,
        endToEndId: String? = nil,
        paymentInfoId: String? = nil,
        amount: Double,
        currencyCode: String,
        isReversed: Bool = false
    ) {
        self.paymentNumber = paymentNumber
        self.endToEndId = endToEndId
        self.paymentInfoId = paymentInfoId
        self.amount = amount
        self.currencyCode = currencyCode
        self.isReversed = isReversed
    }
}

// MARK: - RemittanceAdviceDocumentKind

/// What a settled document is.
public enum RemittanceAdviceDocumentKind: Sendable, Equatable {
    case invoice
    case creditNote
}

// MARK: - RemittanceAdviceAmount

/// A figure with its own ISO 4217 code.
public struct RemittanceAdviceAmount: Sendable {
    public var value: Double
    public var currencyCode: String

    public init(value: Double, currencyCode: String) {
        self.value = value
        self.currencyCode = currencyCode
    }
}

// MARK: - RemittanceAdviceDetailRow

/// One settled document, already summed. Figures in the document's currency
/// unless stated; a `nil` figure prints "—".
public struct RemittanceAdviceDetailRow: Sendable {
    public var kind: RemittanceAdviceDocumentKind
    /// The payee's own document number.
    public var theirNumber: String?
    /// The payee's document date, already formatted — printed in the date column.
    public var theirDate: String?
    /// Our document number.
    public var ourReference: String?
    public var documentCurrencyCode: String
    public var gross: Double?
    public var paidByOtherPayments: Double?
    /// The amount applied, in the paying payment's currency.
    public var applied: Double
    public var appliedCurrencyCode: String
    /// Both set ⇒ the rate sub-row.
    public var appliedInDocumentCurrency: Double?
    public var exchangeRate: Double?
    /// `nil` ⇒ "—", never the settled marker.
    public var remaining: Double?
    public var isSettled: Bool
    /// A sub-row only when non-zero.
    public var discount: RemittanceAdviceAmount?
    /// A sub-row only when non-zero.
    public var adjustment: RemittanceAdviceAmount?
    public var adjustmentReason: String?
    /// The member payment that paid this document — read in the batch form only.
    public var paidByPaymentNumber: String?
    /// Batch form: the member payment that paid this document was reversed.
    public var isReversed: Bool

    public init(
        kind: RemittanceAdviceDocumentKind = .invoice,
        theirNumber: String? = nil,
        theirDate: String? = nil,
        ourReference: String? = nil,
        documentCurrencyCode: String,
        gross: Double? = nil,
        paidByOtherPayments: Double? = nil,
        applied: Double,
        appliedCurrencyCode: String,
        appliedInDocumentCurrency: Double? = nil,
        exchangeRate: Double? = nil,
        remaining: Double? = nil,
        isSettled: Bool = false,
        discount: RemittanceAdviceAmount? = nil,
        adjustment: RemittanceAdviceAmount? = nil,
        adjustmentReason: String? = nil,
        paidByPaymentNumber: String? = nil,
        isReversed: Bool = false
    ) {
        self.kind = kind
        self.theirNumber = theirNumber
        self.theirDate = theirDate
        self.ourReference = ourReference
        self.documentCurrencyCode = documentCurrencyCode
        self.gross = gross
        self.paidByOtherPayments = paidByOtherPayments
        self.applied = applied
        self.appliedCurrencyCode = appliedCurrencyCode
        self.appliedInDocumentCurrency = appliedInDocumentCurrency
        self.exchangeRate = exchangeRate
        self.remaining = remaining
        self.isSettled = isSettled
        self.discount = discount
        self.adjustment = adjustment
        self.adjustmentReason = adjustmentReason
        self.paidByPaymentNumber = paidByPaymentNumber
        self.isReversed = isReversed
    }
}

// MARK: - RemittanceAdviceTotals

/// One currency's closing totals. VAT-free by construction; every figure
/// computed by the mapper.
public struct RemittanceAdviceTotals: Sendable {
    public var currencyCode: String
    public var bills: Double
    /// A row only when non-nil and non-zero.
    public var discount: Double?
    /// A row only when non-nil and non-zero.
    public var adjustments: Double?
    /// A row iff non-nil (the mapper sets it iff a credit note was applied).
    public var credits: Double?
    public var transferred: Double
    /// Always printed, a zero included.
    public var onAccount: Double
    /// Informational bank-charge rows, each in its own currency.
    public var charges: [RemittanceAdviceAmount]

    public init(
        currencyCode: String,
        bills: Double,
        discount: Double? = nil,
        adjustments: Double? = nil,
        credits: Double? = nil,
        transferred: Double,
        onAccount: Double,
        charges: [RemittanceAdviceAmount] = []
    ) {
        self.currencyCode = currencyCode
        self.bills = bills
        self.discount = discount
        self.adjustments = adjustments
        self.credits = credits
        self.transferred = transferred
        self.onAccount = onAccount
        self.charges = charges
    }
}

// MARK: - RemittanceAdviceTextLine

/// One payment's remittance information, as the payment builder emitted it.
public struct RemittanceAdviceTextLine: Sendable {
    public var text: String
    /// The text is what the bank received.
    public var asSent: Bool
    /// The builder shortened the text to what the bank transmits.
    public var truncated: Bool
    /// The member payment it belongs to (batch form); printed as a prefix.
    public var paymentNumber: String?

    public init(text: String, asSent: Bool = false, truncated: Bool = false, paymentNumber: String? = nil) {
        self.text = text
        self.asSent = asSent
        self.truncated = truncated
        self.paymentNumber = paymentNumber
    }
}

// MARK: - RemittanceAdviceWatermark

/// The status watermark. The mapper decides precedence; the layout prints the
/// one it is given on every page, with its notice on the last page.
public enum RemittanceAdviceWatermark: Sendable, Equatable {
    case none
    /// The payment was reversed; the notice resolves the reason code through
    /// ``PaymentReceiptLabels/reversalReason(forCode:)``.
    case reversed(reasonCode: String?)
    /// The batch has not been submitted to the bank yet.
    case notYetSubmitted
}
