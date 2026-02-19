import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 12 · Quotation · Classic layout · Standard theme

@MainActor private let quoteInvoice = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "QUO-2026-001",
        documentTitle: "Quotation",
        issueDate: "2026-02-19",
        serviceDate: "2026-03-01",
        currency: "EUR"
    ),
    supplier: demoSupplier,
    client: demoClient,
    lines: demoShortLines,
    footer: demoFooter
)

@MainActor private let quotePdf = PDF(
    quoteLayout: .classic,
    invoice: quoteInvoice,
    supplement: demoQuoteSupplement,
    theme: .standard
)

@available(macOS 14, iOS 17, *)
#Preview("12 · Quote", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(quotePdf)
}
