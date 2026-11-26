import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - PurchaseOrderLayout + table, breakdown, totals, footer, page fit

/// The lines table (rows of wrapping, stacked cells with a real gutter box
/// between every two columns), the page planner, the tax breakdown, the totals
/// stack, the footer and the page-fit accounting. Split out of
/// `PurchaseOrderLayout.swift` only to keep each file and type body inside the
/// lint limits; it is the same enum.
///
/// The kit's own page planner, footer and totals ladder are bound to the
/// invoice model, and the kit's hairline table draws single-line cells, so
/// these jobs are composed here from the plain primitives instead.
extension PurchaseOrderLayout {

    // MARK: Geometry

    /// The table's cells are drawn in this face at these sizes on every theme,
    /// so the column widths below stay true to what they were sized against.
    static let lineCellFont: PDFFont = .helvetica
    static let lineCellFontSize: CGFloat = 9
    static let lineSubLineFontSize: CGFloat = 8

    /// A real, empty box between every two columns — not the flex `gap`, which
    /// the HTML path expresses as CSS `gap` — so the separation is the same on
    /// both render paths.
    static let lineGutter: CGFloat = 6

    /// Vertical padding above and below a row's cells.
    static let lineRowPadding: CGFloat = 4.5

    /// Fixed widths of the item and the five numeric columns; the description
    /// column takes the rest (153 pt on A4 at 40 pt margins).
    static let lineItemWidth: CGFloat = 72
    static let lineFixedWidths: [CGFloat] = [48, 58, 42, 38, 68]

    /// Width of each of the seven columns for a table `contentWidth` wide; the
    /// description column never narrows below the item column.
    static func lineColumnWidths(contentWidth: CGFloat) -> [CGFloat] {
        let fixed = lineItemWidth + lineFixedWidths.reduce(0, +) + lineGutter * 6
        return [lineItemWidth, max(contentWidth - fixed, lineItemWidth)] + lineFixedWidths
    }

    static let lineAlignments: [TextAlignment] = [
        .leading, .leading, .trailing, .trailing, .trailing, .trailing, .trailing,
    ]

    // MARK: Cell content

    /// One string of a stacked cell; a sub-line is drawn smaller and muted.
    struct CellLine {
        let text: String
        var isSubLine: Bool = false
    }

    /// One table row, already formatted: a stack of lines per column.
    struct PurchaseOrderLineCells {
        let columns: [[CellLine]]
    }

    /// Formats one order line. Item: the SKU (a sub-line) over the name.
    /// Description: the description, then the line's own expected-delivery
    /// date and its note as sub-lines. A unit is printed only when the line
    /// has one; a `nil` or zero discount and a `nil` tax rate print nothing.
    static func lineCells(
        _ line: PurchaseOrderDocumentLine,
        labels: PurchaseOrderLabels,
        fmt: DocumentFormatter,
        locale: Locale
    ) -> PurchaseOrderLineCells {
        var item: [CellLine] = []
        if let sku = nonBlank(line.itemSKU) { item.append(CellLine(text: sku, isSubLine: true)) }
        if let name = nonBlank(line.itemName) { item.append(CellLine(text: name)) }

        var description: [CellLine] = []
        if let text = nonBlank(line.description) { description.append(CellLine(text: text)) }
        if let date = nonBlank(line.expectedDelivery) {
            description.append(CellLine(text: labels.lineExpectedDelivery(date: date), isSubLine: true))
        }
        if let note = nonBlank(line.note) { description.append(CellLine(text: note, isSubLine: true)) }

        var quantity = fmt.quantity(line.quantity)
        if let unit = nonBlank(line.unitOfMeasure) { quantity += " " + unit }
        let unitCost = line.unitCost.formatted(.number.precision(.fractionLength(2...4)).locale(locale))
        let discount = line.discountPercent.flatMap { $0 == 0 ? nil : fmt.percent($0) } ?? ""
        let taxRate = line.taxRatePercent.map { fmt.percent($0) } ?? ""

        return PurchaseOrderLineCells(columns: [
            item, description,
            [CellLine(text: quantity)], [CellLine(text: unitCost)], [CellLine(text: discount)],
            [CellLine(text: taxRate)], [CellLine(text: fmt.amount(line.lineTotal))],
        ])
    }

