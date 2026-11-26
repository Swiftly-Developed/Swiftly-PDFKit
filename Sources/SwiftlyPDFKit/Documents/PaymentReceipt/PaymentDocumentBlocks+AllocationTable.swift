import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - PaymentDocumentBlocks + allocation table

/// The allocation table (PRINT02 phase 00c): rows of wrapping cells with a real
/// gutter box between every two columns, and the page-fit estimate of a row's
/// height. Split out of `PaymentDocumentBlocks.swift` only to keep each file
/// and type body inside the lint limits; it is the same enum.
extension PaymentDocumentBlocks {

    // MARK: Allocation table geometry

    /// The allocation table's cells are drawn in this face at this size on
    /// every theme, so the column widths below stay true to what they were
    /// measured against (the hairline table drew Helvetica regardless of theme).
    static let allocationCellFont: PDFFont = .helvetica
    static let allocationCellFontSize: CGFloat = 9

    /// A real, empty box between every two columns — not the flex `gap`, which
    /// is a `Columns` spacing the HTML path expresses as CSS `gap` — so the
    /// separation is the same on both render paths.
    static let allocationGutter: CGFloat = 8

    /// Fixed widths of the five columns after the document column, which takes
    /// the rest. Measured at 9 pt Helvetica with CoreText (PRINT02 phase 00c
    /// §0): the widest date the mappers print (`Sept 30, 2026`) is 56.0 pt; the
    /// widest amount a seven-digit figure prints (`9,999,999.99 EUR`) is
    /// 74.1 pt; the widest single header word in bold across the 16 catalog
    /// columns (`Gesamtbetrag`) is 60.5 pt. A longer value wraps inside its
    /// column instead of reaching the next one.
    static let allocationDateWidth: CGFloat = 60
    static let allocationAmountWidth: CGFloat = 78

    /// Vertical padding above and below a row's cells; with one 9 pt line the
    /// row is the hairline table's 20 pt.
    static let allocationRowPadding: CGFloat = 4.5

    /// Width of each of the six columns for a table `contentWidth` wide.
    static func allocationColumnWidths(contentWidth: CGFloat) -> [CGFloat] {
        let fixed = allocationDateWidth + allocationAmountWidth * 4 + allocationGutter * 5
        return [max(contentWidth - fixed, allocationAmountWidth), allocationDateWidth]
            + Array(repeating: allocationAmountWidth, count: 4)
    }

    private static let allocationAlignments: [TextAlignment] = [
        .leading, .leading, .trailing, .trailing, .trailing, .trailing,
    ]

