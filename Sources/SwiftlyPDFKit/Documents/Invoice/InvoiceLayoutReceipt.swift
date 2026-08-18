import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Receipt family

/// The compact family, derived from the GitHub reference.
///
/// Grammar, as measured: a **centred masthead** (logo, title, short divider)
/// over a **full-width, left-aligned label/value row list** — the body is *not*
/// a narrow centred stack; every body rule spans ~80% of page width, margin to
/// margin. Line items fold into the same row list rather than a separate grid.
/// A large faint acknowledgement sits below the content.
///
/// This family **prunes**: no two-column party blocks, no ship-to, no per-rate
/// tax breakdown. Pruning is the point of choosing it.
///
/// ## The unpaid case
///
/// The GitHub reference is a *paid* receipt and gives no authority whatever for
/// an unpaid one — but `document_layout_preference` is company-wide, so a
/// tenant on Receipt gets this family for **every** document. Pruning the
/// payment block unconditionally would emit an invoice with no IBAN, no
/// payment reference and no QR: unpayable, and arguably legally deficient.
/// So the payment block is pruned **only in the paid state** (owner decision
/// D2); the due state keeps due date, IBAN/BIC, reference and QR.
extension InvoiceLayoutBuilder {

    static func receiptLayout(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        labels: InvoiceLabels,
        locale: Locale,
        pageSize: PageSize
    ) -> PDF {
        let fmt = InvoiceFormatter(
            theme: theme, locale: locale,
            currencyCode: invoice.header.currency, labels: labels)

        let lineH = theme.bodyFontSize * 1.2
        let mastheadH: CGFloat = theme.logoMaxHeight
            + InvoiceLayoutKit.receiptTitleSize * 1.2 + 40
        let identityRows: CGFloat = 4
            + (invoice.client.vatNumber != nil ? 1 : 0)
            + (invoice.header.paymentReference != nil ? 1 : 0)
        let identityH: CGFloat = identityRows * (theme.totalsRowHeight + 2) + 20
        let page1Overhead = mastheadH + identityH

        let totalsRows: CGFloat = 3 + ((invoice.totals.amountPaid ?? 0) > 0 ? 1 : 0)
        let historyN = invoice.paymentHistory?.count ?? 0
        let bottomH: CGFloat =
            totalsRows * theme.totalsRowHeight + 20
            + (historyN > 0 ? CGFloat(historyN + 1) * theme.totalsRowHeight + 26 : 0)
            + (hasPaymentBlock(invoice) ? 104 : 0)
            + (invoice.taxNote != nil ? lineH + 10 : 0)
            + 60      // the acknowledgement + footer slack
            + 28

        let plan = InvoiceLayoutKit.paginate(
            invoice: invoice, theme: theme, pageSize: pageSize,
            page1Overhead: page1Overhead, bottomHeight: bottomH)

        var pages: [Page] = []
        for (idx, chunk) in plan.chunks.enumerated() {
            let isFirst = idx == 0
            let isLast  = idx == plan.chunks.count - 1

            pages.append(Page(size: pageSize, margins: plan.margins) {
                if isFirst {
                    receiptMasthead(invoice: invoice, theme: theme, fmt: fmt)
                    Spacer(height: 22)
                    receiptIdentityRows(invoice: invoice, theme: theme, fmt: fmt)
                    Spacer(height: 6)
                }

                if !chunk.isEmpty {
                    receiptLineRows(chunk, theme: theme, fmt: fmt)
                }

                if isLast {
                    receiptTotalRows(invoice: invoice, theme: theme, fmt: fmt)

                    if let taxNote = invoice.taxNote {
                        Spacer(height: 10)
                        Text("* \(taxNote)")
                            .font(theme.bodyFont, size: theme.bodyFontSize - 2)
                            .color(InvoiceLayoutKit.mutedText)
                    }
                    if let history = invoice.paymentHistory, !history.isEmpty {
                        Spacer(height: 18)
                        modernPaymentHistory(history, theme: theme, fmt: fmt)
                    }
                    // Kept when unpaid (D2) — an unpayable receipt is worse
                    // than a less pure one.
                    if hasPaymentBlock(invoice) {
                        Spacer(height: 18)
                        modernPaymentBlock(invoice: invoice, theme: theme, fmt: fmt)
                    }
                    if !InvoiceLayoutKit.isOutstanding(invoice) {
                        Spacer(height: 26)
                        Text(fmt.labels.thankYouNote)
                            .font(theme.bodyFont, size: InvoiceLayoutKit.receiptThanksSize)
                            .bold()
                            .color(PDFColor(white: 0.90))
                    }
                }

                InvoiceLayoutKit.footer(
                    invoice: invoice, theme: theme, fmt: fmt,
                    page: idx + 1, of: plan.pageCount, height: plan.footerHeight,
                    ruleColor: PDFColor(white: 0.82),
                    alignment: .center)
            })
        }
        return PDF(pages: pages)
    }

