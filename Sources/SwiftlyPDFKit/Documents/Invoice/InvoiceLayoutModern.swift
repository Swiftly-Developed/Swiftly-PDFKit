import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Modern family

/// The contemporary family, derived from five reference samples that share one
/// generator grammar (Anthropic, Slack, WishKit, Apollo, Calendly).
///
/// Grammar, as measured off those references:
/// full-bleed accent bar · large flush-left title with the logo optically
/// opposite · bold-label / aligned-value metadata · two-column supplier ÷
/// Bill-to · one loud headline carrying the paid-or-due state · a hairline
/// line table with no fills or vertical rules · a right-half totals stack.
///
/// Blocks the references never had to solve — ship-to, the per-rate VAT
/// breakdown, and the SEPA bank block — are **kept** and drawn in the same
/// visual language (owner decision D1). The reference vendors are US companies
/// billing through a payment portal; an EU B2B invoice is not, and dropping
/// those blocks would make the mapper's enrichment dead data.
extension InvoiceLayoutBuilder {

    static func modernLayout(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        labels: InvoiceLabels,
        locale: Locale,
        pageSize: PageSize
    ) -> PDF {
        let fmt = InvoiceFormatter(
            theme: theme, locale: locale,
            currencyCode: invoice.header.currency, labels: labels)

        // Page-fit accounting only — no design authority. Estimated from the
        // real line heights the renderer uses (font size x 1.2), because a
        // pessimistic guess costs a needless page break: the first draft
        // over-reserved by ~70pt and pushed the totals onto page 2 of a
        // three-line invoice that was half empty.
        let rowH  = theme.lineItemRowHeight
        let lineH = theme.bodyFontSize * 1.2

        let mastheadH: CGFloat = max(theme.logoMaxHeight,
                                     InvoiceLayoutKit.modernTitleSize * 1.2) + 14
        let metaRows: CGFloat  = 2
            + (invoice.header.dueDate != nil ? 1 : 0)
            + (invoice.header.paymentReference != nil ? 1 : 0)
        let metaH: CGFloat     = metaRows * lineH + 16
        // Both party columns render side by side, so only the taller one counts.
        let clientRows: CGFloat = 6 + (invoice.shipTo != nil ? 5 : 0)
        let partiesH: CGFloat   = clientRows * lineH + 18
        let headlineH: CGFloat  = invoice.paymentState != nil
            ? InvoiceLayoutKit.modernHeadlineSize * 1.2 + 18 : 0
        let page1Overhead       = mastheadH + metaH + partiesH + headlineH

        let totalsRows: CGFloat = (invoice.totals.amountPaid ?? 0) > 0 ? 5 : 4
        let breakdownN          = invoice.taxBreakdown?.count ?? 0
        let historyN            = invoice.paymentHistory?.count ?? 0
        let bottomH: CGFloat =
            totalsRows * theme.totalsRowHeight + 14
            + (breakdownN > 0 ? CGFloat(breakdownN + 1) * theme.totalsRowHeight + 26 : 0)
            + (invoice.taxNote != nil ? 20 : 0)
            + (invoice.header.notes != nil ? 24 : 0)
            + (historyN > 0 ? CGFloat(historyN + 1) * theme.totalsRowHeight + 26 : 0)
            + (hasPaymentBlock(invoice) ? 104 : 0)
            // Slack. Every term above is a per-block approximation, and the
            // renderer clips nothing: when the estimate is a few points short
            // the closing blocks simply draw *through* the footer. The first
            // render of this family fitted with 0.4pt to spare and the QR code
            // overlapped the footer text. An extra page is a cheap mistake; an
            // overlap is not, so the accounting is deliberately biased to break
            // early rather than late.
            + 28

        let plan = InvoiceLayoutKit.paginate(
            invoice: invoice, theme: theme, pageSize: pageSize,
            page1Overhead: page1Overhead, bottomHeight: bottomH)
        _ = rowH

        var pages: [Page] = []
        for (idx, chunk) in plan.chunks.enumerated() {
            let isFirst = idx == 0
            let isLast  = idx == plan.chunks.count - 1

            pages.append(Page(size: pageSize, margins: plan.margins) {
                // Always drawn, tinted by the accent: four of the five samples
                // carry it, and Anthropic's only *reads* as absent because its
                // brand colour is a near-white bone.
                TopAccentBar(color: theme.accentColor, height: 6)

                if isFirst {
                    modernMasthead(invoice: invoice, theme: theme, fmt: fmt)
                    Spacer(height: 14)
                    modernMeta(invoice: invoice, theme: theme, fmt: fmt)
                    Spacer(height: 16)
                    modernParties(invoice: invoice, theme: theme, fmt: fmt)
                    Spacer(height: 18)
                    if let state = invoice.paymentState {
                        modernHeadline(state: state, invoice: invoice, theme: theme, fmt: fmt)
                        Spacer(height: 18)
                    }
                }

                if !chunk.isEmpty {
                    modernLineTable(chunk, theme: theme, fmt: fmt)
                }

                if isLast {
                    Spacer(height: 14)
                    modernTotals(invoice: invoice, theme: theme, fmt: fmt)

                    if let breakdown = invoice.taxBreakdown, !breakdown.isEmpty {
                        Spacer(height: 18)
                        modernTaxBreakdown(breakdown, theme: theme, fmt: fmt)
                    }
                    if let taxNote = invoice.taxNote {
                        Spacer(height: 10)
                        Text("[1] \(taxNote)")
                            .font(theme.bodyFont, size: theme.bodyFontSize - 2)
                            .color(InvoiceLayoutKit.mutedText)
                    }
                    if let notes = invoice.header.notes {
                        Spacer(height: 12)
                        Text(notes)
                            .font(theme.bodyFont, size: theme.bodyFontSize - 1)
                            .color(InvoiceLayoutKit.mutedText)
                    }
                    // Only when rows exist: Slack is a paid sample with no
                    // history table at all, so an unconditional table would
                    // contradict half the paid references (and §6's
                    // "where available").
                    if let history = invoice.paymentHistory, !history.isEmpty {
                        Spacer(height: 18)
                        modernPaymentHistory(history, theme: theme, fmt: fmt)
                    }
                    if hasPaymentBlock(invoice) {
                        Spacer(height: 18)
                        modernPaymentBlock(invoice: invoice, theme: theme, fmt: fmt)
                    }
                }

                InvoiceLayoutKit.footer(
                    invoice: invoice, theme: theme, fmt: fmt,
                    page: idx + 1, of: plan.pageCount, height: plan.footerHeight,
                    ruleColor: PDFColor(white: 0.82))
            })
        }
        return PDF(pages: pages)
    }

