import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - TopAccentBar

/// A full-bleed colour bar along the very top edge of the page.
///
/// This is the brand hook of the **Modern** layout family: four of the five
/// Modern reference samples carry it (Slack purple, WishKit green, Apollo
/// slate, and Anthropic in a near-white brand bone that reads as absent to the
/// eye but measures `#F0F0EB`). It is therefore rendered *unconditionally*,
/// tinted by the theme accent — not gated on whether a tenant has chosen a
/// brand colour.
///
/// ## Why this is page-level rather than ordinary content
///
/// Every ``PDFContent`` is drawn inside `Page`'s *body bounds*, which are inset
/// by `margins` on all sides — so a `FilledBox` can never reach the page edge.
/// A full-bleed bar has to be positioned against the **page** rect, which only
/// ``Page`` knows. `TopAccentBar` is therefore a marker: it conforms to
/// ``PDFContent`` so it can be written inline in a `Page { … }` builder, but
/// both of its own render methods are deliberately inert, and ``Page`` pulls it
/// out by type and draws it itself — exactly the mechanism ``Footer`` already
/// uses.
///
/// Both render paths are implemented here-and-in-`Page` together. The package
/// renders through CoreGraphics on Apple platforms and through hand-written
/// HTML on Linux (where the server generates email attachments), and the two
/// are independent code paths with no shared fallback: a primitive that
/// implements only one of them renders a *different document* on the server
/// than in the client preview.
public struct TopAccentBar: PDFContent {

    /// Fill colour of the bar. Supply the theme accent.
    public let color: PDFColor
    /// Bar thickness in points. The references sit between 4 and 8pt on A4.
    public let height: CGFloat

    public init(color: PDFColor, height: CGFloat = 6) {
        self.color = color
        self.height = height
    }

    // MARK: Rendering — both inert by design

    #if canImport(CoreGraphics)
    /// No-op: ``Page/render(in:)`` draws the bar against the page rect, because
    /// `bounds` here is the margin-inset body rect and cannot reach the edge.
    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {}
    #endif

    /// No-op: ``Page/renderHTML()`` emits the bar as an absolutely-positioned
    /// element outside the page's padding box, for the same reason.
    public func renderHTML(bounds: CGRect, cursor: inout CGFloat) -> String { "" }
}
