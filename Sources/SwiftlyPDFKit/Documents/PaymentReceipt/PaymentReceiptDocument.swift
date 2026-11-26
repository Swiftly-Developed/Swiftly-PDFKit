import Foundation

// MARK: - PaymentReceiptDocument

/// Everything the payment-receipt family renders: one recorded customer
/// payment, the documents it was applied to, and what is left over.
///
/// A payment has no line items and carries no VAT, so this is its own model
/// rather than a reuse of the invoice model with a synthetic one-line body.
///
/// Mappers hand the package **resolved display values**: dates arrive as
/// formatted strings (the mapper owns the timezone rule), the payment facts
/// arrive as an ordered caption / value list, and the settled marker is a flag
/// the mapper computes against the company's own tolerance. Money stays a
/// number plus an ISO 4217 code and is formatted by the layout in the
/// document's locale.
public struct PaymentReceiptDocument: Sendable {
    /// The issuing company — the letterhead (its `logoPath` included).
    public var supplier: InvoiceSupplier
    /// Who paid.
    public var payer: PaymentReceiptPayer
    /// Receipt number and dates.
    public var header: PaymentReceiptHeader
    /// The payment's own facts, ordered and already captioned (date, method,
    /// bank reference …). Absent facts are simply not in the list.
    public var paymentFacts: [PaymentReceiptFact]
    /// One row per document the payment was applied to, already netted and
    /// summed per document. Empty when nothing was applied.
    public var allocations: [PaymentReceiptAllocationRow]
    /// Received / allocated / unallocated amounts and any bank charges.
    public var totals: PaymentReceiptTotals
    /// Set iff the payment was reversed.
    public var reversal: PaymentReceiptReversal?
    /// The receipt's own notes; never the payment's internal notes.
    public var notes: String?
    /// The receipt-specific captions.
    public var labels: PaymentReceiptLabels
    /// The family-neutral captions the shared blocks and the footer read.
    public var common: CommonDocumentLabels

    public init(
        supplier: InvoiceSupplier,
        payer: PaymentReceiptPayer,
        header: PaymentReceiptHeader,
        paymentFacts: [PaymentReceiptFact] = [],
        allocations: [PaymentReceiptAllocationRow] = [],
        totals: PaymentReceiptTotals,
        reversal: PaymentReceiptReversal? = nil,
        notes: String? = nil,
        labels: PaymentReceiptLabels = .english,
        common: CommonDocumentLabels = .english
    ) {
        self.supplier = supplier
        self.payer = payer
        self.header = header
        self.paymentFacts = paymentFacts
        self.allocations = allocations
        self.totals = totals
        self.reversal = reversal
        self.notes = notes
        self.labels = labels
        self.common = common
    }
}

// MARK: - PaymentReceiptPayer

/// The paying party, with the two identifiers a receipt prints beside it.
public struct PaymentReceiptPayer: Sendable {
    /// Postal / legal block.
    public var party: InvoiceParty
    /// The payer's commercial-register number, when known.
    public var registerNumber: String?
    /// The issuer's own reference for this customer.
    public var customerReference: String?

    public init(party: InvoiceParty, registerNumber: String? = nil, customerReference: String? = nil) {
        self.party = party
        self.registerNumber = registerNumber
        self.customerReference = customerReference
    }
}

// MARK: - PaymentReceiptHeader

/// Receipt identity: its number and its dates, already formatted.
public struct PaymentReceiptHeader: Sendable {
    public var receiptNumber: String
    public var receiptDate: String
    /// The generation timestamp, when the host prints one.
    public var generatedOn: String?

    public init(receiptNumber: String, receiptDate: String, generatedOn: String? = nil) {
        self.receiptNumber = receiptNumber
        self.receiptDate = receiptDate
        self.generatedOn = generatedOn
    }
}

// MARK: - PaymentReceiptFact

