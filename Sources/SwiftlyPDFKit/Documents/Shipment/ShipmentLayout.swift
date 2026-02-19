import Foundation
import CoreGraphics

// MARK: - ShipmentLayoutType

/// Built-in page layouts for shipment confirmation / dispatch advice documents.
public enum ShipmentLayoutType: Sendable {
    /// Standard shipment: carrier banner, ship-to strip, meta grid, simplified line items.
    case standard
    /// Compact single-page: carrier banner + ship-to strip + plain-text item list. No table.
    case compact
}

// MARK: - PDF + Shipment factory

public extension PDF {

    /// Creates a `PDF` from an ``InvoiceDocument`` rendered as a shipment confirmation.
    ///
    /// Set `invoice.header.documentTitle` to `"Shipment Confirmation"` (or `"Dispatch Advice"`)
    /// before calling.
    ///
    /// - Parameters:
    ///   - shipmentLayout: The page arrangement to use.
    ///   - invoice: The data model (reused from the invoice system).
    ///   - supplement: Shipment-specific extra fields (carrier, tracking, ship-to address).
    ///   - theme: Visual configuration. Defaults to ``InvoiceTheme/standard``.
    ///   - pageSize: Paper size. Defaults to A4.
    init(
        shipmentLayout: ShipmentLayoutType,
        invoice: InvoiceDocument,
        supplement: ShipmentSupplement = ShipmentSupplement(),
        theme: InvoiceTheme = .standard,
        pageSize: PageSize = .a4
    ) {
        switch shipmentLayout {
        case .standard:
            self = ShipmentLayoutBuilder.standardLayout(
                invoice: invoice, supplement: supplement, theme: theme, pageSize: pageSize)
        case .compact:
            self = ShipmentLayoutBuilder.compactLayout(
                invoice: invoice, supplement: supplement, theme: theme, pageSize: pageSize)
        }
    }
}
