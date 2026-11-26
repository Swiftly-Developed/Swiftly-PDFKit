import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - DocumentWatermark

/// A large, faint, rotated word across the middle of the page — the
/// duplicate / not-yet-issued marking a document carries when it is not the
/// original.
///
/// Supply the text from the label set (``CommonDocumentLabels/watermarkCopy`` /
/// ``CommonDocumentLabels/watermarkDraft``) so it is localized with everything
/// else; this type takes an already-resolved string and never picks one.
///
/// ## Why this is page-level rather than ordinary content
///
/// Every ``PDFContent`` is drawn inside `Page`'s *body bounds*, which are inset
/// by `margins` on all sides and consumed top-down through a shared cursor — so
/// ordinary content can neither reach the page edge nor sit behind the rest of
/// the page. A centred full-bleed overlay has to be positioned against the
/// **page** rect, which only ``Page`` knows. `DocumentWatermark` is therefore a
/// marker, exactly like ``TopAccentBar``: it conforms to ``PDFContent`` so it
/// can be written inline in a `Page { … }` builder, but both of its own render
/// methods are deliberately inert, and ``Page`` pulls it out by type and draws
/// it itself.
///
/// Both render paths are implemented here-and-in-`Page` together. The package
/// renders through CoreGraphics on Apple platforms and through hand-written
/// HTML on Linux (where the server generates email attachments), and the two
/// are independent code paths with no shared fallback: a primitive that
/// implements only one of them renders a *different document* on the server
/// than in the client preview.
public struct DocumentWatermark: PDFContent {

    /// The already-resolved, already-localized word to render.
    public let text: String
    /// Ink colour. Supply something faint — this sits behind the document.
    public let color: PDFColor
    /// Type size in points. The default fills a typical A4 width.
    public let fontSize: CGFloat
    /// Counter-clockwise rotation in **radians**, measured from horizontal, as
    /// CoreGraphics does. The HTML path negates it, because CSS `rotate()`
    /// measures clockwise.
    public let rotation: CGFloat
    /// Face the word is set in.
    public let font: PDFFont

    /// The conventional faint grey, at the opacity the references use.
    public static let defaultColor = PDFColor(white: 0.5, alpha: 0.18)

    public init(
        text: String,
        color: PDFColor = DocumentWatermark.defaultColor,
        fontSize: CGFloat = 96,
        rotation: CGFloat = .pi / 6,
        font: PDFFont = .helvetica
    ) {
        self.text = text
        self.color = color
        self.fontSize = fontSize
        self.rotation = rotation
        self.font = font
    }

    // MARK: Rendering — both inert by design

    #if canImport(CoreGraphics)
    /// No-op: ``Page/render(in:)`` draws the watermark against the page rect,
    /// because `bounds` here is the margin-inset body rect and cannot reach the
    /// edge or sit behind the body.
    public func draw(in context: CGContext, bounds: CGRect, cursor: inout CGFloat) {}
    #endif

    /// No-op: ``Page/renderHTML()`` emits the watermark as an
    /// absolutely-positioned element outside the page's padding box, for the
    /// same reason.
    public func renderHTML(bounds: CGRect, cursor: inout CGFloat) -> String { "" }
}
