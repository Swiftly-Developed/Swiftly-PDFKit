import Foundation
import CoreGraphics

// MARK: - DeliveryLayoutType

/// Built-in page layouts for delivery note / packing slip documents.
public enum DeliveryLayoutType: Sendable {
    /// Standard delivery note: two-column header, ship-to strip, delivery meta,
    /// simplified line items (no pricing), optional signature block.
    case standard
}

// MARK: - PDF + Delivery factory

public extension PDF {

    /// Creates a `PDF` from an ``InvoiceDocument`` rendered as a delivery note.
    ///
    /// Line item pricing columns (Unit Price, Discount, VAT %, Subtotal) are omitted.
    /// Set `invoice.header.documentTitle` to `"Delivery Note"` (or `"Packing Slip"`) before calling.
    ///
    /// - Parameters:
    ///   - deliveryLayout: The page arrangement to use.
    ///   - invoice: The data model (reused from the invoice system).
    ///   - supplement: Delivery-specific extra fields (ship-to address, signature).
    ///   - theme: Visual configuration. Defaults to ``InvoiceTheme/standard``.
    ///   - pageSize: Paper size. Defaults to A4.
    init(
        deliveryLayout: DeliveryLayoutType,
        invoice: InvoiceDocument,
        supplement: DeliverySupplement = DeliverySupplement(),
        theme: InvoiceTheme = .standard,
        pageSize: PageSize = .a4
    ) {
        switch deliveryLayout {
        case .standard:
            self = DeliveryLayoutBuilder.standardLayout(
                invoice: invoice, supplement: supplement, theme: theme, pageSize: pageSize)
        }
    }
}
