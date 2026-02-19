import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 02 · Gold theme · logo left · no QR

@MainActor private let invoice = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "INV-2026-002",
        documentTitle: "Invoice",
        issueDate: "2026-02-19",
        dueDate: "2026-03-05",
        currency: "EUR",
        paymentTerms: "Payable within 14 days.",
        paymentReference: "+++002/2026/00001+++"
    ),
    supplier: demoSupplier,
    client: demoClient,
    lines: demoLines,
    footer: demoFooter
)

@MainActor private let pdf = PDF(layout: .classic, invoice: invoice, theme: .gold)

@available(macOS 14, iOS 17, *)
#Preview("02 · Gold", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(pdf)
}
