import Foundation

// MARK: - InvoiceSupplier

/// The party issuing the invoice (your company).
public struct InvoiceSupplier: Sendable {
    /// Company or person name.
    public var name: String
    /// Street + number.
    public var street: String?
    /// Zip code + city.
    public var city: String?
    /// Country (optional).
    public var country: String?
    /// VAT / tax registration number.
    public var vatNumber: String?
    /// Chamber of commerce / company registration number.
    public var registrationNumber: String?
    /// Phone number.
    public var phone: String?
    /// E-mail address.
    public var email: String?
    /// Website URL string.
    public var website: String?
    /// IBAN bank account number.
    public var iban: String?
    /// BIC / SWIFT code.
    public var bic: String?
    /// File-system path to a logo image (PNG or JPEG).
    public var logoPath: String?

    public init(
        name: String,
        street: String? = nil,
        city: String? = nil,
        country: String? = nil,
        vatNumber: String? = nil,
        registrationNumber: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        iban: String? = nil,
        bic: String? = nil,
        logoPath: String? = nil
    ) {
        self.name = name
        self.street = street
        self.city = city
        self.country = country
        self.vatNumber = vatNumber
        self.registrationNumber = registrationNumber
        self.phone = phone
        self.email = email
        self.website = website
        self.iban = iban
        self.bic = bic
        self.logoPath = logoPath
    }
}

// MARK: - InvoiceClient

/// The party receiving the invoice (your customer).
public struct InvoiceClient: Sendable {
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
    /// VAT number of the client (for B2B invoices).
    public var vatNumber: String?
    /// Internal client / customer reference number.
    public var clientNumber: String?
    /// Client's purchase order reference.
    public var poNumber: String?

    public init(
        name: String,
        attention: String? = nil,
        street: String? = nil,
        city: String? = nil,
        country: String? = nil,
        vatNumber: String? = nil,
        clientNumber: String? = nil,
        poNumber: String? = nil
    ) {
        self.name = name
        self.attention = attention
        self.street = street
        self.city = city
        self.country = country
        self.vatNumber = vatNumber
        self.clientNumber = clientNumber
        self.poNumber = poNumber
    }
}

// MARK: - InvoiceHeader

/// Document-level metadata shown at the top of the invoice.
public struct InvoiceHeader: Sendable {
    /// Unique invoice number / identifier.
    public var invoiceNumber: String
    /// Readable document type label shown on the page (e.g. "Invoice", "Factuur", "Proforma").
    public var documentTitle: String
    /// Date the invoice was issued.
    public var issueDate: String
    /// Payment due date.
    public var dueDate: String?
    /// Optional delivery / service date range.
    public var serviceDate: String?
    /// Currency code shown in the totals (e.g. "EUR", "USD").
    public var currency: String
    /// Payment terms free-text (e.g. "Net 30", "Payable within 8 days").
    public var paymentTerms: String?
    /// Structured payment reference (e.g. Belgian OGM +++xxx/xxxx/xxxxx+++).
    public var paymentReference: String?
    /// Free-text notes shown below the line items.
    public var notes: String?
    /// SEPA QR / EPC QR payload string — rendered as a QR code when present.
    public var qrPayload: String?

    public init(
        invoiceNumber: String,
        documentTitle: String = "Invoice",
        issueDate: String,
        dueDate: String? = nil,
        serviceDate: String? = nil,
        currency: String = "EUR",
        paymentTerms: String? = nil,
        paymentReference: String? = nil,
        notes: String? = nil,
        qrPayload: String? = nil
    ) {
        self.invoiceNumber = invoiceNumber
        self.documentTitle = documentTitle
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.serviceDate = serviceDate
        self.currency = currency
        self.paymentTerms = paymentTerms
        self.paymentReference = paymentReference
        self.notes = notes
        self.qrPayload = qrPayload
    }
}

// MARK: - InvoiceLine

/// A single billable line on the invoice.
public struct InvoiceLine: Sendable {
    /// Short description of the product or service.
    public var description: String
    /// Optional longer detail / sub-description (shown below the main description when set).
    public var detail: String?
    /// Number of units.
    public var quantity: Double
    /// Unit label (e.g. "hrs", "pcs", "days").
    public var unit: String?
    /// Price per unit excluding tax.
    public var unitPrice: Double
    /// VAT / tax rate as a percentage (e.g. 21 for 21 %). Use 0 for tax-exempt lines.
    public var vatRate: Double
    /// Optional discount percentage (0–100). Applied before tax.
    public var discountPercent: Double

    /// Line subtotal excluding VAT: quantity × unitPrice × (1 – discount/100).
    public var subtotalExcl: Double {
        quantity * unitPrice * (1 - discountPercent / 100)
    }