/// One captioned payment fact (e.g. "Payment method" · "SEPA credit transfer").
public struct PaymentReceiptFact: Sendable {
    public var caption: String
    public var value: String

    public init(caption: String, value: String) {
        self.caption = caption
        self.value = value
    }
}

// MARK: - PaymentReceiptAllocationRow

/// One document the payment was applied to.
///
/// `appliedAmount` is in the payment's currency. When the document is in a
/// different currency, both `appliedInDocumentCurrency` and `exchangeRate` are
/// set and the layout prints a rate sub-row under the document's row.
///
/// `paidByOtherPayments` and `remaining` are in the document's currency. When a
/// figure cannot be stated in the document's own currency (a document whose
/// currency differs from the payment's), the mapper passes `nil` and the layout
/// prints "—"; a `nil` `remaining` also suppresses the settled marker.
///
/// `documentTotal` is in the document's currency; a mapper whose caller cannot
/// read the document's total (a withheld field) passes `nil` and the layout
/// prints "—" in that cell.
///
/// `documentDate` is printed verbatim: `nil` is a genuinely undated document
/// and prints an empty cell; a withheld date is passed as the string "—"
/// (U+2014), which prints as given.
public struct PaymentReceiptAllocationRow: Sendable {
    public var documentNumber: String
    public var documentDate: String?
    public var documentCurrencyCode: String
    public var documentTotal: Double?
    public var paidByOtherPayments: Double?
    public var appliedAmount: Double
    public var appliedInDocumentCurrency: Double?
    public var exchangeRate: Double?
    public var remaining: Double?
    /// Computed by the mapper against the company's tolerance; the layout
    /// prints the settled marker instead of `remaining` when set — unless
    /// `remaining` is `nil`, which prints "—" either way.
    public var isSettled: Bool

    public init(
        documentNumber: String,
        documentDate: String? = nil,
        documentCurrencyCode: String,
        documentTotal: Double?,
        paidByOtherPayments: Double?,
        appliedAmount: Double,
        appliedInDocumentCurrency: Double? = nil,
        exchangeRate: Double? = nil,
        remaining: Double?,
        isSettled: Bool
    ) {
        self.documentNumber = documentNumber
        self.documentDate = documentDate
        self.documentCurrencyCode = documentCurrencyCode
        self.documentTotal = documentTotal
        self.paidByOtherPayments = paidByOtherPayments
        self.appliedAmount = appliedAmount
        self.appliedInDocumentCurrency = appliedInDocumentCurrency
        self.exchangeRate = exchangeRate
        self.remaining = remaining
        self.isSettled = isSettled
    }
}

// MARK: - PaymentReceiptTotals

/// The closing totals stack. VAT-free by construction.
public struct PaymentReceiptTotals: Sendable {
    /// The payment's currency, which is also the receipt's.
    public var currencyCode: String
    public var received: Double
    public var allocated: Double
    /// Always rendered, a zero included.
    public var unallocated: Double
    /// Informational only — never subtracted from anything.
    public var charges: [PaymentReceiptCharge]

    public init(
        currencyCode: String,
        received: Double,
        allocated: Double,
        unallocated: Double,
        charges: [PaymentReceiptCharge] = []
    ) {
        self.currencyCode = currencyCode
        self.received = received
        self.allocated = allocated
        self.unallocated = unallocated
        self.charges = charges
    }
}

// MARK: - PaymentReceiptCharge

/// One bank charge, in its own currency.
public struct PaymentReceiptCharge: Sendable {
    public var amount: Double
    public var currencyCode: String

    public init(amount: Double, currencyCode: String) {
        self.amount = amount
        self.currencyCode = currencyCode
    }
}

// MARK: - PaymentReceiptReversal

/// Present iff the payment was reversed.
public struct PaymentReceiptReversal: Sendable {
    /// The R-transaction reason code, when the bank supplied one.
    public var reasonCode: String?

    public init(reasonCode: String? = nil) {
        self.reasonCode = reasonCode
    }
}
