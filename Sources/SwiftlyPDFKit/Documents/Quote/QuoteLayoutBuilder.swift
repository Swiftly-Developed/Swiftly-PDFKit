import Foundation
import CoreGraphics

// MARK: - QuoteLayoutBuilder (internal)

enum QuoteLayoutBuilder {

    // MARK: - Classic

    static func classicLayout(
        invoice: InvoiceDocument,
        supplement: QuoteSupplement,
        theme: InvoiceTheme,
        pageSize: PageSize
    ) -> PDF {
        let fmt = InvoiceFormatter(theme: theme)

        // ── Height accounting ──────────────────────────────────────────────
        let rowH:          CGFloat = theme.lineItemRowHeight
        let headerHeight:  CGFloat = theme.logoMaxHeight + 13 + 52
        let metaHeight:    CGFloat = 80
        let page1Overhead: CGFloat = headerHeight + 20 + metaHeight + 20
        let tableHeaderH:  CGFloat = rowH

        // Quote totals: 3 rows (subtotal excl, VAT, total incl) — no Amount Due rows.
        let totalsH:       CGFloat = 3 * theme.totalsRowHeight + 12
        let notesH:        CGFloat = invoice.header.notes != nil ? 20 + 14 : 0
        let acceptanceH:   CGFloat = supplement.acceptanceNote != nil ? 24 + 8 + 16 + 18 + 30 : 0
        let lastPageBottomH: CGFloat = totalsH + notesH + acceptanceH

        let footerH: CGFloat = invoice.footer.map { $0.height } ?? 0
        let margins          = theme.pageMargins
        let bodyH            = pageSize.height - margins * 2 - footerH

        let p1RowsMax   = max(1, Int(floor((bodyH - page1Overhead - tableHeaderH) / rowH)))
        let contRowsMax = max(1, Int(floor((bodyH - tableHeaderH) / rowH)))

        // ── Pass 1: split lines into chunks ───────────────────────────────
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

        // ── Pass 2: ensure bottom content fits on last page ───────────────
        if let last = chunks.last {
            let isFirst     = chunks.count == 1
            let overhead    = isFirst ? page1Overhead : 0
            let lastUsed    = overhead + tableHeaderH + CGFloat(last.count) * rowH
            if lastUsed + lastPageBottomH > bodyH {
                chunks.append([])
            }
        }

        // ── Page builder ───────────────────────────────────────────────────
        func makeFooter() -> Footer? {
            guard let f = invoice.footer else { return nil }
            return Footer(height: f.height) {
                HRule(thickness: 0.5, color: theme.ruleColor)
                Spacer(height: 4)
                for line in f.lines {
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
                    InvoiceLayoutBuilder.headerSection(invoice: invoice, theme: theme, fmt: fmt)
                    Spacer(height: 20)
                    quoteMetaSection(invoice: invoice, supplement: supplement, theme: theme, fmt: fmt)
                    Spacer(height: 20)
                }

                InvoiceLayoutBuilder.lineItemsTableForRows(
                    chunk, invoice: invoice, theme: theme, fmt: fmt, showHeader: true)

                if isLast {
                    Spacer(height: 12)
                    quoteTotalsTable(invoice: invoice, theme: theme, fmt: fmt)
                    if let notes = invoice.header.notes {
                        Spacer(height: 12)
                        Text(notes).font(theme.bodyFont, size: theme.bodyFontSize - 1)
                    }
                    for item in acceptanceBlock(note: supplement.acceptanceNote, theme: theme) {
                        item
                    }
                }

                if let f = makeFooter() { f }
            }
            pages.append(page)
        }

        // Edge case: no lines
        if pages.isEmpty {
            let page = Page(size: pageSize, margins: margins) {
                InvoiceLayoutBuilder.headerSection(invoice: invoice, theme: theme, fmt: fmt)
                Spacer(height: 20)
                quoteMetaSection(invoice: invoice, supplement: supplement, theme: theme, fmt: fmt)
                Spacer(height: 20)
                quoteTotalsTable(invoice: invoice, theme: theme, fmt: fmt)
                if let notes = invoice.header.notes {
                    Spacer(height: 12)
                    Text(notes).font(theme.bodyFont, size: theme.bodyFontSize - 1)
                }
                for item in acceptanceBlock(note: supplement.acceptanceNote, theme: theme) {
                    item
                }
                if let f = makeFooter() { f }
            }
            pages.append(page)
        }

        return PDF(pages: pages)
    }

