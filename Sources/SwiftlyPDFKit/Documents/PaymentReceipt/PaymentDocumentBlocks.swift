import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - PaymentDocumentBlocks

/// The reusable parts of a payment document: the allocation table, the
/// payment-facts grid, the totals stack, the footer and the page planning.
///
/// The kit's own page planner, footer and totals ladder are bound to the
/// invoice model (the planner splits invoice lines, the footer reads the
/// invoice label set, the ladder always prints a tax row), and a payment has
/// no lines and no VAT. These builders compose the same jobs from the plain
/// primitives instead, mirroring the kit's two-pass page arithmetic.
///
/// No builder here takes ``PaymentReceiptDocument``: each takes only the rows,
/// labels, theme and locale it renders, so a second payment document family
/// (a remittance advice) composes the same parts from its own model. The
/// receipt-specific decisions — which totals rows exist, the watermark, the
/// notice, the masthead — stay in ``PaymentReceiptLayout``.
/// ``RemittanceAdviceLayout`` is that second family (PRINT03).
enum PaymentDocumentBlocks {

    /// The cell printed for a figure the mapper could not state in the
    /// document's currency. A typographic placeholder, not a label: it has no
    /// catalog key and no ``PaymentReceiptLabels`` member.
    private static let unavailableCell = "—"

    // MARK: Allocation display rows

    /// Flattens the allocation rows into table rows, one group per document.
    ///
    /// Each group is the document's row, followed — only when the document is
    /// in a foreign currency (both `appliedInDocumentCurrency` and
    /// `exchangeRate` set) — by a rate sub-row carrying the amount applied in
    /// the document's own currency. The sub-row is its own row (the line-table
    /// detail-row precedent), and a group is never split across pages.
    ///
    /// Every money cell prints its ISO 4217 code rather than a symbol: the
    /// documents on one receipt can be in different currencies. A `nil`
    /// total, other-payments or remaining figure prints ``unavailableCell``,
    /// and a `nil` remaining figure never prints the settled marker.
    static func allocationDisplayRows(
        _ rows: [PaymentReceiptAllocationRow],
        paymentCurrencyCode: String,
        labels: PaymentReceiptLabels,
        locale: Locale
    ) -> [[[String]]] {
        func money(_ value: Double, _ code: String) -> String {
            value.formatted(.number.precision(.fractionLength(2)).locale(locale)) + " " + code
        }
        return rows.map { row in
            let code = row.documentCurrencyCode
            var group: [[String]] = [[
                row.documentNumber,
                row.documentDate ?? "",
                row.documentTotal.map { money($0, code) } ?? unavailableCell,
                row.paidByOtherPayments.map { money($0, code) } ?? unavailableCell,
                money(row.appliedAmount, paymentCurrencyCode),
                row.remaining.map { row.isSettled ? labels.allocationSettledMarker : money($0, code) }
                    ?? unavailableCell,
            ]]
            if let inDocument = row.appliedInDocumentCurrency, let rate = row.exchangeRate {
                let rateString = rate.formatted(
                    .number.precision(.fractionLength(0...6)).locale(locale))
                group.append([
                    labels.exchangeRate(rateString), "", "", "",
                    money(inDocument, code), "",
                ])
            }
            return group
        }
    }

    // MARK: Page planning