    /// The header row's cells: the seven column captions.
    static func headerCells(_ labels: PurchaseOrderLabels) -> PurchaseOrderLineCells {
        PurchaseOrderLineCells(columns: [
            labels.linesColumnItem, labels.linesColumnDescription, labels.linesColumnQuantity,
            labels.linesColumnUnitCost, labels.linesColumnDiscount, labels.linesColumnTaxRate,
            labels.linesColumnLineTotal,
        ].map { [CellLine(text: $0)] })
    }

    // MARK: Rows

    /// One row: padding, then the cells side by side with a gutter box between
    /// every two, then padding. Each column stacks one wrapping cell per line,
    /// so the row is as tall as its tallest stack.
    static func wrappingRow(
        _ columns: [[CellLine]],
        widths: [ColumnWidth],
        alignments: [TextAlignment],
        isHeader: Bool
    ) -> [any PDFContent] {
        var items: [ColumnItem] = []
        for index in widths.indices {
            if index > 0 {
                items.append(ColumnItem(width: .fixed(lineGutter)) { Spacer(height: 0) })
            }
            let stack = index < columns.count ? columns[index] : []
            let cells: [any PDFContent] = stack.isEmpty
                ? [Spacer(height: 0)]
                : stack.map { cellText($0, alignment: alignments[index], isHeader: isHeader) }
            items.append(ColumnItem(width: widths[index]) {
                for cell in cells { cell }
            })
        }
        return [
            Spacer(height: lineRowPadding),
            Columns(spacing: 0) {
                for item in items { item }
            },
            Spacer(height: lineRowPadding),
        ]
    }

    private static func cellText(_ line: CellLine, alignment: TextAlignment, isHeader: Bool) -> any PDFContent {
        var text = Text(line.text)
            .font(lineCellFont, size: line.isSubLine ? lineSubLineFontSize : lineCellFontSize)
            .alignment(alignment)
        if isHeader {
            text = text.bold().color(PDFColor(white: 0.4))
        } else if line.isSubLine {
            text = text.color(DocumentLayoutKit.mutedText)
        }
        return PurchaseOrderWrappingCell(text: text)
    }

    static func lineRow(_ cells: PurchaseOrderLineCells, isHeader: Bool) -> [any PDFContent] {
        let widths: [ColumnWidth] = [.fixed(lineItemWidth), .flex] + lineFixedWidths.map { .fixed($0) }
        return wrappingRow(cells.columns, widths: widths, alignments: lineAlignments, isHeader: isHeader)
    }

    // MARK: Estimates

    /// Estimated height of one row: the tallest column's stacked estimated
    /// lines at 1.25 × their size, plus the row padding. Cross-platform (the
    /// server paginates on Linux, where there is no CoreText).
    static func lineRowHeight(_ cells: PurchaseOrderLineCells, contentWidth: CGFloat) -> CGFloat {
        stackedHeight(cells.columns, widths: lineColumnWidths(contentWidth: contentWidth))
            + lineRowPadding * 2
    }

    static func stackedHeight(_ columns: [[CellLine]], widths: [CGFloat]) -> CGFloat {
        var tallest = lineCellFontSize * 1.25
        for (stack, width) in zip(columns, widths) {
            let height = stack.reduce(CGFloat(0)) { sum, line in
                let size = line.isSubLine ? lineSubLineFontSize : lineCellFontSize
                return sum + CGFloat(estimatedLineCount(line.text, width: width, fontSize: size)) * size * 1.25
            }
            tallest = max(tallest, height)
        }
        return tallest
    }

