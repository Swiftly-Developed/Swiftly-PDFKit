import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 08 · Classic + Sidebar · corporate theme

@MainActor private let invoice08 = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "INV-2026-008",
        documentTitle: "Invoice",
        issueDate: "2026-02-19",
        dueDate: "2026-03-05",
        currency: "EUR",
        paymentTerms: "Payable within 14 days of issue date.",
        paymentReference: "+++008/2026/00008+++",
        qrPayload: demoQRPayload
    ),
    supplier: demoSupplier,
    client: demoClient,
    lines: Array(demoLines.prefix(8)),
    footer: demoFooter
)

@MainActor private let pdf08 = PDF(layout: .classicWithSidebar, invoice: invoice08, theme: .corporate)

@available(macOS 14, iOS 17, *)
#Preview("08 · Classic + Sidebar", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(pdf08)
}