    /// VAT amount for this line.
    public var vatAmount: Double {
        subtotalExcl * vatRate / 100
    }

    /// Line total including VAT.
    public var totalIncl: Double {
        subtotalExcl + vatAmount
    }

    public init(
        description: String,
        detail: String? = nil,
        quantity: Double,
        unit: String? = nil,
        unitPrice: Double,
        vatRate: Double = 0,
        discountPercent: Double = 0
    ) {
        self.description = description
        self.detail = detail
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.vatRate = vatRate
        self.discountPercent = discountPercent
    }
}

// MARK: - InvoiceTotals

/// Computed totals derived from an array of ``InvoiceLine`` values.
///
/// You can create this from a lines array using ``InvoiceTotals/init(lines:)``, or
/// override individual fields with the memberwise initialiser for edge cases such as
/// global discounts, rounding, or prepaid amounts.
public struct InvoiceTotals: Sendable {
    /// Sum of all line subtotals excluding VAT (after per-line discounts).
    public var subtotalExcl: Double
    /// Total VAT amount across all lines.
    public var totalVat: Double
    /// Total amount including all VAT.
    public var totalIncl: Double
    /// Optional global/document-level discount amount (already deducted from subtotalExcl when non-nil).
    public var globalDiscount: Double?
    /// Optional amount already paid (deposit / advance). Shown in "amount due" calculation.
    public var amountPaid: Double?

    /// Amount still owed: totalIncl – amountPaid (or totalIncl when nil).
    public var amountDue: Double {
        totalIncl - (amountPaid ?? 0)
    }

    /// Derive totals automatically from an array of lines.
    public init(lines: [InvoiceLine]) {
        subtotalExcl = lines.reduce(0) { $0 + $1.subtotalExcl }
        totalVat     = lines.reduce(0) { $0 + $1.vatAmount }
        totalIncl    = lines.reduce(0) { $0 + $1.totalIncl }
        globalDiscount = nil
        amountPaid   = nil
    }

    public init(
        subtotalExcl: Double,
        totalVat: Double,
        totalIncl: Double,
        globalDiscount: Double? = nil,
        amountPaid: Double? = nil
    ) {
        self.subtotalExcl = subtotalExcl
        self.totalVat = totalVat
        self.totalIncl = totalIncl
        self.globalDiscount = globalDiscount
        self.amountPaid = amountPaid
    }
}

// MARK: - InvoiceFooter

/// Text content pinned to the bottom of every page.
public struct InvoiceFooter: Sendable {
    /// Lines of text rendered in the footer (centred by default in built-in layouts).
    public var lines: [String]
    /// Pixel height reserved for the footer area.
    public var height: CGFloat

    public init(lines: [String], height: CGFloat = 72) {
        self.lines = lines
        self.height = height
    }
}

// MARK: - InvoiceDocument

/// The complete, self-contained invoice data model.
///
/// Pass a fully populated ``InvoiceDocument`` value to ``PDF/init(layout:invoice:)``
/// to generate a ready-to-render `PDF`:
///
/// ```swift
/// let invoice = InvoiceDocument(
///     header: InvoiceHeader(invoiceNumber: "INV-001", issueDate: "2026-01-01"),
///     supplier: InvoiceSupplier(name: "Acme Corp", logoPath: "/assets/logo.png"),
///     client: InvoiceClient(name: "Client BV"),
///     lines: [
///         InvoiceLine(description: "Consulting", quantity: 8, unitPrice: 150, vatRate: 21)
///     ]
/// )
/// let pdf = PDF(layout: .classic, invoice: invoice)
/// let data = try pdf.render()
/// ```
public struct InvoiceDocument: Sendable {
    public var header: InvoiceHeader
    public var supplier: InvoiceSupplier
    public var client: InvoiceClient
    /// Ordered list of billable lines.
    public var lines: [InvoiceLine]
    /// Totals — computed from lines by default; supply your own for overrides.
    public var totals: InvoiceTotals
    /// Optional footer pinned to the bottom of every page.
    public var footer: InvoiceFooter?

    /// Memberwise initialiser. `totals` defaults to values computed from `lines`.
    public init(
        header: InvoiceHeader,
        supplier: InvoiceSupplier,
        client: InvoiceClient,
        lines: [InvoiceLine],
        totals: InvoiceTotals? = nil,
        footer: InvoiceFooter? = nil
    ) {
        self.header = header
        self.supplier = supplier
        self.client = client
        self.lines = lines
        self.totals = totals ?? InvoiceTotals(lines: lines)
        self.footer = footer
    }
}
