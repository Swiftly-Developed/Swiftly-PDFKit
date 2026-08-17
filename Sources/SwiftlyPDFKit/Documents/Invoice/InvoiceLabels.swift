import Foundation

// MARK: - InvoiceLabels

/// Every rendered string a document layout emits that is *not* data.
///
/// Layouts read all of their fixed wording — titles, table column headers,
/// totals labels, section headers, headline templates — from an
/// ``InvoiceLabels`` value instead of hardcoding English literals, so a host
/// application can supply a fully localized instance. The package stays usable
/// standalone through ``InvoiceLabels/english``.
///
/// Templated labels (the paid/due headlines and the page-numbering footer) use
/// `{token}` placeholders rather than positional format specifiers so
/// translations can reorder them freely; expand them through
/// ``pageNumber(_:of:)``, ``paidHeadline(date:)`` and
/// ``dueHeadline(amount:date:)``.
///
/// ```swift
/// var labels = InvoiceLabels()               // == .english
/// labels.documentTitleInvoice = "Factuur"
/// labels.billToHeader = "Factuuradres"
/// ```
public struct InvoiceLabels: Sendable {

    // MARK: Document-type titles

    /// Title rendered for a standard invoice.
    public var documentTitleInvoice: String
    /// Title rendered for a credit note.
    public var documentTitleCreditNote: String
    /// Title rendered for a proforma invoice.
    public var documentTitleProforma: String

    // MARK: Line-table column headers

    /// Header of the line-description column.
    public var columnDescription: String
    /// Header of the quantity column.
    public var columnQuantity: String
    /// Header of the unit-price column.
    public var columnUnitPrice: String
    /// Header of the tax / VAT-rate column.
    public var columnTax: String
    /// Header of the line-amount column.
    public var columnAmount: String

    // MARK: Totals labels

    /// Label for the subtotal (excluding tax) row.
    public var subtotalLabel: String
    /// Label for the grand-total (including tax) row.
    public var totalLabel: String
    /// Label for the tax / VAT total row.
    public var vatLabel: String
    /// Label for the amount still owed.
    public var amountDueLabel: String
    /// Label for the amount already paid.
    public var amountPaidLabel: String

    // MARK: Section headers

    /// Header of the billing-address block.
    public var billToHeader: String
    /// Header of the shipping-address block (rendered when it differs from billing).
    public var shipToHeader: String
    /// Header of the payment-history table.
    public var paymentHistoryHeader: String
    /// Header of the supplier (issuing party) block.
    public var supplierHeader: String
    /// Header of the client (receiving party) block.
    public var clientHeader: String

    // MARK: Templates

    /// Headline shown when the document is settled. Supports a `{date}` token.
    public var paidHeadlineTemplate: String
    /// Headline shown while payment is outstanding. Supports `{amount}` and `{date}` tokens.
    public var dueHeadlineTemplate: String
    /// Page-numbering footer. Supports `{page}` and `{pages}` tokens.
    public var pageNumberTemplate: String

    // MARK: Legal phrasing

    /// Default reverse-charge note (VAT shifted to the recipient).
    public var reverseChargeNote: String

    // MARK: - English default

    /// The built-in English label set — the package-standalone default.
    public static let english = InvoiceLabels()

    // MARK: - Init

    /// Memberwise initialiser. Every parameter defaults to its English value,
    /// so `InvoiceLabels()` equals ``InvoiceLabels/english`` and hosts override
    /// only the entries they localize.
    public init(
        documentTitleInvoice: String = "Invoice",
        documentTitleCreditNote: String = "Credit Note",
        documentTitleProforma: String = "Proforma Invoice",
        columnDescription: String = "Description",
        columnQuantity: String = "Qty",
        columnUnitPrice: String = "Unit price",
        columnTax: String = "Tax",
        columnAmount: String = "Amount",
        subtotalLabel: String = "Subtotal",
        totalLabel: String = "Total",
        vatLabel: String = "VAT",
        amountDueLabel: String = "Amount due",
        amountPaidLabel: String = "Amount paid",
        billToHeader: String = "Bill to",
        shipToHeader: String = "Ship to",
        paymentHistoryHeader: String = "Payment history",
        supplierHeader: String = "Supplier",
        clientHeader: String = "Client",
        paidHeadlineTemplate: String = "Paid on {date}",
        dueHeadlineTemplate: String = "{amount} due by {date}",
        pageNumberTemplate: String = "Page {page} of {pages}",
        reverseChargeNote: String = "Reverse charge: VAT to be accounted for by the recipient."
    ) {
        self.documentTitleInvoice = documentTitleInvoice
        self.documentTitleCreditNote = documentTitleCreditNote
        self.documentTitleProforma = documentTitleProforma
        self.columnDescription = columnDescription
        self.columnQuantity = columnQuantity
        self.columnUnitPrice = columnUnitPrice
        self.columnTax = columnTax
        self.columnAmount = columnAmount
        self.subtotalLabel = subtotalLabel
        self.totalLabel = totalLabel
        self.vatLabel = vatLabel
        self.amountDueLabel = amountDueLabel
        self.amountPaidLabel = amountPaidLabel
        self.billToHeader = billToHeader
        self.shipToHeader = shipToHeader
        self.paymentHistoryHeader = paymentHistoryHeader
        self.supplierHeader = supplierHeader
        self.clientHeader = clientHeader
        self.paidHeadlineTemplate = paidHeadlineTemplate
        self.dueHeadlineTemplate = dueHeadlineTemplate
        self.pageNumberTemplate = pageNumberTemplate
        self.reverseChargeNote = reverseChargeNote
    }

    // MARK: - Template expansion

    /// Expands ``pageNumberTemplate`` for a concrete page.
    public func pageNumber(_ page: Int, of pages: Int) -> String {
        pageNumberTemplate
            .replacingOccurrences(of: "{page}", with: String(page))
            .replacingOccurrences(of: "{pages}", with: String(pages))
    }

    /// Expands ``paidHeadlineTemplate`` with an already-formatted date string.
    public func paidHeadline(date: String) -> String {
        paidHeadlineTemplate.replacingOccurrences(of: "{date}", with: date)
    }

    /// Expands ``dueHeadlineTemplate`` with already-formatted amount and date strings.
    public func dueHeadline(amount: String, date: String) -> String {
        dueHeadlineTemplate
            .replacingOccurrences(of: "{amount}", with: amount)
            .replacingOccurrences(of: "{date}", with: date)
    }
}