    // MARK: Sections

    /// Centred logo, centred title, short centred divider — the only centred
    /// part of the document.
    static func receiptMasthead(
        invoice: InvoiceDocument, theme: InvoiceTheme, fmt: InvoiceFormatter
    ) -> some PDFContent {
        Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                logoOrFallback(supplier: invoice.supplier, theme: theme, alignment: .center)
                Spacer(height: 10)
                Text(InvoiceLayoutKit.title(for: invoice, fmt: fmt))
                    .font(theme.bodyFont, size: InvoiceLayoutKit.receiptTitleSize)
                    .bold()
                    .alignment(.center)
                Spacer(height: 10)
            }
        }
    }

    /// The label/value row list: identity, dates, references. Full width,
    /// left-aligned, hairline-separated — the customer identity is folded in
    /// here rather than into a party column.
    static func receiptIdentityRows(
        invoice: InvoiceDocument, theme: InvoiceTheme, fmt: InvoiceFormatter
    ) -> some PDFContent {
        let h = invoice.header
        let c = invoice.client
        var rows: [[String]] = [
            [fmt.labels.invoiceNumberLabel, h.invoiceNumber],
            [fmt.labels.issueDateLabel, h.issueDate],
        ]
        if InvoiceLayoutKit.isOutstanding(invoice), let due = h.dueDate {
            rows.append([fmt.labels.dueDateLabel, due])
        }
        rows.append([fmt.labels.billToHeader, c.name])
        if let vat = c.vatNumber { rows.append([fmt.labels.vatNumberLabel, vat]) }
        if let ref = h.paymentReference { rows.append([fmt.labels.paymentReferenceLabel, ref]) }

        return Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                HRule(thickness: 0.5, color: PDFColor(white: 0.85))
                Table(data: rows,
                      style: InvoiceLayoutKit.hairlineTableStyle(
                        theme: theme, rowHeight: theme.totalsRowHeight + 2, cellBold: false),
                      showHeader: false) {
                    Column("", width: .fixed(200), alignment: .leading)
                    Column("", width: .flex, alignment: .leading)
                }
                HRule(thickness: 0.5, color: PDFColor(white: 0.85))
            }
        }
    }

    /// Line items folded into the same row list: description (+ period) left,
    /// amount right.
    static func receiptLineRows(
        _ lines: [InvoiceLine], theme: InvoiceTheme, fmt: InvoiceFormatter
    ) -> some PDFContent {
        var rows: [[String]] = []
        for line in lines {
            rows.append([line.description, fmt.money(line.subtotalExcl)])
            if let detail = line.detail { rows.append([detail, ""]) }
        }
        return Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                Table(data: rows,
                      style: InvoiceLayoutKit.hairlineTableStyle(
                        theme: theme, rowHeight: theme.totalsRowHeight + 2),
                      showHeader: true) {
                    Column(fmt.labels.columnDescription, width: .flex, alignment: .leading)
                    Column(fmt.labels.columnAmount, width: .fixed(130),
                           alignment: .trailing, headerAlignment: .trailing)
                }
                HRule(thickness: 0.5, color: PDFColor(white: 0.85))
            }
        }
    }

    static func receiptTotalRows(
        invoice: InvoiceDocument, theme: InvoiceTheme, fmt: InvoiceFormatter
    ) -> some PDFContent {
        let t = invoice.totals
        var rows: [[String]] = [[fmt.labels.subtotalLabel, fmt.money(t.subtotalExcl)]]
        if t.totalVat > 0 { rows.append([fmt.labels.vatLabel, fmt.money(t.totalVat)]) }
        rows.append([fmt.labels.totalLabel, fmt.money(t.totalIncl)])
        rows.append([
            InvoiceLayoutKit.isOutstanding(invoice)
                ? fmt.labels.amountDueLabel : fmt.labels.amountPaidLabel,
            InvoiceLayoutKit.isOutstanding(invoice)
                ? fmt.money(t.amountDue) : fmt.money(t.amountPaid ?? t.totalIncl),
        ])
        return Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                Table(data: rows,
                      style: InvoiceLayoutKit.hairlineTableStyle(
                        theme: theme, rowHeight: theme.totalsRowHeight + 2, cellBold: true),
                      showHeader: false) {
                    Column("", width: .flex, alignment: .leading)
                    Column("", width: .fixed(130), alignment: .trailing)
                }
                HRule(thickness: 0.5, color: PDFColor(white: 0.85))
            }
        }
    }
}
