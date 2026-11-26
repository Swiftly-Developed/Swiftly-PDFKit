import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - RemittanceAdviceLayout

/// The remittance-advice family: one layout, in the Modern grammar.
///
/// Accent bar · flush-left title with the logo opposite · advice number (or
/// batch reference) and dates · our company (its bank line printed) ÷ the
/// payee with its identifiers · in the batch form, the member payments (a
/// paginated list whose header repeats) · the payment's own facts · the
/// settled documents through the payment receipt's six-column atom, whose
/// document cell stacks the payee's number, the document type and our
/// reference (and, in a batch, the paying member), with cash-discount and
/// adjustment sub-rows · one totals stack per currency, its on-account row
/// always present · the remittance information · the reversed or
/// not-yet-submitted watermark on every page and its notice · notes · a
/// footer announcing that execution is the bank's.
///
/// The totals stay on the page of the last settled-documents row whenever they
/// fit; only the remittance lines, the notice and the notes may flow on, each
/// kept whole (PRINT03 §25 #48).
///
/// No line items, no tax, no payment block, QR code or signature are ever
/// read or drawn, and the layout does no arithmetic: every figure arrives
/// computed. The table, pager, totals stack and footer are
/// `PaymentDocumentBlocks`' (reused through additive overloads); this type
/// owns only the advice's page arrangement and its own choices.
///
/// Renders through both paths (CoreGraphics; HTML → `wkhtmltopdf` on Linux),
/// because every part is composed from the shared primitives.
public enum RemittanceAdviceLayout {

    public static func build(
        _ document: RemittanceAdviceDocument,
        theme: InvoiceTheme = .standard,
        locale: Locale = Locale(identifier: "en_US"),
        pageSize: PageSize = .a4
    ) -> PDF {
        let labels = document.labels, payment = document.payment, common = document.common
        let isBatch = document.memberPayments != nil

        // MARK: Rows

        let groups = detailGroups(document, isBatch: isBatch, locale: locale)
        let memberRows = memberPaymentRows(document, locale: locale)
        let detailHeader = detailHeader(isBatch: isBatch, payment: payment, labels: labels)

        let watermarkText: String? = watermarkText(document.watermark, labels: labels, payment: payment)
        let footerLines = footerLines(document)

        // MARK: Page-fit accounting — no design authority

        let margins = theme.pageMargins
        let contentWidth = pageSize.width - margins * 2
        let footerH = PaymentDocumentBlocks.footerHeight(lines: footerLines, contentWidth: contentWidth)
        let bodyH = pageSize.height - margins * 2 - footerH
        let closing = closingUnits(document, theme: theme, locale: locale, contentWidth: contentWidth)
        let plan = pagePlan(
            document, groups: groups, memberRows: memberRows, detailHeader: detailHeader,
            isBatch: isBatch, bodyH: bodyH, theme: theme, contentWidth: contentWidth,
            closingHeights: closing.map(\.height))
        let chunks = plan.chunks

        // MARK: Pages

        var pages: [Page] = []
        for (idx, chunk) in chunks.enumerated() {
            // `isFirst` is the detail table's first page; earlier pages carry
            // only the member list (and, on page 1, the head blocks).
            let isFirst = idx == plan.detailStart
            // The detail table's first page always carries it (its empty state
            // included); a later empty chunk is a closing-only page.
            let showsTable = isFirst || !chunk.isEmpty
            let members: [[[String]]]? = idx < plan.memberChunks.count ? plan.memberChunks[idx] : nil
            let closingItems: [any PDFContent] = idx >= plan.closingStart
                ? plan.closingPages[idx - plan.closingStart].flatMap { closing[$0].contents }
                : []

            pages.append(Page(size: pageSize, margins: margins) {
                TopAccentBar(color: theme.accentColor, height: 6)
                if let watermarkText {
                    DocumentWatermark(text: watermarkText, fontSize: watermarkFontSize(watermarkText))
                }

                if idx == 0 {
                    for item in headBlocks(document, theme: theme) { item }
                }

                if let members {
                    for item in memberTable(members, document: document, theme: theme, continued: idx > 0) {
                        item
                    }
                    Spacer(height: memberTableGap)
                }

                if isFirst {
                    for item in factsGrid(document, theme: theme) { item }
                }

                if showsTable {
                    for item in PaymentDocumentBlocks.allocationTable(
                        stackedRows: chunk, title: labels.settledDocumentsTitle, header: detailHeader,
                        emptyRow: payment.allocationEmptyRow, common: common, theme: theme,
                        continued: !isFirst) { item }
                }

                for item in closingItems { item }

                PaymentDocumentBlocks.footer(
                    lines: footerLines, common: common, page: idx + 1, of: chunks.count,
                    theme: theme, contentWidth: contentWidth)
            })
        }
        return PDF(pages: pages)
    }

