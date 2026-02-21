import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - FilledBox

/// A rectangle filled with a background colour that renders its child content on top.
/// Useful for coloured banners, section headers, etc.
public struct FilledBox: PDFContent {
    let fillColor: PDFColor
    let height: CGFloat
    let padding: CGFloat
    let contents: [any PDFContent]

    #if canImport(CoreGraphics)
    public init(
        color: CGColor,
        height: CGFloat,
        padding: CGFloat = 4,
        @ContentBuilder content: () -> [any PDFContent]
    ) {
        self.fillColor = PDFColor(cgColor: color)
        self.height = height
        self.padding = padding
        self.contents = content()
    }
    #endif

    public init(
        color: PDFColor,
        height: CGFloat,
        padding: CGFloat = 4,
        @ContentBuilder content: () -> [any PDFContent]
    ) {
        self.fillColor = color
        self.height = height
        self.padding = padding
        self.contents = content()
    }

    // MARK: CoreGraphics Rendering

    #if canImport(CoreGraphics)
    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {
        // Fill background
        context.setFillColor(fillColor.cgColor)
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
    #endif

    // MARK: HTML Rendering

    public func renderHTML(bounds: CGRect, cursor: inout CGFloat) -> String {
        let innerBounds = CGRect(
            x: 0, y: bounds.minY,
            width: bounds.width - padding * 2,
            height: bounds.height
        )
        var innerCursor = cursor - padding
        var childHTML = ""
        for item in contents {
            childHTML += item.renderHTML(bounds: innerBounds, cursor: &innerCursor)
        }

        cursor -= height
        return """
        <div style="background:\(fillColor.cssRGBA);height:\(height)pt;\
        padding:\(padding)pt;box-sizing:border-box;overflow:hidden;">\
        \(childHTML)</div>
        """
    }
}
