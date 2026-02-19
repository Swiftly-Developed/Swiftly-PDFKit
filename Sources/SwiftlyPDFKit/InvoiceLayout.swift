import Foundation
import CoreGraphics

// MARK: - InvoiceLayoutType

/// Built-in invoice page layouts.
///
/// Each case produces a different visual arrangement of the invoice sections
/// from the same ``InvoiceDocument`` data.
public enum InvoiceLayoutType: Sendable {
    /// Classic single-column layout.
    ///
    /// - Logo and supplier address in a two-column header
    /// - Invoice metadata (number, dates) in a two-column block
    /// - Line-items table
    /// - Totals summary row
    /// - Optional QR code + payment reference banner
    /// - Optional footer
    case classic

    /// Like ``classic`` but adds a sidebar accent bar on the left edge (future layout).
    case classicWithSidebar

    /// Minimalist layout: no table borders, generous whitespace (future layout).
    case minimal
}

// MARK: - PDF + Invoice factory

public extension PDF {

    /// Creates a `PDF` pre-built from an ``InvoiceDocument`` using a named layout.
    ///
    /// ```swift
    /// let pdf = PDF(layout: .classic, invoice: invoice)
    /// let data = try pdf.render()
    /// ```
    ///
    /// - Parameters:
    ///   - layout: The page arrangement to use.
    ///   - invoice: The data model containing all invoice content.
    ///   - theme: Visual configuration (colors, fonts, logo size). Defaults to ``InvoiceTheme/standard``.
    ///   - pageSize: Paper size. Defaults to A4.
    init(
        layout: InvoiceLayoutType,
        invoice: InvoiceDocument,
        theme: InvoiceTheme = .standard,
        pageSize: PageSize = .a4
    ) {
        switch layout {
        case .classic, .classicWithSidebar, .minimal:
            // All three share the classic builder for now; distinct layouts can be
            // added incrementally without breaking the public API.
            self = InvoiceLayoutBuilder.classicLayout(
                invoice: invoice,
                theme: theme,
                pageSize: pageSize
            )
        }
    }
}

// MARK: - InvoiceLayoutBuilder (internal)

enum InvoiceLayoutBuilder {

