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

    /// Like ``classic`` but adds a full-height accent bar on the left edge of every page.
    case classicWithSidebar

    /// Minimalist layout: no table borders, generous whitespace, plain-text totals.
    case minimal

    /// Stacked layout: supplier and client stacked vertically below a full-width title banner.
    case stacked

    /// Summary-first layout: page 1 shows totals and payment only; line items start on page 2.
    case summaryFirst
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
        case .classic:
            self = InvoiceLayoutBuilder.classicLayout(
                invoice: invoice, theme: theme, pageSize: pageSize)
        case .classicWithSidebar:
            self = InvoiceLayoutBuilder.classicWithSidebarLayout(
                invoice: invoice, theme: theme, pageSize: pageSize)
        case .minimal:
            self = InvoiceLayoutBuilder.minimalLayout(
                invoice: invoice, theme: theme, pageSize: pageSize)
        case .stacked:
            self = InvoiceLayoutBuilder.stackedLayout(
                invoice: invoice, theme: theme, pageSize: pageSize)
        case .summaryFirst:
            self = InvoiceLayoutBuilder.summaryFirstLayout(
                invoice: invoice, theme: theme, pageSize: pageSize)
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

    // MARK: - classicWithSidebarLayout

    static func classicWithSidebarLayout(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        pageSize: PageSize
    ) -> PDF {
        // The sidebar is a fixed-width FilledBox column on the left. Because Columns
        // advances the cursor by the *tallest* column, the sidebar column must contain a
        // FilledBox tall enough to cover the entire page body. We use a large fixed height.
        let sidebarWidth: CGFloat = 14
        let sidebarGap:   CGFloat = 16

        // Re-use classicLayout pagination math; column layout handles the shift.

        let fmt = InvoiceFormatter(theme: theme)

        let rowH           = theme.lineItemRowHeight
        let headerHeight:  CGFloat = theme.logoMaxHeight + 13 + 52
        let metaHeight:    CGFloat = 80
        let page1Overhead: CGFloat = headerHeight + 20 + metaHeight + 20
        let tableHeaderH:  CGFloat = rowH

        let totalsRowCount   = (invoice.totals.amountPaid ?? 0) > 0 ? 5 : 4
        let totalsH:         CGFloat = CGFloat(totalsRowCount) * theme.totalsRowHeight + 12
        let notesH:          CGFloat = invoice.header.notes != nil ? 20 + 14 : 0
        let paymentH:        CGFloat = (invoice.header.qrPayload != nil ||
                                        invoice.header.paymentReference != nil) ? 16 + 80 : 0
        let lastPageBottomH: CGFloat = totalsH + notesH + paymentH

        let footerH: CGFloat = invoice.footer.map { $0.height } ?? 0
        let margins          = theme.pageMargins
        let bodyH            = pageSize.height - margins * 2 - footerH

        let p1RowsMax   = max(1, Int(floor((bodyH - page1Overhead - tableHeaderH) / rowH)))
        let contRowsMax = max(1, Int(floor((bodyH - tableHeaderH) / rowH)))

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

        let lastChunkUsed: CGFloat
        if let last = chunks.last {
            let isFirstPage = chunks.count == 1
            let overhead    = isFirstPage ? page1Overhead : 0
            lastChunkUsed   = overhead + tableHeaderH + CGFloat(last.count) * rowH
        } else {
            lastChunkUsed = page1Overhead + tableHeaderH
        }
        if lastChunkUsed + lastPageBottomH > bodyH {
            chunks.append([])
        }

        func makeFooter() -> Footer? {
            guard let invoiceFooter = invoice.footer else { return nil }
            return Footer(height: invoiceFooter.height) {
                HRule(thickness: 0.5, color: theme.ruleColor)
                Spacer(height: 4)
                for line in invoiceFooter.lines {
                    Text(line).font(theme.bodyFont, size: 8).alignment(.center)
                }
            }
        }

        var pages: [Page] = []

        for (pageIdx, chunk) in chunks.enumerated() {
            let isFirst = pageIdx == 0
            let isLast  = pageIdx == chunks.count - 1

            let page = Page(size: pageSize, margins: margins) {
                // Sidebar + content side by side. The sidebar FilledBox height is set to a
                // very large value so it always fills the full column regardless of page content.
                Columns(spacing: sidebarGap) {
                    ColumnItem(width: .fixed(sidebarWidth)) {
                        FilledBox(color: theme.accentColor, height: pageSize.height) {}
                    }
                    ColumnItem(width: .flex) {
                        if isFirst {
                            headerSection(invoice: invoice, theme: theme, fmt: fmt)
                            Spacer(height: 20)
                            metaSection(invoice: invoice, theme: theme, fmt: fmt)
                            Spacer(height: 20)
                        }
                        lineItemsTableForRows(chunk, invoice: invoice, theme: theme, fmt: fmt,
                                              showHeader: true)
                        if isLast {
                            Spacer(height: 12)
                            totalsTable(invoice: invoice, theme: theme, fmt: fmt)
                            if let notes = invoice.header.notes {
                                Spacer(height: 12)
                                Text(notes).font(theme.bodyFont, size: theme.bodyFontSize - 1)
                            }
                            if invoice.header.qrPayload != nil || invoice.header.paymentReference != nil {
                                Spacer(height: 16)
                                paymentSection(invoice: invoice, theme: theme, fmt: fmt)
                            }
                        }
                    }
                }
                if let f = makeFooter() { f }
            }
            pages.append(page)
        }

        if pages.isEmpty {
            let page = Page(size: pageSize, margins: margins) {
                Columns(spacing: sidebarGap) {
                    ColumnItem(width: .fixed(sidebarWidth)) {
                        FilledBox(color: theme.accentColor, height: pageSize.height) {}
                    }
                    ColumnItem(width: .flex) {
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
                    }
                }
                if let f = makeFooter() { f }
            }
            pages.append(page)
        }

        return PDF(pages: pages)
    }

    // MARK: - minimalLayout

    static func minimalLayout(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        pageSize: PageSize
    ) -> PDF {
        let fmt = InvoiceFormatter(theme: theme)

        // Minimal uses slightly taller rows and smaller font for an airy feel.
        var minTheme = theme
        minTheme.lineItemRowHeight = max(theme.lineItemRowHeight, 22)
        minTheme.bodyFontSize      = min(theme.bodyFontSize, 9)

        let rowH           = minTheme.lineItemRowHeight
        let headerHeight:  CGFloat = theme.logoMaxHeight + 13 + 52
        let metaHeight:    CGFloat = 80
        let page1Overhead: CGFloat = headerHeight + 20 + metaHeight + 20
        let tableHeaderH:  CGFloat = rowH

        let totalsRowCount   = (invoice.totals.amountPaid ?? 0) > 0 ? 5 : 4
        // Each minimal totals row is ~16 pt (plain text) plus an HRule separator.
        let totalsH:         CGFloat = CGFloat(totalsRowCount) * 16 + 12
        let notesH:          CGFloat = invoice.header.notes != nil ? 20 + 14 : 0
        let paymentH:        CGFloat = (invoice.header.qrPayload != nil ||
                                        invoice.header.paymentReference != nil) ? 16 + 80 : 0
        let lastPageBottomH: CGFloat = totalsH + notesH + paymentH

        let footerH: CGFloat = invoice.footer.map { $0.height } ?? 0
        let margins          = theme.pageMargins
        let bodyH            = pageSize.height - margins * 2 - footerH

        let p1RowsMax   = max(1, Int(floor((bodyH - page1Overhead - tableHeaderH) / rowH)))
        let contRowsMax = max(1, Int(floor((bodyH - tableHeaderH) / rowH)))

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

        let lastChunkUsed: CGFloat
        if let last = chunks.last {
            let isFirstPage = chunks.count == 1
            let overhead    = isFirstPage ? page1Overhead : 0
            lastChunkUsed   = overhead + tableHeaderH + CGFloat(last.count) * rowH
        } else {
            lastChunkUsed = page1Overhead + tableHeaderH
        }
        if lastChunkUsed + lastPageBottomH > bodyH {
            chunks.append([])
        }

        // Borderless table style.
        func minimalTableStyle(rowHeight: CGFloat) -> TableStyle {
            TableStyle(
                headerBackground:   PDFColor(white: 1.0),  // white = invisible header bg
                headerTextColor:    .black,
                headerFontSize:     minTheme.bodyFontSize,
                cellFontSize:       minTheme.bodyFontSize,
                rowHeight:          rowHeight,
                alternateRowColor:  nil,
                borderColor:        PDFColor(white: 1.0),  // white = no visible border
                borderWidth:        0,
                cellPadding:        4
            )
        }

        func minimalLineItemsTable(_ lines: [InvoiceLine], showHeader: Bool) -> some PDFContent {
            let rows = lines.map { line -> [String] in
                let qty      = fmt.quantity(line.quantity)
                let price    = fmt.amount(line.unitPrice)
                let discount = line.discountPercent > 0 ? fmt.percent(line.discountPercent) : ""
                let vat      = fmt.percent(line.vatRate)
                let sub      = fmt.amount(line.subtotalExcl)
                return [line.description, qty, price, discount, vat, sub]
            }
            return Table(data: rows, style: minimalTableStyle(rowHeight: rowH), showHeader: showHeader) {
                Column("Description", width: .flex,      alignment: .leading)
                Column("Qty",         width: .fixed(40), alignment: .trailing, headerAlignment: .trailing)
                Column("Unit Price",  width: .fixed(65), alignment: .trailing, headerAlignment: .trailing)
                Column("Discount",    width: .fixed(60), alignment: .trailing, headerAlignment: .trailing)
                Column("VAT %",       width: .fixed(45), alignment: .trailing, headerAlignment: .trailing)
                Column("Subtotal",    width: .fixed(70), alignment: .trailing, headerAlignment: .trailing)
            }
        }

        // Totals as plain column rows (no table wrapper).
        func minimalTotalsBlock() -> some PDFContent {
            let t = invoice.totals
            return Columns(spacing: 0) {
                ColumnItem(width: .flex) {
                    HRule(thickness: 0.5, color: theme.ruleColor)
                    Spacer(height: 4)
                    Text("Subtotal excl. VAT").font(minTheme.bodyFont, size: minTheme.bodyFontSize).bold()
                    if let disc = t.globalDiscount, disc > 0 {
                        Text("Discount").font(minTheme.bodyFont, size: minTheme.bodyFontSize).bold()
                    }
                    Text("VAT").font(minTheme.bodyFont, size: minTheme.bodyFontSize).bold()
                    if let paid = t.amountPaid, paid > 0 {
                        Text("Total incl. VAT").font(minTheme.bodyFont, size: minTheme.bodyFontSize).bold()
                        Text("Amount paid").font(minTheme.bodyFont, size: minTheme.bodyFontSize).bold()
                        Text("Amount due (\(invoice.header.currency))").font(minTheme.bodyFont, size: minTheme.bodyFontSize).bold()
                    } else {
                        Text("Total incl. VAT (\(invoice.header.currency))").font(minTheme.bodyFont, size: minTheme.bodyFontSize).bold()
                    }
                }
                ColumnItem(width: .fixed(100)) {
                    HRule(thickness: 0.5, color: theme.ruleColor)
                    Spacer(height: 4)
                    Text(fmt.amount(t.subtotalExcl)).font(minTheme.bodyFont, size: minTheme.bodyFontSize).alignment(.trailing)
                    if let disc = t.globalDiscount, disc > 0 {
                        Text("-\(fmt.amount(disc))").font(minTheme.bodyFont, size: minTheme.bodyFontSize).alignment(.trailing)
                    }
                    Text(fmt.amount(t.totalVat)).font(minTheme.bodyFont, size: minTheme.bodyFontSize).alignment(.trailing)
                    if let paid = t.amountPaid, paid > 0 {
                        Text(fmt.amount(t.totalIncl)).font(minTheme.bodyFont, size: minTheme.bodyFontSize).alignment(.trailing)
                        Text("-\(fmt.amount(paid))").font(minTheme.bodyFont, size: minTheme.bodyFontSize).alignment(.trailing)
                        Text(fmt.amount(t.amountDue)).font(minTheme.bodyFont, size: minTheme.bodyFontSize).bold().alignment(.trailing)
                    } else {
                        Text(fmt.amount(t.totalIncl)).font(minTheme.bodyFont, size: minTheme.bodyFontSize).bold().alignment(.trailing)
                    }
                }
            }
        }

        func makeFooter() -> Footer? {
            guard let invoiceFooter = invoice.footer else { return nil }
            return Footer(height: invoiceFooter.height) {
                HRule(thickness: 0.5, color: theme.ruleColor)
                Spacer(height: 4)
                for line in invoiceFooter.lines {
                    Text(line).font(theme.bodyFont, size: 8).alignment(.center)
                }
            }
        }

        var pages: [Page] = []

        for (pageIdx, chunk) in chunks.enumerated() {
            let isFirst = pageIdx == 0
            let isLast  = pageIdx == chunks.count - 1

            let page = Page(size: pageSize, margins: margins) {
                if isFirst {
                    headerSection(invoice: invoice, theme: minTheme, fmt: fmt)
                    Spacer(height: 20)
                    metaSection(invoice: invoice, theme: minTheme, fmt: fmt)
                    Spacer(height: 20)
                }
                minimalLineItemsTable(chunk, showHeader: isFirst || pageIdx == 0)
                if isLast {
                    Spacer(height: 12)
                    minimalTotalsBlock()
                    if let notes = invoice.header.notes {
                        Spacer(height: 12)
                        Text(notes).font(minTheme.bodyFont, size: minTheme.bodyFontSize - 1)
                    }
                    if invoice.header.qrPayload != nil || invoice.header.paymentReference != nil {
                        Spacer(height: 16)
                        paymentSection(invoice: invoice, theme: minTheme, fmt: fmt)
                    }
                }
                if let f = makeFooter() { f }
            }
            pages.append(page)
        }

        if pages.isEmpty {
            let page = Page(size: pageSize, margins: margins) {
                headerSection(invoice: invoice, theme: minTheme, fmt: fmt)
                Spacer(height: 20)
                metaSection(invoice: invoice, theme: minTheme, fmt: fmt)
                Spacer(height: 20)
                minimalTotalsBlock()
                if let notes = invoice.header.notes {
                    Spacer(height: 12)
                    Text(notes).font(minTheme.bodyFont, size: minTheme.bodyFontSize - 1)
                }
                if invoice.header.qrPayload != nil || invoice.header.paymentReference != nil {
                    Spacer(height: 16)
                    paymentSection(invoice: invoice, theme: minTheme, fmt: fmt)
                }
                if let f = makeFooter() { f }
            }
            pages.append(page)
        }

        return PDF(pages: pages)
    }

    // MARK: - stackedLayout

    static func stackedLayout(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        pageSize: PageSize
    ) -> PDF {
        let fmt = InvoiceFormatter(theme: theme)

        // Page 1 overhead:
        //   title banner (50) + spacer(8) + supplier block (~52) + spacer(8) +
        //   HRule(1) + spacer(8) + client block (~52) + spacer(8) +
        //   meta banner (28) + spacer(12)
        let titleBannerH:  CGFloat = 50
        let supplierH:     CGFloat = 52
        let clientH:       CGFloat = 52
        let metaBannerH:   CGFloat = 28
        let page1Overhead: CGFloat = titleBannerH + 8 + supplierH + 8 + 1 + 8 + clientH + 8 + metaBannerH + 12

        let rowH           = theme.lineItemRowHeight
        let tableHeaderH:  CGFloat = rowH

        let totalsRowCount   = (invoice.totals.amountPaid ?? 0) > 0 ? 5 : 4
        let totalsH:         CGFloat = CGFloat(totalsRowCount) * theme.totalsRowHeight + 12
        let notesH:          CGFloat = invoice.header.notes != nil ? 20 + 14 : 0
        let paymentH:        CGFloat = (invoice.header.qrPayload != nil ||
                                        invoice.header.paymentReference != nil) ? 16 + 80 : 0
        let lastPageBottomH: CGFloat = totalsH + notesH + paymentH

        let footerH: CGFloat = invoice.footer.map { $0.height } ?? 0
        let margins          = theme.pageMargins
        let bodyH            = pageSize.height - margins * 2 - footerH

        let p1RowsMax   = max(1, Int(floor((bodyH - page1Overhead - tableHeaderH) / rowH)))
        let contRowsMax = max(1, Int(floor((bodyH - tableHeaderH) / rowH)))

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

        let lastChunkUsed: CGFloat
        if let last = chunks.last {
            let isFirstPage = chunks.count == 1
            let overhead    = isFirstPage ? page1Overhead : 0
            lastChunkUsed   = overhead + tableHeaderH + CGFloat(last.count) * rowH
        } else {
            lastChunkUsed = page1Overhead + tableHeaderH
        }
        if lastChunkUsed + lastPageBottomH > bodyH {
            chunks.append([])
        }

        // Light tint for the meta banner — derive from CGColor components when available,
        // otherwise fall back to a neutral light gray.
        let lightBannerColor: PDFColor = {
            let cg = theme.accentColor.cgColor
            if let comps = cg.components, cg.numberOfComponents >= 3 {
                let r = comps[0] * 0.15 + 0.85
                let g = comps[1] * 0.15 + 0.85
                let b = comps[2] * 0.15 + 0.85
                return PDFColor(red: r, green: g, blue: b)
            }
            return PDFColor(white: 0.90)
        }()

        func stackedPage1Header() -> some PDFContent {
            // Full-width title banner
            Columns(spacing: 0) {
                ColumnItem(width: .flex) {
                    FilledBox(color: theme.accentColor, height: titleBannerH) {
                        Text(invoice.header.documentTitle)
                            .font(theme.titleFont, size: theme.titleFontSize + 4)
                            .bold()
                            .foregroundColor(PDFColor.white)
                            .alignment(.center)
                    }
                    Spacer(height: 8)
                    // Supplier block centred
                    supplierBlock(supplier: invoice.supplier, theme: theme, fmt: fmt, alignment: .center)
                    Spacer(height: 8)
                    HRule(thickness: 0.5, color: theme.ruleColor)
                    Spacer(height: 8)
                    // Client block left-aligned
                    clientBlock(client: invoice.client, theme: theme, fmt: fmt)
                    Spacer(height: 8)
                    // Meta banner strip
                    stackedMetaBanner(invoice: invoice, theme: theme, fmt: fmt,
                                      bannerColor: lightBannerColor)
                    Spacer(height: 12)
                }
            }
        }

        // Continuation page mini-header: invoice number + accent rule.
        func contHeader() -> some PDFContent {
            Columns(spacing: 0) {
                ColumnItem(width: .flex) {
                    FilledBox(color: theme.accentColor, height: 20) {
                        Text("Invoice \(invoice.header.invoiceNumber)")
                            .font(theme.bodyFont, size: 9)
                            .foregroundColor(PDFColor.white)
                            .alignment(.center)
                    }
                    Spacer(height: 10)
                }
            }
        }

        func makeFooter() -> Footer? {
            guard let invoiceFooter = invoice.footer else { return nil }
            return Footer(height: invoiceFooter.height) {
                HRule(thickness: 0.5, color: theme.ruleColor)
                Spacer(height: 4)
                for line in invoiceFooter.lines {
                    Text(line).font(theme.bodyFont, size: 8).alignment(.center)
                }
            }
        }

        var pages: [Page] = []

        for (pageIdx, chunk) in chunks.enumerated() {
            let isFirst = pageIdx == 0
            let isLast  = pageIdx == chunks.count - 1

            let page = Page(size: pageSize, margins: margins) {
                if isFirst {
                    stackedPage1Header()
                } else {
                    contHeader()
                }
                lineItemsTableForRows(chunk, invoice: invoice, theme: theme, fmt: fmt, showHeader: true)
                if isLast {
                    Spacer(height: 12)
                    totalsTable(invoice: invoice, theme: theme, fmt: fmt)
                    if let notes = invoice.header.notes {
                        Spacer(height: 12)
                        Text(notes).font(theme.bodyFont, size: theme.bodyFontSize - 1)
                    }
                    if invoice.header.qrPayload != nil || invoice.header.paymentReference != nil {
                        Spacer(height: 16)
                        paymentSection(invoice: invoice, theme: theme, fmt: fmt)
                    }
                }
                if let f = makeFooter() { f }
            }
            pages.append(page)
        }

        if pages.isEmpty {
            let page = Page(size: pageSize, margins: margins) {
                stackedPage1Header()
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

    /// Renders the invoice number, dates, and currency as a compact filled banner strip.
    private static func stackedMetaBanner(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter,
        bannerColor: PDFColor
    ) -> some PDFContent {
        let h = invoice.header
        let parts: [String] = [
            "No. \(h.invoiceNumber)",
            h.issueDate.isEmpty ? nil : "Date: \(h.issueDate)",
            h.dueDate.map { "Due: \($0)" },
            h.currency.isEmpty ? nil : h.currency,
        ].compactMap { $0 }
        let summary = parts.joined(separator:  "   ·   ")
        return FilledBox(color: bannerColor, height: 22) {
            Text(summary)
                .font(theme.bodyFont, size: 9)
                .bold()
                .alignment(.center)
        }
    }

    // MARK: - summaryFirstLayout

    static func summaryFirstLayout(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        pageSize: PageSize
    ) -> PDF {
        let fmt = InvoiceFormatter(theme: theme)

        let footerH: CGFloat = invoice.footer.map { $0.height } ?? 0
        let margins          = theme.pageMargins
        let bodyH            = pageSize.height - margins * 2 - footerH

        // Line-item pages: full body minus table header row.
        let rowH           = theme.lineItemRowHeight
        let tableHeaderH:  CGFloat = rowH
        let contRowsMax    = max(1, Int(floor((bodyH - tableHeaderH) / rowH)))

        // Split all lines into page-sized chunks for pages 2+.
        var detailChunks: [[InvoiceLine]] = []
        var remaining = invoice.lines
        while !remaining.isEmpty {
            let take = min(contRowsMax, remaining.count)
            detailChunks.append(Array(remaining.prefix(take)))
            remaining = Array(remaining.dropFirst(take))
        }

        func makeFooter() -> Footer? {
            guard let invoiceFooter = invoice.footer else { return nil }
            return Footer(height: invoiceFooter.height) {
                HRule(thickness: 0.5, color: theme.ruleColor)
                Spacer(height: 4)
                for line in invoiceFooter.lines {
                    Text(line).font(theme.bodyFont, size: 8).alignment(.center)
                }
            }
        }

        var pages: [Page] = []

        // ── Page 1: summary (header + meta + totals + notes + payment) ──────
        let summaryPage = Page(size: pageSize, margins: margins) {
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
        pages.append(summaryPage)

        // ── Pages 2+: line items ─────────────────────────────────────────────
        for (idx, chunk) in detailChunks.enumerated() {
            let page = Page(size: pageSize, margins: margins) {
                lineItemsTableForRows(chunk, invoice: invoice, theme: theme, fmt: fmt,
                                      showHeader: true)
                if let f = makeFooter() { f }
            }
            pages.append(page)
            _ = idx  // suppress unused-variable warning
        }

        return PDF(pages: pages)
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
