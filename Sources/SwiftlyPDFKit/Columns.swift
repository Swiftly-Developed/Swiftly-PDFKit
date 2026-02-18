import CoreGraphics

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

    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {
        guard !items.isEmpty else { return }

        let totalSpacing = spacing * CGFloat(items.count - 1)
        let fixedTotal = items.compactMap {
            if case .fixed(let w) = $0.width { return w } else { return nil }
        }.reduce(CGFloat(0), +)
        let flexCount = items.filter {
            if case .flex = $0.width { return true } else { return false }
        }.count
        let flexWidth = flexCount > 0 ? (bounds.width - fixedTotal - totalSpacing) / CGFloat(flexCount) : 0

        var xOffset = bounds.minX
        var minCursor = cursor  // track lowest point across all columns

        for item in items {
            let colWidth: CGFloat
            switch item.width {
            case .fixed(let w): colWidth = w
            case .flex:         colWidth = flexWidth
            }

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
}
