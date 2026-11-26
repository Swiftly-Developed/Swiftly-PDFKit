import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Classic family

/// The traditional, compliance-dense family, derived from the CloudTalk
/// reference — the one reference authored for an EU B2B audience rather than a
/// US self-serve one.
///
/// Grammar, as measured: `Invoice <number>` on one line with the logo opposite ·
/// `SUPPLIER` / `CLIENT` small-caps headers over rules, each with an identity
/// grid (company ID, VAT) · a three-cell date strip · a wide multi-column line
/// table carrying unit, tax-exclusive and tax-inclusive prices · a bottom-left
/// `NOTE` block where the reverse-charge sentence lives · a bottom-right totals
/// stack whose closing rows are emphasised · a heavy footer rule.
///
/// No top accent bar: the reference has none, and the family's formality is the
/// point of choosing it.
extension InvoiceLayoutBuilder {

    static func classicLayout(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        labels: InvoiceLabels,
        locale: Locale,
        pageSize: PageSize
    ) -> PDF {
        let fmt = DocumentFormatter(
            theme: theme, locale: locale,
            currencyCode: invoice.header.currency, labels: labels)

        let lineH = theme.bodyFontSize * 1.2
        let mastheadH: CGFloat = max(theme.logoMaxHeight,
                                     DocumentLayoutKit.classicTitleSize * 1.2) + 16
        // The two party columns render side by side, so only the taller counts.
        let partyRows: CGFloat = 9 + (invoice.shipTo != nil ? 6 : 0)
        let partiesH: CGFloat  = partyRows * lineH + 20
        let dateStripH: CGFloat = 2 * lineH + 22
        let page1Overhead = mastheadH + partiesH + dateStripH

        let totalsRows: CGFloat = ((invoice.totals.amountPaid ?? 0) > 0 ? 6 : 4)
            - (invoice.hidesSettlement ? 1 : 0)
        let breakdownN = invoice.taxBreakdown?.count ?? 0
        let historyN   = invoice.paymentHistory?.count ?? 0
        let bottomH: CGFloat =
            totalsRows * theme.totalsRowHeight + 20
            + (breakdownN > 0 ? CGFloat(breakdownN + 1) * theme.totalsRowHeight + 26 : 0)
            + (historyN > 0 ? CGFloat(historyN + 1) * theme.totalsRowHeight + 26 : 0)
            + (hasPaymentBlock(invoice) ? 104 : 0)
            + 28

        let plan = DocumentLayoutKit.paginate(
            invoice: invoice, theme: theme, pageSize: pageSize,
            page1Overhead: page1Overhead, bottomHeight: bottomH)

        var pages: [Page] = []
        for (idx, chunk) in plan.chunks.enumerated() {
            let isFirst = idx == 0
            let isLast  = idx == plan.chunks.count - 1

            pages.append(Page(size: pageSize, margins: plan.margins) {
                if isFirst {
                    classicMasthead(invoice: invoice, theme: theme, fmt: fmt)
                    Spacer(height: 16)
                    classicParties(invoice: invoice, theme: theme, fmt: fmt)
                    Spacer(height: 16)
                    classicDateStrip(invoice: invoice, theme: theme, fmt: fmt)
                    Spacer(height: 22)
                }

                if !chunk.isEmpty {
                    classicLineTable(chunk, theme: theme, fmt: fmt)
                }

                if isLast {
                    Spacer(height: 16)
                    classicNoteAndTotals(invoice: invoice, theme: theme, fmt: fmt)

                    if let breakdown = invoice.taxBreakdown, !breakdown.isEmpty {
                        Spacer(height: 18)
                        modernTaxBreakdown(breakdown, theme: theme, fmt: fmt)
                    }
                    if let history = invoice.paymentHistory, !history.isEmpty {
                        Spacer(height: 18)
                        modernPaymentHistory(history, theme: theme, fmt: fmt)
                    }
                    if hasPaymentBlock(invoice) {
                        Spacer(height: 18)
                        modernPaymentBlock(invoice: invoice, theme: theme, fmt: fmt)
                    }
                }

                DocumentLayoutKit.footer(
                    invoice: invoice, theme: theme, fmt: fmt,
                    page: idx + 1, of: plan.pageCount, height: plan.footerHeight,
                    ruleThickness: 2.0)
            })
        }
        return PDF(pages: pages)
    }