    static func classicLayout(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        pageSize: PageSize
    ) -> PDF {
        let fmt = InvoiceFormatter(theme: theme)

        // ── Height accounting ──────────────────────────────────────────────
        let rowH = theme.lineItemRowHeight

        // Page 1 overhead: logo/address block + spacer + meta block + spacer.
        // logo column height: logoMaxHeight + spacer(6) + HRule(1) + spacer(6) +
        //   supplier name + up to 3 address lines ≈ logoMaxHeight + 13 + 4×13
        let headerHeight:  CGFloat = theme.logoMaxHeight + 13 + 52   // generous but accurate
        let metaHeight:    CGFloat = 80   // 5–6 label rows at ~13 pt each
        let page1Overhead: CGFloat = headerHeight + 20 + metaHeight + 20

        // Table header row (repeated on every page).
        let tableHeaderH:  CGFloat = rowH

        // Bottom content reserved on the last page: totals + optional notes + payment.
        let totalsRowCount   = (invoice.totals.amountPaid ?? 0) > 0 ? 5 : 4
        let totalsH:         CGFloat = CGFloat(totalsRowCount) * theme.totalsRowHeight + 12
        let notesH:          CGFloat = invoice.header.notes != nil ? 20 + 14 : 0
        let paymentH:        CGFloat = (invoice.header.qrPayload != nil ||
                                        invoice.header.paymentReference != nil) ? 16 + 80 : 0
        let lastPageBottomH: CGFloat = totalsH + notesH + paymentH

        let footerH: CGFloat = invoice.footer.map { $0.height } ?? 0
        let margins          = theme.pageMargins
        let bodyH            = pageSize.height - margins * 2 - footerH

        // Max rows that fit on each page type, *ignoring* the bottom content.
        // We handle bottom-content fit in a second pass below.
        let p1RowsMax   = max(1, Int(floor((bodyH - page1Overhead - tableHeaderH) / rowH)))
        let contRowsMax = max(1, Int(floor((bodyH - tableHeaderH) / rowH)))

        // ── Pass 1: split lines into page chunks (rows only, no bottom content) ──
        var chunks: [[InvoiceLine]] = []
        var remaining = invoice.lines

        let p1Take = min(p1RowsMax, remaining.count)
        chunks.append(Array(remaining.prefix(p1Take)))
        remaining = Array(remaining.dropFirst(p1Take))

        while !remaining.isEmpty {
            let take = min(contRowsMax, remaining.count)
            chunks.append(Array(remaining.prefix(take)))
            remaining = Array(remaining.dropFirst(take))
        }

        // ── Pass 2: check if bottom content fits after the last chunk ─────────
        // Compute how much space the last chunk's rows actually use.
        let lastChunkUsed: CGFloat
        if let last = chunks.last {
            let isFirstPage = chunks.count == 1
            let overhead    = isFirstPage ? page1Overhead : 0
            lastChunkUsed   = overhead + tableHeaderH + CGFloat(last.count) * rowH
        } else {
            lastChunkUsed = page1Overhead + tableHeaderH
        }
        // If the bottom content doesn't fit on the last chunk's page, add an empty
        // overflow chunk so the page loop emits a dedicated totals-only page.
        let lastPageBodyH = chunks.count == 1 ? bodyH : bodyH
        if lastChunkUsed + lastPageBottomH > lastPageBodyH {
            chunks.append([])   // empty chunk → page with only bottom content
        }

        // ── Page builder ───────────────────────────────────────────────────
        func makeFooter() -> Footer? {
            guard let invoiceFooter = invoice.footer else { return nil }
            return Footer(height: invoiceFooter.height) {
                HRule(thickness: 0.5, color: theme.ruleColor)
                Spacer(height: 4)
                for line in invoiceFooter.lines {
                    Text(line)
                        .font(theme.bodyFont, size: 8)
                        .alignment(.center)
                }
            }
        }

        var pages: [Page] = []

        for (pageIdx, chunk) in chunks.enumerated() {
            let isFirst = pageIdx == 0
            let isLast  = pageIdx == chunks.count - 1

            let page = Page(size: pageSize, margins: margins) {

                if isFirst {
                    // ── Header ────────────────────────────────────────────
                    headerSection(invoice: invoice, theme: theme, fmt: fmt)
                    Spacer(height: 20)
                    // ── Meta ──────────────────────────────────────────────
                    metaSection(invoice: invoice, theme: theme, fmt: fmt)
                    Spacer(height: 20)
                }

                // ── Line items (this page's chunk) ─────────────────────
                lineItemsTableForRows(chunk, invoice: invoice, theme: theme, fmt: fmt,
                                      showHeader: true)

                if isLast {
                    Spacer(height: 12)
                    // ── Totals ────────────────────────────────────────────
                    totalsTable(invoice: invoice, theme: theme, fmt: fmt)

                    // ── Notes ─────────────────────────────────────────────
                    if let notes = invoice.header.notes {
                        Spacer(height: 12)
                        Text(notes).font(theme.bodyFont, size: theme.bodyFontSize - 1)
                    }

                    // ── QR code + payment reference ───────────────────────
                    if invoice.header.qrPayload != nil || invoice.header.paymentReference != nil {
                        Spacer(height: 16)
                        paymentSection(invoice: invoice, theme: theme, fmt: fmt)
                    }
                }

                if let f = makeFooter() { f }
            }
            pages.append(page)
        }

        // Edge-case: no lines at all — emit a single page with just header/meta/totals.
        if pages.isEmpty {
            let page = Page(size: pageSize, margins: margins) {
                headerSection(invoice: invoice, theme: theme, fmt: fmt)
                Spacer(height: 20)
                metaSection(invoice: invoice, theme: theme, fmt: fmt)
                Spacer(height: 20)
                totalsTable(invoice: invoice, theme: theme, fmt: fmt)
                if let notes = invoice.header.notes {
                    Spacer(height: 12)
                    Text(notes).font(theme.bodyFont, size: theme.bodyFontSize - 1)
                }
                if invoice.header.qrPayload != nil || invoice.header.paymentReference != nil {
                    Spacer(height: 16)
                    paymentSection(invoice: invoice, theme: theme, fmt: fmt)
                }
                if let f = makeFooter() { f }
            }
            pages.append(page)
        }

        return PDF(pages: pages)
    }

