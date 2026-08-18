import Foundation

// MARK: - InvoiceParty

/// A postal/legal party address block shared by the enrichment fields on
/// ``InvoiceDocument`` (e.g. the ship-to address).
///
/// Unlike ``InvoiceSupplier`` / ``InvoiceClient`` — which carry
/// document-role-specific extras such as bank details or PO numbers — this is
/// the neutral address shape used wherever a plain party block is rendered.
public struct InvoiceParty: Sendable {
    /// Company or person name.
    public var name: String
    /// Attention / contact person inside the company.
    public var attention: String?
    /// Street + number.
    public var street: String?
    /// Zip code + city.
    public var city: String?
    /// Country (optional).
    public var country: String?
    /// VAT / tax registration number.
    public var vatNumber: String?

    public init(
        name: String,
        attention: String? = nil,
        street: String? = nil,
        city: String? = nil,
        country: String? = nil,
        vatNumber: String? = nil
    ) {
        self.name = name
        self.attention = attention
        self.street = street
        self.city = city
        self.country = country
        self.vatNumber = vatNumber
    }
}

// MARK: - InvoiceTaxSubtotal

/// One row of the per-rate tax breakdown table: everything taxed at a single
/// rate, aggregated.
public struct InvoiceTaxSubtotal: Sendable {
    /// Tax rate as a percentage (e.g. 21 for 21 %).
    public var ratePercent: Double
    /// Taxable base — the sum of line subtotals (excluding tax) taxed at this rate.
    public var taxableBase: Double
    /// Tax amount charged on ``taxableBase`` at ``ratePercent``.
    public var taxAmount: Double
    /// Optional exemption reason shown for a 0 % / exempt rate row.
    public var exemptionReason: String?

    public init(
        ratePercent: Double,
        taxableBase: Double,
        taxAmount: Double,
        exemptionReason: String? = nil
    ) {
        self.ratePercent = ratePercent
        self.taxableBase = taxableBase
        self.taxAmount = taxAmount
        self.exemptionReason = exemptionReason
    }
}

// MARK: - InvoicePaymentRow

/// One row of the payment-history table: a single payment received against the
/// document.
public struct InvoicePaymentRow: Sendable {
    /// Payment method label (e.g. "Bank transfer", "Card").
    public var method: String
    /// Date the payment was received.
    public var date: Date
    /// Amount paid, in the document's currency.
    public var amount: Double
    /// Optional receipt / payment reference number.
    public var receiptNumber: String?

    public init(
        method: String,
        date: Date,
        amount: Double,
        receiptNumber: String? = nil
    ) {
        self.method = method
        self.date = date
        self.amount = amount
        self.receiptNumber = receiptNumber
    }
}

// MARK: - InvoicePaymentState

/// Settlement state of the document, driving the paid/due headline.
public enum InvoicePaymentState: Sendable {
    /// Payment is outstanding; the associated date is the payment due date.
    case due(on: Date)
    /// The document is settled; the associated date is the settlement date.
    case paid(on: Date)
}
