import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - InvoiceLayoutType

/// Built-in invoice page layouts.
///
/// Each case produces a different visual arrangement of the invoice sections
/// from the same ``InvoiceDocument`` data.
public enum InvoiceLayoutType: Sendable {
    /// Classic single-column layout.
    ///
    /// - Logo and supplier address in a two-column header
    /// - Invoice metadata (number, dates) in a two-column block
    /// - Line-items table
    /// - Totals summary row
    /// - Optional QR code + payment reference banner
    /// - Optional footer
    case classic

    /// Like ``classic`` but adds a full-height accent bar on the left edge of every page.
    case classicWithSidebar

    /// Minimalist layout: no table borders, generous whitespace, plain-text totals.
    case minimal

    /// Stacked layout: supplier and client stacked vertically below a full-width title banner.
    case stacked

    /// Summary-first layout: page 1 shows totals and payment only; line items start on page 2.
    case summaryFirst
}

// MARK: - PDF + Invoice factory

public extension PDF {

    /// Creates a `PDF` pre-built from an ``InvoiceDocument`` using a named layout.
    ///
    /// ```swift
    /// let pdf = PDF(layout: .classic, invoice: invoice)
    /// let data = try pdf.render()
    /// ```
    ///
    /// - Parameters:
    ///   - layout: The page arrangement to use.
    ///   - invoice: The data model containing all invoice content.
    ///   - theme: Visual configuration (colors, fonts, logo size). Defaults to ``InvoiceTheme/standard``.
    ///   - pageSize: Paper size. Defaults to A4.
    init(
        layout: InvoiceLayoutType,
        invoice: InvoiceDocument,
        theme: InvoiceTheme = .standard,
        pageSize: PageSize = .a4
    ) {
        switch layout {
        case .classic:
            self = InvoiceLayoutBuilder.classicLayout(
                invoice: invoice, theme: theme, pageSize: pageSize)
        case .classicWithSidebar:
            self = InvoiceLayoutBuilder.classicWithSidebarLayout(
                invoice: invoice, theme: theme, pageSize: pageSize)
        case .minimal:
            self = InvoiceLayoutBuilder.minimalLayout(
                invoice: invoice, theme: theme, pageSize: pageSize)
        case .stacked:
            self = InvoiceLayoutBuilder.stackedLayout(
                invoice: invoice, theme: theme, pageSize: pageSize)
        case .summaryFirst:
            self = InvoiceLayoutBuilder.summaryFirstLayout(
                invoice: invoice, theme: theme, pageSize: pageSize)
        }
    }
}
