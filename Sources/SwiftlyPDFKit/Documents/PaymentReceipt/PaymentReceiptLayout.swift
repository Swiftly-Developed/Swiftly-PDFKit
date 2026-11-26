import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - PaymentReceiptLayout

/// The payment-receipt family: one layout, in the Modern grammar.
///
/// Accent bar · flush-left title with the logo opposite · receipt number and
/// dates · supplier ÷ payer · the payment's own facts · a hairline allocation
/// table whose header repeats on every page that carries rows · a right-half
/// totals stack whose unallocated row is always present · the reversal
/// watermark and notice · notes · a footer that says this is not an invoice.
///
/// No line items, no tax and no payment block are ever read or drawn. The
/// reusable parts live in `PaymentDocumentBlocks`; this type owns only the
/// receipt's page arrangement and the receipt-specific choices.
///
/// Renders through both paths (CoreGraphics; HTML → `wkhtmltopdf` on Linux),
/// because every part is composed from the shared primitives.
public enum PaymentReceiptLayout {

    public static func build(
        _ document: PaymentReceiptDocument,
        theme: InvoiceTheme = .standard,
        locale: Locale = Locale(identifier: "en_US"),
        pageSize: PageSize = .a4
    ) -> PDF {
        let labels = document.labels
        let common = document.common

        // MARK: Rows

        let groups = PaymentDocumentBlocks.allocationDisplayRows(
            document.allocations, paymentCurrencyCode: document.totals.currencyCode,
            labels: labels, locale: locale)
        let closingRows = Self.totalsRows(document.totals, labels: labels, theme: theme, locale: locale)

        let notice: String? = document.reversal.flatMap { reversal in
            guard let code = reversal.reasonCode,
                  !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return labels.reversedNotice(reason: labels.reversalReason(forCode: code))
        }
        let notes: String? = document.notes.flatMap {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
        }

        // MARK: Page-fit accounting — no design authority

        let lineH = theme.bodyFontSize * 1.2
        let emphasisedCount = closingRows.filter(\.emphasised).count
        let bottomH = 14
            + PaymentDocumentBlocks.totalsStackHeight(
                count: closingRows.count, emphasised: emphasisedCount, theme: theme)
            + (notice != nil ? 12 + lineH * 2 : 0)
            + (notes != nil ? 12 + 8 * 1.2 + lineH * 3 : 0)
            // Slack: biased to break early rather than draw through the footer.
            + 28

        let footerLines = [labels.notAnInvoiceFooter]
        let footerH = PaymentDocumentBlocks.footerHeight(lineCount: footerLines.count)
        let margins = theme.pageMargins
        let contentWidth = pageSize.width - margins * 2
        let chunks = PaymentDocumentBlocks.paginate(
            groups: groups,
            rowHeight: { PaymentDocumentBlocks.allocationRowHeight($0, contentWidth: contentWidth) },
            emptyStateHeight: theme.lineItemRowHeight,
            bodyHeight: pageSize.height - margins * 2 - footerH,
            page1Overhead: page1Overhead(document, theme: theme),
            tableOverhead: PaymentDocumentBlocks.allocationTableOverhead(
                labels: labels, contentWidth: contentWidth),
            bottomHeight: bottomH)

        // MARK: Pages

        var pages: [Page] = []
        for (idx, chunk) in chunks.enumerated() {
            let isFirst = idx == 0
            let isLast = idx == chunks.count - 1
            // Page 1 always carries the table (its empty state included); a
            // later empty chunk is a closing-only page.
            let showsTable = isFirst || !chunk.isEmpty

            pages.append(Page(size: pageSize, margins: margins) {
                TopAccentBar(color: theme.accentColor, height: 6)
                if document.reversal != nil {
                    DocumentWatermark(text: labels.reversedWatermark)
                }

                if isFirst {
                    masthead(document, theme: theme)
                    Spacer(height: 14)
                    for item in headerGrid(document, theme: theme) { item }
                    Spacer(height: 10)
                    parties(document, theme: theme)
                    Spacer(height: 18)
                    let facts = PaymentDocumentBlocks.paymentFactsGrid(
                        document.paymentFacts, theme: theme)
                    if !facts.isEmpty {
                        for item in facts { item }
                        Spacer(height: 12)
                    }
                }

                if showsTable {
                    for item in PaymentDocumentBlocks.allocationTable(
                        chunk, labels: labels, common: common, theme: theme,
                        continued: !isFirst) { item }
                }

                if isLast {
                    Spacer(height: 14)
                    for item in PaymentDocumentBlocks.totalsStack(closingRows, theme: theme) { item }
                    if let notice {
                        Spacer(height: 12)
                        Text(notice)
                            .font(theme.bodyFont, size: theme.bodyFontSize)
                            .bold()
                    }
                    if let notes {
                        Spacer(height: 12)
                        Text(labels.notesLabel)
                            .font(theme.bodyFont, size: 8)
                            .bold()
                            .color(DocumentLayoutKit.mutedText)
                        Text(notes)
                            .font(theme.bodyFont, size: theme.bodyFontSize - 1)
                            .color(DocumentLayoutKit.mutedText)
                    }
                }

                PaymentDocumentBlocks.footer(
                    lines: footerLines, common: common,
                    page: idx + 1, of: chunks.count, theme: theme)
            })
        }
        return PDF(pages: pages)
    }

