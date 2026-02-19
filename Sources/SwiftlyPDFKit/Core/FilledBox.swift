import CoreGraphics

// MARK: - FilledBox

/// A rectangle filled with a background colour that renders its child content on top.
/// Useful for coloured banners, section headers, etc.
public struct FilledBox: PDFContent {
    let fillColor: CGColor
    let height: CGFloat
    let padding: CGFloat
    let contents: [any PDFContent]

    public init(
        color: CGColor,
        height: CGFloat,
        padding: CGFloat = 4,
        @ContentBuilder content: () -> [any PDFContent]
    ) {
        self.fillColor = color
        self.height = height
        self.padding = padding
        self.contents = content()
    }

    public init(
        color: PDFColor,
        height: CGFloat,
        padding: CGFloat = 4,
        @ContentBuilder content: () -> [any PDFContent]
    ) {
        self.fillColor = color.cgColor
        self.height = height
        self.padding = padding
        self.contents = content()
    }

    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {
        // Fill background
        context.setFillColor(fillColor)
        context.fill(CGRect(x: bounds.minX, y: cursor - height, width: bounds.width, height: height))

        // Render children inside padded bounds
        let innerBounds = CGRect(
            x: bounds.minX + padding,
            y: bounds.minY,
            width: bounds.width - padding * 2,
            height: bounds.height
        )
        var innerCursor = cursor - padding
        for item in contents {
            item.draw(in: context, bounds: innerBounds, cursor: &innerCursor)
        }

        cursor -= height
    }
}