    /// Estimated height of one display row (header or body): the tallest
    /// cell's estimated line count, plus the row padding.
    ///
    /// Cross-platform (the server paginates on Linux, where there is no
    /// CoreText), so the line count is a greedy wrap over conservative glyph
    /// widths — ``estimatedLineCount(_:width:fontSize:)`` — and the line
    /// height is 1.25 × the size (CoreText draws a 9 pt Helvetica line in
    /// 11.0 pt, HTML in 10.8 pt).
    static func allocationRowHeight(_ cells: [String], contentWidth: CGFloat) -> CGFloat {
        let widths = allocationColumnWidths(contentWidth: contentWidth)
        var lines = 1
        for (cell, width) in zip(cells, widths) {
            lines = max(lines, estimatedLineCount(cell, width: width, fontSize: allocationCellFontSize))
        }
        return CGFloat(lines) * allocationCellFontSize * 1.25 + allocationRowPadding * 2
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

    // MARK: Allocation table

    /// The allocation section for one page: title, hairlines, the header row
    /// (drawn on every page that renders through here) and the body rows.
    ///
    /// Every cell wraps within its own column on both render paths and every
    /// two columns are separated by ``allocationGutter``, so a long document
    /// number or a long localized header grows its row instead of reaching the
    /// next column. An empty `rows` renders the header row followed by the
    /// explicit empty-state line — never a blank body.
    static func allocationTable(
        _ rows: [[String]],
        labels: PaymentReceiptLabels,
        common: CommonDocumentLabels,
        theme: InvoiceTheme,
        continued: Bool
    ) -> [any PDFContent] {
        let title = continued
            ? labels.allocationSectionTitle + " — " + common.continuedLabel
            : labels.allocationSectionTitle
        let header = [
            labels.allocationColumnDocument, labels.allocationColumnDocumentDate,
            labels.allocationColumnDocumentTotal, labels.allocationColumnOtherPayments,
            labels.allocationColumnApplied, labels.allocationColumnRemaining,
        ]
        var contents: [any PDFContent] = [
            Text(title)
                .font(theme.bodyFont, size: DocumentLayoutKit.modernSectionSize)
                .bold(),
            Spacer(height: 6),
            HRule(thickness: 0.8, color: PDFColor(white: 0.15)),
        ]
        contents += allocationRow(header, isHeader: true)
        for row in rows {
            contents += allocationRow(row, isHeader: false)
        }
        if rows.isEmpty {
            contents.append(Spacer(height: 6))
            contents.append(
                Text(labels.allocationEmptyRow)
                    .font(theme.bodyFont, size: theme.bodyFontSize - 1)
                    .color(DocumentLayoutKit.mutedText)
            )
            contents.append(Spacer(height: 4))
        }
        contents.append(HRule(thickness: 0.5, color: PDFColor(white: 0.8)))
        return contents
    }

    /// One table row: padding, then the six cells side by side with a gutter
    /// box between every two, then padding. The row is as tall as its tallest
    /// cell.
    static func allocationRow(_ cells: [String], isHeader: Bool) -> [any PDFContent] {
        var items: [ColumnItem] = []
        for index in allocationAlignments.indices {
            if index > 0 {
                items.append(ColumnItem(width: .fixed(allocationGutter)) { Spacer(height: 0) })
            }
            let string = index < cells.count ? cells[index] : ""
            var text = Text(string)
                .font(allocationCellFont, size: allocationCellFontSize)
                .alignment(allocationAlignments[index])
            text = isHeader ? text.bold().color(PDFColor(white: 0.4)) : text
            let width: ColumnWidth = index == 0
                ? .flex
                : .fixed(index == 1 ? allocationDateWidth : allocationAmountWidth)
            items.append(ColumnItem(width: width) { WrappingCell(text: text) })
        }
        return [
            Spacer(height: allocationRowPadding),
            Columns(spacing: 0) {
                for item in items { item }
            },
            Spacer(height: allocationRowPadding),
        ]
    }

    /// Height ``allocationTable(_:labels:common:theme:continued:)`` costs on a
    /// page besides its body rows: title + spacer + two hairlines + the header
    /// row, which may wrap to more than one line.
    static func allocationTableOverhead(
        labels: PaymentReceiptLabels, contentWidth: CGFloat
    ) -> CGFloat {
        let header = [
            labels.allocationColumnDocument, labels.allocationColumnDocumentDate,
            labels.allocationColumnDocumentTotal, labels.allocationColumnOtherPayments,
            labels.allocationColumnApplied, labels.allocationColumnRemaining,
        ]
        return DocumentLayoutKit.modernSectionSize * 1.2 + 6 + (0.8 + 4) + (0.5 + 4)
            + allocationRowHeight(header, contentWidth: contentWidth)
    }
}

// MARK: - WrappingCell

/// A table cell that wraps inside its column on both render paths.
///
/// CoreGraphics: ``Text`` already wraps through a framesetter, which breaks a
/// unit wider than the line by character. HTML: the ``Text`` `div` wraps at
/// spaces and hyphens, but an unbroken run wider than the column would spill
/// into the next one, so the cell adds `word-wrap` / `overflow-wrap:
/// break-word` (the first is the spelling `wkhtmltopdf`'s WebKit reads). No
/// `overflow:hidden` and no `nowrap`: nothing is ever clipped.
private struct WrappingCell: PDFContent {
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

// MARK: Stacked allocation rows (PRINT03 — additive; the receipt never calls these)

/// The same six-column atom for a family whose cells stack more than one line
/// (the remittance advice's document cell, PRINT03). Written beside
/// ``WrappingCell`` because that cell is file-private; every receipt builder
/// above is untouched, so the receipt keeps calling exactly the code it did.
extension PaymentDocumentBlocks {

    /// Size of every line after the first in a stacked cell.
    static let allocationSubLineFontSize: CGFloat = 8

