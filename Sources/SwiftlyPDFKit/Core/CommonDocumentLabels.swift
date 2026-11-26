import Foundation

// MARK: - CommonDocumentLabels

/// Every caption the family-neutral composition blocks in ``DocumentLayoutKit``
/// render, and nothing else.
///
/// The member list is **frozen at 24**. A block authored against this shape can
/// be given values by any consumer without that consumer re-signing a block's
/// API, which is the whole point — a later phase supplies localized values into
/// this shape and never grows it. Growing it silently is what the package test
/// suite's member-count assertion exists to prevent.
///
/// The metadata grid appears in no group here on purpose: its captions are
/// supplied by the caller alongside the values, so the grid owns none of its own.
///
/// Templated members use `{token}` placeholders rather than positional format
/// specifiers, matching the convention ``InvoiceLabels`` already documents, so
/// translations can reorder freely. Expand ``pageNumberTemplate`` through
/// ``pageNumber(_:of:)``.
public struct CommonDocumentLabels: LabelSet {

    // MARK: Page furniture

    /// Page-numbering footer line. Supports `{page}` and `{pages}` tokens.
    public var pageNumberTemplate: String
    /// Marker on a continuation page, shown beside a repeated table header.
    public var continuedLabel: String
    /// Caption preceding the document's generation timestamp.
    public var generatedOnLabel: String

    // MARK: Watermark

    /// Full-bleed watermark text for a duplicate of an already-issued document.
    public var watermarkCopy: String
    /// Full-bleed watermark text for a document that is not yet issued.
    public var watermarkDraft: String

    // MARK: Supplier identity block

    /// Caption of the supplier's VAT / tax identification number.
    public var vatNumberLabel: String
    /// Caption of the supplier's commercial-register / company number.
    public var registrationNumberLabel: String
    /// Caption of the supplier's bank account number.
    public var ibanLabel: String
    /// Caption of the supplier's bank identifier code.
    public var bicLabel: String
    /// Caption of the supplier's telephone number.
    public var phoneLabel: String
    /// Caption of the supplier's e-mail address.
    public var emailLabel: String
    /// Caption of the supplier's website.
    public var websiteLabel: String

    // MARK: Party block

    /// Header of the billing-address block.
    public var billToHeader: String
    /// Header of the delivery-address block.
    public var shipToHeader: String

    // MARK: Signature block

    /// Header of the signature acknowledgement block.
    public var signatureHeader: String
    /// Caption under the signature rule.
    public var signatureLabel: String
    /// Caption under the signature-date rule.
    public var signatureDateLabel: String
    /// Caption under the printed-name rule.
    public var signatureNameLabel: String

    // MARK: Totals block

    /// Caption of the tax-exclusive subtotal row.
    public var totalsSubtotalLabel: String
    /// Caption of the document-level discount row.
    public var totalsDiscountLabel: String
    /// Caption of the tax total row.
    public var totalsTaxLabel: String
    /// Caption of the grand-total row.
    public var totalsTotalLabel: String
    /// Caption of the already-paid row.
    public var totalsAmountPaidLabel: String
    /// Caption of the amount-still-owed row.
    public var totalsAmountDueLabel: String

    // MARK: - English default

    /// The built-in English label set — the package-standalone default.
    public static let english = CommonDocumentLabels()

    // MARK: - Init

    /// Memberwise initialiser. Every parameter defaults to its English value, so
    /// `CommonDocumentLabels()` equals ``CommonDocumentLabels/english`` and a
    /// host overrides only the entries it localizes.
    public init(
        pageNumberTemplate: String = "Page {page} of {pages}",
        continuedLabel: String = "Continued",
        generatedOnLabel: String = "Generated on",
        watermarkCopy: String = "COPY",
        watermarkDraft: String = "DRAFT",
        vatNumberLabel: String = "VAT No.",
        registrationNumberLabel: String = "Reg. No.",
        ibanLabel: String = "IBAN",
        bicLabel: String = "BIC",
        phoneLabel: String = "Tel.",
        emailLabel: String = "Email",
        websiteLabel: String = "Web",
        billToHeader: String = "Bill to",
        shipToHeader: String = "Ship to",
        signatureHeader: String = "Acknowledgement of receipt",
        signatureLabel: String = "Signature",
        signatureDateLabel: String = "Date",
        signatureNameLabel: String = "Print name",
        totalsSubtotalLabel: String = "Subtotal",
        totalsDiscountLabel: String = "Discount",
        totalsTaxLabel: String = "Tax",
        totalsTotalLabel: String = "Total",
        totalsAmountPaidLabel: String = "Amount paid",
        totalsAmountDueLabel: String = "Amount due"
    ) {
        self.pageNumberTemplate = pageNumberTemplate
        self.continuedLabel = continuedLabel
        self.generatedOnLabel = generatedOnLabel
        self.watermarkCopy = watermarkCopy
        self.watermarkDraft = watermarkDraft
        self.vatNumberLabel = vatNumberLabel
        self.registrationNumberLabel = registrationNumberLabel
        self.ibanLabel = ibanLabel
        self.bicLabel = bicLabel
        self.phoneLabel = phoneLabel
        self.emailLabel = emailLabel
        self.websiteLabel = websiteLabel
        self.billToHeader = billToHeader
        self.shipToHeader = shipToHeader
        self.signatureHeader = signatureHeader
        self.signatureLabel = signatureLabel
        self.signatureDateLabel = signatureDateLabel
        self.signatureNameLabel = signatureNameLabel
        self.totalsSubtotalLabel = totalsSubtotalLabel
        self.totalsDiscountLabel = totalsDiscountLabel
        self.totalsTaxLabel = totalsTaxLabel
        self.totalsTotalLabel = totalsTotalLabel
        self.totalsAmountPaidLabel = totalsAmountPaidLabel
        self.totalsAmountDueLabel = totalsAmountDueLabel
    }

    // MARK: - Template expansion

    /// Expands ``pageNumberTemplate`` for a concrete page — the one member
    /// ``LabelSet`` requires.
    public func pageNumber(_ page: Int, of pages: Int) -> String {
        pageNumberTemplate
            .replacingOccurrences(of: "{page}", with: String(page))
            .replacingOccurrences(of: "{pages}", with: String(pages))
    }
}
