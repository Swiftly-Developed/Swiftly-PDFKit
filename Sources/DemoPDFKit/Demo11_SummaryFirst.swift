import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 11 · Summary-first layout · gold theme

@MainActor private let invoice11 = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "INV-2026-011",
        documentTitle: "Invoice",
        issueDate: "2026-02-19",
        dueDate: "2026-03-05",
        currency: "EUR",
        paymentTerms: "Payable within 14 days of issue date.",
        paymentReference: "+++011/2026/00011+++",
        notes: "Detailed line items are listed on the following page(s).",
        qrPayload: demoQRPayload
    ),
    supplier: demoSupplier,
    client: demoClient,
    lines: demoLines,
    footer: demoFooter
)

@MainActor private let pdf11 = PDF(layout: .summaryFirst, invoice: invoice11, theme: .gold)

@available(macOS 14, iOS 17, *)
#Preview("11 · Summary First", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(pdf11)
}
