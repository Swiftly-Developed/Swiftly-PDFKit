import Foundation
import SwiftlyPDFKit

// MARK: - Output directory

let outputDir: URL = {
    // Place DemoPDFs/ at the package root (two levels up from Sources/GenerateDemos/)
    let src = URL(fileURLWithPath: #filePath)
    let packageRoot = src
        .deletingLastPathComponent() // GenerateDemos
        .deletingLastPathComponent() // Sources
        .deletingLastPathComponent() // package root
    let dir = packageRoot.appendingPathComponent("DemoPDFs")
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}()

func write(_ pdf: PDF, name: String) throws {
    let url = outputDir.appendingPathComponent(name)
    try pdf.write(to: url)
    print("  ✓  \(name)")
}

// MARK: - Shared fixtures (mirrors Sources/DemoPDFKit/Shared.swift)

let logoPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // GenerateDemos
    .deletingLastPathComponent() // Sources
    .deletingLastPathComponent() // package root
    .appendingPathComponent("icon_512x512.png")
    .path

let demoSupplier = InvoiceSupplier(
    name: "Acme Corp",
    street: "Main Street 1",
    city: "2000 Antwerp",
    country: "Belgium",
    vatNumber: "BE 0123.456.789",
    registrationNumber: "RPR Antwerp 0123.456.789",
    phone: "+32 3 123 45 67",
    email: "billing@acme.be",
    website: "www.acme.be",
    iban: "BE71 3630 8427 9163",
    bic: "GEBABEBB",
    logoPath: logoPath
)

let demoClient = InvoiceClient(
    name: "Client BV",
    attention: "Jane Doe",
    street: "Client Road 42",
    city: "1000 Brussels",
    country: "Belgium",
    vatNumber: "BE 0987.654.321",
    clientNumber: "C-042",
    poNumber: "PO-2026-007"
)

let demoLines: [InvoiceLine] = (0..<22).flatMap { _ in [
    InvoiceLine(description: "Software consulting",           quantity: 8, unit: "hrs",  unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review",           quantity: 3, unit: "hrs",  unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo", unitPrice: 299, vatRate: 21),
] }.prefix(66).map { $0 }

let demoShortLines = Array(demoLines.prefix(6))

let demoFooter = InvoiceFooter(
    lines: [
        "Acme Corp  ·  Main Street 1  ·  2000 Antwerp",
        "VAT BE 0123.456.789  ·  billing@acme.be  ·  www.acme.be",
        "IBAN BE71 3630 8427 9163  ·  BIC GEBABEBB",
    ],
    height: 54
)

let demoQRPayload = "https://www.swiftly-workspace.com"

let demoQuoteSupplement = QuoteSupplement(
    expiryDate: "2026-03-31",
    acceptanceNote: "Please sign and return to confirm acceptance of this quotation. By signing you agree to the terms and conditions on our website."
)

let demoSalesOrderSupplement = SalesOrderSupplement(
    poConfirmedDate: "2026-02-18",
    requestedDeliveryDate: "2026-03-15"
)

let demoDeliverySupplement = DeliverySupplement(
    shipToAddress: "Warehouse BV\nIndustrieweg 88\n9000 Ghent\nBelgium",
    signatureRequired: true,
    signatureLabel: "Received in good order by:"
)

let demoShipmentSupplement = ShipmentSupplement(
    carrier: "DHL Express",
    trackingNumber: "1Z999AA10123456784",
    shipToAddress: "Warehouse BV\nIndustrieweg 88\n9000 Ghent\nBelgium",
    estimatedDelivery: "2026-02-25",
    signatureRequired: false
)

// MARK: - Generate all demos

print("Generating demos → \(outputDir.path)\n")

do {
    // MARK: Demo 01 — Standard / classic / QR
    let inv01 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "INV-2026-001", documentTitle: "Invoice",
            issueDate: "2026-02-19", dueDate: "2026-03-05", currency: "EUR",
            paymentTerms: "Payable within 14 days of issue date.",
            paymentReference: "+++001/2026/00001+++",
            qrPayload: demoQRPayload
        ),
        supplier: demoSupplier, client: demoClient, lines: demoLines, footer: demoFooter
    )
    try write(PDF(layout: .classic, invoice: inv01, theme: .standard), name: "Demo01_Standard.pdf")

    // MARK: Demo 02 — Gold / classic / no QR
    let inv02 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "INV-2026-002", documentTitle: "Invoice",
            issueDate: "2026-02-19", dueDate: "2026-03-05", currency: "EUR",
            paymentTerms: "Payable within 14 days.",
            paymentReference: "+++002/2026/00001+++"
        ),
        supplier: demoSupplier, client: demoClient, lines: demoLines, footer: demoFooter
    )
    try write(PDF(layout: .classic, invoice: inv02, theme: .gold), name: "Demo02_Gold.pdf")

    // MARK: Demo 03 — Corporate / classic / QR + notes + service date
    let inv03 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "INV-2026-003", documentTitle: "Invoice",
            issueDate: "2026-02-19", dueDate: "2026-03-05",
            serviceDate: "2026-02-01 – 2026-02-28", currency: "EUR",
            paymentTerms: "Net 14 days. Late payments incur 1% monthly interest.",
            paymentReference: "+++003/2026/00001+++",
            notes: "Thank you for your business. All prices are exclusive of VAT unless otherwise stated.",
            qrPayload: demoQRPayload
        ),
        supplier: demoSupplier, client: demoClient, lines: demoLines, footer: demoFooter
    )
    var theme03 = InvoiceTheme.corporate
    theme03.logoMaxWidth = 120
    theme03.logoMaxHeight = 60
    try write(PDF(layout: .classic, invoice: inv03, theme: theme03), name: "Demo03_Corporate.pdf")

    // MARK: Demo 04 — Purple serif / classic / logo right
    let lines04: [InvoiceLine] = [
        InvoiceLine(description: "Annual software licence",   quantity: 1, unit: "yr",  unitPrice: 2400, vatRate: 21),
        InvoiceLine(description: "Priority support package",  quantity: 1, unit: "yr",  unitPrice: 800,  vatRate: 21),
    ]
    let client04 = InvoiceClient(
        name: "Global Ventures Ltd", attention: "John Smith",
        street: "Park Lane 8", city: "9000 Ghent", country: "Belgium",
        vatNumber: "BE 0111.222.333", clientNumber: "C-099"
    )
    let inv04 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "INV-2026-004", documentTitle: "Tax Invoice",
            issueDate: "2026-02-19", dueDate: "2026-03-19", currency: "EUR",
            paymentTerms: "Payment due within 30 days.",
            paymentReference: "+++004/2026/00001+++"
        ),
        supplier: demoSupplier, client: client04, lines: lines04, footer: demoFooter
    )
    var theme04 = InvoiceTheme.standard
    theme04.bodyFont = .times
    theme04.titleFont = .timesBold
    theme04.logoPosition = .right
    theme04.accentColor = PDFColor(red: 0.35, green: 0.15, blue: 0.55)
    theme04.ruleColor = PDFColor(red: 0.35, green: 0.15, blue: 0.55)
    theme04.tableHeaderBackground = PDFColor(red: 0.35, green: 0.15, blue: 0.55)
    theme04.tableHeaderTextColor = PDFColor.white
    theme04.tableAlternateRowColor = PDFColor(red: 0.94, green: 0.90, blue: 0.97)
    theme04.paymentBannerColor = PDFColor(red: 0.35, green: 0.15, blue: 0.55)
    try write(PDF(layout: .classic, invoice: inv04, theme: theme04), name: "Demo04_Purple.pdf")

    // MARK: Demo 05 — Green eco / classic / logo top-center / no footer
    let lines05: [InvoiceLine] = [
        InvoiceLine(description: "Brand identity design",        quantity: 1, unit: "proj",  unitPrice: 1800, vatRate: 21),
        InvoiceLine(description: "Sustainable packaging design", quantity: 3, unit: "items", unitPrice: 450,  vatRate: 21, discountPercent: 5),
        InvoiceLine(description: "Carbon offset consulting",     quantity: 4, unit: "hrs",   unitPrice: 110,  vatRate: 21),
    ]
    let supplier05 = InvoiceSupplier(
        name: "GreenLeaf Studio", street: "Forest Avenue 7", city: "3000 Leuven",
        country: "Belgium", vatNumber: "BE 0555.666.777",
        phone: "+32 16 555 66 77", email: "hello@greenleaf.be", website: "www.greenleaf.be",
        iban: "BE64 0018 4550 7852", bic: "GEBABEBB"
    )
    let client05 = InvoiceClient(
        name: "EcoStart BV", street: "Green Lane 3", city: "2000 Antwerp",
        country: "Belgium", vatNumber: "BE 0333.444.555"
    )
    let inv05 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "ECO-2026-005", documentTitle: "Invoice",
            issueDate: "2026-02-19", dueDate: "2026-03-05", currency: "EUR",
            paymentTerms: "Pay within 14 days. Thank you for supporting sustainable business.",
            paymentReference: "+++005/2026/00001+++",
            notes: "This invoice was generated with zero paper. Powered by SwiftlyPDFKit.",
            qrPayload: demoQRPayload
        ),
        supplier: supplier05, client: client05, lines: lines05
    )
    var theme05 = InvoiceTheme.standard
    theme05.accentColor = PDFColor(red: 0.10, green: 0.50, blue: 0.20)
    theme05.ruleColor = PDFColor(red: 0.10, green: 0.50, blue: 0.20)
    theme05.tableHeaderBackground = PDFColor(red: 0.10, green: 0.50, blue: 0.20)
    theme05.tableHeaderTextColor = PDFColor.white
    theme05.tableAlternateRowColor = PDFColor(red: 0.90, green: 0.96, blue: 0.91)
    theme05.tableBorderColor = PDFColor(red: 0.10, green: 0.50, blue: 0.20)
    theme05.paymentBannerColor = PDFColor(red: 0.10, green: 0.50, blue: 0.20)
    theme05.logoPosition = .topCenter
    theme05.logoMaxWidth = 140
    theme05.logoMaxHeight = 60
    try write(PDF(layout: .classic, invoice: inv05, theme: theme05), name: "Demo05_Green.pdf")

    // MARK: Demo 06 — Partial payment
    let lines06: [InvoiceLine] = [
        InvoiceLine(description: "Phase 1 — Discovery & planning", quantity: 10, unit: "hrs", unitPrice: 175, vatRate: 21),
        InvoiceLine(description: "Phase 2 — Development",          quantity: 24, unit: "hrs", unitPrice: 175, vatRate: 21),
        InvoiceLine(description: "Phase 3 — QA & deployment",      quantity:  6, unit: "hrs", unitPrice: 175, vatRate: 21, discountPercent: 15),
    ]
    var totals06 = InvoiceTotals(lines: lines06)
    totals06.amountPaid = 2000.00
    let client06 = InvoiceClient(
        name: "StartupXYZ SRL", street: "Innovation Park 12",
        city: "6000 Charleroi", country: "Belgium",
        vatNumber: "BE 0222.333.444", clientNumber: "C-088", poNumber: "PO-2026-XYZ"
    )
    let inv06 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "INV-2026-006", documentTitle: "Invoice",
            issueDate: "2026-02-19", dueDate: "2026-03-05", currency: "EUR",
            paymentTerms: "Balance due within 14 days of issue.",
            paymentReference: "+++006/2026/00001+++",
            notes: "A deposit of EUR 2,000.00 was received on 2026-01-15. The remaining balance is due on the date shown above.",
            qrPayload: demoQRPayload
        ),
        supplier: demoSupplier, client: client06, lines: lines06, totals: totals06, footer: demoFooter
    )
    try write(PDF(layout: .classic, invoice: inv06, theme: .standard), name: "Demo06_PartialPayment.pdf")

    // MARK: Demo 07 — Monochrome / Courier / Letter
    let lines07: [InvoiceLine] = [
        InvoiceLine(description: "Font licensing — Mono Slab Pro", quantity: 5, unit: "seats", unitPrice: 89,  vatRate: 0),
        InvoiceLine(description: "Extended commercial licence",     quantity: 1, unit: "lic",   unitPrice: 250, vatRate: 0),
    ]
    let supplier07 = InvoiceSupplier(
        name: "TypeSpec Labs", street: "Monospace Road 1",
        city: "New York, NY 10001", country: "USA",
        email: "accounts@typespec.io", website: "typespec.io",
        iban: "US12 3456 7890 1234"
    )
    let client07 = InvoiceClient(
        name: "Retro Systems Inc.", street: "Old School Blvd 99",
        city: "San Francisco, CA 94105", country: "USA"
    )
    let inv07 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "2026-007", documentTitle: "Statement",
            issueDate: "2026-02-19", dueDate: "2026-03-05", currency: "USD",
            paymentTerms: "Net 15. Wire transfer only."
        ),
        supplier: supplier07, client: client07, lines: lines07
    )
    var theme07 = InvoiceTheme.standard
    theme07.bodyFont = .courier
    theme07.titleFont = .courierBold
    theme07.accentColor = PDFColor(white: 0.0)
    theme07.ruleColor = PDFColor(white: 0.0)
    theme07.tableHeaderBackground = PDFColor(white: 0.0)
    theme07.tableHeaderTextColor = PDFColor.white
    theme07.tableAlternateRowColor = nil
    theme07.tableBorderColor = PDFColor(white: 0.0)
    theme07.paymentBannerColor = nil
    theme07.lineItemRowHeight = 22
    theme07.totalsRowHeight = 20
    try write(PDF(layout: .classic, invoice: inv07, theme: theme07, pageSize: .letter), name: "Demo07_Mono.pdf")

    // MARK: Demo 08 — Classic + Sidebar / corporate
    let inv08 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "INV-2026-008", documentTitle: "Invoice",
            issueDate: "2026-02-19", dueDate: "2026-03-05", currency: "EUR",
            paymentTerms: "Payable within 14 days of issue date.",
            paymentReference: "+++008/2026/00008+++",
            qrPayload: demoQRPayload
        ),
        supplier: demoSupplier, client: demoClient, lines: Array(demoLines.prefix(8)), footer: demoFooter
    )
    try write(PDF(layout: .classicWithSidebar, invoice: inv08, theme: .corporate), name: "Demo08_Sidebar.pdf")

    // MARK: Demo 09 — Minimal
    let inv09 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "INV-2026-009", documentTitle: "Invoice",
            issueDate: "2026-02-19", dueDate: "2026-03-05", currency: "EUR",
            paymentTerms: "Payable within 14 days of issue date.",
            notes: "Thank you for your business."
        ),
        supplier: demoSupplier, client: demoClient, lines: [
            InvoiceLine(description: "Software consulting",           quantity: 8, unit: "hrs", unitPrice: 150, vatRate: 21),
            InvoiceLine(description: "UI/UX design review",           quantity: 3, unit: "hrs", unitPrice: 120, vatRate: 21, discountPercent: 10),
            InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",unitPrice: 299, vatRate: 21),
            InvoiceLine(description: "Project management",            quantity: 4, unit: "hrs", unitPrice: 110, vatRate: 21),
            InvoiceLine(description: "Code review & documentation",   quantity: 2, unit: "hrs", unitPrice: 130, vatRate: 21),
        ],
        footer: demoFooter
    )
    try write(PDF(layout: .minimal, invoice: inv09, theme: .standard), name: "Demo09_Minimal.pdf")

    // MARK: Demo 10 — Stacked / teal
    let teal = PDFColor(red: 0.0, green: 0.49, blue: 0.49)
    let lightTeal = PDFColor(red: 0.85, green: 0.95, blue: 0.95)
    var theme10 = InvoiceTheme.standard
    theme10.accentColor = teal
    theme10.tableHeaderBackground = teal
    theme10.tableHeaderTextColor = PDFColor.white
    theme10.tableAlternateRowColor = lightTeal
    theme10.ruleColor = teal
    theme10.paymentBannerColor = teal
    theme10.paymentBannerTextColor = PDFColor.white
    theme10.titleFont = .helvetica
    let inv10 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "INV-2026-010", documentTitle: "Invoice",
            issueDate: "2026-02-19", dueDate: "2026-03-12", currency: "EUR",
            paymentTerms: "Payable within 21 days.",
            paymentReference: "+++010/2026/00010+++",
            notes: "All amounts in EUR. VAT applied per Belgian regulations."
        ),
        supplier: demoSupplier, client: demoClient, lines: Array(demoLines.prefix(6)), footer: demoFooter
    )
    try write(PDF(layout: .stacked, invoice: inv10, theme: theme10), name: "Demo10_Stacked.pdf")

    // MARK: Demo 11 — Summary-first / gold
    let inv11 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "INV-2026-011", documentTitle: "Invoice",
            issueDate: "2026-02-19", dueDate: "2026-03-05", currency: "EUR",
            paymentTerms: "Payable within 14 days of issue date.",
            paymentReference: "+++011/2026/00011+++",
            notes: "Detailed line items are listed on the following page(s).",
            qrPayload: demoQRPayload
        ),
        supplier: demoSupplier, client: demoClient, lines: demoLines, footer: demoFooter
    )
    try write(PDF(layout: .summaryFirst, invoice: inv11, theme: .gold), name: "Demo11_SummaryFirst.pdf")

    // MARK: Demo 12 — Quote / classic / standard
    let inv12 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "QUO-2026-001", documentTitle: "Quotation",
            issueDate: "2026-02-19", serviceDate: "2026-03-01", currency: "EUR"
        ),
        supplier: demoSupplier, client: demoClient, lines: demoShortLines, footer: demoFooter
    )
    try write(PDF(quoteLayout: .classic, invoice: inv12, supplement: demoQuoteSupplement, theme: .standard), name: "Demo12_Quote.pdf")

    // MARK: Demo 13 — Sales Order / classic / corporate
    let inv13 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "SO-2026-001", documentTitle: "Sales Order",
            issueDate: "2026-02-19", dueDate: "2026-03-15", currency: "EUR",
            notes: "All prices are subject to applicable taxes. Delivery times are estimates only."
        ),
        supplier: demoSupplier, client: demoClient, lines: demoLines, footer: demoFooter
    )
    try write(PDF(salesOrderLayout: .classic, invoice: inv13, supplement: demoSalesOrderSupplement, theme: .corporate), name: "Demo13_SalesOrder.pdf")

    // MARK: Demo 14 — Delivery Note / standard / standard
    let lines14: [InvoiceLine] = [
        InvoiceLine(description: "Widget A",           detail: "Lot #WA-2026-01",      quantity: 50, unit: "pcs",    unitPrice: 0),
        InvoiceLine(description: "Widget B",           detail: "Lot #WB-2026-02",      quantity: 20, unit: "pcs",    unitPrice: 0),
        InvoiceLine(description: "Packaging foam",                                     quantity: 10, unit: "sheets", unitPrice: 0),
        InvoiceLine(description: "User manual",        detail: "Rev. 3.1 — EN/FR/DE", quantity: 70, unit: "pcs",    unitPrice: 0),
        InvoiceLine(description: "Power adapter",                                      quantity: 70, unit: "pcs",    unitPrice: 0),
        InvoiceLine(description: "Mounting hardware kit", detail: "Includes 4× bolt M6", quantity: 70, unit: "sets", unitPrice: 0),
    ]
    let inv14 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "DN-2026-001", documentTitle: "Delivery Note",
            issueDate: "2026-02-19", currency: "EUR",
            notes: "Handle with care. Store below 25 °C."
        ),
        supplier: demoSupplier, client: demoClient, lines: lines14, footer: demoFooter
    )
    try write(PDF(deliveryLayout: .standard, invoice: inv14, supplement: demoDeliverySupplement, theme: .standard), name: "Demo14_Delivery.pdf")

    // MARK: Demo 15 — Shipment / standard / corporate
    let inv15 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "SHP-2026-001", documentTitle: "Shipment Confirmation",
            issueDate: "2026-02-19", currency: "EUR",
            notes: "If you have any questions about your shipment, contact logistics@acme.com."
        ),
        supplier: demoSupplier, client: demoClient, lines: demoShortLines, footer: demoFooter
    )
    try write(PDF(shipmentLayout: .standard, invoice: inv15, supplement: demoShipmentSupplement, theme: .corporate), name: "Demo15_Shipment.pdf")

    print("\n15 PDFs written to \(outputDir.path)")

} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
