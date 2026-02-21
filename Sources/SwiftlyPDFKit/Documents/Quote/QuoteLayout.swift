import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - QuoteLayoutType

/// Built-in page layouts for quote / proposal documents.
public enum QuoteLayoutType: Sendable {
    /// Classic two-column header, meta grid, priced line items, totals, acceptance block.
    case classic
    /// Borderless minimal variant with lighter totals and acceptance block.
    case minimal
}

// MARK: - PDF + Quote factory

public extension PDF {

    /// Creates a `PDF` from an ``InvoiceDocument`` rendered as a quotation.
    ///
    /// The `supplement` carries quote-specific fields (expiry date, acceptance note).
    /// Set `invoice.header.documentTitle` to `"Quotation"` (or similar) before calling.
    ///
    /// - Parameters:
    ///   - quoteLayout: The page arrangement to use.
    ///   - invoice: The data model (reused from the invoice system).
    ///   - supplement: Quote-specific extra fields.
    ///   - theme: Visual configuration. Defaults to ``InvoiceTheme/standard``.
    ///   - pageSize: Paper size. Defaults to A4.
    init(
        quoteLayout: QuoteLayoutType,
        invoice: InvoiceDocument,
        supplement: QuoteSupplement = QuoteSupplement(),
        theme: InvoiceTheme = .standard,
        pageSize: PageSize = .a4
    ) {
        switch quoteLayout {
        case .classic:
            self = QuoteLayoutBuilder.classicLayout(
                invoice: invoice, supplement: supplement, theme: theme, pageSize: pageSize)
        case .minimal:
            self = QuoteLayoutBuilder.minimalLayout(
                invoice: invoice, supplement: supplement, theme: theme, pageSize: pageSize)
        }
    }
}
