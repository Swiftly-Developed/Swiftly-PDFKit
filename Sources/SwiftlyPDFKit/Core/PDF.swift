import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - PageBuilder

@resultBuilder
public struct PageBuilder {
    public static func buildBlock(_ pages: Page...) -> [Page] { pages }
    public static func buildArray(_ pages: [[Page]]) -> [Page] { pages.flatMap { $0 } }
    public static func buildOptional(_ pages: [Page]?) -> [Page] { pages ?? [] }
    public static func buildEither(first pages: [Page]) -> [Page] { pages }
    public static func buildEither(second pages: [Page]) -> [Page] { pages }
}

// MARK: - PDF

/// Top-level entry point for the DSL.
///
/// ```swift
/// let pdf = PDF {
///     Page(size: .a4) {
///         Text("Hello").font(.helvetica, size: 24).bold()
///     }
/// }
/// let data = try pdf.render()
/// ```
public struct PDF {
    public let pages: [Page]

    public init(@PageBuilder content: () -> [Page]) {
        self.pages = content()
    }

    /// Initialises a `PDF` from an already-built array of pages.
    /// Useful when pages are constructed programmatically (e.g. in preview helpers).
    public init(pages: [Page]) {
        self.pages = pages
    }

    // MARK: Rendering

    /// Renders all pages and returns the PDF as `Data`.
    public func render() throws -> Data {
        #if canImport(CoreGraphics)
        let mutableData = NSMutableData()
        guard let consumer = CGDataConsumer(data: mutableData),
              var mediaBox = pages.first.map({ CGRect(x: 0, y: 0, width: $0.size.width, height: $0.size.height) }),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            throw PDFRenderError.contextCreationFailed
        }

        for page in pages {
            var pageBox = CGRect(x: 0, y: 0, width: page.size.width, height: page.size.height)
            context.beginPage(mediaBox: &pageBox)
            page.render(in: context)
            context.endPage()
        }

        context.closePDF()
        return mutableData as Data
        #else
        return try renderViaHTML()
        #endif
    }

    /// Renders and returns the assembled HTML string (useful for debugging/testing).
    public func renderHTML() -> String {
        guard let firstPage = pages.first else { return "" }

        let pageWidth = firstPage.size.width
        let pageHeight = firstPage.size.height

        var pagesHTML = ""
        for page in pages {
            pagesHTML += page.renderHTML()
        }

        return """
        <!DOCTYPE html>
        <html><head>
        <meta charset="utf-8">
        <style>
        @page {
            size: \(pageWidth)pt \(pageHeight)pt;
            margin: 0;
        }
        * { margin: 0; padding: 0; }
        body { font-family: Helvetica, Arial, sans-serif; -webkit-print-color-adjust: exact; }
        .page { page-break-after: always; position: relative; overflow: hidden; box-sizing: border-box; }
        .page:last-child { page-break-after: auto; }
        table { border-collapse: collapse; }
        img { display: block; }
        </style>
        </head><body>
        \(pagesHTML)
        </body></html>
        """
    }

    /// Convenience: renders and writes to a file URL.
    @discardableResult
    public func write(to url: URL) throws -> URL {
        let data = try render()
        try data.write(to: url)
        return url
    }

    // MARK: HTML-to-PDF (Linux)

    #if !canImport(CoreGraphics)
    private func renderViaHTML() throws -> Data {
        let html = renderHTML()
        guard !html.isEmpty, let firstPage = pages.first else {
            throw PDFRenderError.contextCreationFailed
        }
        return try HTMLToPDFConverter.convert(
            html: html,
            pageWidth: firstPage.size.width,
            pageHeight: firstPage.size.height
        )
    }
    #endif
}

// MARK: - Errors

public enum PDFRenderError: Error {
    case contextCreationFailed
    case htmlConversionFailed
    case externalToolNotFound(String)
}
