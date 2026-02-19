import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 05 · Green eco theme · logo top-center · no footer

@MainActor private let lines: [InvoiceLine] = [
    InvoiceLine(description: "Brand identity design", quantity: 1, unit: "proj",
                unitPrice: 1800, vatRate: 21),
    InvoiceLine(description: "Sustainable packaging design", quantity: 3, unit: "items",
                unitPrice: 450, vatRate: 21, discountPercent: 5),
    InvoiceLine(description: "Carbon offset consulting", quantity: 4, unit: "hrs",
                unitPrice: 110, vatRate: 21),
]

@MainActor private let invoice = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "ECO-2026-005",
        documentTitle: "Invoice",
        issueDate: "2026-02-19",
        dueDate: "2026-03-05",
        currency: "EUR",
        paymentTerms: "Pay within 14 days. Thank you for supporting sustainable business.",
        paymentReference: "+++005/2026/00001+++",
        notes: "This invoice was generated with zero paper. Powered by SwiftlyPDFKit.",
        qrPayload: demoQRPayload
    ),
    supplier: InvoiceSupplier(
        name: "GreenLeaf Studio",
        street: "Forest Avenue 7",
        city: "3000 Leuven",
        country: "Belgium",
        vatNumber: "BE 0555.666.777",
        phone: "+32 16 555 66 77",
        email: "hello@greenleaf.be",
        website: "www.greenleaf.be",
        iban: "BE64 0018 4550 7852",
        bic: "GEBABEBB"
    ),
    client: InvoiceClient(
        name: "EcoStart BV",
        street: "Green Lane 3",
        city: "2000 Antwerp",
        country: "Belgium",
        vatNumber: "BE 0333.444.555"
    ),
    lines: lines
    // no footer
)

@MainActor private let theme: InvoiceTheme = {
    var t = InvoiceTheme.standard
    t.accentColor = PDFColor(red: 0.10, green: 0.50, blue: 0.20)
    t.ruleColor = PDFColor(red: 0.10, green: 0.50, blue: 0.20)
    t.tableHeaderBackground = PDFColor(red: 0.10, green: 0.50, blue: 0.20)
    t.tableHeaderTextColor = PDFColor.white
    t.tableAlternateRowColor = PDFColor(red: 0.90, green: 0.96, blue: 0.91)
    t.tableBorderColor = PDFColor(red: 0.10, green: 0.50, blue: 0.20)
    t.paymentBannerColor = PDFColor(red: 0.10, green: 0.50, blue: 0.20)
    t.logoPosition = .topCenter
    t.logoMaxWidth = 140
    t.logoMaxHeight = 60
    return t
}()

@MainActor private let pdf = PDF(layout: .classic, invoice: invoice, theme: theme)

@available(macOS 14, iOS 17, *)
#Preview("05 · Green · Top Center", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(pdf)
}
