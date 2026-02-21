import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(CoreText)
import CoreText
import CoreFoundation
#endif

// MARK: - ColumnWidth

public enum ColumnWidth: Sendable {
    case fixed(CGFloat)
    case flex
}

// MARK: - Column

public struct Column {
    public let header: String
    public let width: ColumnWidth
    public let alignment: TextAlignment
    public let headerAlignment: TextAlignment

    public init(
        _ header: String,
        width: ColumnWidth = .flex,
        alignment: TextAlignment = .leading,
        headerAlignment: TextAlignment? = nil
    ) {
        self.header = header
        self.width = width
        self.alignment = alignment
        self.headerAlignment = headerAlignment ?? alignment
    }
}

// MARK: - ColumnBuilder

@resultBuilder
public struct ColumnBuilder {
    public static func buildBlock(_ columns: Column...) -> [Column] { columns }
}

// MARK: - TableStyle

public struct TableStyle: Sendable {
    public var headerBackground: PDFColor
    public var headerTextColor: PDFColor
    public var headerFontSize: CGFloat
    public var cellFontSize: CGFloat
    public var rowHeight: CGFloat
    public var alternateRowColor: PDFColor?
    public var borderColor: PDFColor
    public var borderWidth: CGFloat
    public var cellPadding: CGFloat
    /// When true, data cells are rendered in bold.
    public var cellBold: Bool

    public static let `default` = TableStyle(
        headerBackground: PDFColor(white: 0.85),
        headerTextColor: .black,
        headerFontSize: 10,
        cellFontSize: 10,
        rowHeight: 20,
        alternateRowColor: nil,
        borderColor: PDFColor(white: 0.7),
        borderWidth: 0.25,
        cellPadding: 4,
        cellBold: false
    )

    #if canImport(CoreGraphics)
    public init(
        headerBackground: CGColor = CGColor(gray: 0.85, alpha: 1),
        headerTextColor: CGColor = CGColor(gray: 0, alpha: 1),
        headerFontSize: CGFloat = 10,
        cellFontSize: CGFloat = 10,
        rowHeight: CGFloat = 20,
        alternateRowColor: CGColor? = nil,
        borderColor: CGColor = CGColor(gray: 0.7, alpha: 1),
        borderWidth: CGFloat = 0.25,
        cellPadding: CGFloat = 4,
        cellBold: Bool = false
    ) {
        self.headerBackground = PDFColor(cgColor: headerBackground)
        self.headerTextColor = PDFColor(cgColor: headerTextColor)
        self.headerFontSize = headerFontSize
        self.cellFontSize = cellFontSize
        self.rowHeight = rowHeight
        self.alternateRowColor = alternateRowColor.map { PDFColor(cgColor: $0) }
        self.borderColor = PDFColor(cgColor: borderColor)
        self.borderWidth = borderWidth
        self.cellPadding = cellPadding
        self.cellBold = cellBold
    }
    #endif

    /// PDFColor convenience initialiser — no CoreGraphics import needed in call sites.
    public init(
        headerBackground: PDFColor = PDFColor(white: 0.85),
        headerTextColor: PDFColor = .black,
        headerFontSize: CGFloat = 10,
        cellFontSize: CGFloat = 10,
        rowHeight: CGFloat = 20,
        alternateRowColor: PDFColor? = nil,
        borderColor: PDFColor = PDFColor(white: 0.7),
        borderWidth: CGFloat = 0.25,
        cellPadding: CGFloat = 4,
        cellBold: Bool = false
    ) {
        self.headerBackground = headerBackground
        self.headerTextColor = headerTextColor
        self.headerFontSize = headerFontSize
        self.cellFontSize = cellFontSize
        self.rowHeight = rowHeight
        self.alternateRowColor = alternateRowColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cellPadding = cellPadding
        self.cellBold = cellBold
    }
}

// MARK: - Table

public struct Table: PDFContent {
    let rows: [[String]]
    let columns: [Column]
    let style: TableStyle
    let showHeader: Bool

    public init(
        data: [[String]],
        style: TableStyle = .default,
        showHeader: Bool = true,
        @ColumnBuilder columns: () -> [Column]
    ) {
        self.rows = data
        self.columns = columns()
        self.style = style
        self.showHeader = showHeader
    }

    // MARK: Width resolution (shared)

    func resolvedWidths(totalWidth: CGFloat) -> [CGFloat] {
        let fixedTotal = columns.compactMap {
            if case .fixed(let w) = $0.width { return w } else { return nil }
        }.reduce(CGFloat(0), +)
        let flexCount = columns.filter {
            if case .flex = $0.width { return true } else { return false }
        }.count
        let flexWidth = flexCount > 0 ? (totalWidth - fixedTotal) / CGFloat(flexCount) : 0
        return columns.map { col in
            switch col.width { case .fixed(let w): return w; case .flex: return flexWidth }
        }
    }

    // MARK: CoreGraphics Rendering

