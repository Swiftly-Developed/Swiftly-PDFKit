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

    // MARK: Document-meta captions

    /// Caption of the invoice-number meta row.
    public var invoiceNumberLabel: String
    /// Caption of the issue-date meta row.
    public var issueDateLabel: String
    /// Caption of the due-date meta row.
    public var dueDateLabel: String
    /// Caption of the service-date meta row.
    public var serviceDateLabel: String
    /// Caption of the client-number meta row.
    public var clientNumberLabel: String
    /// Caption of the purchase-order-reference meta row.
    public var poNumberLabel: String
    /// Caption of a VAT / tax-registration number (meta row and party blocks).
    public var vatNumberLabel: String
    /// Prefix for the attention / contact person line in a party block.
    public var attentionLabel: String

    // MARK: Additional line-table columns

    /// Header of the per-line discount column (also the totals discount row).
    public var columnDiscount: String

    // MARK: Payment-section prefixes

    /// Prefix of the structured payment reference line.
    public var paymentReferenceLabel: String
    /// Prefix of the supplier bank account (IBAN) line.
    public var ibanLabel: String
    /// Prefix of the supplier bank BIC / SWIFT code.
    public var bicLabel: String

    // MARK: Tax-breakdown table

    /// Header of the per-rate tax breakdown section.
    public var taxBreakdownHeader: String
    /// Header of the tax-rate column in the breakdown table.
    public var columnTaxRate: String
    /// Header of the taxable-base column in the breakdown table.
    public var columnTaxableBase: String
    /// Header of the exemption-reason column in the breakdown table.
    public var columnExemptionReason: String

    // MARK: Payment-history table

    /// Header of the payment-method column in the payment-history table.
    public var columnPaymentMethod: String
    /// Header of the payment-date column in the payment-history table.
    public var columnPaymentDate: String
    /// Header of the receipt-number column in the payment-history table.
    public var columnReceiptNumber: String

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
        reverseChargeNote: String = "Reverse charge: VAT to be accounted for by the recipient.",
        invoiceNumberLabel: String = "Invoice No.",
        issueDateLabel: String = "Date",
        dueDateLabel: String = "Due Date",
        serviceDateLabel: String = "Service Date",
        clientNumberLabel: String = "Client No.",
        poNumberLabel: String = "PO Number",
        vatNumberLabel: String = "VAT No.",
        attentionLabel: String = "Attn",
        columnDiscount: String = "Discount",
        paymentReferenceLabel: String = "Payment reference",
        ibanLabel: String = "IBAN",
        bicLabel: String = "BIC",
        taxBreakdownHeader: String = "Tax breakdown",
        columnTaxRate: String = "Rate",
        columnTaxableBase: String = "Taxable base",
        columnExemptionReason: String = "Exemption",
        columnPaymentMethod: String = "Method",
        columnPaymentDate: String = "Date",
        columnReceiptNumber: String = "Receipt no."
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
        self.invoiceNumberLabel = invoiceNumberLabel
        self.issueDateLabel = issueDateLabel
        self.dueDateLabel = dueDateLabel
        self.serviceDateLabel = serviceDateLabel
        self.clientNumberLabel = clientNumberLabel
        self.poNumberLabel = poNumberLabel
        self.vatNumberLabel = vatNumberLabel
        self.attentionLabel = attentionLabel
        self.columnDiscount = columnDiscount
        self.paymentReferenceLabel = paymentReferenceLabel
        self.ibanLabel = ibanLabel
        self.bicLabel = bicLabel
        self.taxBreakdownHeader = taxBreakdownHeader
        self.columnTaxRate = columnTaxRate
        self.columnTaxableBase = columnTaxableBase
        self.columnExemptionReason = columnExemptionReason
        self.columnPaymentMethod = columnPaymentMethod
        self.columnPaymentDate = columnPaymentDate
        self.columnReceiptNumber = columnReceiptNumber
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
