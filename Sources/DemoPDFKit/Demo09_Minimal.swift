import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 09 · Minimal layout · standard theme

@MainActor private let invoice09 = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "INV-2026-009",
        documentTitle: "Invoice",
        issueDate: "2026-02-19",
        dueDate: "2026-03-05",
        currency: "EUR",
        paymentTerms: "Payable within 14 days of issue date.",
        notes: "Thank you for your business."
    ),
    supplier: demoSupplier,
    client: demoClient,
    lines: [
        InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                    unitPrice: 150, vatRate: 21),
        InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                    unitPrice: 120, vatRate: 21, discountPercent: 10),
        InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                    unitPrice: 299, vatRate: 21),
        InvoiceLine(description: "Project management", quantity: 4, unit: "hrs",
                    unitPrice: 110, vatRate: 21),
        InvoiceLine(description: "Code review & documentation", quantity: 2, unit: "hrs",
                    unitPrice: 130, vatRate: 21),
    ],
    footer: demoFooter
)

@MainActor private let pdf09 = PDF(layout: .minimal, invoice: invoice09, theme: .standard)

@available(macOS 14, iOS 17, *)
#Preview("09 · Minimal", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(pdf09)
}