    /// Lines `text` takes when wrapped into `width` — an over-estimate.
    ///
    /// Break opportunities are after a space, `-` or `/`; a unit wider than
    /// the line is broken by character, as both render paths do. Glyph widths
    /// sit above Helvetica Bold's per-class average (digits, punctuation and
    /// spaces 0.56 em, lower case 0.6 em, upper case and anything else
    /// 0.78 em), so the estimate breaks a page early rather than late.
    static func estimatedLineCount(_ text: String, width: CGFloat, fontSize: CGFloat) -> Int {
        guard !text.isEmpty else { return 0 }
        guard width > 0 else { return 1 }
        func glyphWidth(_ char: Character) -> CGFloat {
            let ems: CGFloat
            if char.isNumber || char.isPunctuation || char.isWhitespace {
                ems = 0.56
            } else if char.isLowercase {
                ems = 0.6
            } else {
                ems = 0.78
            }
            return ems * fontSize
        }
        var units: [[CGFloat]] = [[]]
        for char in text {
            units[units.count - 1].append(glyphWidth(char))
            if char == " " || char == "-" || char == "/" {
                units.append([])
            }
        }
        var lines = 1
        var used: CGFloat = 0
        for unit in units where !unit.isEmpty {
            let unitWidth = unit.reduce(0, +)
            if used + unitWidth <= width {
                used += unitWidth
                continue
            }
            if used > 0 {
                lines += 1
                used = 0
            }
            for glyph in unit {
                if used + glyph > width && used > 0 {
                    lines += 1
                    used = 0
                }
                used += glyph
            }
        }
        return lines
    }

    /// Height the lines table costs on a page besides its body rows: the
    /// continued marker, two hairlines and the header row, which may wrap.
    static func linesTableOverhead(labels: PurchaseOrderLabels, contentWidth: CGFloat) -> CGFloat {
        12 + (0.8 + 4) + (0.5 + 4) + lineRowHeight(headerCells(labels), contentWidth: contentWidth)
    }

    // MARK: Page planning

