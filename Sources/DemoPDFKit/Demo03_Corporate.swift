import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 03 · Corporate theme · logo left · QR + notes + service date

@MainActor private let invoice = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "INV-2026-003",
        documentTitle: "Invoice",
        issueDate: "2026-02-19",
        dueDate: "2026-03-05",
        serviceDate: "2026-02-01 – 2026-02-28",
        currency: "EUR",
        paymentTerms: "Net 14 days. Late payments incur 1% monthly interest.",
        paymentReference: "+++003/2026/00001+++",
        notes: "Thank you for your business. All prices are exclusive of VAT unless otherwise stated.",
        qrPayload: demoQRPayload
    ),
    supplier: demoSupplier,
    client: demoClient,
    lines: demoLines,
    footer: demoFooter
)

@MainActor private let theme: InvoiceTheme = {
    var t = InvoiceTheme.corporate
    t.logoMaxWidth = 120
    t.logoMaxHeight = 60
    return t
}()

@MainActor private let pdf = PDF(layout: .classic, invoice: invoice, theme: theme)

@available(macOS 14, iOS 17, *)
#Preview("03 · Corporate", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(pdf)
}
