import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Footer

/// Pins content to the bottom margin of the page.
public struct Footer: PDFContent {
    let contents: [any PDFContent]
    let height: CGFloat

    public init(height: CGFloat = 40, @ContentBuilder content: () -> [any PDFContent]) {
        self.height = height
        self.contents = content()
    }

    // MARK: CoreGraphics Rendering

    /// Footer is not drawn inline — Page.render() handles it separately.
    /// This no-op satisfies the protocol so Footer can appear in a ContentBuilder.
    #if canImport(CoreGraphics)
    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {}
    #endif

    public func renderHTML(bounds: CGRect, cursor: inout CGFloat) -> String {
        // Footer is not rendered inline — Page.renderHTML() handles it separately.
        return ""
    }

    // MARK: Footer-specific rendering

    #if canImport(CoreGraphics)
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
    #endif

    /// Called by Page.renderHTML() to produce the footer HTML.
    func renderFooterHTML(bounds: CGRect) -> String {
        let footerBounds = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: height
        )
        var cursor = footerBounds.maxY
        var html = ""
        for item in contents {
            html += item.renderHTML(bounds: footerBounds, cursor: &cursor)
        }
        return html
    }
}