    // MARK: Sections

    static func classicMasthead(
        invoice: InvoiceDocument, theme: InvoiceTheme, fmt: DocumentFormatter
    ) -> some PDFContent {
        Columns(spacing: 20) {
            ColumnItem(width: .flex) {
                Text("\(InvoiceLayoutKit.title(for: invoice, fmt: fmt))  \(invoice.header.invoiceNumber)")
                    .font(theme.bodyFont, size: DocumentLayoutKit.classicTitleSize)
                    .bold()
            }
            ColumnItem(width: .fixed(150)) {
                logoOrFallback(supplier: invoice.supplier, theme: theme, alignment: .trailing)
            }
        }
    }

    /// Small-caps header over a rule, name, address, then the identity grid.
    static func classicParties(
        invoice: InvoiceDocument, theme: InvoiceTheme, fmt: DocumentFormatter
    ) -> some PDFContent {
        let s = invoice.supplier
        let c = invoice.client
        return Columns(spacing: 28) {
            ColumnItem(width: .flex) {
                classicPartyHeader(fmt.labels.supplierHeader, theme: theme)
                Text(s.name).font(theme.bodyFont, size: theme.bodyFontSize).bold()
                if let street = s.street { Text(street).font(theme.bodyFont, size: theme.bodyFontSize) }
                if let city = s.city { Text(city).font(theme.bodyFont, size: theme.bodyFontSize) }
                if let country = s.country { Text(country).font(theme.bodyFont, size: theme.bodyFontSize) }
                Spacer(height: 6)
                classicIdentityRow(fmt.labels.registrationIdLabel, s.registrationNumber, theme: theme)
                classicIdentityRow(fmt.labels.vatNumberLabel, s.vatNumber, theme: theme)
            }
            ColumnItem(width: .flex) {
                classicPartyHeader(fmt.labels.clientHeader, theme: theme)
                Text(c.name).font(theme.bodyFont, size: theme.bodyFontSize).bold()
                if let attn = c.attention {
                    Text("\(fmt.labels.attentionLabel): \(attn)")
                        .font(theme.bodyFont, size: theme.bodyFontSize)
                }
                if let street = c.street { Text(street).font(theme.bodyFont, size: theme.bodyFontSize) }
                if let city = c.city { Text(city).font(theme.bodyFont, size: theme.bodyFontSize) }
                if let country = c.country { Text(country).font(theme.bodyFont, size: theme.bodyFontSize) }
                Spacer(height: 6)
                classicIdentityRow(fmt.labels.clientNumberLabel, c.clientNumber, theme: theme)
                classicIdentityRow(fmt.labels.vatNumberLabel, c.vatNumber, theme: theme)
                classicIdentityRow(fmt.labels.registrationIdLabel, c.registrationNumber, theme: theme)
                // Kept per D1 though the CloudTalk reference has no case for
                // it — drawn in this family's own small-caps grammar rather
                // than importing Modern's. The mapper suppresses ship-to when
                // it equals bill-to, so its presence is already the signal.
                if let shipTo = invoice.shipTo {
                    Spacer(height: 10)
                    classicPartyHeader(fmt.labels.shipToHeader, theme: theme)
                    Text(shipTo.name).font(theme.bodyFont, size: theme.bodyFontSize).bold()
                    if let street = shipTo.street {
                        Text(street).font(theme.bodyFont, size: theme.bodyFontSize)
                    }
                    if let city = shipTo.city {
                        Text(city).font(theme.bodyFont, size: theme.bodyFontSize)
                    }
                    if let country = shipTo.country {
                        Text(country).font(theme.bodyFont, size: theme.bodyFontSize)
                    }
                }
            }
        }
    }

