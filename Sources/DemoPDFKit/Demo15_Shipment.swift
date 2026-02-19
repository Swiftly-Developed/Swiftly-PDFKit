import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 15 · Shipment Confirmation · Standard layout · Corporate theme

@MainActor private let shipmentInvoice = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "SHP-2026-001",
        documentTitle: "Shipment Confirmation",
        issueDate: "2026-02-19",
        currency: "EUR",
        notes: "If you have any questions about your shipment, contact logistics@acme.com."
    ),
    supplier: demoSupplier,
    client: demoClient,
    lines: demoShortLines,
    footer: demoFooter
)

@MainActor private let shipmentPdf = PDF(
    shipmentLayout: .standard,
    invoice: shipmentInvoice,
    supplement: demoShipmentSupplement,
    theme: .corporate
)

@available(macOS 14, iOS 17, *)
#Preview("15 · Shipment", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(shipmentPdf)
}