    // MARK: - Minimal

    static func minimalLayout(
        invoice: InvoiceDocument,
        supplement: QuoteSupplement,
        theme: InvoiceTheme,
        pageSize: PageSize
    ) -> PDF {
        // Build a minimal-style theme override (no table borders, larger row height).
        let minimalTheme = InvoiceTheme(
            accentColor: theme.accentColor,
            tableHeaderBackground: theme.tableHeaderBackground,
            tableHeaderTextColor: theme.tableHeaderTextColor,
            tableAlternateRowColor: PDFColor.white,
            ruleColor: theme.ruleColor,
            paymentBannerColor: theme.paymentBannerColor,
            paymentBannerTextColor: theme.paymentBannerTextColor,
            tableBorderColor: PDFColor.white,
            bodyFont: theme.bodyFont,
            titleFont: theme.titleFont,
            bodyFontSize: 9,
            titleFontSize: theme.titleFontSize,
            tableHeaderFontSize: theme.tableHeaderFontSize,
            tableCellFontSize: 9,
            pageMargins: theme.pageMargins,
            logoPosition: theme.logoPosition,
            logoMaxWidth: theme.logoMaxWidth,
            logoMaxHeight: theme.logoMaxHeight,
            lineItemRowHeight: 22,
            totalsRowHeight: theme.totalsRowHeight
        )
        // Delegate to classic with the minimal theme overrides applied.
        return classicLayout(
            invoice: invoice, supplement: supplement, theme: minimalTheme, pageSize: pageSize)
    }

    // MARK: - Section helpers

    static func quoteMetaSection(
        invoice: InvoiceDocument,
        supplement: QuoteSupplement,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        let h = invoice.header
        return Columns(spacing: 20) {
            ColumnItem(width: .fixed(240)) {
                Columns(spacing: 0) {
                    ColumnItem(width: .fixed(100)) {
                        Text(fmt.label("Quote No."))
                            .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        if h.issueDate.isEmpty == false {
                            Text(fmt.label("Date"))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if supplement.expiryDate != nil {
                            Text(fmt.label("Valid Until"))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if h.serviceDate != nil {
                            Text(fmt.label("Delivery Date"))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if invoice.client.clientNumber != nil {
                            Text(fmt.label("Client No."))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if invoice.client.poNumber != nil {
                            Text(fmt.label("Your Ref."))
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
                        if let exp = supplement.expiryDate {
                            Text(": \(exp)")
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

    /// Quote totals: subtotal excl, VAT, total incl. No "Amount Due" row.
    static func quoteTotalsTable(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        let t = invoice.totals
        let currency = invoice.header.currency

        var rows: [[String]] = [
            ["Subtotal excl. VAT", "", fmt.amount(t.subtotalExcl)],
            ["VAT",                "", fmt.amount(t.totalVat)],
            ["Total incl. VAT (\(currency))", "", fmt.amount(t.totalIncl)],
        ]
        if let disc = t.globalDiscount, disc > 0 {
            rows.insert(["Discount", "", "-\(fmt.amount(disc))"], at: 1)
        }

        let style = TableStyle(
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
        return Table(data: rows, style: style, showHeader: false) {
            Column("", width: .flex,       alignment: .leading)
            Column("", width: .flex,       alignment: .leading)
            Column("", width: .fixed(100), alignment: .trailing)
        }
    }
}