    // MARK: Sections

    /// Title flush left, logo optically opposite.
    static func modernMasthead(
        invoice: InvoiceDocument, theme: InvoiceTheme, fmt: InvoiceFormatter
    ) -> some PDFContent {
        Columns(spacing: 20) {
            ColumnItem(width: .flex) {
                Text(InvoiceLayoutKit.title(for: invoice, fmt: fmt))
                    .font(theme.bodyFont, size: InvoiceLayoutKit.modernTitleSize)
                    .bold()
            }
            ColumnItem(width: .fixed(150)) {
                logoOrFallback(supplier: invoice.supplier, theme: theme, alignment: .trailing)
            }
        }
    }

    /// Bold labels in a narrow left column, values aligned in a second.
    static func modernMeta(
        invoice: InvoiceDocument, theme: InvoiceTheme, fmt: InvoiceFormatter
    ) -> some PDFContent {
        let h = invoice.header
        let isPaid: Bool = { if case .paid = invoice.paymentState { return true }; return false }()
        return Columns(spacing: 8) {
            ColumnItem(width: .fixed(120)) {
                Text(fmt.labels.invoiceNumberLabel)
                    .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                Text(fmt.labels.issueDateLabel)
                    .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                if h.dueDate != nil && !isPaid {
                    Text(fmt.labels.dueDateLabel)
                        .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                }
                if h.paymentReference != nil {
                    Text(fmt.labels.paymentReferenceLabel)
                        .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                }
            }
            ColumnItem(width: .flex) {
                Text(h.invoiceNumber).font(theme.bodyFont, size: theme.bodyFontSize)
                Text(h.issueDate).font(theme.bodyFont, size: theme.bodyFontSize)
                if let due = h.dueDate, !isPaid {
                    Text(due).font(theme.bodyFont, size: theme.bodyFontSize)
                }
                if let ref = h.paymentReference {
                    Text(ref).font(theme.bodyFont, size: theme.bodyFontSize)
                }
            }
        }
    }

    /// Supplier left, Bill-to right; Ship-to under Bill-to only when it differs
    /// (the mapper suppresses it when equal, so its presence *is* the signal).
    static func modernParties(
        invoice: InvoiceDocument, theme: InvoiceTheme, fmt: InvoiceFormatter
    ) -> some PDFContent {
        Columns(spacing: 24) {
            ColumnItem(width: .flex) {
                supplierBlock(supplier: invoice.supplier, theme: theme, fmt: fmt)
            }
            ColumnItem(width: .flex) {
                supersetClientBlock(client: invoice.client, theme: theme, fmt: fmt)
                if let shipTo = invoice.shipTo {
                    Spacer(height: 10)
                    supersetShipToBlock(party: shipTo, theme: theme, fmt: fmt)
                }
            }
        }
    }