    /// Splits display groups into per-page row chunks by **height**.
    ///
    /// Page 1 holds what fits in `bodyH − page1Overhead − tableOverhead`, a
    /// continuation page what fits in `bodyH − tableOverhead`; a row's height
    /// comes from `rowHeight`, because a wrapped cell makes its row taller. A
    /// group is never split. When the closing blocks do not fit beside the last
    /// chunk an empty chunk is appended — a closing-only page. No groups at all
    /// yields `[[]]`: one page carrying the table's empty state.
    ///
    /// Page-fit accounting only, biased to break early: a needless page break
    /// is cheap, closing blocks drawn through the footer are not.
    ///
    /// - Parameters:
    ///   - rowHeight: the estimated height of one display row, from
    ///     ``allocationRowHeight(_:contentWidth:)``.
    ///   - emptyStateHeight: the height the empty-state line takes in place of
    ///     the rows.
    ///   - bodyHeight: the page height inside the margins, less the footer
    ///     (``footerHeight(lineCount:)``).
    ///   - tableOverhead: the height the table costs on every page besides its
    ///     rows (section title, hairlines, the repeated header row).
    static func paginate(
        groups: [[[String]]],
        rowHeight: ([String]) -> CGFloat,
        emptyStateHeight: CGFloat,
        bodyHeight bodyH: CGFloat,
        page1Overhead: CGFloat,
        tableOverhead: CGFloat,
        bottomHeight: CGFloat
    ) -> [[[String]]] {
        let p1Capacity = bodyH - page1Overhead - tableOverhead
        let contCapacity = bodyH - tableOverhead

        var chunks: [[[String]]] = [[]]
        var used: CGFloat = 0
        for group in groups {
            let groupH = group.reduce(CGFloat(0)) { $0 + rowHeight($1) }
            let capacity = chunks.count == 1 ? p1Capacity : contCapacity
            if !chunks[chunks.count - 1].isEmpty && used + groupH > capacity {
                chunks.append(group)
                used = groupH
            } else {
                chunks[chunks.count - 1].append(contentsOf: group)
                used += groupH
            }
        }

        let last = chunks[chunks.count - 1]
        let lastRowsH = last.isEmpty ? emptyStateHeight : used
        let lastUsed = (chunks.count == 1 ? page1Overhead : 0) + tableOverhead + lastRowsH
        if lastUsed + bottomHeight > bodyH {
            chunks.append([])
        }
        return chunks
    }

    // MARK: Payment facts

    /// The payment's own facts as a two-column caption / value grid; `[]` when
    /// there are none.
    static func paymentFactsGrid(
        _ facts: [PaymentReceiptFact],
        theme: InvoiceTheme
    ) -> [any PDFContent] {
        DocumentLayoutKit.metadataGrid(
            rows: facts.map { (caption: $0.caption, value: $0.value) },
            theme: theme, columns: 2)
    }

    /// Height ``paymentFactsGrid(_:theme:)`` takes for `count` facts.
    static func paymentFactsGridHeight(count: Int, theme: InvoiceTheme) -> CGFloat {
        let gridRows = CGFloat((count + 1) / 2)
        return gridRows * (8 * 1.2 + theme.bodyFontSize * 1.2 + 6)
    }

    // MARK: Totals stack

    /// One totals row, already formatted.
    struct TotalsRow {
        let caption: String
        let value: String
        var emphasised: Bool = false
    }

    /// A right-half caption / value stack with a hairline above every
    /// emphasised row. It renders only the rows it is given, so it is VAT-free
    /// by construction.
    static func totalsStack(_ rows: [TotalsRow], theme: InvoiceTheme) -> [any PDFContent] {
        var stack: [any PDFContent] = []
        for row in rows {
            if row.emphasised {
                stack.append(Spacer(height: 2))
                stack.append(HRule(thickness: 0.5, color: theme.ruleColor))
                stack.append(Spacer(height: 2))
            }
            stack.append(
                Columns(spacing: 12) {
                    ColumnItem(width: .flex) {
                        totalsCell(row.caption, theme: theme, bold: row.emphasised)
                    }
                    ColumnItem(width: .fixed(110)) {
                        totalsCell(row.value, theme: theme, bold: row.emphasised)
                    }
                }
            )
        }
        return [
            Columns(spacing: 0) {
                ColumnItem(width: .flex) { Spacer(height: 1) }
                ColumnItem(width: .fixed(280)) {
                    for item in stack { item }
                }
            },
        ]
    }

    /// Height ``totalsStack(_:theme:)`` takes for `count` rows of which
    /// `emphasised` carry a hairline.
    static func totalsStackHeight(count: Int, emphasised: Int, theme: InvoiceTheme) -> CGFloat {
        CGFloat(count) * theme.totalsRowHeight + CGFloat(emphasised) * (2 + 4.5 + 2)
    }

    private static func totalsCell(_ string: String, theme: InvoiceTheme, bold: Bool) -> Text {
        let text = Text(string)
            .font(theme.bodyFont, size: theme.bodyFontSize)
            .alignment(.trailing)
        return bold ? text.bold() : text
    }

    // MARK: Footer