    // MARK: - Section builders

    private static func headerSection(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        let supplier = invoice.supplier
        let client   = invoice.client

        switch theme.logoPosition {
        case .left:
            return Columns(spacing: 20) {
                // Left: logo + supplier name
                ColumnItem(width: .fixed(160)) {
                    logoOrFallback(supplier: supplier, theme: theme)
                    Spacer(height: 6)
                    HRule(thickness: 0.5, color: theme.accentColor)
                    Spacer(height: 6)
                    supplierBlock(supplier: supplier, theme: theme, fmt: fmt)
                }
                // Right: client address
                ColumnItem(width: .flex) {
                    Spacer(height: 4)
                    clientBlock(client: client, theme: theme, fmt: fmt)
                }
            }

        case .right:
            return Columns(spacing: 20) {
                ColumnItem(width: .flex) {
                    Spacer(height: 4)
                    clientBlock(client: client, theme: theme, fmt: fmt)
                }
                ColumnItem(width: .fixed(160)) {
                    logoOrFallback(supplier: supplier, theme: theme)
                    Spacer(height: 6)
                    HRule(thickness: 0.5, color: theme.accentColor)
                    Spacer(height: 6)
                    supplierBlock(supplier: supplier, theme: theme, fmt: fmt)
                }
            }

        case .topCenter:
            return Columns(spacing: 0) {
                ColumnItem(width: .flex) {
                    logoOrFallback(supplier: supplier, theme: theme, alignment: .center)
                    Spacer(height: 8)
                    supplierBlock(supplier: supplier, theme: theme, fmt: fmt, alignment: .center)
                    Spacer(height: 12)
                    HRule(thickness: 0.5, color: theme.accentColor)
                    Spacer(height: 8)
                    clientBlock(client: client, theme: theme, fmt: fmt)
                }
            }
        }
    }