    /// The loudest element after the title.
    static func modernHeadline(
        state: InvoicePaymentState, invoice: InvoiceDocument,
        theme: InvoiceTheme, fmt: InvoiceFormatter
    ) -> some PDFContent {
        let headline: String
        switch state {
        case .paid(let date):
            headline = fmt.labels.paidHeadline(date: fmt.date(date))
        case .due(let date):
            headline = fmt.labels.dueHeadline(
                amount: fmt.money(invoice.totals.amountDue), date: fmt.date(date))
        }
        return Text(headline)
            .font(theme.bodyFont, size: InvoiceLayoutKit.modernHeadlineSize)
            .bold()
    }

    /// Hairline above and below the header row; no fills, no vertical rules.
    static func modernLineTable(
        _ lines: [InvoiceLine], theme: InvoiceTheme, fmt: InvoiceFormatter
    ) -> some PDFContent {
        let anyTax = lines.contains { $0.vatRate > 0 } || lines.contains { $0.vatRate == 0 }
        // Table cells are single-line: a "\n" renders literally. The
        // references put the service period on its own muted line under the
        // description, so it becomes its own row with empty numeric cells.
        var rows: [[String]] = []
        for line in lines {
            rows.append([
                line.description,
                fmt.quantity(line.quantity),
                fmt.money(line.unitPrice),
                anyTax ? fmt.percent(line.vatRate) : "",
                fmt.money(line.subtotalExcl),
            ])
            if let detail = line.detail {
                rows.append([detail, "", "", "", ""])
            }
        }
        return Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                HRule(thickness: 0.8, color: PDFColor(white: 0.15))
                Table(data: rows,
                      style: InvoiceLayoutKit.hairlineTableStyle(theme: theme),
                      showHeader: true) {
                    Column(fmt.labels.columnDescription, width: .flex, alignment: .leading)
                    Column(fmt.labels.columnQuantity, width: .fixed(45),
                           alignment: .trailing, headerAlignment: .trailing)
                    Column(fmt.labels.columnUnitPrice, width: .fixed(75),
                           alignment: .trailing, headerAlignment: .trailing)
                    Column(anyTax ? fmt.labels.columnTax : "", width: .fixed(50),
                           alignment: .trailing, headerAlignment: .trailing)
                    Column(fmt.labels.columnAmount, width: .fixed(80),
                           alignment: .trailing, headerAlignment: .trailing)
                }
                HRule(thickness: 0.5, color: PDFColor(white: 0.8))
            }
        }
    }

    /// Right-half stack, hairline between rows, bold final row.
    static func modernTotals(
        invoice: InvoiceDocument, theme: InvoiceTheme, fmt: InvoiceFormatter
    ) -> some PDFContent {
        let t = invoice.totals
        var rows: [[String]] = [[fmt.labels.subtotalLabel, fmt.money(t.subtotalExcl)]]
        if let disc = t.globalDiscount, disc > 0 {
            rows.append([fmt.labels.columnDiscount, "-\(fmt.money(disc))"])
        }
        if t.totalVat > 0 {
            rows.append([fmt.labels.vatLabel, fmt.money(t.totalVat)])
        }
        rows.append([fmt.labels.totalLabel, fmt.money(t.totalIncl)])
        if let paid = t.amountPaid, paid > 0 {
            rows.append([fmt.labels.amountPaidLabel, fmt.money(paid)])
        }
        let closing: String = InvoiceLayoutKit.isOutstanding(invoice)
            ? fmt.labels.amountDueLabel : fmt.labels.amountPaidLabel
        let closingValue: String = InvoiceLayoutKit.isOutstanding(invoice)
            ? fmt.money(t.amountDue) : fmt.money(t.amountPaid ?? t.totalIncl)
        rows.append([closing, closingValue])

        return Columns(spacing: 0) {
            ColumnItem(width: .flex) { Spacer(height: 1) }
            ColumnItem(width: .fixed(280)) {
                Table(data: rows,
                      style: InvoiceLayoutKit.hairlineTableStyle(
                        theme: theme, rowHeight: theme.totalsRowHeight),
                      showHeader: false) {
                    Column("", width: .flex, alignment: .leading)
                    Column("", width: .fixed(110), alignment: .trailing)
                }
            }
        }
    }

    /// Kept though no reference has one (D1) — rendered in the same hairline
    /// grammar so it reads as part of the family.
    static func modernTaxBreakdown(
        _ breakdown: [InvoiceTaxSubtotal], theme: InvoiceTheme, fmt: InvoiceFormatter
    ) -> some PDFContent {
        let rows = breakdown.map { r in
            [fmt.percent(r.ratePercent), fmt.money(r.taxableBase),
             fmt.money(r.taxAmount), r.exemptionReason ?? ""]
        }
        return Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                Text(fmt.labels.taxBreakdownHeader)
                    .font(theme.bodyFont, size: theme.bodyFontSize).bold()
                Spacer(height: 6)
                HRule(thickness: 0.8, color: PDFColor(white: 0.15))
                Table(data: rows,
                      style: InvoiceLayoutKit.hairlineTableStyle(
                        theme: theme, rowHeight: theme.totalsRowHeight),
                      showHeader: true) {
                    Column(fmt.labels.columnTaxRate, width: .fixed(70), alignment: .trailing,
                           headerAlignment: .trailing)
                    Column(fmt.labels.columnTaxableBase, width: .fixed(100), alignment: .trailing,
                           headerAlignment: .trailing)
                    Column(fmt.labels.vatLabel, width: .fixed(90), alignment: .trailing,
                           headerAlignment: .trailing)
                    Column(fmt.labels.columnExemptionReason, width: .flex, alignment: .leading)
                }
                HRule(thickness: 0.5, color: PDFColor(white: 0.8))
            }
        }
    }

    static func modernPaymentHistory(
        _ history: [InvoicePaymentRow], theme: InvoiceTheme, fmt: InvoiceFormatter
    ) -> some PDFContent {
        let rows = history.map { r in
            [r.method, fmt.date(r.date), fmt.money(r.amount), r.receiptNumber ?? ""]
        }
        return Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                Text(fmt.labels.paymentHistoryHeader)
                    .font(theme.bodyFont, size: InvoiceLayoutKit.modernSectionSize).bold()
                Spacer(height: 8)
                HRule(thickness: 0.8, color: PDFColor(white: 0.15))
                Table(data: rows,
                      style: InvoiceLayoutKit.hairlineTableStyle(
                        theme: theme, rowHeight: theme.totalsRowHeight),
                      showHeader: true) {
                    Column(fmt.labels.columnPaymentMethod, width: .flex, alignment: .leading)
                    Column(fmt.labels.columnPaymentDate, width: .fixed(110), alignment: .trailing,
                           headerAlignment: .trailing)
                    Column(fmt.labels.amountPaidLabel, width: .fixed(100), alignment: .trailing,
                           headerAlignment: .trailing)
                    Column(fmt.labels.columnReceiptNumber, width: .fixed(110), alignment: .trailing,
                           headerAlignment: .trailing)
                }
                HRule(thickness: 0.5, color: PDFColor(white: 0.8))
            }
        }
    }

    /// IBAN / BIC / structured reference, with the EPC QR when one was mapped.
    static func modernPaymentBlock(
        invoice: InvoiceDocument, theme: InvoiceTheme, fmt: InvoiceFormatter
    ) -> some PDFContent {
        let s = invoice.supplier
        return Columns(spacing: 16) {
            ColumnItem(width: .flex) {
                HRule(thickness: 0.5, color: PDFColor(white: 0.8))
                Spacer(height: 8)
                if let iban = s.iban {
                    Text("\(fmt.labels.ibanLabel)  \(iban)")
                        .font(theme.bodyFont, size: theme.bodyFontSize)
                }
                if let bic = s.bic {
                    Text("\(fmt.labels.bicLabel)  \(bic)")
                        .font(theme.bodyFont, size: theme.bodyFontSize)
                }
                if let ref = invoice.header.paymentReference {
                    Text("\(fmt.labels.paymentReferenceLabel)  \(ref)")
                        .font(theme.bodyFont, size: theme.bodyFontSize)
                }
            }
            ColumnItem(width: .fixed(76)) {
                if let payload = invoice.header.qrPayload {
                    QRCodeContent(payload, size: 68)
                }
            }
        }
    }

    /// A payment block is worth drawing only when the document is unpaid and
    /// there is something payable to show.
    static func hasPaymentBlock(_ invoice: InvoiceDocument) -> Bool {
        guard InvoiceLayoutKit.isOutstanding(invoice) else { return false }
        return invoice.supplier.iban != nil
            || invoice.header.paymentReference != nil
            || invoice.header.qrPayload != nil
    }
}
