import CoreGraphics

// MARK: - LogoPosition

/// Where the supplier logo is rendered relative to the supplier address block.
public enum LogoPosition: Sendable {
    /// Logo on the left, supplier info on the right (default).
    case left
    /// Logo on the right, supplier info on the left.
    case right
    /// Logo centred above the address block.
    case topCenter
}

// MARK: - InvoiceTheme

/// Visual configuration for a rendered invoice.
///
/// Create a custom theme or start from one of the built-in presets:
///
/// ```swift
/// var theme = InvoiceTheme.standard
/// theme.accentColor = PDFColor(red: 0.2, green: 0.4, blue: 0.8)
/// theme.logoPosition = .right
/// ```
public struct InvoiceTheme: Sendable {

    // MARK: Colors

    /// Primary accent color — used for headers, rules, and highlighted text.
    public var accentColor: PDFColor
    /// Background color of the line-items table header row.
    public var tableHeaderBackground: PDFColor
    /// Text color used inside the table header row.
    public var tableHeaderTextColor: PDFColor
    /// Alternating row tint for the line items table. Pass `nil` to disable.
    public var tableAlternateRowColor: PDFColor?
    /// Color of horizontal rule lines.
    public var ruleColor: PDFColor
    /// Background color of the payment-reference banner. Pass `nil` to hide the banner.
    public var paymentBannerColor: PDFColor?
    /// Text color inside the payment banner.
    public var paymentBannerTextColor: PDFColor
    /// Border color for all table cells.
    public var tableBorderColor: PDFColor

    // MARK: Fonts

    /// Body / label font face.
    public var bodyFont: PDFFont
    /// Font face used for the large document title ("Invoice").
    public var titleFont: PDFFont
    /// Base font size for body text.
    public var bodyFontSize: CGFloat
    /// Font size for the document title.
    public var titleFontSize: CGFloat
    /// Font size for table header row labels.
    public var tableHeaderFontSize: CGFloat
    /// Font size for table data cells.
    public var tableCellFontSize: CGFloat

    // MARK: Layout

    /// Page margins (points) applied on all four sides.
    public var pageMargins: CGFloat
    /// Where to place the logo relative to the supplier info block.
    public var logoPosition: LogoPosition
    /// Maximum width of the logo image (points).
    public var logoMaxWidth: CGFloat
    /// Maximum height of the logo image (points).
    public var logoMaxHeight: CGFloat
    /// Height (points) of each line-item table row.
    public var lineItemRowHeight: CGFloat
    /// Height (points) of the totals table row.
    public var totalsRowHeight: CGFloat

    // MARK: - Presets

    /// A clean, minimal black-and-white theme suitable for most invoices.
    public static let standard = InvoiceTheme(
        accentColor:              PDFColor(white: 0.15),
        tableHeaderBackground:    PDFColor(white: 0.88),
        tableHeaderTextColor:     .black,
        tableAlternateRowColor:   PDFColor(white: 0.96),
        ruleColor:                PDFColor(white: 0.3),
        paymentBannerColor:       PDFColor(white: 0.15),
        paymentBannerTextColor:   PDFColor.white,
        tableBorderColor:         PDFColor(white: 0.5),
        bodyFont:                 .helvetica,
        titleFont:                .times,
        bodyFontSize:             10,
        titleFontSize:            14,
        tableHeaderFontSize:      10,
        tableCellFontSize:        10,
        pageMargins:              40,
        logoPosition:             .left,
        logoMaxWidth:             120,
        logoMaxHeight:            70,
        lineItemRowHeight:        20,
        totalsRowHeight:          18
    )

    /// A warm gold-tinted theme (similar to the TFC example).
    public static let gold: InvoiceTheme = {
        let g = PDFColor(red: 0.60, green: 0.49, blue: 0.31)
        return InvoiceTheme(
            accentColor:              g,
            tableHeaderBackground:    PDFColor(white: 0.88),
            tableHeaderTextColor:     .black,
            tableAlternateRowColor:   nil,
            ruleColor:                g,
            paymentBannerColor:       PDFColor(white: 0.15),
            paymentBannerTextColor:   PDFColor.white,
            tableBorderColor:         PDFColor(white: 0.4),
            bodyFont:                 .helvetica,
            titleFont:                .times,
            bodyFontSize:             10,
            titleFontSize:            14,
            tableHeaderFontSize:      10,
            tableCellFontSize:        10,
            pageMargins:              40,
            logoPosition:             .left,
            logoMaxWidth:             120,
            logoMaxHeight:            70,
            lineItemRowHeight:        20,
            totalsRowHeight:          18
        )
    }()

    /// A bold blue corporate theme.
    public static let corporate: InvoiceTheme = {
        let blue = PDFColor(red: 0.10, green: 0.30, blue: 0.60)
        let lightBlue = PDFColor(red: 0.85, green: 0.90, blue: 0.97)
        return InvoiceTheme(
            accentColor:              blue,
            tableHeaderBackground:    blue,
            tableHeaderTextColor:     PDFColor.white,
            tableAlternateRowColor:   lightBlue,
            ruleColor:                blue,
            paymentBannerColor:       blue,
            paymentBannerTextColor:   PDFColor.white,
            tableBorderColor:         PDFColor(white: 0.6),
            bodyFont:                 .helvetica,
            titleFont:                .helvetica,
            bodyFontSize:             10,
            titleFontSize:            14,
            tableHeaderFontSize:      10,
            tableCellFontSize:        10,
            pageMargins:              40,
            logoPosition:             .left,
            logoMaxWidth:             120,
            logoMaxHeight:            70,
            lineItemRowHeight:        20,
            totalsRowHeight:          18
        )
    }()

    // MARK: - Memberwise init

    public init(
        accentColor: PDFColor,
        tableHeaderBackground: PDFColor,
        tableHeaderTextColor: PDFColor,
        tableAlternateRowColor: PDFColor?,
        ruleColor: PDFColor,
        paymentBannerColor: PDFColor?,
        paymentBannerTextColor: PDFColor,
        tableBorderColor: PDFColor,
        bodyFont: PDFFont,
        titleFont: PDFFont,
        bodyFontSize: CGFloat,
        titleFontSize: CGFloat,
        tableHeaderFontSize: CGFloat,
        tableCellFontSize: CGFloat,
        pageMargins: CGFloat,
        logoPosition: LogoPosition,
        logoMaxWidth: CGFloat,
        logoMaxHeight: CGFloat,
        lineItemRowHeight: CGFloat,
        totalsRowHeight: CGFloat
    ) {
        self.accentColor = accentColor
        self.tableHeaderBackground = tableHeaderBackground
        self.tableHeaderTextColor = tableHeaderTextColor
        self.tableAlternateRowColor = tableAlternateRowColor
        self.ruleColor = ruleColor
        self.paymentBannerColor = paymentBannerColor
        self.paymentBannerTextColor = paymentBannerTextColor
        self.tableBorderColor = tableBorderColor
        self.bodyFont = bodyFont
        self.titleFont = titleFont
        self.bodyFontSize = bodyFontSize
        self.titleFontSize = titleFontSize
        self.tableHeaderFontSize = tableHeaderFontSize
        self.tableCellFontSize = tableCellFontSize
        self.pageMargins = pageMargins
        self.logoPosition = logoPosition
        self.logoMaxWidth = logoMaxWidth
        self.logoMaxHeight = logoMaxHeight
        self.lineItemRowHeight = lineItemRowHeight
        self.totalsRowHeight = totalsRowHeight
    }
}
