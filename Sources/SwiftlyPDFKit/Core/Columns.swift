import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - ColumnItem

/// A single column in a Columns layout: a fixed or flex width + content.
public struct ColumnItem {
    public let width: ColumnWidth
    public let contents: [any PDFContent]

    public init(width: ColumnWidth = .flex, @ContentBuilder content: () -> [any PDFContent]) {
        self.width = width
        self.contents = content()
    }
}

// MARK: - ColumnsBuilder

@resultBuilder
public struct ColumnsBuilder {
    public static func buildBlock(_ items: ColumnItem...) -> [ColumnItem] { items }
    public static func buildOptional(_ items: [ColumnItem]?) -> [ColumnItem] { items ?? [] }
    public static func buildEither(first items: [ColumnItem]) -> [ColumnItem] { items }
    public static func buildEither(second items: [ColumnItem]) -> [ColumnItem] { items }
    public static func buildArray(_ items: [[ColumnItem]]) -> [ColumnItem] { items.flatMap { $0 } }
    public static func buildExpression(_ item: ColumnItem) -> [ColumnItem] { [item] }
    public static func buildBlock(_ items: [ColumnItem]...) -> [ColumnItem] { items.flatMap { $0 } }
}

// MARK: - Columns

/// Horizontal layout container. Divides the available width among columns,
/// then renders each column's content independently with its own cursor.
/// The overall cursor advances by the height of the tallest column.
public struct Columns: PDFContent {
    let items: [ColumnItem]
    let spacing: CGFloat

    public init(spacing: CGFloat = 0, @ColumnsBuilder content: () -> [ColumnItem]) {
        self.spacing = spacing
        self.items = content()
    }

    // MARK: Shared width resolution

    private func resolvedColumnWidths(totalWidth: CGFloat) -> [CGFloat] {
        let totalSpacing = spacing * CGFloat(items.count - 1)
        let fixedTotal = items.compactMap {
            if case .fixed(let w) = $0.width { return w } else { return nil }
        }.reduce(CGFloat(0), +)
        let flexCount = items.filter {
            if case .flex = $0.width { return true } else { return false }
        }.count
        let flexWidth = flexCount > 0 ? (totalWidth - fixedTotal - totalSpacing) / CGFloat(flexCount) : 0
        return items.map { item in
            switch item.width {
            case .fixed(let w): return w
            case .flex:         return flexWidth
            }
        }
    }

    // MARK: CoreGraphics Rendering

    #if canImport(CoreGraphics)
    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {
        guard !items.isEmpty else { return }

        let colWidths = resolvedColumnWidths(totalWidth: bounds.width)

        var xOffset = bounds.minX
        var minCursor = cursor

        for (idx, item) in items.enumerated() {
            let colWidth = colWidths[idx]
            let colBounds = CGRect(x: xOffset, y: bounds.minY, width: colWidth, height: bounds.height)
            var colCursor = cursor
            for content in item.contents {
                content.draw(in: context, bounds: colBounds, cursor: &colCursor)
            }
            minCursor = min(minCursor, colCursor)
            xOffset += colWidth + spacing
        }

        cursor = minCursor
    }
    #endif

    // MARK: HTML Rendering

    public func renderHTML(bounds: CGRect, cursor: inout CGFloat) -> String {
        guard !items.isEmpty else { return "" }

        let colWidths = resolvedColumnWidths(totalWidth: bounds.width)

        var html = "<div style=\"display:flex;gap:\(spacing)pt;\">"
        var minCursor = cursor

        for (idx, item) in items.enumerated() {
            let w = colWidths[idx]
            var colCursor = cursor
            let colBounds = CGRect(x: 0, y: bounds.minY, width: w, height: bounds.height)

            html += "<div style=\"width:\(w)pt;flex-shrink:0;flex-grow:0;\">"
            for content in item.contents {
                html += content.renderHTML(bounds: colBounds, cursor: &colCursor)
            }
            html += "</div>"
            minCursor = min(minCursor, colCursor)
        }

        html += "</div>"
        cursor = minCursor
        return html
    }
}
