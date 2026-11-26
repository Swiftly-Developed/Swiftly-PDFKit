import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - PurchaseOrderLayout

/// The purchase-order family: one layout, in the Modern grammar.
///
/// Accent bar · flush-left title with the logo opposite · order number (or the
/// draft placeholder), dates and revision · the issuing company ÷ the supplier
/// · the delivery location under the issuer · the optional header rows · a
/// hairline lines table whose stacked cells wrap inside their columns and
/// whose header repeats on every page that carries rows · the omitted-lines
/// count · a tax breakdown · a right-half totals stack whose values carry the
/// ISO code · the special instructions · the draft / cancelled watermark on
/// every page · a footer asking the supplier to confirm.
///
/// The issuer's bank line is **never** printed: the layout strips it itself,
/// so a purchase order can never carry a payment instruction to the supplier
/// whatever the caller passes. No payment block, QR code, signature or
/// base-currency figure is read or drawn — the model has no member that could
/// carry one.
///
/// Renders through both paths (CoreGraphics; HTML → `wkhtmltopdf` on Linux),
/// because every part is composed from the shared primitives.
public enum PurchaseOrderLayout {

    public static func build(
        _ document: PurchaseOrderDocument,
        theme: InvoiceTheme = .standard,
        locale: Locale = Locale(identifier: "en_US"),
        pageSize: PageSize = .a4
    ) -> PDF {
        let labels = document.labels
        let common = document.common
        let fmt = DocumentFormatter(theme: theme, locale: locale, currencyCode: document.totals.currencyCode)
        let issuer = strippedIssuer(document.issuer)

        // MARK: Rows and page-fit accounting — no design authority

        let margins = theme.pageMargins
        let contentWidth = pageSize.width - margins * 2
        let rows = document.lines.map { lineCells($0, labels: labels, fmt: fmt, locale: locale) }
        let footerLines = [labels.confirmationRequestFooter, labels.indicativeTaxFooter]
        let footerH = footerHeight(lines: footerLines, contentWidth: contentWidth)
        let chunks = paginate(
            rowHeights: rows.map { lineRowHeight($0, contentWidth: contentWidth) },
            emptyStateHeight: theme.lineItemRowHeight,
            bodyHeight: pageSize.height - margins * 2 - footerH,
            page1Overhead: page1Overhead(document, theme: theme, contentWidth: contentWidth),
            tableOverhead: linesTableOverhead(labels: labels, contentWidth: contentWidth),
            bottomHeight: bottomHeight(document, theme: theme, fmt: fmt, contentWidth: contentWidth))

        let watermarkText: String? = {
            switch document.watermark {
            case .none: return nil
            case .draft: return common.watermarkDraft
            case .cancelled: return labels.cancelledWatermark
            }
        }()
        let notice = cancellationNotice(document)

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
                if let watermarkText {
                    DocumentWatermark(text: watermarkText)
                }

                if isFirst {
                    masthead(document, issuer: issuer, theme: theme)
                    Spacer(height: 14)
                    for item in headerGrid(document, theme: theme, locale: locale) { item }
                    if let notice {
                        Text(notice)
                            .font(theme.bodyFont, size: theme.bodyFontSize)
                            .bold()
                        Spacer(height: 8)
                    }
                    Spacer(height: 10)
                    parties(document, issuer: issuer, theme: theme)
                    Spacer(height: 18)
                    for item in deliverToBlock(document, theme: theme) { item }
                    for item in metadataGrid(document, theme: theme) { item }
                }

                if showsTable {
                    for item in linesTable(
                        chunk.map { rows[$0] }, labels: labels, common: common, theme: theme,
                        continued: !isFirst) { item }
                }

                if isLast {
                    for item in closingBlocks(document, theme: theme, fmt: fmt, locale: locale) { item }
                }

                footer(lines: footerLines, common: common, page: idx + 1, of: chunks.count,
                       theme: theme, contentWidth: contentWidth)
            })
        }
        return PDF(pages: pages)
    }

    // MARK: Issuer

    /// The issuer with its bank details removed — the only issuer value any
    /// block receives. A purchase order is a request to a supplier, so printing
    /// the buyer's account would only invite a payment-redirection fraud.
    static func strippedIssuer(_ issuer: InvoiceSupplier) -> InvoiceSupplier {
        var stripped = issuer
        stripped.iban = nil
        stripped.bic = nil
        return stripped
    }

    // MARK: Sections

    /// Title flush left, logo optically opposite.
    static func masthead(
        _ document: PurchaseOrderDocument, issuer: InvoiceSupplier, theme: InvoiceTheme
    ) -> some PDFContent {
        Columns(spacing: 20) {
            ColumnItem(width: .flex) {
                Text(document.labels.purchaseOrderTitle)
                    .font(theme.bodyFont, size: DocumentLayoutKit.modernTitleSize)
                    .bold()
            }
            ColumnItem(width: .fixed(150)) {
                InvoiceLayoutBuilder.logoOrFallback(supplier: issuer, theme: theme, alignment: .trailing)
            }
        }
    }

    /// Order number (or the draft placeholder), order date, revision and — when
    /// the host prints one — the generation timestamp, four to a row.
    static func headerGrid(
        _ document: PurchaseOrderDocument, theme: InvoiceTheme, locale: Locale
    ) -> [any PDFContent] {
        let header = document.header
        let labels = document.labels
        var rows: [(caption: String, value: String)] = [
            (labels.purchaseOrderNumberLabel, nonBlank(header.orderNumber) ?? labels.draftNumberPlaceholder),
            (labels.orderDateLabel, header.orderDate),
        ]
        if let revision = header.revision {
            rows.append((labels.revisionLabel, revision.formatted(.number.grouping(.never).locale(locale))))
        }
        if let generated = nonBlank(header.generatedOn) {
            rows.append((document.common.generatedOnLabel, generated))
        }
        return DocumentLayoutKit.metadataGrid(rows: rows, theme: theme, columns: 4)
    }

    /// The cancellation notice — only for a cancelled order whose date is known.
    static func cancellationNotice(_ document: PurchaseOrderDocument) -> String? {
        guard case .cancelled(let cancelledOn) = document.watermark,
              let date = nonBlank(cancelledOn) else { return nil }
        return document.labels.cancelledNotice(date: date)
    }

    /// Issuer left (captioned as the buyer, bank line stripped), supplier right
    /// with its register number and the issuer's supplier number under it.
    static func parties(
        _ document: PurchaseOrderDocument, issuer: InvoiceSupplier, theme: InvoiceTheme
    ) -> some PDFContent {
        let extras = vendorExtras(document)
        return Columns(spacing: 24) {
            ColumnItem(width: .flex) {
                Text(document.labels.buyerHeader)
                    .font(theme.bodyFont, size: 8)
                    .bold()
                    .color(DocumentLayoutKit.mutedText)
                Spacer(height: 3)
                for item in DocumentLayoutKit.supplierIdentityBlock(
                    supplier: issuer, labels: document.common, theme: theme) { item }
            }
            ColumnItem(width: .flex) {
                for item in DocumentLayoutKit.partyBlock(
                    party: document.vendor.party, header: document.labels.vendorHeader,
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

    /// The supplier's register-number and supplier-number lines, when present.
    static func vendorExtras(_ document: PurchaseOrderDocument) -> [String] {
        [
            nonBlank(document.vendor.registerNumber).map { "\(document.common.registrationNumberLabel) \($0)" },
            nonBlank(document.vendor.vendorNumber).map { "\(document.labels.vendorNumberLabel) \($0)" },
        ].compactMap { $0 }
    }

    /// The receiving location under the issuer column (it is the issuer's own
    /// address): the warehouse block with its code, then the free-text
    /// delivery address. `[]` when there is neither.
    static func deliverToBlock(_ document: PurchaseOrderDocument, theme: InvoiceTheme) -> [any PDFContent] {
        guard let deliverTo = document.deliverTo, isDeliverToRendered(deliverTo) else { return [] }
        let labels = document.labels
        var left: [any PDFContent] = []
        if let warehouse = deliverTo.warehouse {
            left += DocumentLayoutKit.partyBlock(
                party: warehouse, header: labels.deliverToHeader, labels: document.common, theme: theme)
            if let code = nonBlank(deliverTo.warehouseCode) {
                left.append(
                    Text("\(labels.warehouseLabel) \(code)")
                        .font(theme.bodyFont, size: 8)
                        .color(DocumentLayoutKit.mutedText))
            }
        } else {
            left.append(
                Text(labels.deliverToHeader)
                    .font(theme.bodyFont, size: 8)
                    .bold()
                    .color(DocumentLayoutKit.mutedText))
            left.append(Spacer(height: 3))
        }
        if let address = nonBlank(deliverTo.deliveryAddress) {
            if deliverTo.warehouse != nil {
                left.append(Spacer(height: 4))
            }
            left.append(Text(address).font(theme.bodyFont, size: theme.bodyFontSize))
        }
        return [
            Columns(spacing: 24) {
                ColumnItem(width: .flex) {
                    for item in left { item }
                }
                ColumnItem(width: .flex) { Spacer(height: 0) }
            },
            Spacer(height: 12),
        ]
    }

    /// Whether ``deliverToBlock(_:theme:)`` renders anything.
    static func isDeliverToRendered(_ deliverTo: PurchaseOrderDocumentDeliverTo) -> Bool {
        deliverTo.warehouse != nil || nonBlank(deliverTo.deliveryAddress) != nil
    }

    /// The mapper's ordered, captioned header rows, three to a row; `[]` for none.
    static func metadataGrid(_ document: PurchaseOrderDocument, theme: InvoiceTheme) -> [any PDFContent] {
        let grid = DocumentLayoutKit.metadataGrid(
            rows: document.metadataRows.map { (caption: $0.caption, value: $0.value) },
            theme: theme, columns: 3)
        return grid.isEmpty ? [] : grid + [Spacer(height: 6)]
    }

    /// Last page, after the table: the omitted-lines count, the tax breakdown,
    /// the totals stack and the special instructions.
    static func closingBlocks(
        _ document: PurchaseOrderDocument, theme: InvoiceTheme, fmt: DocumentFormatter, locale: Locale
    ) -> [any PDFContent] {
        let labels = document.labels
        var contents: [any PDFContent] = [Spacer(height: 10)]
        if document.closedShortOmittedCount > 0 {
            let count = document.closedShortOmittedCount.formatted(.number.locale(locale))
            contents.append(
                Text(labels.closedShortLinesOmitted(count: count))
                    .font(theme.bodyFont, size: theme.bodyFontSize - 1)
                    .color(DocumentLayoutKit.mutedText))
            contents.append(Spacer(height: 8))
        }
        if !document.taxRows.isEmpty {
            contents += taxBreakdown(document.taxRows, labels: labels, theme: theme, fmt: fmt)
            contents.append(Spacer(height: 10))
        }
        contents += totalsStack(
            totalsRows(document.totals, labels: labels, common: document.common, fmt: fmt), theme: theme)
        if let instructions = nonBlank(document.specialInstructions) {
            contents.append(Spacer(height: 12))
            contents.append(
                Text(labels.specialInstructionsHeader)
                    .font(theme.bodyFont, size: 8)
                    .bold()
                    .color(DocumentLayoutKit.mutedText))
            contents.append(
                Text(instructions)
                    .font(theme.bodyFont, size: theme.bodyFontSize - 1))
        }
        return contents
    }

    // MARK: Helpers

    /// `value` unless it is `nil` or whitespace only.
    static func nonBlank(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}
