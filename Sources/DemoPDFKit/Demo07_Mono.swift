import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 07 · Monochrome Courier theme · logo left · Letter size · zero VAT

@MainActor private let lines: [InvoiceLine] = [
    InvoiceLine(description: "Font licensing — Mono Slab Pro", quantity: 5, unit: "seats",
                unitPrice: 89, vatRate: 0),
    InvoiceLine(description: "Extended commercial licence", quantity: 1, unit: "lic",
                unitPrice: 250, vatRate: 0),
]

@MainActor private let invoice = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "2026-007",
        documentTitle: "Statement",
        issueDate: "2026-02-19",
        dueDate: "2026-03-05",
        currency: "USD",
        paymentTerms: "Net 15. Wire transfer only."
    ),
    supplier: InvoiceSupplier(
        name: "TypeSpec Labs",
        street: "Monospace Road 1",
        city: "New York, NY 10001",
        country: "USA",
        email: "accounts@typespec.io",
        website: "typespec.io",
        iban: "US12 3456 7890 1234"
    ),
    client: InvoiceClient(
        name: "Retro Systems Inc.",
        street: "Old School Blvd 99",
        city: "San Francisco, CA 94105",
        country: "USA"
    ),
    lines: lines
)

@MainActor private let theme: InvoiceTheme = {
    var t = InvoiceTheme.standard
    t.bodyFont = .courier
    t.titleFont = .courierBold
    t.accentColor = PDFColor(white: 0.0)
    t.ruleColor = PDFColor(white: 0.0)
    t.tableHeaderBackground = PDFColor(white: 0.0)
    t.tableHeaderTextColor = PDFColor.white
    t.tableAlternateRowColor = nil
    t.tableBorderColor = PDFColor(white: 0.0)
    t.paymentBannerColor = nil
    t.lineItemRowHeight = 22
    t.totalsRowHeight = 20
    return t
}()

// Letter size: 612 × 792 pt
@MainActor private let pdf = PDF(layout: .classic, invoice: invoice, theme: theme, pageSize: .letter)

@available(macOS 14, iOS 17, *)
#Preview("07 · Mono · Letter", traits: .fixedLayout(width: 612, height: 792)) {
    invoicePreview(pdf)
}
