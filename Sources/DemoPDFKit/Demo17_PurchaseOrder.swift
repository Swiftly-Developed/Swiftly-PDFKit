import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 17 · Purchase Order · Standard theme

// A draft order (watermark, the draft placeholder for the number) across the
// three line kinds: a stock line, a service line whose long description wraps
// in its column with its own expected-delivery date and a note, and an expense
// line; one closed-short line left off; two VAT rates; a shipping row; and
// special instructions. The issuer is the shared demo supplier, which carries
// an IBAN and a BIC — the order prints neither.
@MainActor private let purchaseOrderLabels = PurchaseOrderLabels.english

@MainActor private let purchaseOrderDocument = PurchaseOrderDocument(
    issuer: demoSupplier,
    vendor: PurchaseOrderDocumentVendor(
        party: InvoiceParty(
            name: "Rotterdam Pump Supply BV",
            street: "Havenweg 12",
            city: "3011 AB Rotterdam",
            country: "Netherlands",
            vatNumber: "NL812345678B01"
        ),
        registerNumber: "KvK 12345678",
        vendorNumber: "V-00042"
    ),
    deliverTo: PurchaseOrderDocumentDeliverTo(
        warehouse: InvoiceParty(
            name: "Antwerp Central Warehouse",
            street: "Dokweg 7",
            city: "2030 Antwerp",
            country: "Belgium"
        ),
        warehouseCode: "WH-ANT",
        deliveryAddress: "Loading dock 3, Dokweg 7, 2030 Antwerp, Belgium"
    ),
    header: PurchaseOrderDocumentHeader(
        orderNumber: nil, orderDate: "2026-10-26", revision: 1, generatedOn: "2026-10-26 14:05"
    ),
    metadataRows: [
        PurchaseOrderDocumentMetadataRow(caption: purchaseOrderLabels.requestedByLabel, value: "Jane Doe"),
        PurchaseOrderDocumentMetadataRow(caption: purchaseOrderLabels.vendorReferenceLabel, value: "Q-2026-118"),
        PurchaseOrderDocumentMetadataRow(caption: purchaseOrderLabels.expectedDeliveryDateLabel, value: "2026-11-15"),
        PurchaseOrderDocumentMetadataRow(
            caption: purchaseOrderLabels.paymentTermsLabel,
            value: purchaseOrderLabels.paymentTermsDays(name: "Net 30", days: "30")
        ),
        PurchaseOrderDocumentMetadataRow(caption: purchaseOrderLabels.currencyLabel, value: "EUR"),
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

@MainActor private let purchaseOrderPdf = PurchaseOrderLayout.build(
    purchaseOrderDocument,
    theme: .standard
)

@available(macOS 14, iOS 17, *)
#Preview("17 · Purchase Order", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(purchaseOrderPdf)
}