    /// One table row whose cells each stack one or more lines: the first at
    /// the cell size, every later line smaller and muted (header: bold grey).
    /// A cell with one line renders exactly as ``allocationRow(_:isHeader:)``.
    ///
    /// `documentSpan` lets the first cell take that many columns' width: the
    /// columns it spans are not drawn, the rest stay where they are. A row whose
    /// spanned cells are blank (the advice's member list, PRINT03 §25 #48) stops
    /// wrapping a long id without moving its figure. `1` is the plain six-column
    /// atom.
    static func allocationRow(
        stacked cells: [[String]], isHeader: Bool, documentSpan: Int = 1
    ) -> [any PDFContent] {
        var items: [ColumnItem] = []
        for index in allocationAlignments.indices where index == 0 || index >= documentSpan {
            if index > 0 {
                items.append(ColumnItem(width: .fixed(allocationGutter)) { Spacer(height: 0) })
            }
            let lines = index < cells.count && !cells[index].isEmpty ? cells[index] : [""]
            var texts: [Text] = []
            for (lineIndex, line) in lines.enumerated() {
                let size = lineIndex == 0 ? allocationCellFontSize : allocationSubLineFontSize
                var text = Text(line)
                    .font(allocationCellFont, size: size)
                    .alignment(allocationAlignments[index])
                if isHeader {
                    text = text.bold().color(PDFColor(white: 0.4))
                } else if lineIndex > 0 {
                    text = text.color(DocumentLayoutKit.mutedText)
                }
                texts.append(text)
            }
            let width: ColumnWidth = index == 0
                ? .flex
                : .fixed(index == 1 ? allocationDateWidth : allocationAmountWidth)
            items.append(ColumnItem(width: width) { for text in texts { WrappingCell(text: text) } })
        }
        return [
            Spacer(height: allocationRowPadding),
            Columns(spacing: 0) {
                for item in items { item }
            },
            Spacer(height: allocationRowPadding),
        ]
    }

    /// Estimated height of one stacked row: per column, the sum of its lines'
    /// estimated heights; the row is its tallest column plus the padding.
    /// `documentSpan` as in ``allocationRow(stacked:isHeader:documentSpan:)``.
    static func allocationRowHeight(
        stacked cells: [[String]], contentWidth: CGFloat, documentSpan: Int = 1
    ) -> CGFloat {
        var widths = allocationColumnWidths(contentWidth: contentWidth)
        if documentSpan > 1 {
            widths[0] = widths.prefix(documentSpan).reduce(0, +) + allocationGutter * CGFloat(documentSpan - 1)
        }
        var tallest = allocationCellFontSize * 1.25
        for (lines, width) in zip(cells, widths) {
            var height: CGFloat = 0
            for (lineIndex, line) in lines.enumerated() {
                let size = lineIndex == 0 ? allocationCellFontSize : allocationSubLineFontSize
                height += CGFloat(estimatedLineCount(line, width: width, fontSize: size)) * size * 1.25
            }
            tallest = max(tallest, height)
        }
        return tallest + allocationRowPadding * 2
    }

    /// The allocation section for one page with a caller-supplied title, header
    /// and empty-state line, its rows' cells stacking lines through
    /// ``allocationRow(stacked:isHeader:)``. With one line per cell and the
    /// receipt's own title, header and empty row it renders exactly as
    /// ``allocationTable(_:labels:common:theme:continued:)``.
    static func allocationTable(
        stackedRows: [[[String]]],
        title: String,
        header: [[String]],
        emptyRow: String,
        common: CommonDocumentLabels,
        theme: InvoiceTheme,
        continued: Bool,
        documentSpan: Int = 1
    ) -> [any PDFContent] {
        let shownTitle = continued ? title + " — " + common.continuedLabel : title
        var contents: [any PDFContent] = [
            Text(shownTitle)
                .font(theme.bodyFont, size: DocumentLayoutKit.modernSectionSize)
                .bold(),
            Spacer(height: 6),
            HRule(thickness: 0.8, color: PDFColor(white: 0.15)),
        ]
        contents += allocationRow(stacked: header, isHeader: true, documentSpan: documentSpan)
        for row in stackedRows {
            contents += allocationRow(stacked: row, isHeader: false, documentSpan: documentSpan)
        }
        if stackedRows.isEmpty {
            contents.append(Spacer(height: 6))
            contents.append(
                Text(emptyRow)
                    .font(theme.bodyFont, size: theme.bodyFontSize - 1)
                    .color(DocumentLayoutKit.mutedText)
            )
            contents.append(Spacer(height: 4))
        }
        contents.append(HRule(thickness: 0.5, color: PDFColor(white: 0.8)))
        return contents
    }

    /// Height ``allocationTable(stackedRows:title:header:emptyRow:common:theme:continued:documentSpan:)``
    /// costs on a page besides its body rows: the title (which may wrap),
    /// spacer, two hairlines and the stacked header row.
    static func allocationTableOverhead(
        title: String, header: [[String]], contentWidth: CGFloat, documentSpan: Int = 1
    ) -> CGFloat {
        let titleLines = max(1, estimatedLineCount(
            title, width: contentWidth, fontSize: DocumentLayoutKit.modernSectionSize))
        return CGFloat(titleLines) * DocumentLayoutKit.modernSectionSize * 1.2 + 6 + (0.8 + 4) + (0.5 + 4)
            + allocationRowHeight(stacked: header, contentWidth: contentWidth, documentSpan: documentSpan)
    }
}
