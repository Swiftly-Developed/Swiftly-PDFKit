import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
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
        self.bodyContents = all.filter { !($0 is Footer) && !($0 is TopAccentBar) }
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

        var html = "<div class=\"page\" style=\"width:\(size.width)pt;height:\(size.height)pt;"
        html += "padding:\(margins)pt;position:relative;box-sizing:border-box;"
        html += "page-break-after:always;overflow:hidden;\">"
        html += "<div class=\"body\" style=\"min-height:\(bodyHeight)pt;\">"
        html += bodyHTML
        html += "</div>"
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