    private static func metaSection(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        let h = invoice.header
        return Columns(spacing: 20) {
            // Left: key–value pairs
            ColumnItem(width: .fixed(240)) {
                Columns(spacing: 0) {
                    ColumnItem(width: .fixed(90)) {
                        Text(fmt.label("Invoice No."))
                            .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        if h.issueDate.isEmpty == false {
                            Text(fmt.label("Date"))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if h.dueDate != nil {
                            Text(fmt.label("Due Date"))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if h.serviceDate != nil {
                            Text(fmt.label("Service Date"))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if invoice.client.clientNumber != nil {
                            Text(fmt.label("Client No."))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if invoice.client.poNumber != nil {
                            Text(fmt.label("PO Number"))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                    }
                    ColumnItem(width: .flex) {
                        Text(": \(h.invoiceNumber)")
                            .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        if h.issueDate.isEmpty == false {
                            Text(": \(h.issueDate)")
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if let due = h.dueDate {
                            Text(": \(due)")
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if let svc = h.serviceDate {
                            Text(": \(svc)")
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if let cn = invoice.client.clientNumber {
                            Text(": \(cn)")
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if let po = invoice.client.poNumber {
                            Text(": \(po)")
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                    }
                }
            }
            // Right: supplier VAT + document title
            ColumnItem(width: .flex) {
                if let vat = invoice.supplier.vatNumber {
                    Columns(spacing: 4) {
                        ColumnItem(width: .fixed(60)) {
                            Text(fmt.label("VAT No."))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        ColumnItem(width: .flex) {
                            Text(vat).font(theme.bodyFont, size: theme.bodyFontSize)
                        }
                    }
                    Spacer(height: 8)
                }
                Text(h.documentTitle)
                    .font(theme.titleFont, size: theme.titleFontSize)
                    .bold()
                    .italic()
                    .alignment(.center)
            }
        }
    }

    private static func lineItemsTable(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        lineItemsTableForRows(invoice.lines, invoice: invoice, theme: theme, fmt: fmt, showHeader: true)
    }

    private static func lineItemsTableForRows(
        _ lines: [InvoiceLine],
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter,
        showHeader: Bool
    ) -> some PDFContent {
        let rows = lines.map { line -> [String] in
            let qty       = fmt.quantity(line.quantity)
            let unitPrice = fmt.amount(line.unitPrice)
            let discount  = line.discountPercent > 0 ? fmt.percent(line.discountPercent) : ""
            let vatRate   = fmt.percent(line.vatRate)
            let subtotal  = fmt.amount(line.subtotalExcl)
            return [line.description, qty, unitPrice, discount, vatRate, subtotal]
        }

        let lineStyle = TableStyle(
            headerBackground: theme.tableHeaderBackground,
            headerTextColor:  theme.tableHeaderTextColor,
            headerFontSize:   theme.tableHeaderFontSize,
            cellFontSize:     theme.tableCellFontSize,
            rowHeight:        theme.lineItemRowHeight,
            alternateRowColor: theme.tableAlternateRowColor,
            borderColor:      theme.tableBorderColor,
            borderWidth:      0.5,
            cellPadding:      4
        )

        return Table(data: rows, style: lineStyle, showHeader: showHeader) {
            Column("Description",  width: .flex,        alignment: .leading)
            Column("Qty",          width: .fixed(40),   alignment: .trailing, headerAlignment: .trailing)
            Column("Unit Price",   width: .fixed(65),   alignment: .trailing, headerAlignment: .trailing)
            Column("Discount",     width: .fixed(60),   alignment: .trailing, headerAlignment: .trailing)
            Column("VAT %",        width: .fixed(45),   alignment: .trailing, headerAlignment: .trailing)
            Column("Subtotal",     width: .fixed(70),   alignment: .trailing, headerAlignment: .trailing)
        }
    }

    private static func totalsTable(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        let t = invoice.totals
        var rows: [[String]] = []

        rows.append(["Subtotal excl. VAT", "", fmt.amount(t.subtotalExcl)])

        if let disc = t.globalDiscount, disc > 0 {
            rows.append(["Discount", "", "-\(fmt.amount(disc))"])
        }

        rows.append(["VAT", "", fmt.amount(t.totalVat)])

        if let paid = t.amountPaid, paid > 0 {
            rows.append(["Total incl. VAT", "", fmt.amount(t.totalIncl)])
            rows.append(["Amount paid", "", "-\(fmt.amount(paid))"])
            rows.append(["Amount due (\(invoice.header.currency))", "", fmt.amount(t.amountDue)])
        } else {
            rows.append(["Total incl. VAT (\(invoice.header.currency))", "", fmt.amount(t.totalIncl)])
        }

        let totalsStyle = TableStyle(
            headerBackground: theme.tableHeaderBackground,
            headerTextColor:  theme.tableHeaderTextColor,
            headerFontSize:   theme.tableHeaderFontSize,
            cellFontSize:     theme.tableCellFontSize,
            rowHeight:        theme.totalsRowHeight,
            alternateRowColor: nil,
            borderColor:      theme.tableBorderColor,
            borderWidth:      0.5,
            cellPadding:      4,
            cellBold:         true
        )

        return Table(data: rows, style: totalsStyle, showHeader: false) {
            Column("",        width: .flex,      alignment: .leading)
            Column("",        width: .flex,      alignment: .leading)
            Column("Amount",  width: .fixed(100), alignment: .trailing)
        }
    }

    private static func paymentSection(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        let hasQR  = invoice.header.qrPayload != nil
        let hasRef = invoice.header.paymentReference != nil

        return Columns(spacing: 16) {
            ColumnItem(width: .flex) {
                if hasRef || hasQR {
                    if let ref = invoice.header.paymentReference,
                       let bannerColor = theme.paymentBannerColor {
                        FilledBox(color: bannerColor, height: 22) {
                            Text("Payment reference: \(ref)")
                                .font(theme.bodyFont, size: 9).bold()
                                .foregroundColor(theme.paymentBannerTextColor)
                                .alignment(.center)
                        }
                    } else if let ref = invoice.header.paymentReference {
                        Text("Payment reference: \(ref)")
                            .font(theme.bodyFont, size: 9).bold()
                    }
                    if let terms = invoice.header.paymentTerms {
                        Spacer(height: 4)
                        Text(terms).font(theme.bodyFont, size: 9)
                    }
                    if let iban = invoice.supplier.iban {
                        Spacer(height: 4)
                        Text("IBAN: \(iban)\(invoice.supplier.bic.map { "  BIC: \($0)" } ?? "")")
                            .font(theme.bodyFont, size: 9)
                    }
                }
            }
            if let payload = invoice.header.qrPayload {
                ColumnItem(width: .fixed(70)) {
                    QRCodeContent(payload, size: 65, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Reusable sub-blocks

    private static func logoOrFallback(
        supplier: InvoiceSupplier,
        theme: InvoiceTheme,
        alignment: TextAlignment = .leading
    ) -> any PDFContent {
        if let path = supplier.logoPath,
           let img = ImageContent(path: path, maxWidth: theme.logoMaxWidth, maxHeight: theme.logoMaxHeight) {
            return img
        }
        // Fallback: initials or company name in accent color
        let initials = supplier.name
            .split(separator: " ")
            .prefix(3)
            .compactMap { $0.first.map(String.init) }
            .joined()
        return Text(initials.isEmpty ? supplier.name : initials)
            .font(theme.bodyFont, size: 26)
            .bold()
            .foregroundColor(theme.accentColor)
            .alignment(alignment)
    }

    private static func supplierBlock(
        supplier: InvoiceSupplier,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter,
        alignment: TextAlignment = .leading
    ) -> some PDFContent {
        return Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                Text(supplier.name)
                    .font(theme.bodyFont, size: theme.bodyFontSize)
                    .bold()
                    .alignment(alignment)
                if let street = supplier.street {
                    Text(street).font(theme.bodyFont, size: theme.bodyFontSize).alignment(alignment)
                }
                if let city = supplier.city {
                    Text(city).font(theme.bodyFont, size: theme.bodyFontSize).alignment(alignment)
                }
                if let country = supplier.country {
                    Text(country).font(theme.bodyFont, size: theme.bodyFontSize).alignment(alignment)
                }
            }
        }
    }

    private static func clientBlock(
        client: InvoiceClient,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        return Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                Text(client.name)
                    .font(theme.bodyFont, size: theme.bodyFontSize)
                    .bold()
                if let attn = client.attention {
                    Text("Attn: \(attn)").font(theme.bodyFont, size: theme.bodyFontSize)
                }
                if let street = client.street {
                    Text(street).font(theme.bodyFont, size: theme.bodyFontSize)
                }
                if let city = client.city {
                    Text(city).font(theme.bodyFont, size: theme.bodyFontSize)
                }
                if let country = client.country {
                    Text(country).font(theme.bodyFont, size: theme.bodyFontSize)
                }
                if let vat = client.vatNumber {
                    Spacer(height: 4)
                    Text("VAT: \(vat)").font(theme.bodyFont, size: theme.bodyFontSize)
                }
            }
        }
    }
}

// MARK: - InvoiceFormatter (internal)

/// Lightweight number/label formatting helpers used by the layout builder.
struct InvoiceFormatter {
    let theme: InvoiceTheme

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        return f
    }()

    private static let quantityFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        return f
    }()

    func label(_ text: String) -> String { text }

    func amount(_ value: Double) -> String {
        Self.amountFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    func quantity(_ value: Double) -> String {
        Self.quantityFormatter.string(from: NSNumber(value: value)) ?? String(format: value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", value)
    }

    func percent(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f%%", value)
            : String(format: "%.2f%%", value)
    }
}
