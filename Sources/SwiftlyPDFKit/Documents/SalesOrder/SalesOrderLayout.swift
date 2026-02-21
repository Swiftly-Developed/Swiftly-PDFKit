import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - SalesOrderLayoutType

/// Built-in page layouts for sales order / order confirmation documents.
public enum SalesOrderLayoutType: Sendable {
    /// Classic two-column header, meta grid, priced line items, totals.
    case classic
    /// Stacked layout: full-width title banner with vertically arranged supplier and client.
    case stacked
}

// MARK: - PDF + SalesOrder factory

public extension PDF {

    /// Creates a `PDF` from an ``InvoiceDocument`` rendered as a sales order confirmation.
    ///
    /// Set `invoice.header.documentTitle` to `"Sales Order"` (or `"Order Confirmation"`) before calling.
    ///
    /// - Parameters:
    ///   - salesOrderLayout: The page arrangement to use.
    ///   - invoice: The data model (reused from the invoice system).
    ///   - supplement: Sales-order-specific extra fields (PO confirmed date, requested delivery date).
    ///   - theme: Visual configuration. Defaults to ``InvoiceTheme/standard``.
    ///   - pageSize: Paper size. Defaults to A4.
    init(
        salesOrderLayout: SalesOrderLayoutType,
        invoice: InvoiceDocument,
        supplement: SalesOrderSupplement = SalesOrderSupplement(),
        theme: InvoiceTheme = .standard,
        pageSize: PageSize = .a4
    ) {
        switch salesOrderLayout {
        case .classic:
            self = SalesOrderLayoutBuilder.classicLayout(
                invoice: invoice, supplement: supplement, theme: theme, pageSize: pageSize)
        case .stacked:
            self = SalesOrderLayoutBuilder.stackedLayout(
                invoice: invoice, supplement: supplement, theme: theme, pageSize: pageSize)
        }
    }
}