    /// Hairline, the caller's lines, then the page line from
    /// ``CommonDocumentLabels/pageNumber(_:of:)``.
    static func footer(
        lines: [String],
        common: CommonDocumentLabels,
        page: Int,
        of pageCount: Int,
        theme: InvoiceTheme
    ) -> Footer {
        Footer(height: footerHeight(lineCount: lines.count)) {
            HRule(thickness: 0.5, color: PDFColor(white: 0.82))
            Spacer(height: 4)
            for line in lines {
                Text(line)
                    .font(theme.bodyFont, size: 8)
                    .alignment(.trailing)
                    .color(DocumentLayoutKit.mutedText)
            }
            Text(common.pageNumber(page, of: pageCount))
                .font(theme.bodyFont, size: 8)
                .alignment(.trailing)
                .color(DocumentLayoutKit.mutedText)
        }
    }

    /// The footer's height: its lines and the page line, plus the rule and
    /// spacer above them. Under-reserving does not shrink the footer — it lets
    /// the page line fall past the page edge and vanish.
    static func footerHeight(lineCount: Int) -> CGFloat {
        CGFloat(lineCount) * 12 + 12 + 22
    }

    // MARK: Stacked-family planning and footer (PRINT03 — additive; the receipt never calls these)

    /// ``paginate(groups:rowHeight:emptyStateHeight:bodyHeight:page1Overhead:tableOverhead:bottomHeight:)``
    /// over any row type, so a family whose rows stack lines per cell
    /// (`[[String]]`) plans its pages with the same rules. The algorithm is
    /// copied, not routed through, so the receipt's planner is untouched.
    static func paginate<Row>(
        rowGroups: [[Row]],
        rowHeight: (Row) -> CGFloat,
        emptyStateHeight: CGFloat,
        bodyHeight bodyH: CGFloat,
        page1Overhead: CGFloat,
        tableOverhead: CGFloat,
        bottomHeight: CGFloat
    ) -> [[Row]] {
        let p1Capacity = bodyH - page1Overhead - tableOverhead
        let contCapacity = bodyH - tableOverhead

        var chunks: [[Row]] = [[]]
        var used: CGFloat = 0
        for group in rowGroups {
            let groupH = group.reduce(CGFloat(0)) { $0 + rowHeight($1) }
            let capacity = chunks.count == 1 ? p1Capacity : contCapacity
            if !chunks[chunks.count - 1].isEmpty && used + groupH > capacity {
                chunks.append(group)
                used = groupH
            } else {
                chunks[chunks.count - 1].append(contentsOf: group)
                used += groupH
            }
        }

        let last = chunks[chunks.count - 1]
        let lastRowsH = last.isEmpty ? emptyStateHeight : used
        let lastUsed = (chunks.count == 1 ? page1Overhead : 0) + tableOverhead + lastRowsH
        if lastUsed + bottomHeight > bodyH {
            chunks.append([])
        }
        return chunks
    }

    /// ``footer(lines:common:page:of:theme:)`` with a height reserved per
    /// **estimated** wrapped line, for footer lines long enough to wrap.
    static func footer(
        lines: [String],
        common: CommonDocumentLabels,
        page: Int,
        of pageCount: Int,
        theme: InvoiceTheme,
        contentWidth: CGFloat
    ) -> Footer {
        Footer(height: footerHeight(lines: lines, contentWidth: contentWidth)) {
            HRule(thickness: 0.5, color: PDFColor(white: 0.82))
            Spacer(height: 4)
            for line in lines {
                Text(line)
                    .font(theme.bodyFont, size: 8)
                    .alignment(.trailing)
                    .color(DocumentLayoutKit.mutedText)
            }
            Text(common.pageNumber(page, of: pageCount))
                .font(theme.bodyFont, size: 8)
                .alignment(.trailing)
                .color(DocumentLayoutKit.mutedText)
        }
    }

    /// The footer's height with each line's estimated wrap counted.
    static func footerHeight(lines: [String], contentWidth: CGFloat) -> CGFloat {
        let lineCount = lines.reduce(0) { $0 + max(1, estimatedLineCount($1, width: contentWidth, fontSize: 8)) }
        return CGFloat(lineCount) * 12 + 12 + 22
    }
}
