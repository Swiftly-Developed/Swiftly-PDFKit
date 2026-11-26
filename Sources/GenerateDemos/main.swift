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
    try write(PDF(layout: .modern, invoice: inv08, theme: .corporate), name: "Demo08_ModernCorporate.pdf")

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
    try write(PDF(layout: .modern, invoice: inv09, theme: .standard), name: "Demo09_ModernStandard.pdf")

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
    try write(PDF(layout: .modern, invoice: inv10, theme: theme10), name: "Demo10_ModernBrandAccent.pdf")

    // MARK: Demo 11 — Receipt family, settled state / gold
    //
    // The roster had no Receipt demo at all: all 11 invoice demos rendered
    // Modern or Classic. This one is settled, because the Receipt family's
    // paid state is where its pruning (no bank block, acknowledgement shown)
    // actually differs from its due state — a due Receipt looks much closer to
    // the other families.
    let inv11 = InvoiceDocument(
        header: InvoiceHeader(
            invoiceNumber: "INV-2026-011", documentTitle: "Invoice",
            issueDate: "2026-02-19", dueDate: "2026-03-05", currency: "EUR",
            paymentTerms: "Payable within 14 days of issue date.",
            paymentReference: "+++011/2026/00011+++",
            notes: "Detailed line items are listed on the following page(s).",
            qrPayload: demoQRPayload
        ),
        supplier: demoSupplier, client: demoClient, lines: demoLines, footer: demoFooter,
        paymentState: .paid(on: Date(timeIntervalSince1970: 1_772_000_000)),
        paymentHistory: [
            InvoicePaymentRow(method: "SEPA credit transfer",
                              date: Date(timeIntervalSince1970: 1_772_000_000),
                              amount: 1_250.00, receiptNumber: "R-2026-011"),
        ]
    )
    try write(PDF(layout: .receipt, invoice: inv11, theme: .gold), name: "Demo11_ReceiptPaid.pdf")

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

    // MARK: Demo 16 — Payment Receipt
    //
    // The receipt family has its own model (no lines, no VAT). The widest row
    // shape: settled / partial (a long, wrapping number) / foreign-currency ("—"
    // other-payments and remaining) documents, a positive
    // unallocated remainder, a bank charge, notes, and a reversal with a known
    // reason code — so the oracle measures a watermarked page.
    let receipt16 = PaymentReceiptDocument(
        supplier: demoSupplier,
        payer: PaymentReceiptPayer(
            party: InvoiceParty(
                name: "Client BV", attention: "Jane Doe", street: "Client Road 42",
                city: "1000 Brussels", country: "Belgium", vatNumber: "BE 0987.654.321"
            ),
            registerNumber: "0987.654.321",
            customerReference: "C-042"
        ),
        header: PaymentReceiptHeader(receiptNumber: "RCPT-2026-0016", receiptDate: "2026-02-19"),
        paymentFacts: [
            PaymentReceiptFact(caption: "Payment date", value: "2026-02-18"),
            PaymentReceiptFact(caption: "Value date", value: "2026-02-18"),
            PaymentReceiptFact(caption: "Payment method", value: "SEPA credit transfer"),
            PaymentReceiptFact(caption: "Bank reference", value: "BNK-2026-88231"),
        ],
        allocations: [
            PaymentReceiptAllocationRow(
                documentNumber: "INV-2026-001", documentDate: "2026-01-10",
                documentCurrencyCode: "EUR", documentTotal: 1_210, paidByOtherPayments: 0,
                appliedAmount: 1_210, remaining: 0, isSettled: true),
            PaymentReceiptAllocationRow(
                documentNumber: "INV-2026-ANTWERP-HQ-000004", documentDate: "2026-01-14",
                documentCurrencyCode: "EUR", documentTotal: 2_420, paidByOtherPayments: 400,
                appliedAmount: 1_000, remaining: 1_020, isSettled: false),
            PaymentReceiptAllocationRow(
                documentNumber: "INV-2026-007", documentDate: "2026-01-20",
                documentCurrencyCode: "USD", documentTotal: 650, paidByOtherPayments: nil,
                appliedAmount: 552.60, appliedInDocumentCurrency: 600, exchangeRate: 1.0858,
                remaining: nil, isSettled: false),
        ],
        totals: PaymentReceiptTotals(
            currencyCode: "EUR", received: 3_000, allocated: 2_762.60, unallocated: 237.40,
            charges: [PaymentReceiptCharge(amount: 2.50, currencyCode: "EUR")]
        ),
        reversal: PaymentReceiptReversal(reasonCode: "MD06"),
        notes: "The unallocated remainder is held on account against future invoices."
    )
    try write(PaymentReceiptLayout.build(receipt16, theme: .standard), name: "Demo16_PaymentReceipt.pdf")

    // MARK: Demo 17 — Purchase Order
    //
    // The purchase-order family has its own model (the issuer is the buyer). A
    // draft (watermark + the draft placeholder) across the three line kinds —
    // stock, a service line whose long description wraps with its own
    // expected-delivery date and a note, an expense — one closed-short line left
    // off, two VAT rates, a shipping row and instructions. The issuer carries an
    // IBAN and a BIC; the order prints neither.
    let poLabels17 = PurchaseOrderLabels.english
    let purchaseOrder17 = PurchaseOrderDocument(
        issuer: demoSupplier,
        vendor: PurchaseOrderDocumentVendor(
            party: InvoiceParty(
                name: "Rotterdam Pump Supply BV", street: "Havenweg 12", city: "3011 AB Rotterdam",
                country: "Netherlands", vatNumber: "NL812345678B01"
            ),
            registerNumber: "KvK 12345678",
            vendorNumber: "V-00042"
        ),
        deliverTo: PurchaseOrderDocumentDeliverTo(
            warehouse: InvoiceParty(
                name: "Antwerp Central Warehouse", street: "Dokweg 7", city: "2030 Antwerp", country: "Belgium"
            ),
            warehouseCode: "WH-ANT",
            deliveryAddress: "Loading dock 3, Dokweg 7, 2030 Antwerp, Belgium"
        ),
        header: PurchaseOrderDocumentHeader(
            orderNumber: nil, orderDate: "2026-10-26", revision: 1, generatedOn: "2026-10-26 14:05"
        ),
        metadataRows: [
            PurchaseOrderDocumentMetadataRow(caption: poLabels17.requestedByLabel, value: "Jane Doe"),
            PurchaseOrderDocumentMetadataRow(caption: poLabels17.vendorReferenceLabel, value: "Q-2026-118"),
            PurchaseOrderDocumentMetadataRow(caption: poLabels17.expectedDeliveryDateLabel, value: "2026-11-15"),
            PurchaseOrderDocumentMetadataRow(
                caption: poLabels17.paymentTermsLabel,
                value: poLabels17.paymentTermsDays(name: "Net 30", days: "30")
            ),
            PurchaseOrderDocumentMetadataRow(caption: poLabels17.currencyLabel, value: "EUR"),
        ],
        lines: [
            PurchaseOrderDocumentLine(
                itemSKU: "PMP-4410", itemName: "Centrifugal pump 4 kW",
                description: "Stainless steel housing, 400 V three-phase motor",
                quantity: 2, unitOfMeasure: "pcs", unitCost: 1_250, discountPercent: 5,
                taxRatePercent: 21, lineTotal: 2_375
            ),
            PurchaseOrderDocumentLine(
                description: "Installation and commissioning on site, including alignment of pump and motor, "
                    + "a pressure test and a written handover report",
                quantity: 1, unitCost: 680, taxRatePercent: 21, lineTotal: 680,
                expectedDelivery: "2026-11-20", note: "Technician to report to the warehouse gate"
            ),
            PurchaseOrderDocumentLine(
                description: "Printed safety documentation (NL / FR)",
                quantity: 3, unitOfMeasure: "sets", unitCost: 12.5, taxRatePercent: 6, lineTotal: 37.5
            ),
        ],
        closedShortOmittedCount: 1,
        taxRows: [
            PurchaseOrderDocumentTaxRow(ratePercent: 21, taxableBase: 3_055, taxAmount: 641.55),
            PurchaseOrderDocumentTaxRow(ratePercent: 6, taxableBase: 37.5, taxAmount: 2.25),
        ],
        totals: PurchaseOrderDocumentTotals(
            currencyCode: "EUR", subtotal: 3_092.5, discount: nil, shipping: 85, tax: 643.80, total: 3_821.30
        ),
        specialInstructions: "Deliver between 08:00 and 16:00. Quote the order number on every delivery note.",
        watermark: .draft
    )
    try write(PurchaseOrderLayout.build(purchaseOrder17, theme: .standard), name: "Demo17_PurchaseOrder.pdf")

    // MARK: Demo 18 — Remittance Advice
    //
    // The remittance-advice family has its own model (the issuer is the payer).
    // A batch not yet submitted (watermark): two member payments settling an
    // EUR invoice net of a cash discount, a USD invoice paid in EUR (rate
    // sub-row), an invoice short-paid with an adjustment and a credit note, each
    // document cell stacking the payee's number, the type, our reference and the
    // paying member; one EUR totals stack with an on-account remainder; a
    // remittance text shortened to 140 characters. The issuer's IBAN prints.
    let raLabels18 = RemittanceAdviceLabels.english
    let raPayment18 = PaymentReceiptLabels.english
    let raFullText18 = "Payment of invoices INV-DE-77812 and INV-DE-77840 for September deliveries "
        + "under framework agreement FA-2026-03, net of the agreed cash discount and the short-delivery adjustment"
    let remittance18 = RemittanceAdviceDocument(
        issuer: demoSupplier,
        payee: RemittanceAdvicePayee(
            party: InvoiceParty(
                name: "Bosch Industrial Supply GmbH", street: "Robert-Bosch-Platz 1", city: "70839 Gerlingen",
                country: "Germany", vatNumber: "DE811128135"
            ),
            registerNumber: "HRB 14000",
            supplierNumber: "V-00017",
            yourReferenceForUs: "CUST-88213",
            paidToAccount: "•••• 3000",
            paidToBIC: "DEUTDEFF"
        ),
        header: RemittanceAdviceHeader(
            batchReference: "MSG-20261028-001 / V-00017", adviceDate: "2026-10-30", generatedOn: "2026-10-28 15:10"
        ),
        paymentFacts: [
            RemittanceAdviceFact(caption: raLabels18.executionDateLabel, value: "2026-10-30"),
            RemittanceAdviceFact(caption: raPayment18.paymentMethodLabel, value: raPayment18.paymentMeansSEPACreditTransfer),
            RemittanceAdviceFact(caption: raLabels18.amountPaidLabel, value: "4,312.50 EUR"),
            RemittanceAdviceFact(caption: raLabels18.ourBankAccountLabel, value: "•••• 9163"),
        ],
        memberPayments: [
            RemittanceAdviceMemberPayment(
                paymentNumber: "VPMT00041", endToEndId: "E2E-7f3a2c10-55b1-4e0b-9d2a-1c3e",
                paymentInfoId: "PMTINF-20261030-01", amount: 3_312.50, currencyCode: "EUR"
            ),
            RemittanceAdviceMemberPayment(
                paymentNumber: "VPMT00042", endToEndId: "E2E-0b9e44d2-7a6c-4f21-8e03-a4d1",
                paymentInfoId: "PMTINF-20261030-01", amount: 1_000, currencyCode: "EUR"
            ),
        ],
        details: [
            RemittanceAdviceDetailRow(
                kind: .invoice, theirNumber: "INV-DE-77812", theirDate: "2026-09-15", ourReference: "VBILL00031",
                documentCurrencyCode: "EUR", gross: 2_500, paidByOtherPayments: 0,
                applied: 2_450, appliedCurrencyCode: "EUR", remaining: 0, isSettled: true,
                discount: RemittanceAdviceAmount(value: 50, currencyCode: "EUR"), paidByPaymentNumber: "VPMT00041"
            ),
            RemittanceAdviceDetailRow(
                kind: .invoice, theirNumber: "INV-DE-77840", theirDate: "2026-09-22", ourReference: "VBILL00034",
                documentCurrencyCode: "USD", gross: 1_000, paidByOtherPayments: 0,
                applied: 862.50, appliedCurrencyCode: "EUR", appliedInDocumentCurrency: 1_000, exchangeRate: 1.15942,
                remaining: 0, isSettled: true, paidByPaymentNumber: "VPMT00041"
            ),
            RemittanceAdviceDetailRow(
                kind: .invoice, theirNumber: "INV-DE-77901", theirDate: "2026-10-02", ourReference: "VBILL00040",
                documentCurrencyCode: "EUR", gross: 1_200, paidByOtherPayments: 0,
                applied: 1_175, appliedCurrencyCode: "EUR", remaining: 0, isSettled: true,
                adjustment: RemittanceAdviceAmount(value: 25, currencyCode: "EUR"), adjustmentReason: "Short delivery",
                paidByPaymentNumber: "VPMT00042"
            ),
            RemittanceAdviceDetailRow(
                kind: .creditNote, theirNumber: "CN-DE-0907", theirDate: "2026-10-05", ourReference: "VCRN00007",
                documentCurrencyCode: "EUR", gross: 300, paidByOtherPayments: 0,
                applied: 300, appliedCurrencyCode: "EUR", remaining: 0, isSettled: true,
                paidByPaymentNumber: "VPMT00042"
            ),
        ],
        totals: [
            RemittanceAdviceTotals(
                currencyCode: "EUR", bills: 4_487.50, discount: 50, adjustments: 25, credits: 300,
                transferred: 4_312.50, onAccount: 125
            ),
        ],
        remittanceLines: [
            RemittanceAdviceTextLine(
                text: String(raFullText18.prefix(140)), asSent: true, truncated: true, paymentNumber: "VPMT00041"
            ),
            RemittanceAdviceTextLine(text: "RF18 5390 0754 7034", asSent: true, truncated: false, paymentNumber: "VPMT00042"),
        ],
        watermark: .notYetSubmitted,
        notes: "Thank you for the September deliveries.",
        contactEmail: "accounts@swiftly-demo.example"
    )
    try write(RemittanceAdviceLayout.build(remittance18, theme: .standard), name: "Demo18_RemittanceAdvice.pdf")

    print("\n17 PDFs written to \(outputDir.path)")

} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
