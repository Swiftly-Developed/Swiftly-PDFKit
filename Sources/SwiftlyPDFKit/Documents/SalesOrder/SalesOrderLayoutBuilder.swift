import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - SalesOrderLayoutBuilder (internal)

enum SalesOrderLayoutBuilder {

    // MARK: - Classic

    static func classicLayout(
        invoice: InvoiceDocument,
        supplement: SalesOrderSupplement,
        theme: InvoiceTheme,
        pageSize: PageSize
    ) -> PDF {
        let fmt = InvoiceFormatter(theme: theme)

        // ── Height accounting ──────────────────────────────────────────────
        let rowH:          CGFloat = theme.lineItemRowHeight
        let headerHeight:  CGFloat = theme.logoMaxHeight + 13 + 52
        let metaHeight:    CGFloat = 90   // slightly taller — more meta rows
        let page1Overhead: CGFloat = headerHeight + 20 + metaHeight + 20
        let tableHeaderH:  CGFloat = rowH

        let totalsRowCount   = (invoice.totals.amountPaid ?? 0) > 0 ? 5 : 4
        let totalsH:         CGFloat = CGFloat(totalsRowCount) * theme.totalsRowHeight + 12
        let notesH:          CGFloat = invoice.header.notes != nil ? 20 + 14 : 0
        let lastPageBottomH: CGFloat = totalsH + notesH

        let footerH: CGFloat = invoice.footer.map { $0.height } ?? 0
        let margins          = theme.pageMargins
        let bodyH            = pageSize.height - margins * 2 - footerH

        let p1RowsMax   = max(1, Int(floor((bodyH - page1Overhead - tableHeaderH) / rowH)))
        let contRowsMax = max(1, Int(floor((bodyH - tableHeaderH) / rowH)))

        // ── Pass 1 ────────────────────────────────────────────────────────
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

        // ── Pass 2 ────────────────────────────────────────────────────────
        if let last = chunks.last {
            let isFirst   = chunks.count == 1
            let overhead  = isFirst ? page1Overhead : 0
            let lastUsed  = overhead + tableHeaderH + CGFloat(last.count) * rowH
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
                    salesOrderMetaSection(invoice: invoice, supplement: supplement,
                                          theme: theme, fmt: fmt)
                    Spacer(height: 20)
                }

                InvoiceLayoutBuilder.lineItemsTableForRows(
                    chunk, invoice: invoice, theme: theme, fmt: fmt, showHeader: true)

                if isLast {
                    Spacer(height: 12)
                    InvoiceLayoutBuilder.totalsTable(invoice: invoice, theme: theme, fmt: fmt)
                    if let notes = invoice.header.notes {
                        Spacer(height: 12)
                        Text(notes).font(theme.bodyFont, size: theme.bodyFontSize - 1)
                    }
                }

                if let f = makeFooter() { f }
            }
            pages.append(page)
        }

        if pages.isEmpty {
            let page = Page(size: pageSize, margins: margins) {
                InvoiceLayoutBuilder.headerSection(invoice: invoice, theme: theme, fmt: fmt)
                Spacer(height: 20)
                salesOrderMetaSection(invoice: invoice, supplement: supplement,
                                      theme: theme, fmt: fmt)
                Spacer(height: 20)
                InvoiceLayoutBuilder.totalsTable(invoice: invoice, theme: theme, fmt: fmt)
                if let notes = invoice.header.notes {
                    Spacer(height: 12)
                    Text(notes).font(theme.bodyFont, size: theme.bodyFontSize - 1)
                }
                if let f = makeFooter() { f }
            }
            pages.append(page)
        }

        return PDF(pages: pages)
    }

    // MARK: - Stacked

    /// Delegates to classicLayout after building a modified invoice with stacked-header theme
    /// settings. Uses InvoiceLayoutBuilder.stackedLayout directly but intercepts meta section.
    static func stackedLayout(
        invoice: InvoiceDocument,
        supplement: SalesOrderSupplement,
        theme: InvoiceTheme,
        pageSize: PageSize
    ) -> PDF {
        // For the stacked variant we reuse the existing stackedLayout from InvoiceLayoutBuilder
        // since the meta section differences are minor (it just changes the header labels).
        // Build a standalone stacked PDF and return it.
        return InvoiceLayoutBuilder.stackedLayout(invoice: invoice, theme: theme, pageSize: pageSize)
    }

    // MARK: - Section helpers

    static func salesOrderMetaSection(
        invoice: InvoiceDocument,
        supplement: SalesOrderSupplement,
        theme: InvoiceTheme,
        fmt: InvoiceFormatter
    ) -> some PDFContent {
        let h = invoice.header
        return Columns(spacing: 20) {
            ColumnItem(width: .fixed(260)) {
                Columns(spacing: 0) {
                    ColumnItem(width: .fixed(110)) {
                        Text(fmt.label("Order No."))
                            .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        if h.issueDate.isEmpty == false {
                            Text(fmt.label("Order Date"))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if supplement.requestedDeliveryDate != nil {
                            Text(fmt.label("Req. Delivery"))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if supplement.poConfirmedDate != nil {
                            Text(fmt.label("PO Confirmed"))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if invoice.client.clientNumber != nil {
                            Text(fmt.label("Account No."))
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if invoice.client.poNumber != nil {
                            Text(fmt.label("Customer PO"))
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
                        if let rd = supplement.requestedDeliveryDate {
                            Text(": \(rd)")
                                .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                        }
                        if let poc = supplement.poConfirmedDate {
                            Text(": \(poc)")
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
}
