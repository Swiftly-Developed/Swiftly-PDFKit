import CoreGraphics

// MARK: - Footer

/// Pins content to the bottom margin of the page.
public struct Footer: PDFContent {
    let contents: [any PDFContent]
    let height: CGFloat

    public init(height: CGFloat = 40, @ContentBuilder content: () -> [any PDFContent]) {
        self.height = height
        self.contents = content()
    }

    /// Footer is not drawn inline — Page.render() handles it separately.
    /// This no-op satisfies the protocol so Footer can appear in a ContentBuilder.
    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {}

    /// Called by Page.render() at the bottom of the page.
    func renderInFooter(in context: CGContext, bounds: CGRect) {
        let footerBounds = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: height
        )
        var cursor = footerBounds.maxY
        for item in contents {
            item.draw(in: context, bounds: footerBounds, cursor: &cursor)
        }
    }
}