    // MARK: Watermark and notice

    /// The watermark word for the status, or `nil` for none.
    static func watermarkText(
        _ watermark: RemittanceAdviceWatermark,
        labels: RemittanceAdviceLabels,
        payment: PaymentReceiptLabels
    ) -> String? {
        switch watermark {
        case .none: return nil
        case .reversed: return payment.reversedWatermark
        case .notYetSubmitted: return labels.notYetSubmittedWatermark
        }
    }

    /// The watermark's size: the receipt's 96 pt for a short word, smaller for
    /// a long one so it stays inside the A4 diagonal, never below 36 pt.
    static func watermarkFontSize(_ text: String) -> CGFloat {
        let fitted = 700 / (CGFloat(max(text.count, 1)) * 0.72)
        return max(36, min(96, fitted))
    }

    /// The status notice printed after the totals, or `nil` for none.
    static func statusNotice(
        _ watermark: RemittanceAdviceWatermark,
        labels: RemittanceAdviceLabels,
        payment: PaymentReceiptLabels
    ) -> String? {
        switch watermark {
        case .none: return nil
        case .reversed(let reasonCode): return reversedNotice(reasonCode, payment: payment)
        case .notYetSubmitted: return labels.notYetSubmittedNotice
        }
    }

    /// The reversal notice — only when the reason code is non-blank.
    static func reversedNotice(_ code: String?, payment: PaymentReceiptLabels) -> String? {
        guard let code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return payment.reversedNotice(reason: payment.reversalReason(forCode: code))
    }

    // MARK: Footer

    /// The funds notice on every page, then the queries line when an address is set.
    static func footerLines(_ document: RemittanceAdviceDocument) -> [String] {
        var lines = [document.labels.fundsSubjectToProcessingNotice]
        if let email = nonBlank(document.contactEmail) {
            lines.append(document.labels.queriesContactLabel + " " + email)
        }
        return lines
    }

    // MARK: Sections

    /// Page 1's masthead, header grid and parties. The gaps are the receipt's
    /// less a few points each (phase 07d: 14 / 10 / 18 → 12 / 8 / 14), so a
    /// one-member batch with a two-line note keeps its notes on page 1;
    /// `headOverhead` counts the same three.
    static func headBlocks(_ document: RemittanceAdviceDocument, theme: InvoiceTheme) -> [any PDFContent] {
        [masthead(document, theme: theme), Spacer(height: mastheadGap)]
            + headerGrid(document, theme: theme)
            + [Spacer(height: headerGridGap), parties(document, theme: theme), Spacer(height: partiesGap)]
    }

    /// The head's three gaps and the one under the member list (phase 07d).
    static let mastheadGap: CGFloat = 12
    static let headerGridGap: CGFloat = 8
    static let partiesGap: CGFloat = 14
    static let memberTableGap: CGFloat = 10

    /// Title flush left, logo optically opposite.
    static func masthead(_ document: RemittanceAdviceDocument, theme: InvoiceTheme) -> some PDFContent {
        Columns(spacing: 20) {
            ColumnItem(width: .flex) {
                Text(document.labels.remittanceAdviceTitle)
                    .font(theme.bodyFont, size: DocumentLayoutKit.modernTitleSize)
                    .bold()
            }
            ColumnItem(width: .fixed(150)) {
                InvoiceLayoutBuilder.logoOrFallback(
                    supplier: document.issuer, theme: theme, alignment: .trailing)
            }
        }
    }