    /// Splits row indices into per-page chunks by **height**: page 1 holds what
    /// fits in `bodyH − page1Overhead − tableOverhead`, a continuation page
    /// what fits in `bodyH − tableOverhead`. A row is never split. When the
    /// closing blocks do not fit beside the last chunk an empty chunk is
    /// appended — a closing-only page. No rows yields `[[]]`: one page carrying
    /// the table's empty state. Biased to break early.
    static func paginate(
        rowHeights: [CGFloat],
        emptyStateHeight: CGFloat,
        bodyHeight bodyH: CGFloat,
        page1Overhead: CGFloat,
        tableOverhead: CGFloat,
        bottomHeight: CGFloat
    ) -> [[Int]] {
        let p1Capacity = bodyH - page1Overhead - tableOverhead
        let contCapacity = bodyH - tableOverhead

        var chunks: [[Int]] = [[]]
        var used: CGFloat = 0
        for (index, rowH) in rowHeights.enumerated() {
            let capacity = chunks.count == 1 ? p1Capacity : contCapacity
            if !chunks[chunks.count - 1].isEmpty && used + rowH > capacity {
                chunks.append([index])
                used = rowH
            } else {
                chunks[chunks.count - 1].append(index)
                used += rowH
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

    // MARK: Lines table

    /// The lines table for one page: on a continuation page the continued
    /// marker, then the hairline, the header row (drawn on every page that
    /// renders through here), the body rows — or, with none, the explicit
    /// empty-state line — and the closing hairline.
    static func linesTable(
        _ rows: [PurchaseOrderLineCells],
        labels: PurchaseOrderLabels,
        common: CommonDocumentLabels,
        theme: InvoiceTheme,
        continued: Bool
    ) -> [any PDFContent] {
        var contents: [any PDFContent] = []
        if continued {
            contents.append(
                Text(common.continuedLabel)
                    .font(theme.bodyFont, size: 8)
                    .color(DocumentLayoutKit.mutedText))
            contents.append(Spacer(height: 4))
        }
        contents.append(HRule(thickness: 0.8, color: PDFColor(white: 0.15)))
        contents += lineRow(headerCells(labels), isHeader: true)
        for row in rows {
            contents += lineRow(row, isHeader: false)
        }
        if rows.isEmpty {
            contents.append(Spacer(height: 6))
            contents.append(
                Text(labels.linesEmptyRow)
                    .font(theme.bodyFont, size: theme.bodyFontSize - 1)
                    .color(DocumentLayoutKit.mutedText))
            contents.append(Spacer(height: 4))
        }
        contents.append(HRule(thickness: 0.5, color: PDFColor(white: 0.8)))
        return contents
    }

    // MARK: Tax breakdown

    static let taxBreakdownWidth: CGFloat = 260
    static let taxAmountWidth: CGFloat = 90

    /// The rows of the breakdown, header first: rate (or the tax's own name),
    /// taxable base, tax amount.
    static func taxBreakdownCells(
        _ rows: [PurchaseOrderDocumentTaxRow], labels: PurchaseOrderLabels, fmt: DocumentFormatter
    ) -> [[[CellLine]]] {
        let header = [labels.taxColumnRate, labels.taxColumnBase, labels.taxColumnAmount]
        let body = rows.map { row in
            [nonBlank(row.name) ?? fmt.percent(row.ratePercent), fmt.amount(row.taxableBase), fmt.amount(row.taxAmount)]
        }
        return ([header] + body).map { $0.map { [CellLine(text: $0)] } }
    }

    /// A left-half three-column breakdown under its caption.
    static func taxBreakdown(
        _ rows: [PurchaseOrderDocumentTaxRow],
        labels: PurchaseOrderLabels,
        theme: InvoiceTheme,
        fmt: DocumentFormatter
    ) -> [any PDFContent] {
        let widths: [ColumnWidth] = [.flex, .fixed(taxAmountWidth), .fixed(taxAmountWidth)]
        let alignments: [TextAlignment] = [.leading, .trailing, .trailing]
        var table: [any PDFContent] = [
            Text(labels.taxBreakdownHeader)
                .font(theme.bodyFont, size: 8)
                .bold()
                .color(DocumentLayoutKit.mutedText),
            Spacer(height: 3),
            HRule(thickness: 0.5, color: PDFColor(white: 0.8)),
        ]
        for (index, cells) in taxBreakdownCells(rows, labels: labels, fmt: fmt).enumerated() {
            table += wrappingRow(cells, widths: widths, alignments: alignments, isHeader: index == 0)
        }
        table.append(HRule(thickness: 0.5, color: PDFColor(white: 0.8)))
        return [
            Columns(spacing: 0) {
                ColumnItem(width: .fixed(taxBreakdownWidth)) {
                    for item in table { item }
                }
                ColumnItem(width: .flex) { Spacer(height: 0) }
            },
        ]
    }

    /// Height ``taxBreakdown(_:labels:theme:fmt:)`` takes.
    static func taxBreakdownHeight(
        _ rows: [PurchaseOrderDocumentTaxRow], labels: PurchaseOrderLabels, fmt: DocumentFormatter
    ) -> CGFloat {
        let rateWidth = taxBreakdownWidth - taxAmountWidth * 2 - lineGutter * 2
        let widths = [rateWidth, taxAmountWidth, taxAmountWidth]
        let rowsH = taxBreakdownCells(rows, labels: labels, fmt: fmt).reduce(CGFloat(0)) {
            $0 + stackedHeight($1, widths: widths) + lineRowPadding * 2
        }
        return 8 * 1.2 + 3 + (0.5 + 4) * 2 + rowsH
    }

    // MARK: Totals stack

    /// One totals row, already formatted.
    struct TotalsRow {
        let caption: String
        let value: String
        var emphasised: Bool = false
    }

    /// Subtotal · discount (non-zero only) · shipping (non-zero only) · tax
    /// (**always**, a zero included) · total. Captions are the common family's
    /// except shipping; every value carries the ISO code, never a symbol.
    static func totalsRows(
        _ totals: PurchaseOrderDocumentTotals,
        labels: PurchaseOrderLabels,
        common: CommonDocumentLabels,
        fmt: DocumentFormatter
    ) -> [TotalsRow] {
        func value(_ amount: Double) -> String { fmt.amount(amount) + " " + totals.currencyCode }
        var rows = [TotalsRow(caption: common.totalsSubtotalLabel, value: value(totals.subtotal))]
        if let discount = totals.discount, discount != 0 {
            rows.append(TotalsRow(caption: common.totalsDiscountLabel, value: value(discount)))
        }
        if let shipping = totals.shipping, shipping != 0 {
            rows.append(TotalsRow(caption: labels.shippingLabel, value: value(shipping)))
        }
        rows.append(TotalsRow(caption: common.totalsTaxLabel, value: value(totals.tax)))
        rows.append(TotalsRow(caption: common.totalsTotalLabel, value: value(totals.total), emphasised: true))
        return rows
    }

    /// A right-half caption / value stack with a hairline above every
    /// emphasised row.
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
                    ColumnItem(width: .flex) { totalsCell(row.caption, theme: theme, bold: row.emphasised) }
                    ColumnItem(width: .fixed(110)) { totalsCell(row.value, theme: theme, bold: row.emphasised) }
                })
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

    /// Hairline, the family's lines (leading; they may wrap), then the page
    /// line from ``CommonDocumentLabels/pageNumber(_:of:)``.
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
                    .alignment(.leading)
                    .color(DocumentLayoutKit.mutedText)
            }
            Text(common.pageNumber(page, of: pageCount))
                .font(theme.bodyFont, size: 8)
                .alignment(.trailing)
                .color(DocumentLayoutKit.mutedText)
        }
    }

    /// The footer's height, reserved per **estimated** line so a wrapped long
    /// footer stays on the page, plus the page line and the rule and spacer
    /// above them. Under-reserving lets the page line fall off the page.
    static func footerHeight(lines: [String], contentWidth: CGFloat) -> CGFloat {
        let lineCount = lines.reduce(0) { $0 + estimatedLineCount($1, width: contentWidth, fontSize: 8) }
        return CGFloat(lineCount) * 12 + 12 + 22
    }

    // MARK: Page-fit accounting — no design authority

    /// Height consumed on page 1 before the lines table: masthead, header grid,
    /// the cancellation notice, the taller of the two party columns, the
    /// deliver-to block and the metadata grid.
    static func page1Overhead(
        _ document: PurchaseOrderDocument, theme: InvoiceTheme, contentWidth: CGFloat
    ) -> CGFloat {
        let lineH = theme.bodyFontSize * 1.2
        let smallH: CGFloat = 8 * 1.2
        let columnWidth = (contentWidth - 24) / 2
        let gridRowH = smallH + lineH + 6
        let mastheadH = max(theme.logoMaxHeight, DocumentLayoutKit.modernTitleSize * 1.2) + 14
        let noticeH: CGFloat = cancellationNotice(document) != nil ? lineH * 2 + 8 : 0

        func smallRunH(_ run: [String?]) -> CGFloat {
            let parts = run.compactMap { $0 }
            guard !parts.isEmpty else { return 0 }
            let joined = parts.joined(separator: DocumentLayoutKit.separator)
            return 4 + CGFloat(estimatedLineCount(joined, width: columnWidth, fontSize: 8)) * smallH
        }
        let issuer = document.issuer
        let addressCount = [issuer.street, issuer.city, issuer.country].compactMap { $0 }.count
        let issuerH = smallH + 3 + theme.titleFontSize * 1.2 + CGFloat(addressCount) * lineH
            + smallRunH([issuer.vatNumber, DocumentLayoutKit.registrationNumber(for: issuer)])
            + smallRunH([issuer.phone, issuer.email, issuer.website])

        let extras = vendorExtras(document).count
        let vendorH = partyBlockHeight(document.vendor.party, theme: theme)
            + (extras > 0 ? 4 + CGFloat(extras) * smallH : 0)
        let partiesH = max(issuerH, vendorH) + 10 + 18

        var deliverToH: CGFloat = 0
        if let deliverTo = document.deliverTo, isDeliverToRendered(deliverTo) {
            deliverToH = 12
            if let warehouse = deliverTo.warehouse {
                deliverToH += partyBlockHeight(warehouse, theme: theme)
                    + (nonBlank(deliverTo.warehouseCode) != nil ? smallH : 0)
            } else {
                deliverToH += smallH + 3
            }
            if let address = nonBlank(deliverTo.deliveryAddress) {
                deliverToH += 4 + CGFloat(estimatedLineCount(
                    address, width: columnWidth, fontSize: theme.bodyFontSize)) * lineH
            }
        }

        let metaRows = (document.metadataRows.count + 2) / 3
        let metadataH = metaRows == 0 ? 0 : CGFloat(metaRows) * gridRowH + 6
        return mastheadH + gridRowH + noticeH + partiesH + deliverToH + metadataH
    }

    /// Height of a ``DocumentLayoutKit/partyBlock(party:header:labels:theme:)``.
    static func partyBlockHeight(_ party: InvoiceParty, theme: InvoiceTheme) -> CGFloat {
        let lines = [party.attention, party.street, party.city, party.country, party.vatNumber]
            .compactMap { $0 }.count
        return 8 * 1.2 + 3 + CGFloat(1 + lines) * theme.bodyFontSize * 1.2
    }

    /// Height of the last page's closing blocks, with a slack that biases the
    /// planner to break early rather than draw through the footer.
    static func bottomHeight(
        _ document: PurchaseOrderDocument, theme: InvoiceTheme, fmt: DocumentFormatter, contentWidth: CGFloat
    ) -> CGFloat {
        let lineH = theme.bodyFontSize * 1.2
        var height: CGFloat = 10
        if document.closedShortOmittedCount > 0 {
            height += lineH * 2 + 8
        }
        if !document.taxRows.isEmpty {
            height += taxBreakdownHeight(document.taxRows, labels: document.labels, fmt: fmt) + 10
        }
        let rows = totalsRows(document.totals, labels: document.labels, common: document.common, fmt: fmt)
        height += totalsStackHeight(count: rows.count, emphasised: rows.filter(\.emphasised).count, theme: theme)
        if let instructions = nonBlank(document.specialInstructions) {
            height += 12 + 8 * 1.2 + CGFloat(estimatedLineCount(
                instructions, width: contentWidth, fontSize: theme.bodyFontSize)) * lineH
        }
        return height + 28
    }
}

// MARK: - PurchaseOrderWrappingCell

/// A table cell that wraps inside its column on both render paths.
///
/// CoreGraphics: ``Text`` already wraps through a framesetter, which breaks a
/// unit wider than the line by character. HTML: the ``Text`` `div` wraps at
/// spaces and hyphens, but an unbroken run wider than the column would spill
/// into the next one, so the cell adds `word-wrap` / `overflow-wrap:
/// break-word` (the first is the spelling `wkhtmltopdf`'s WebKit reads). No
/// `overflow:hidden` and no `nowrap`: nothing is ever clipped.
private struct PurchaseOrderWrappingCell: PDFContent {
    let text: Text

    #if canImport(CoreGraphics)
    func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {
        text.draw(in: context, bounds: bounds, cursor: &cursor)
    }
    #endif

    func renderHTML(bounds: CGRect, cursor: inout CGFloat) -> String {
        "<div style=\"word-wrap:break-word;overflow-wrap:break-word;\">"
            + text.renderHTML(bounds: bounds, cursor: &cursor)
            + "</div>"
    }
}
