import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Shared invoice fixtures

@MainActor let demoLogoPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()           // Sources/DemoPDFKit
    .deletingLastPathComponent()           // Sources
    .deletingLastPathComponent()           // package root
    .appendingPathComponent("icon_512x512.png")
    .path

@MainActor let demoSupplier = InvoiceSupplier(
    name: "Acme Corp",
    street: "Main Street 1",
    city: "2000 Antwerp",
    country: "Belgium",
    vatNumber: "BE 0123.456.789",
    registrationNumber: "RPR Antwerp 0123.456.789",
    phone: "+32 3 123 45 67",
    email: "billing@acme.be",
    website: "www.acme.be",
    iban: "BE64 0018 4550 7852",
    bic: "GEBABEBB",
    logoPath: demoLogoPath
)

@MainActor let demoClient = InvoiceClient(
    name: "Client BV",
    attention: "Jane Doe",
    street: "Client Road 42",
    city: "1000 Brussels",
    country: "Belgium",
    vatNumber: "BE 0987.654.321",
    clientNumber: "C-042",
    poNumber: "PO-2026-007"
)

@MainActor let demoLines: [InvoiceLine] = [
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
    InvoiceLine(description: "Software consulting", quantity: 8, unit: "hrs",
                unitPrice: 150, vatRate: 21),
    InvoiceLine(description: "UI/UX design review", quantity: 3, unit: "hrs",
                unitPrice: 120, vatRate: 21, discountPercent: 10),
    InvoiceLine(description: "Server infrastructure (monthly)", quantity: 1, unit: "mo",
                unitPrice: 299, vatRate: 21),
]

@MainActor let demoFooter = InvoiceFooter(
    lines: [
        "Acme Corp  ·  Main Street 1  ·  2000 Antwerp",
        "VAT BE 0123.456.789  ·  billing@acme.be  ·  www.acme.be",
        "IBAN BE64 0018 4550 7852  ·  BIC GEBABEBB",
    ],
    height: 54
)

let demoQRPayload = "BCD\n002\n1\nSCT\nGEBABEBB\nAcme Corp\nBE64001845507852\nEUR1633.28\n\n+++001/2026/00001+++"

// MARK: - Preview helper

/// Wraps a pre-built `PDF` in a fixed A4-sized canvas for the Xcode canvas.
@MainActor
func invoicePreview(_ pdf: PDF) -> some View {
    PDFPreviewView(pdf)
        .frame(width: 595, height: 842)
}

// MARK: - Shared fixtures for new document types

/// Short line list (first 6 items) — suitable for single-page docs.
@MainActor let demoShortLines: [InvoiceLine] = Array(demoLines.prefix(6))

/// Quote supplement fixture: valid 30 days, with acceptance note.
@MainActor let demoQuoteSupplement = QuoteSupplement(
    expiryDate: "2026-03-31",
    acceptanceNote: "Please sign and return to confirm acceptance of this quotation. By signing you agree to the terms and conditions on our website."
)

/// Sales order supplement fixture.
@MainActor let demoSalesOrderSupplement = SalesOrderSupplement(
    poConfirmedDate: "2026-02-18",
    requestedDeliveryDate: "2026-03-15"
)

/// Delivery supplement fixture: separate ship-to address, signature required.
@MainActor let demoDeliverySupplement = DeliverySupplement(
    shipToAddress: "Warehouse BV\nIndustrieweg 88\n9000 Ghent\nBelgium",
    signatureRequired: true,
    signatureLabel: "Received in good order by:"
)

/// Shipment supplement fixture: DHL carrier + tracking number.
@MainActor let demoShipmentSupplement = ShipmentSupplement(
    carrier: "DHL Express",
    trackingNumber: "1Z999AA10123456784",
    shipToAddress: "Warehouse BV\nIndustrieweg 88\n9000 Ghent\nBelgium",
    estimatedDelivery: "2026-02-25",
    signatureRequired: false
)
