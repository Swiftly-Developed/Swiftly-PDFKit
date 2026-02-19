import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 06 · Standard theme · partial payment (deposit scenario)

@MainActor private let lines: [InvoiceLine] = [
    InvoiceLine(description: "Phase 1 — Discovery & planning", quantity: 10, unit: "hrs",
                unitPrice: 175, vatRate: 21),
    InvoiceLine(description: "Phase 2 — Development", quantity: 24, unit: "hrs",
                unitPrice: 175, vatRate: 21),
    InvoiceLine(description: "Phase 3 — QA & deployment", quantity: 6, unit: "hrs",
                unitPrice: 175, vatRate: 21, discountPercent: 15),
]

@MainActor private let totals: InvoiceTotals = {
    var t = InvoiceTotals(lines: lines)
    t.amountPaid = 2000.00
    return t
}()

@MainActor private let invoice = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "INV-2026-006",
        documentTitle: "Invoice",
        issueDate: "2026-02-19",
        dueDate: "2026-03-05",
        currency: "EUR",
        paymentTerms: "Balance due within 14 days of issue.",
        paymentReference: "+++006/2026/00001+++",
        notes: "A deposit of EUR 2,000.00 was received on 2026-01-15. The remaining balance is due on the date shown above.",
        qrPayload: demoQRPayload
    ),
    supplier: demoSupplier,
    client: InvoiceClient(
        name: "StartupXYZ SRL",
        street: "Innovation Park 12",
        city: "6000 Charleroi",
        country: "Belgium",
        vatNumber: "BE 0222.333.444",
        clientNumber: "C-088",
        poNumber: "PO-2026-XYZ"
    ),
    lines: lines,
    totals: totals,
    footer: demoFooter
)

@MainActor private let pdf = PDF(layout: .classic, invoice: invoice, theme: .standard)

@available(macOS 14, iOS 17, *)
#Preview("06 · Partial Payment", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(pdf)
}