    /// The batch reference's row, on its own at full width: it joins two ids
    /// (message id / vendor reference), which a third of the page wraps mid-id
    /// (PRINT03 §25 #48). `[]` in the single form.
    static func batchReferenceRow(_ document: RemittanceAdviceDocument) -> [(caption: String, value: String)] {
        nonBlank(document.header.batchReference).map { [(document.labels.batchReferenceLabel, $0)] } ?? []
    }

    /// The header grid's rows: the advice number, the advice date and — when
    /// the host prints one — the generation timestamp.
    static func headerRows(_ document: RemittanceAdviceDocument) -> [(caption: String, value: String)] {
        let header = document.header
        let labels = document.labels
        var rows: [(caption: String, value: String)] = []
        if let number = nonBlank(header.adviceNumber) {
            rows.append((labels.adviceNumberLabel, number))
        }
        rows.append((labels.adviceDateLabel, header.adviceDate))
        if let generated = nonBlank(header.generatedOn) {
            rows.append((document.common.generatedOnLabel, generated))
        }
        return rows
    }

    /// The header grid: the batch reference alone, then three to a row.
    static func headerGrid(_ document: RemittanceAdviceDocument, theme: InvoiceTheme) -> [any PDFContent] {
        DocumentLayoutKit.metadataGrid(rows: batchReferenceRow(document), theme: theme, columns: 1)
            + DocumentLayoutKit.metadataGrid(rows: headerRows(document), theme: theme, columns: 3)
    }

    /// The payee's identifier lines under its block, each only when non-blank.
    static func payeeExtras(_ document: RemittanceAdviceDocument) -> [String] {
        let payee = document.payee
        let labels = document.labels
        let common = document.common
        return [
            nonBlank(payee.registerNumber).map { "\(common.registrationNumberLabel) \($0)" },
            nonBlank(payee.supplierNumber).map { "\(labels.supplierNumberLabel) \($0)" },
            nonBlank(payee.yourReferenceForUs).map { "\(labels.yourReferenceForUsLabel) \($0)" },
            nonBlank(payee.paidToAccount).map { "\(labels.paidToAccountLabel) \($0)" },
            nonBlank(payee.paidToBIC).map { "\(common.bicLabel) \($0)" },
        ].compactMap { $0 }
    }

    /// Our company left (its bank line printed — the account the payment
    /// leaves from), the payee right with its identifiers.
    static func parties(_ document: RemittanceAdviceDocument, theme: InvoiceTheme) -> some PDFContent {
        let extras = payeeExtras(document)
        return Columns(spacing: 24) {
            ColumnItem(width: .flex) {
                for item in DocumentLayoutKit.supplierIdentityBlock(
                    supplier: document.issuer, labels: document.common, theme: theme) { item }
            }
            ColumnItem(width: .flex) {
                for item in DocumentLayoutKit.partyBlock(
                    party: document.payee.party, header: document.labels.paidToLabel,
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

    /// The payment facts, two to a row, then a spacer; `[]` when there are none.
    static func factsGrid(_ document: RemittanceAdviceDocument, theme: InvoiceTheme) -> [any PDFContent] {
        let grid = DocumentLayoutKit.metadataGrid(
            rows: document.paymentFacts.map { (caption: $0.caption, value: $0.value) },
            theme: theme, columns: 2)
        return grid.isEmpty ? [] : grid + [Spacer(height: factsGap)]
    }

    /// The gap under the facts grid (phase 07d: 12 → 10); `factsHeight` counts it.
    static let factsGap: CGFloat = 10

    /// The batch form's member-payment list for one page, through the same
    /// stacked atom; its header repeats on every page it continues onto.
    static func memberTable(
        _ rows: [[[String]]],
        document: RemittanceAdviceDocument,
        theme: InvoiceTheme,
        continued: Bool
    ) -> [any PDFContent] {
        PaymentDocumentBlocks.allocationTable(
            stackedRows: rows, title: document.labels.paymentsInBatchTitle,
            header: memberPaymentHeader(labels: document.labels, payment: document.payment),
            emptyRow: document.payment.allocationEmptyRow, common: document.common, theme: theme,
            continued: continued, documentSpan: memberDocumentSpan)
    }

    // MARK: Helpers

    /// `value` unless it is `nil` or whitespace only.
    static func nonBlank(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}
