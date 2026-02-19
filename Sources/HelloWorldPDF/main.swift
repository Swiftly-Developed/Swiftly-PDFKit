import Foundation
import SwiftlyPDFKit

// MARK: - Invoice model demo

let logoPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()           // Sources/HelloWorldPDF
    .deletingLastPathComponent()           // Sources
    .deletingLastPathComponent()           // package root
    .appendingPathComponent("icon_512x512.png")
    .path


let invoice = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "INV-2026-001",
        documentTitle: "Invoice",
        issueDate: "2026-02-18",
        dueDate: "2026-03-04",
        currency: "EUR",
        paymentTerms: "Payable within 14 days.",
        paymentReference: "+++001/2026/00001+++",
        qrPayload: "BCD\n002\n1\nSCT\nGEBABEBB\nAcme Corp\nBE64001845507852\nEUR1633.28\n\n+++001/2026/00001+++"
    ),
    supplier: InvoiceSupplier(
        name: "Acme Corp",
        street: "Main Street 1",
        city: "2000 Antwerp",
        country: "Belgium",
        vatNumber: "BE 0123.456.789",
        phone: "+32 3 123 45 67",
        email: "billing@acme.be",
        website: "www.acme.be",
        iban: "BE64 0018 4550 7852",
        bic: "GEBABEBB",
        logoPath: logoPath
    ),
    client: InvoiceClient(
        name: "Client BV",
        street: "Client Road 42",
        city: "1000 Brussels",
        country: "Belgium",
        vatNumber: "BE 0987.654.321",
        clientNumber: "C-042",
        poNumber: "PO-2026-007"
    ),
    lines: [
        InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                    unitPrice: 150, vatRate: 21),
        InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                    unitPrice: 120, vatRate: 21, discountPercent: 10),
        InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                    unitPrice: 299, vatRate: 21),
    ],
    footer: InvoiceFooter(
        lines: [
            "Acme Corp  ·  Main Street 1  ·  2000 Antwerp",
            "VAT BE 0123.456.789  ·  billing@acme.be  ·  www.acme.be",
            "IBAN BE64 0018 4550 7852  ·  BIC GEBABEBB",
        ],
        height: 54
    )
)

var corporateTheme = InvoiceTheme.corporate
corporateTheme.logoMaxWidth = 120
corporateTheme.logoMaxHeight = 60

let invoicePDF = PDF(layout: .classic, invoice: invoice, theme: corporateTheme)

let invoiceModelURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Invoice-Model-Demo.pdf")

do {
    try invoicePDF.write(to: invoiceModelURL)
    print("Model invoice written to: \(invoiceModelURL.path)")
} catch {
    print("Failed to write model invoice: \(error)")
}

// MARK: - DSL demo

let dslPDF = PDF {
    Page(size: .a4) {
        Text("Hello, World!")
            .font(.helvetica, size: 36)
            .bold()
            .alignment(.center)
        Spacer(height: 16)
        Text("Built with SwiftlyPDFKit")
            .font(.helvetica, size: 14)
            .alignment(.center)
    }
}

let dslURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("HelloWorld-DSL-Demo.pdf")

do {
    try dslPDF.write(to: dslURL)
    print("DSL demo written to: \(dslURL.path)")
} catch {
    print("Failed to write DSL demo: \(error)")
}