    // MARK: Totals

    /// Received / allocated / **unallocated always** (a zero included —
    /// "nothing is left over" is a fact the payer reads off the receipt, not an
    /// absence) / one informational row per bank charge in that charge's own
    /// currency, never subtracted.
    static func totalsRows(
        _ totals: PaymentReceiptTotals,
        labels: PaymentReceiptLabels,
        theme: InvoiceTheme,
        locale: Locale
    ) -> [PaymentDocumentBlocks.TotalsRow] {
        let fmt = DocumentFormatter(theme: theme, locale: locale, currencyCode: totals.currencyCode)
        var rows: [PaymentDocumentBlocks.TotalsRow] = [
            .init(caption: labels.totalReceivedLabel, value: fmt.money(totals.received)),
            .init(caption: labels.totalAllocatedLabel, value: fmt.money(totals.allocated)),
            .init(caption: labels.totalUnallocatedLabel, value: fmt.money(totals.unallocated),
                  emphasised: true),
        ]
        for charge in totals.charges {
            let chargeFmt = DocumentFormatter(theme: theme, locale: locale,
                                              currencyCode: charge.currencyCode)
            rows.append(.init(caption: labels.bankChargesLabel,
                              value: chargeFmt.money(charge.amount)))
        }
        return rows
    }

    // MARK: Page-fit accounting

    /// Height consumed on page 1 before the allocation table: masthead, header
    /// grid, the two party columns (only the taller counts) and the facts grid.
    /// Page-fit accounting only — no design authority.
    static func page1Overhead(_ document: PaymentReceiptDocument, theme: InvoiceTheme) -> CGFloat {
        let lineH = theme.bodyFontSize * 1.2
        let mastheadH = max(theme.logoMaxHeight, DocumentLayoutKit.modernTitleSize * 1.2) + 14
        let metaH = 8 * 1.2 + lineH + 6 + 10
        let payerExtras = (document.payer.registerNumber != nil ? 1 : 0)
            + (document.payer.customerReference != nil ? 1 : 0)
        let partiesH = CGFloat(9 + payerExtras) * lineH + 18
        let factsH = document.paymentFacts.isEmpty ? 0
            : PaymentDocumentBlocks.paymentFactsGridHeight(
                count: document.paymentFacts.count, theme: theme) + 12
        return mastheadH + metaH + partiesH + factsH
    }

    // MARK: Sections

    /// Title flush left, logo optically opposite.
    static func masthead(_ document: PaymentReceiptDocument, theme: InvoiceTheme) -> some PDFContent {
        Columns(spacing: 20) {
            ColumnItem(width: .flex) {
                Text(document.labels.paymentReceiptTitle)
                    .font(theme.bodyFont, size: DocumentLayoutKit.modernTitleSize)
                    .bold()
            }
            ColumnItem(width: .fixed(150)) {
                InvoiceLayoutBuilder.logoOrFallback(
                    supplier: document.supplier, theme: theme, alignment: .trailing)
            }
        }
    }

    /// Receipt number, receipt date and — when the host prints one — the
    /// generation timestamp, three to a row.
    static func headerGrid(_ document: PaymentReceiptDocument, theme: InvoiceTheme) -> [any PDFContent] {
        let header = document.header
        var rows: [(caption: String, value: String)] = [
            (document.labels.receiptNumberLabel, header.receiptNumber),
            (document.labels.receiptDateLabel, header.receiptDate),
        ]
        if let generated = header.generatedOn {
            rows.append((document.common.generatedOnLabel, generated))
        }
        return DocumentLayoutKit.metadataGrid(rows: rows, theme: theme, columns: 3)
    }

    /// Supplier left, payer right, with the payer's register number and the
    /// issuer's customer reference under the payer block when present.
    static func parties(_ document: PaymentReceiptDocument, theme: InvoiceTheme) -> some PDFContent {
        let payer = document.payer
        let extras = [
            payer.registerNumber.map { "\(document.common.registrationNumberLabel) \($0)" },
            payer.customerReference.map { "\(document.labels.customerReferenceLabel) \($0)" },
        ].compactMap { $0 }
        return Columns(spacing: 24) {
            ColumnItem(width: .flex) {
                for item in DocumentLayoutKit.supplierIdentityBlock(
                    supplier: document.supplier, labels: document.common, theme: theme) { item }
            }
            ColumnItem(width: .flex) {
                for item in DocumentLayoutKit.partyBlock(
                    party: payer.party, header: document.labels.receivedFromLabel,
                    labels: document.common, theme: theme) { item }
                if !extras.isEmpty {
                    Spacer(height: 4)
                }
                for line in extras {
                    Text(line)
                        .font(theme.bodyFont, size: 8)
                        .color(DocumentLayoutKit.mutedText)
                }
            }
        }
    }
}