    static func classicPartyHeader(_ text: String, theme: InvoiceTheme) -> some PDFContent {
        Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                Text(text.uppercased())
                    .font(theme.bodyFont, size: theme.bodyFontSize - 1)
                    .bold()
                    .color(DocumentLayoutKit.mutedText)
                Spacer(height: 3)
                HRule(thickness: 0.8, color: PDFColor(white: 0.2))
                Spacer(height: 6)
            }
        }
    }

    static func classicIdentityRow(
        _ label: String, _ value: String?, theme: InvoiceTheme
    ) -> some PDFContent {
        Columns(spacing: 6) {
            ColumnItem(width: .fixed(90)) {
                if value != nil {
                    Text(label)
                        .font(theme.bodyFont, size: theme.bodyFontSize - 1)
                        .color(DocumentLayoutKit.mutedText)
                }
            }
            ColumnItem(width: .flex) {
                if let value {
                    Text(value).font(theme.bodyFont, size: theme.bodyFontSize - 1)
                }
            }
        }
    }

    /// Right-column-only band — measured at ~43% of page width on the
    /// reference, sitting under the CLIENT column, not spanning both parties.
    static func classicDateStrip(
        invoice: InvoiceDocument, theme: InvoiceTheme, fmt: DocumentFormatter
    ) -> some PDFContent {
        let h = invoice.header
        return Columns(spacing: 0) {
            ColumnItem(width: .flex) { Spacer(height: 1) }
            ColumnItem(width: .fixed(330)) {
                HRule(thickness: 0.8, color: PDFColor(white: 0.2))
                Spacer(height: 4)
                Columns(spacing: 10) {
                    ColumnItem(width: .flex) {
                        Text(fmt.labels.issueDateLabel.uppercased())
                            .font(theme.bodyFont, size: theme.bodyFontSize - 2)
                            .color(DocumentLayoutKit.mutedText)
                        Spacer(height: 3)
                        Text(h.issueDate).font(theme.bodyFont, size: theme.bodyFontSize)
                    }
                    ColumnItem(width: .flex) {
                        Text(fmt.labels.serviceDateLabel.uppercased())
                            .font(theme.bodyFont, size: theme.bodyFontSize - 2)
                            .color(DocumentLayoutKit.mutedText)
                        Spacer(height: 3)
                        Text(h.serviceDate ?? "—").font(theme.bodyFont, size: theme.bodyFontSize)
                    }
                    if !invoice.hidesSettlement {
                        ColumnItem(width: .flex) {
                            Text(fmt.labels.dueDateLabel.uppercased())
                                .font(theme.bodyFont, size: theme.bodyFontSize - 2)
                                .color(DocumentLayoutKit.mutedText)
                            Spacer(height: 3)
                            Text(h.dueDate ?? "—").font(theme.bodyFont, size: theme.bodyFontSize)
                        }
                    }
                }
                Spacer(height: 4)
                HRule(thickness: 0.5, color: PDFColor(white: 0.75))
            }
        }
    }

    /// The wide grid: unit, tax-exclusive and tax-inclusive prices.
    static func classicLineTable(
        _ lines: [InvoiceLine], theme: InvoiceTheme, fmt: DocumentFormatter
    ) -> some PDFContent {
        var rows: [[String]] = []
        for line in lines {
            let inclUnit = line.unitPrice * (1 + line.vatRate / 100)
            let inclTotal = line.subtotalExcl + line.vatAmount
            rows.append([
                line.description,
                fmt.quantity(line.quantity),
                line.unit ?? "",
                fmt.money(line.unitPrice),
                fmt.percent(line.vatRate),
                fmt.money(inclUnit),
                fmt.money(inclTotal),
            ])
            if let detail = line.detail {
                rows.append([detail, "", "", "", "", "", ""])
            }
        }
        return Columns(spacing: 0) {
            ColumnItem(width: .flex) {
                HRule(thickness: 0.8, color: PDFColor(white: 0.2))
                // Seven columns on A4 portrait is a tight budget: the body is
                // 515pt wide, and `Table` neither wraps nor truncates a cell —
                // an over-wide description simply draws over its neighbour.
                // The fixed columns are held to 320pt so the description keeps
                // ~195pt, and the whole grid runs a size down from body copy.
                Table(data: rows,
                      style: DocumentLayoutKit.hairlineTableStyle(
                        theme: theme,
                        headerFontSize: theme.tableHeaderFontSize - 3,
                        cellFontSize: theme.tableCellFontSize - 1.5),
                      showHeader: true) {
                    Column(fmt.labels.columnDescription, width: .flex, alignment: .leading)
                    Column(fmt.labels.columnQuantity, width: .fixed(30),
                           alignment: .trailing, headerAlignment: .trailing)
                    Column(fmt.labels.columnUnit, width: .fixed(36),
                           alignment: .leading, headerAlignment: .leading)
                    Column(fmt.labels.columnUnitPriceExclTax, width: .fixed(72),
                           alignment: .trailing, headerAlignment: .trailing)
                    Column(fmt.labels.columnTax, width: .fixed(34),
                           alignment: .trailing, headerAlignment: .trailing)
                    Column(fmt.labels.columnUnitPriceInclTax, width: .fixed(72),
                           alignment: .trailing, headerAlignment: .trailing)
                    Column(fmt.labels.columnTotalInclTax, width: .fixed(76),
                           alignment: .trailing, headerAlignment: .trailing)
                }
                HRule(thickness: 0.5, color: PDFColor(white: 0.8))
            }
        }
    }

    /// NOTE bottom-left, totals bottom-right — the reference puts the
    /// reverse-charge sentence in the note block, not in a footnote.
    static func classicNoteAndTotals(
        invoice: InvoiceDocument, theme: InvoiceTheme, fmt: DocumentFormatter
    ) -> some PDFContent {
        let t = invoice.totals
        var rows: [[String]] = [[fmt.labels.subtotalLabel, fmt.money(t.subtotalExcl)]]
        if let disc = t.globalDiscount, disc > 0 {
            rows.append([fmt.labels.columnDiscount, "-\(fmt.money(disc))"])
        }
        rows.append([fmt.labels.vatLabel, fmt.money(t.totalVat)])
        rows.append([fmt.labels.totalLabel.uppercased(), fmt.money(t.totalIncl)])
        if let paid = t.amountPaid, paid > 0 {
            rows.append([fmt.labels.amountPaidLabel, fmt.money(paid)])
        }
        if !invoice.hidesSettlement {
            rows.append([
                InvoiceLayoutKit.isOutstanding(invoice)
                    ? fmt.labels.amountDueLabel.uppercased()
                    : fmt.labels.amountPaidLabel.uppercased(),
                InvoiceLayoutKit.isOutstanding(invoice)
                    ? fmt.money(t.amountDue)
                    : fmt.money(t.amountPaid ?? t.totalIncl),
            ])
        }

        let note = invoice.taxNote ?? invoice.header.notes
        return Columns(spacing: 24) {
            ColumnItem(width: .flex) {
                if let note {
                    Text(fmt.labels.noteHeader.uppercased())
                        .font(theme.bodyFont, size: theme.bodyFontSize - 2)
                        .color(DocumentLayoutKit.mutedText)
                    Spacer(height: 4)
                    Text(note)
                        .font(theme.bodyFont, size: theme.bodyFontSize - 1)
                        .color(DocumentLayoutKit.mutedText)
                }
            }
            ColumnItem(width: .fixed(260)) {
                Table(data: rows,
                      style: DocumentLayoutKit.hairlineTableStyle(
                        theme: theme, rowHeight: theme.totalsRowHeight),
                      showHeader: false) {
                    Column("", width: .flex, alignment: .leading)
                    Column("", width: .fixed(110), alignment: .trailing)
                }
            }
        }
    }
}
