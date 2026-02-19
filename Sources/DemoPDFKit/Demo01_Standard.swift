import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 01 · Standard theme · logo left · QR code

@MainActor private let invoice = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "INV-2026-001",
        documentTitle: "Invoice",
        issueDate: "2026-02-19",
        dueDate: "2026-03-05",
        currency: "EUR",
        paymentTerms: "Payable within 14 days of issue date.",
        paymentReference: "+++001/2026/00001+++",
        qrPayload: demoQRPayload
    ),
    supplier: demoSupplier,
    client: demoClient,
    lines: demoLines,
    footer: demoFooter
)

@MainActor private let pdf = PDF(layout: .classic, invoice: invoice, theme: .standard)

@available(macOS 14, iOS 17, *)
#Preview("01 · Standard", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(pdf)
}
