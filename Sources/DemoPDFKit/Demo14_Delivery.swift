import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 14 · Delivery Note · Standard layout · Standard theme

// Lines with detail strings on some rows to trigger the "Notes" column.
@MainActor private let deliveryLines: [InvoiceLine] = [
    InvoiceLine(description: "Widget A", detail: "Lot #WA-2026-01", quantity: 50, unit: "pcs", unitPrice: 0),
    InvoiceLine(description: "Widget B", detail: "Lot #WB-2026-02", quantity: 20, unit: "pcs", unitPrice: 0),
    InvoiceLine(description: "Packaging foam", quantity: 10, unit: "sheets", unitPrice: 0),
    InvoiceLine(description: "User manual", detail: "Rev. 3.1 — EN/FR/DE", quantity: 70, unit: "pcs", unitPrice: 0),
    InvoiceLine(description: "Power adapter", quantity: 70, unit: "pcs", unitPrice: 0),
    InvoiceLine(description: "Mounting hardware kit", detail: "Includes 4× bolt M6", quantity: 70, unit: "sets", unitPrice: 0),
]

@MainActor private let deliveryInvoice = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "DN-2026-001",
        documentTitle: "Delivery Note",
        issueDate: "2026-02-19",
        currency: "EUR",
        notes: "Handle with care. Store below 25 °C."
    ),
    supplier: demoSupplier,
    client: demoClient,
    lines: deliveryLines,
    footer: demoFooter
)

@MainActor private let deliveryPdf = PDF(
    deliveryLayout: .standard,
    invoice: deliveryInvoice,
    supplement: demoDeliverySupplement,
    theme: .standard
)

@available(macOS 14, iOS 17, *)
#Preview("14 · Delivery", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(deliveryPdf)
}
