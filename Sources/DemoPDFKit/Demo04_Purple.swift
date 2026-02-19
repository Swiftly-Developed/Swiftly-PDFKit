import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 04 · Purple serif theme · logo right · software licence lines

@MainActor private let lines: [InvoiceLine] = [
    InvoiceLine(description: "Annual software licence", quantity: 1, unit: "yr",
                unitPrice: 2400, vatRate: 21),
    InvoiceLine(description: "Priority support package", quantity: 1, unit: "yr",
                unitPrice: 800, vatRate: 21),
]

@MainActor private let invoice = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "INV-2026-004",
        documentTitle: "Tax Invoice",
        issueDate: "2026-02-19",
        dueDate: "2026-03-19",
        currency: "EUR",
        paymentTerms: "Payment due within 30 days.",
        paymentReference: "+++004/2026/00001+++"
    ),
    supplier: demoSupplier,
    client: InvoiceClient(
        name: "Global Ventures Ltd",
        attention: "John Smith",
        street: "Park Lane 8",
        city: "9000 Ghent",
        country: "Belgium",
        vatNumber: "BE 0111.222.333",
        clientNumber: "C-099"
    ),
    lines: lines,
    footer: demoFooter
)

@MainActor private let theme: InvoiceTheme = {
    var t = InvoiceTheme.standard
    t.bodyFont = .times
    t.titleFont = .timesBold
    t.logoPosition = .right
    t.accentColor = PDFColor(red: 0.35, green: 0.15, blue: 0.55)
    t.ruleColor = PDFColor(red: 0.35, green: 0.15, blue: 0.55)
    t.tableHeaderBackground = PDFColor(red: 0.35, green: 0.15, blue: 0.55)
    t.tableHeaderTextColor = PDFColor.white
    t.tableAlternateRowColor = PDFColor(red: 0.94, green: 0.90, blue: 0.97)
    t.paymentBannerColor = PDFColor(red: 0.35, green: 0.15, blue: 0.55)
    return t
}()

@MainActor private let pdf = PDF(layout: .classic, invoice: invoice, theme: theme)

@available(macOS 14, iOS 17, *)
#Preview("04 · Purple · Logo Right", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(pdf)
}
