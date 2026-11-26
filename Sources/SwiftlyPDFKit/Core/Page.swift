import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(CoreText)
import CoreText
import CoreFoundation
#endif

// MARK: - PageSize

public struct PageSize: Sendable {
    public let width: CGFloat
    public let height: CGFloat

    public static let a4     = PageSize(width: 595, height: 842)
    public static let letter = PageSize(width: 612, height: 792)
    public static let legal  = PageSize(width: 612, height: 1008)

    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
}

// MARK: - Page

public struct Page {
    public let size: PageSize
    public let margins: CGFloat
    let bodyContents: [any PDFContent]
    let footer: Footer?
    let topAccentBar: TopAccentBar?
    let watermark: DocumentWatermark?

    public init(
        size: PageSize = .a4,
        margins: CGFloat = 40,
        @ContentBuilder content: () -> [any PDFContent]
    ) {
        self.size = size
        self.margins = margins
        let all = content()
        self.footer = all.compactMap { $0 as? Footer }.last
        self.topAccentBar = all.compactMap { $0 as? TopAccentBar }.last
        self.watermark = all.compactMap { $0 as? DocumentWatermark }.last
        self.bodyContents = all.filter {
            !($0 is Footer) && !($0 is TopAccentBar) && !($0 is DocumentWatermark)
        }
    }

    // MARK: CoreGraphics Rendering

    #if canImport(CoreGraphics)
    public func render(in context: CGContext) {
        if let bar = topAccentBar {
            context.saveGState()
            context.setFillColor(bar.color.cgColor)
            context.fill(CGRect(x: 0, y: size.height - bar.height,
                                width: size.width, height: bar.height))
            context.restoreGState()
        }
        let footerHeight = footer?.height ?? 0
        let bodyBounds = CGRect(
            x: margins,
            y: margins + footerHeight,
            width: size.width - margins * 2,
            height: size.height - margins * 2 - footerHeight
        )

        var cursor = bodyBounds.maxY
        for item in bodyContents {
            item.draw(in: context, bounds: bodyBounds, cursor: &cursor)
        }

        // Drawn against the PAGE rect, centred and rotated — `bodyBounds` is
        // margin-inset and consumed top-down, so no `PDFContent` could place
        // this. Painted after the body and before the footer, which is the same
        // order `renderHTML()` emits the three in, so both paths agree.
        if let watermark {
            context.saveGState()
            let ctFont = watermark.font.ctFont(size: watermark.fontSize, bold: true, italic: false)
            let attributes: [CFString: Any] = [
                kCTFontAttributeName: ctFont,
                kCTForegroundColorAttributeName: watermark.color.cgColor,
            ]
            if let attributed = CFAttributedStringCreate(
                nil, watermark.text as CFString, attributes as CFDictionary
            ) {
                let line = CTLineCreateWithAttributedString(attributed)
                var ascent: CGFloat = 0
                var descent: CGFloat = 0
                var leading: CGFloat = 0
                let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
                context.translateBy(x: size.width / 2, y: size.height / 2)
                context.rotate(by: watermark.rotation)
                context.textPosition = CGPoint(x: -width / 2, y: -(ascent - descent) / 2)
                CTLineDraw(line, context)
            }
            context.restoreGState()
        }

        if let footer {
            let footerBounds = CGRect(
                x: margins,
                y: margins,
                width: size.width - margins * 2,
                height: footerHeight
            )
            footer.renderInFooter(in: context, bounds: footerBounds)
        }
    }
    #endif

    // MARK: HTML Rendering

    /// Points shaved off the `.page` box's CSS `height` in `renderHTML()` only.
    ///
    /// `wkhtmltopdf` paginates the fixed-height page box against the paper; when the
    /// two are equal, sub-pixel rounding can spill a blank trailing page (measured
    /// 2026-09-03 across 8 paper sizes; see the fix record
    /// `docs/fixes/2026-09-03-invoice-pdf-linux-smart-shrinking-offcenter.md`).
    /// 1pt of slack removes it; the absolutely-positioned footer and accent bar are
    /// unaffected, and the CoreGraphics `render(in:)` path never reads this.
    static let htmlPageBoxSlack: CGFloat = 1

    /// The watermark's absolutely-positioned div, emitted against the page box.
    ///
    /// CSS `rotate()` measures clockwise where CoreGraphics measures
    /// counter-clockwise, so the angle is negated — the two paths must place the
    /// word identically.
    private static func watermarkHTML(_ watermark: DocumentWatermark) -> String {
        let degrees = -watermark.rotation * 180 / .pi
        var html = "<div class=\"watermark\" style=\"position:absolute;top:50%;left:0;"
        html += "width:100%;text-align:center;line-height:1;"
        html += "transform:translateY(-50%) rotate(\(degrees)deg);"
        html += "font-family:\(watermark.font.cssFontFamily);"
        html += "font-size:\(watermark.fontSize)pt;font-weight:bold;"
        html += "color:\(watermark.color.cssRGBA);\">"
        html += watermark.text.htmlEscaped
        html += "</div>"
        return html
    }

    func renderHTML() -> String {
        let footerHeight = footer?.height ?? 0
        let bodyHeight = size.height - margins * 2 - footerHeight
        let bodyBounds = CGRect(
            x: margins,
            y: margins + footerHeight,
            width: size.width - margins * 2,
            height: bodyHeight
        )

        var cursor = bodyBounds.maxY
        var bodyHTML = ""
        for item in bodyContents {
            bodyHTML += item.renderHTML(bounds: bodyBounds, cursor: &cursor)
        }

        var footerHTML = ""
        if let footer {
            let footerBounds = CGRect(
                x: margins,
                y: margins,
                width: size.width - margins * 2,
                height: footerHeight
            )
            footerHTML = footer.renderFooterHTML(bounds: footerBounds)
        }

        var html = "<div class=\"page\" style=\"width:\(size.width)pt;height:\(size.height - Page.htmlPageBoxSlack)pt;"
        html += "padding:\(margins)pt;position:relative;box-sizing:border-box;"
        html += "page-break-after:always;overflow:hidden;\">"
        html += "<div class=\"body\" style=\"min-height:\(bodyHeight)pt;\">"
        html += bodyHTML
        html += "</div>"
        // The HTML twin of `render(in:)`'s watermark arm: absolutely positioned
        // against the page box rather than inside the padding box, emitted after
        // the body div and before the accent bar and footer, which is the same
        // paint order the CoreGraphics path uses. CSS `rotate()` measures
        // clockwise where CoreGraphics measures counter-clockwise, so the angle
        // is negated here — the two paths must place the word identically.
        if let watermark {
            html += Page.watermarkHTML(watermark)
        }
        if let bar = topAccentBar {
            html += "<div class=\"top-accent-bar\" style=\"position:absolute;top:0;left:0;"
            html += "width:100%;height:\(bar.height)pt;background:\(bar.color.cssRGBA);\"></div>"
        }
        if !footerHTML.isEmpty {
            html += "<div class=\"footer\" style=\"position:absolute;bottom:\(margins)pt;"
            html += "left:\(margins)pt;right:\(margins)pt;height:\(footerHeight)pt;\">"
            html += footerHTML
            html += "</div>"
        }
        html += "</div>"
        return html
    }
}
