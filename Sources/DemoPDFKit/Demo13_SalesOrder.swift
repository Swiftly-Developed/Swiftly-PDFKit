import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 13 · Sales Order · Classic layout · Corporate theme · multi-page

@MainActor private let salesOrderInvoice = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "SO-2026-001",
        documentTitle: "Sales Order",
        issueDate: "2026-02-19",
        dueDate: "2026-03-15",
        currency: "EUR",
        notes: "All prices are subject to applicable taxes. Delivery times are estimates only."
    ),
    supplier: demoSupplier,
    client: demoClient,
    lines: demoLines,   // full list — exercises multi-page pagination
    footer: demoFooter
)

@MainActor private let salesOrderPdf = PDF(
    salesOrderLayout: .classic,
    invoice: salesOrderInvoice,
    supplement: demoSalesOrderSupplement,
    theme: .corporate
)

@available(macOS 14, iOS 17, *)
#Preview("13 · Sales Order", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(salesOrderPdf)
}
