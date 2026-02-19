#if canImport(SwiftUI) && canImport(PDFKit)
import SwiftUI
import PDFKit
import SwiftlyPDFKit

// MARK: - PDFPreviewView

/// A SwiftUI view that renders a ``PDF`` DSL document and displays it inline.
///
/// Use it directly in `#Preview` blocks or anywhere in your SwiftUI hierarchy:
///
/// ```swift
/// #Preview {
///     PDFPreviewView {
///         Page(size: .a4) {
///             Text("Hello, PDF!")
///                 .font(.helvetica, size: 24)
///         }
///     }
/// }
/// ```
public struct PDFPreviewView: View {
    private let pages: [Page]

    public init(@PageBuilder content: () -> [Page]) {
        self.pages = content()
    }

    /// Convenience init that accepts a pre-built ``PDF`` value.
    /// Useful for previewing invoice layouts built with `PDF(layout:invoice:)`.
    public init(_ pdf: PDF) {
        self.pages = pdf.pages
    }

    public var body: some View {
        PDFKitBridgeView(pdfData: renderedData())
    }

    private func renderedData() -> Data? {
        let pdf = PDF(pages: pages)
        return try? pdf.render()
    }
}

// MARK: - Platform bridge

#if os(iOS)
struct PDFKitBridgeView: UIViewRepresentable {
    let pdfData: Data?

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if let data = pdfData {
            uiView.document = PDFDocument(data: data)
        }
    }
}
#elseif os(macOS)
struct PDFKitBridgeView: NSViewRepresentable {
    let pdfData: Data?

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if let data = pdfData {
            nsView.document = PDFDocument(data: data)
        }
    }
}
#endif

#endif // canImport(SwiftUI) && canImport(PDFKit)
