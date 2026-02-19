import SwiftUI
import SwiftlyPDFKit
import SwiftlyPDFKitUI

// MARK: - Demo 10 · Stacked layout · teal theme

@MainActor private var tealTheme: InvoiceTheme = {
    let teal = PDFColor(red: 0.0, green: 0.49, blue: 0.49)
    let lightTeal = PDFColor(red: 0.85, green: 0.95, blue: 0.95)
    var t = InvoiceTheme.standard
    t.accentColor           = teal
    t.tableHeaderBackground = teal
    t.tableHeaderTextColor  = PDFColor.white
    t.tableAlternateRowColor = lightTeal
    t.ruleColor             = teal
    t.paymentBannerColor    = teal
    t.paymentBannerTextColor = PDFColor.white
    t.titleFont             = .helvetica
    return t
}()

@MainActor private let invoice10 = InvoiceDocument(
    header: InvoiceHeader(
        invoiceNumber: "INV-2026-010",
        documentTitle: "Invoice",
        issueDate: "2026-02-19",
        dueDate: "2026-03-12",
        currency: "EUR",
        paymentTerms: "Payable within 21 days.",
        paymentReference: "+++010/2026/00010+++",
        notes: "All amounts in EUR. VAT applied per Belgian regulations."
    ),
    supplier: demoSupplier,
    client: demoClient,
    lines: Array(demoLines.prefix(6)),
    footer: demoFooter
)

@MainActor private let pdf10 = PDF(layout: .stacked, invoice: invoice10, theme: tealTheme)

@available(macOS 14, iOS 17, *)
#Preview("10 · Stacked", traits: .fixedLayout(width: 595, height: 842)) {
    invoicePreview(pdf10)
}