    #if canImport(CoreGraphics)
    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {
        guard !columns.isEmpty else { return }

        let colWidths = resolvedWidths(totalWidth: bounds.width)

        if showHeader {
            drawRow(
                context: context,
                texts: columns.map(\.header),
                alignments: columns.map(\.headerAlignment),
                colWidths: colWidths,
                x: bounds.minX,
                y: cursor,
                rowHeight: style.rowHeight,
                fontSize: style.headerFontSize,
                bold: true,
                textColor: style.headerTextColor.cgColor,
                background: style.headerBackground.cgColor
            )
            cursor -= style.rowHeight
        }

        for (rowIndex, row) in rows.enumerated() {
            let bg: CGColor?
            if let alt = style.alternateRowColor, rowIndex.isMultiple(of: 2) {
                bg = alt.cgColor
            } else {
                bg = nil
            }
            let cells = (0..<columns.count).map { i in i < row.count ? row[i] : "" }
            drawRow(
                context: context,
                texts: cells,
                alignments: columns.map(\.alignment),
                colWidths: colWidths,
                x: bounds.minX,
                y: cursor,
                rowHeight: style.rowHeight,
                fontSize: style.cellFontSize,
                bold: style.cellBold,
                textColor: CGColor(gray: 0, alpha: 1),
                background: bg
            )
            cursor -= style.rowHeight
        }
    }

    private func drawRow(
        context: CGContext,
        texts: [String],
        alignments: [TextAlignment],
        colWidths: [CGFloat],
        x: CGFloat,
        y: CGFloat,
        rowHeight: CGFloat,
        fontSize: CGFloat,
        bold: Bool,
        textColor: CGColor,
        background: CGColor?
    ) {
        let totalWidth = colWidths.reduce(CGFloat(0), +)

        if let bg = background {
            context.setFillColor(bg)
            context.fill(CGRect(x: x, y: y - rowHeight, width: totalWidth, height: rowHeight))
        }

        let fontName = bold ? "Helvetica-Bold" : "Helvetica"
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        let pad = style.cellPadding
        var xOffset = x

        for (idx, (text, width)) in zip(texts, colWidths).enumerated() {
            let cellAlignment = idx < alignments.count ? alignments[idx] : .leading
            let cellBounds = CGRect(x: xOffset + pad, y: y - rowHeight,
                                    width: width - pad * 2, height: rowHeight)
            let attrs: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: textColor,
            ]
            let attributed = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
            let line = CTLineCreateWithAttributedString(attributed)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, nil)

            let lineWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
            let xPos: CGFloat
            switch cellAlignment {
            case .leading:  xPos = cellBounds.minX
            case .center:   xPos = cellBounds.minX + (cellBounds.width - lineWidth) / 2
            case .trailing: xPos = cellBounds.maxX - lineWidth
            }

            let baseline = y - rowHeight / 2 - (ascent - descent) / 2
            context.textPosition = CGPoint(x: xPos, y: baseline)
            CTLineDraw(line, context)

            xOffset += width
        }

        // Bottom border
        context.setLineWidth(style.borderWidth)
        context.setStrokeColor(style.borderColor.cgColor)
        context.move(to: CGPoint(x: x, y: y - rowHeight))
        context.addLine(to: CGPoint(x: x + totalWidth, y: y - rowHeight))
        context.strokePath()
    }
    #endif

    // MARK: HTML Rendering

    public func renderHTML(bounds: CGRect, cursor: inout CGFloat) -> String {
        guard !columns.isEmpty else { return "" }

        let colWidths = resolvedWidths(totalWidth: bounds.width)
        let pad = style.cellPadding
        let borderCSS = "\(style.borderWidth)pt solid \(style.borderColor.cssRGBA)"

        var html = "<table style=\"width:100%;border-collapse:collapse;table-layout:fixed;\">"

        html += "<colgroup>"
        for w in colWidths {
            html += "<col style=\"width:\(w)pt;\">"
        }
        html += "</colgroup>"

        if showHeader {
            html += "<tr>"
            for (idx, col) in columns.enumerated() {
                let align = col.headerAlignment.cssValue
                html += "<th style=\"background:\(style.headerBackground.cssRGBA);"
                html += "color:\(style.headerTextColor.cssRGBA);"
                html += "font-size:\(style.headerFontSize)pt;font-weight:bold;"
                html += "text-align:\(align);height:\(style.rowHeight)pt;"
                html += "padding:0 \(pad)pt;border-bottom:\(borderCSS);"
                html += "overflow:hidden;white-space:nowrap;font-family:Helvetica,Arial,sans-serif;\">"
                html += columns[idx].header.htmlEscaped
                html += "</th>"
            }
            html += "</tr>"
            cursor -= style.rowHeight
        }

        for (rowIndex, row) in rows.enumerated() {
            let bgCSS: String
            if let alt = style.alternateRowColor, rowIndex.isMultiple(of: 2) {
                bgCSS = "background:\(alt.cssRGBA);"
            } else {
                bgCSS = ""
            }
            html += "<tr>"
            for idx in 0..<columns.count {
                let text = idx < row.count ? row[idx] : ""
                let align = columns[idx].alignment.cssValue
                let weight = style.cellBold ? "bold" : "normal"
                html += "<td style=\"font-size:\(style.cellFontSize)pt;"
                html += "font-weight:\(weight);text-align:\(align);"
                html += "height:\(style.rowHeight)pt;padding:0 \(pad)pt;"
                html += "border-bottom:\(borderCSS);\(bgCSS)"
                html += "overflow:hidden;white-space:nowrap;font-family:Helvetica,Arial,sans-serif;\">"
                html += text.htmlEscaped
                html += "</td>"
            }
            html += "</tr>"
            cursor -= style.rowHeight
        }

        html += "</table>"
        return html
    }
}
