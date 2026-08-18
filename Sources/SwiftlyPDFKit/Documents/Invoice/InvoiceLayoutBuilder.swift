import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - InvoiceLayoutBuilder (internal)

enum InvoiceLayoutBuilder {

    // MARK: - Section builders

    static func headerSection(
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

    static func lineItemsTableForRows(
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

    static func totalsTable(
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

    static func paymentSection(
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

    static func logoOrFallback(
        supplier: InvoiceSupplier,
        theme: InvoiceTheme,
        alignment: TextAlignment = .leading
    ) -> any PDFContent {
        // `alignment` must reach the image, not just the text fallback:
        // ImageContent has honoured it since v0.2.1, but this call site dropped
        // it, so a supplier WITH a logo always rendered flush left however the
        // caller asked. Invisible whenever the fallback initials are used —
        // which is every demo without a logoPath, and every probe.
        if let path = supplier.logoPath,
           let img = ImageContent(path: path, maxWidth: theme.logoMaxWidth,
                                  maxHeight: theme.logoMaxHeight, alignment: alignment) {
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

    static func supplierBlock(
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

    static func clientBlock(
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

    // MARK: - stackedLayout

    /// Legacy stacked-banner arrangement, retained solely for the sales-order
    /// builder, which delegates to it by name. No longer reachable from
    /// ``InvoiceLayoutType``; behaviour-frozen for the sibling document family.
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

        // Light tint for the meta banner — derive from accent colour components.
        let lightBannerColor: PDFColor = {
            let comps = theme.accentColor.components
            let r = comps.r * 0.15 + 0.85
            let g = comps.g * 0.15 + 0.85
            let b = comps.b * 0.15 + 0.85
            return PDFColor(red: r, green: g, blue: b)
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
    static func stackedMetaBanner(
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

    // MARK: - Roster builders (v0.3.0)

    // MARK: - Shared provisional superset renderer

    /// Renders the full block superset in one functional arrangement shared by
    /// all three roster builders, adapted from the historical single-column
    /// pagination math.
    ///
    /// Which blocks each family keeps, their order, and the visual grammar are
    /// a later reference-derived deliverable; every spacing and height number
    /// here is page-fit accounting only and carries no design authority.
    static func supersetLayout(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        labels: InvoiceLabels,
        locale: Locale,
        pageSize: PageSize
    ) -> PDF {
        let fmt = InvoiceFormatter(
            theme: theme,
            locale: locale,
            currencyCode: invoice.header.currency,
            labels: labels
        )

        // ── Height accounting (functional page-fit only) ───────────────────
        let rowH = theme.lineItemRowHeight

        let headerHeight: CGFloat = theme.logoMaxHeight + 13 + 52
        let shipToH: CGFloat = invoice.shipTo != nil ? 16 + 6 * 13 + 8 : 0
        let metaHeight: CGFloat = 80
        let headlineH: CGFloat = invoice.paymentState != nil ? 24 + 8 : 0
        let page1Overhead: CGFloat = headerHeight + 20 + shipToH + metaHeight + 12 + headlineH

        let tableHeaderH: CGFloat = rowH

        let totalsRowCount   = (invoice.totals.amountPaid ?? 0) > 0 ? 5 : 4
        let totalsH: CGFloat = CGFloat(totalsRowCount) * theme.totalsRowHeight + 12
        let breakdownRows    = invoice.taxBreakdown?.count ?? 0
        let breakdownH: CGFloat = breakdownRows > 0
            ? CGFloat(breakdownRows + 1) * theme.totalsRowHeight + 16 + 14 : 0
        let taxNoteH: CGFloat = invoice.taxNote != nil ? 8 + 14 : 0
        let notesH: CGFloat = invoice.header.notes != nil ? 20 + 14 : 0
        let historyRows      = invoice.paymentHistory?.count ?? 0
        let historyH: CGFloat = historyRows > 0
            ? CGFloat(historyRows + 1) * theme.totalsRowHeight + 16 + 14 : 0
        let paymentH: CGFloat = (invoice.header.qrPayload != nil ||
                                        invoice.header.paymentReference != nil) ? 16 + 80 : 0
        let lastPageBottomH: CGFloat = totalsH + breakdownH + taxNoteH + notesH + historyH + paymentH

        // The footer always exists here: it reserves an extra line under any
        // caller-supplied footer content for the page-number template.
        let footerH: CGFloat = (invoice.footer.map { $0.height } ?? 12) + 12
        let margins          = theme.pageMargins
        let bodyH            = pageSize.height - margins * 2 - footerH

        let p1RowsMax   = max(1, Int(floor((bodyH - page1Overhead - tableHeaderH) / rowH)))
        let contRowsMax = max(1, Int(floor((bodyH - tableHeaderH) / rowH)))

        // ── Pass 1: split lines into page chunks ───────────────────────────
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

        // ── Pass 2: overflow page when the bottom content does not fit ─────
        let lastChunkUsed: CGFloat
        if let last = chunks.last {
            let isFirstPage = chunks.count == 1
            let overhead    = isFirstPage ? page1Overhead : 0
            lastChunkUsed   = overhead + tableHeaderH + CGFloat(last.count) * rowH
        } else {
            lastChunkUsed = page1Overhead + tableHeaderH
        }
        if lastChunkUsed + lastPageBottomH > bodyH {
            chunks.append([])   // empty chunk → page with only bottom content
        }

        let pageCount = chunks.count

        func makeFooter(page: Int) -> Footer {
            Footer(height: footerH) {
                HRule(thickness: 0.5, color: theme.ruleColor)
                Spacer(height: 4)
                for line in invoice.footer?.lines ?? [] {
                    Text(line)
                        .font(theme.bodyFont, size: 8)
                        .alignment(.center)
                }
                Text(fmt.labels.pageNumber(page, of: pageCount))
                    .font(theme.bodyFont, size: 8)
                    .alignment(.center)
            }
        }

        // ── Page loop ──────────────────────────────────────────────────────
        var pages: [Page] = []

        for (pageIdx, chunk) in chunks.enumerated() {
            let isFirst = pageIdx == 0
            let isLast  = pageIdx == chunks.count - 1

            let page = Page(size: pageSize, margins: margins) {

                if isFirst {
                    supersetHeaderSection(invoice: invoice, theme: theme, fmt: fmt)
                    Spacer(height: 12)
                    if let shipTo = invoice.shipTo {
                        supersetShipToBlock(party: shipTo, theme: theme, fmt: fmt)
                        Spacer(height: 8)
                    }
                    supersetMetaSection(invoice: invoice, theme: theme, fmt: fmt)
                    Spacer(height: 12)
                    if let state = invoice.paymentState {
                        supersetHeadline(state: state, invoice: invoice, theme: theme, fmt: fmt)
                        Spacer(height: 8)
                    }
                }

                supersetLineItemsTable(chunk, theme: theme, fmt: fmt, showHeader: true)

                if isLast {
                    Spacer(height: 12)
                    supersetTotalsTable(invoice: invoice, theme: theme, fmt: fmt)
                    if let breakdown = invoice.taxBreakdown, !breakdown.isEmpty {
                        Spacer(height: 12)
                        supersetTaxBreakdownSection(breakdown, theme: theme, fmt: fmt)
                    }
                    if let taxNote = invoice.taxNote {
                        Spacer(height: 8)
                        Text(taxNote).font(theme.bodyFont, size: theme.bodyFontSize - 1)
                    }
                    if let notes = invoice.header.notes {
                        Spacer(height: 12)
                        Text(notes).font(theme.bodyFont, size: theme.bodyFontSize - 1)
                    }
                    if let history = invoice.paymentHistory, !history.isEmpty {
                        Spacer(height: 12)
                        supersetPaymentHistorySection(history, theme: theme, fmt: fmt)
                    }
                    if invoice.header.qrPayload != nil || invoice.header.paymentReference != nil {
                        Spacer(height: 16)
                        supersetPaymentSection(invoice: invoice, theme: theme, fmt: fmt)
                    }
                }

                makeFooter(page: pageIdx + 1)
            }
            pages.append(page)
        }

        return PDF(pages: pages)
    }

    // MARK: - Superset section variants (labels-threaded)

    // These deliberately duplicate the shape of the retained shared section
    // helpers instead of threading a labels parameter into them: the retained
    // helpers' literals are behaviour-frozen for the sibling document
    // families, and this provisional duplication is replaced wholesale by the
    // reference-derived rework.

    static func supersetHeaderSection(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        let supplier = invoice.supplier
        let client   = invoice.client

        switch theme.logoPosition {
        case .left:
            return Columns(spacing: 20) {
                ColumnItem(width: .fixed(160)) {
                    logoOrFallback(supplier: supplier, theme: theme)
                    Spacer(height: 6)
                    HRule(thickness: 0.5, color: theme.accentColor)
                    Spacer(height: 6)
                    supplierBlock(supplier: supplier, theme: theme, fmt: fmt)
                }
                ColumnItem(width: .flex) {
                    Spacer(height: 4)
                    supersetClientBlock(client: client, theme: theme, fmt: fmt)
                }
            }

        case .right:
            return Columns(spacing: 20) {
                ColumnItem(width: .flex) {
                    Spacer(height: 4)
                    supersetClientBlock(client: client, theme: theme, fmt: fmt)
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
                    supersetClientBlock(client: client, theme: theme, fmt: fmt)
                }
            }
        }
    }

    static func supersetClientBlock(
        client: InvoiceClient,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                Text(fmt.labels.billToHeader)
                    .font(theme.bodyFont, size: theme.bodyFontSize - 1)
                    .bold()
                Spacer(height: 2)
                Text(client.name)
                    .font(theme.bodyFont, size: theme.bodyFontSize)
                    .bold()
                if let attn = client.attention {
                    Text("\(fmt.labels.attentionLabel): \(attn)")
                        .font(theme.bodyFont, size: theme.bodyFontSize)
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
                    Text("\(fmt.labels.vatNumberLabel): \(vat)")
                        .font(theme.bodyFont, size: theme.bodyFontSize)
                }
            }
        }
    }

    static func supersetShipToBlock(
        party: InvoiceParty,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                Text(fmt.labels.shipToHeader)
                    .font(theme.bodyFont, size: theme.bodyFontSize - 1)
                    .bold()
                Spacer(height: 2)
                Text(party.name)
                    .font(theme.bodyFont, size: theme.bodyFontSize)
                    .bold()
                if let attn = party.attention {
                    Text("\(fmt.labels.attentionLabel): \(attn)")
                        .font(theme.bodyFont, size: theme.bodyFontSize)
                }
                if let street = party.street {
                    Text(street).font(theme.bodyFont, size: theme.bodyFontSize)
                }
                if let city = party.city {
                    Text(city).font(theme.bodyFont, size: theme.bodyFontSize)
                }
                if let country = party.country {
                    Text(country).font(theme.bodyFont, size: theme.bodyFontSize)
                }
                if let vat = party.vatNumber {
                    Spacer(height: 4)
                    Text("\(fmt.labels.vatNumberLabel): \(vat)")
                        .font(theme.bodyFont, size: theme.bodyFontSize)
                }
            }
        }
    }

    static func supersetMetaSection(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        let header = invoice.header
        return Columns(spacing: 20) {
            // Left: key–value pairs
            ColumnItem(width: .fixed(240)) {
                Columns(spacing: 0) {
                    ColumnItem(width: .fixed(90)) {
                        Text(fmt.labels.invoiceNumberLabel)
                            .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        if header.issueDate.isEmpty == false {
                            Text(fmt.labels.issueDateLabel)
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if header.dueDate != nil {
                            Text(fmt.labels.dueDateLabel)
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if header.serviceDate != nil {
                            Text(fmt.labels.serviceDateLabel)
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if invoice.client.clientNumber != nil {
                            Text(fmt.labels.clientNumberLabel)
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if invoice.client.poNumber != nil {
                            Text(fmt.labels.poNumberLabel)
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                    }
                    ColumnItem(width: .flex) {
                        Text(": \(header.invoiceNumber)")
                            .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        if header.issueDate.isEmpty == false {
                            Text(": \(header.issueDate)")
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if let due = header.dueDate {
                            Text(": \(due)")
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if let svc = header.serviceDate {
                            Text(": \(svc)")
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if let clientNo = invoice.client.clientNumber {
                            Text(": \(clientNo)")
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if let poRef = invoice.client.poNumber {
                            Text(": \(poRef)")
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
                            Text(fmt.labels.vatNumberLabel)
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        ColumnItem(width: .flex) {
                            Text(vat).font(theme.bodyFont, size: theme.bodyFontSize)
                        }
                    }
                    Spacer(height: 8)
                }
                Text(header.documentTitle)
                    .font(theme.titleFont, size: theme.titleFontSize)
                    .bold()
                    .italic()
                    .alignment(.center)
            }
        }
    }

    static func supersetHeadline(
        state: InvoicePaymentState,
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        let headline: String
        switch state {
        case .paid(let date):
            headline = fmt.labels.paidHeadline(date: fmt.date(date))
        case .due(let date):
            headline = fmt.labels.dueHeadline(
                amount: fmt.money(invoice.totals.amountDue),
                date: fmt.date(date))
        }
        return Text(headline)
            .font(theme.bodyFont, size: theme.bodyFontSize + 2)
            .bold()
    }

    static func supersetLineItemsTable(
        _ lines: [InvoiceLine],
        theme: InvoiceTheme,
        fmt: InvoiceFormatter,
        showHeader: Bool
    ) -> some PDFContent {
        let rows = lines.map { line -> [String] in
            let qty       = fmt.quantity(line.quantity)
            let unitPrice = fmt.money(line.unitPrice)
            let discount  = line.discountPercent > 0 ? fmt.percent(line.discountPercent) : ""
            let vatRate   = fmt.percent(line.vatRate)
            let subtotal  = fmt.money(line.subtotalExcl)
            return [line.description, qty, unitPrice, discount, vatRate, subtotal]
        }

        let lineStyle = TableStyle(
            headerBackground: theme.tableHeaderBackground,
            headerTextColor: theme.tableHeaderTextColor,
            headerFontSize: theme.tableHeaderFontSize,
            cellFontSize: theme.tableCellFontSize,
            rowHeight: theme.lineItemRowHeight,
            alternateRowColor: theme.tableAlternateRowColor,
            borderColor: theme.tableBorderColor,
            borderWidth: 0.5,
            cellPadding: 4
        )

        return Table(data: rows, style: lineStyle, showHeader: showHeader) {
            Column(fmt.labels.columnDescription, width: .flex, alignment: .leading)
            Column(fmt.labels.columnQuantity, width: .fixed(40), alignment: .trailing, headerAlignment: .trailing)
            Column(fmt.labels.columnUnitPrice, width: .fixed(65), alignment: .trailing, headerAlignment: .trailing)
            Column(fmt.labels.columnDiscount, width: .fixed(60), alignment: .trailing, headerAlignment: .trailing)
            Column(fmt.labels.columnTax, width: .fixed(45), alignment: .trailing, headerAlignment: .trailing)
            Column(fmt.labels.columnAmount, width: .fixed(70), alignment: .trailing, headerAlignment: .trailing)
        }
    }

    static func supersetTotalsTable(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        let totals = invoice.totals
        var rows: [[String]] = []

        rows.append([fmt.labels.subtotalLabel, "", fmt.money(totals.subtotalExcl)])

        if let disc = totals.globalDiscount, disc > 0 {
            rows.append([fmt.labels.columnDiscount, "", "-\(fmt.money(disc))"])
        }

        rows.append([fmt.labels.vatLabel, "", fmt.money(totals.totalVat)])

        if let paid = totals.amountPaid, paid > 0 {
            rows.append([fmt.labels.totalLabel, "", fmt.money(totals.totalIncl)])
            rows.append([fmt.labels.amountPaidLabel, "", "-\(fmt.money(paid))"])
            rows.append([fmt.labels.amountDueLabel, "", fmt.money(totals.amountDue)])
        } else {
            rows.append([fmt.labels.totalLabel, "", fmt.money(totals.totalIncl)])
        }

        let totalsStyle = TableStyle(
            headerBackground: theme.tableHeaderBackground,
            headerTextColor: theme.tableHeaderTextColor,
            headerFontSize: theme.tableHeaderFontSize,
            cellFontSize: theme.tableCellFontSize,
            rowHeight: theme.totalsRowHeight,
            alternateRowColor: nil,
            borderColor: theme.tableBorderColor,
            borderWidth: 0.5,
            cellPadding: 4,
            cellBold: true
        )

        return Table(data: rows, style: totalsStyle, showHeader: false) {
            Column("", width: .flex, alignment: .leading)
            Column("", width: .flex, alignment: .leading)
            Column("", width: .fixed(100), alignment: .trailing)
        }
    }

    static func supersetTaxBreakdownSection(
        _ breakdown: [InvoiceTaxSubtotal],
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        let rows = breakdown.map { row -> [String] in
            [
                fmt.percent(row.ratePercent),
                fmt.money(row.taxableBase),
                fmt.money(row.taxAmount),
                row.exemptionReason ?? ""
            ]
        }

        let style = TableStyle(
            headerBackground: theme.tableHeaderBackground,
            headerTextColor: theme.tableHeaderTextColor,
            headerFontSize: theme.tableHeaderFontSize,
            cellFontSize: theme.tableCellFontSize,
            rowHeight: theme.totalsRowHeight,
            alternateRowColor: nil,
            borderColor: theme.tableBorderColor,
            borderWidth: 0.5,
            cellPadding: 4
        )

        return Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                Text(fmt.labels.taxBreakdownHeader)
                    .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                Spacer(height: 4)
                Table(data: rows, style: style, showHeader: true) {
                    Column(fmt.labels.columnTaxRate, width: .fixed(60),
                           alignment: .trailing, headerAlignment: .trailing)
                    Column(fmt.labels.columnTaxableBase, width: .fixed(90),
                           alignment: .trailing, headerAlignment: .trailing)
                    Column(fmt.labels.columnTax, width: .fixed(90),
                           alignment: .trailing, headerAlignment: .trailing)
                    Column(fmt.labels.columnExemptionReason, width: .flex, alignment: .leading)
                }
            }
        }
    }

    static func supersetPaymentHistorySection(
        _ history: [InvoicePaymentRow],
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        let rows = history.map { row -> [String] in
            [
                row.method,
                fmt.date(row.date),
                fmt.money(row.amount),
                row.receiptNumber ?? ""
            ]
        }

        let style = TableStyle(
            headerBackground: theme.tableHeaderBackground,
            headerTextColor: theme.tableHeaderTextColor,
            headerFontSize: theme.tableHeaderFontSize,
            cellFontSize: theme.tableCellFontSize,
            rowHeight: theme.totalsRowHeight,
            alternateRowColor: nil,
            borderColor: theme.tableBorderColor,
            borderWidth: 0.5,
            cellPadding: 4
        )

        return Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                Text(fmt.labels.paymentHistoryHeader)
                    .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                Spacer(height: 4)
                Table(data: rows, style: style, showHeader: true) {
                    Column(fmt.labels.columnPaymentMethod, width: .flex, alignment: .leading)
                    Column(fmt.labels.columnPaymentDate, width: .fixed(80),
                           alignment: .trailing, headerAlignment: .trailing)
                    Column(fmt.labels.columnAmount, width: .fixed(80),
                           alignment: .trailing, headerAlignment: .trailing)
                    Column(fmt.labels.columnReceiptNumber, width: .fixed(90),
                           alignment: .trailing, headerAlignment: .trailing)
                }
            }
        }
    }

    static func supersetPaymentSection(
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
                            Text("\(fmt.labels.paymentReferenceLabel): \(ref)")
                                .font(theme.bodyFont, size: 9).bold()
                                .foregroundColor(theme.paymentBannerTextColor)
                                .alignment(.center)
                        }
                    } else if let ref = invoice.header.paymentReference {
                        Text("\(fmt.labels.paymentReferenceLabel): \(ref)")
                            .font(theme.bodyFont, size: 9).bold()
                    }
                    if let terms = invoice.header.paymentTerms {
                        Spacer(height: 4)
                        Text(terms).font(theme.bodyFont, size: 9)
                    }
                    if let iban = invoice.supplier.iban {
                        Spacer(height: 4)
                        let bicSuffix = invoice.supplier.bic
                            .map { "  \(fmt.labels.bicLabel): \($0)" } ?? ""
                        Text("\(fmt.labels.ibanLabel): \(iban)\(bicSuffix)")
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
}
