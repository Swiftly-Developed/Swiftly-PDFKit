import Foundation
import Testing
@testable import SwiftlyPDFKit

/// `QA-UNIT06-DOCUMENTS-144` … `-147` — `DocumentFormatter`'s number paths
/// honour the document locale it is handed, never the process locale.
///
/// `percent(_:)` printed with `String(format: "%.2f%%")` and `amount(_:)` /
/// `quantity(_:)` read a static `NumberFormatter` that had no locale, so an
/// nl-BE invoice showed its VAT column as "5.50%" and the client preview and
/// the Linux email attachment could disagree on every quantity. Each case
/// formats under **two** locales in one process: a locale-blind formatter
/// returns the same string for both, whatever the host's own locale is, so
/// the pair cannot pass by accident on an nl or en machine.
///
/// The type name deliberately carries the token `Document` so the suite
/// manifest's §2 grep reaches it.
@Suite("Document formatter locale")
struct DocumentFormatterLocaleTests {

    static let nlBE = Locale(identifier: "nl_BE")
    static let enUS = Locale(identifier: "en_US")

    static func formatter(_ locale: Locale) -> DocumentFormatter {
        DocumentFormatter(theme: .standard, locale: locale, currencyCode: "EUR")
    }

    // MARK: - QA-UNIT06-DOCUMENTS-144

    /// The value is a 0–100 rate (`21` means 21 %), the shape every layout
    /// passes (`InvoiceLine.vatRate`, `InvoiceTaxSubtotal.ratePercent`).
    @Test("percent follows the injected locale for whole and fractional rates")
    func percentFollowsLocale() {
        let nl = Self.formatter(Self.nlBE), en = Self.formatter(Self.enUS)
        #expect(nl.percent(5.5) == "5,5%")
        #expect(nl.percent(21) == "21%")
        #expect(en.percent(5.5) == "5.5%")
        #expect(en.percent(21) == "21%")
        #expect(nl.percent(0) == "0%")
        #expect(nl.percent(5.5) != en.percent(5.5), "percent ignores the injected locale")
    }

    // MARK: - QA-UNIT06-DOCUMENTS-145

    @Test("amount and quantity follow the injected locale, not the process locale")
    func amountAndQuantityFollowLocale() {
        let nl = Self.formatter(Self.nlBE), en = Self.formatter(Self.enUS)
        #expect(nl.amount(1234.5) == "1.234,50")
        #expect(en.amount(1234.5) == "1,234.50")
        #expect(nl.amount(-3) == "-3,00")
        #expect(nl.quantity(2.5) == "2,5")
        #expect(en.quantity(2.5) == "2.5")
        #expect(nl.quantity(3) == "3")
        #expect(nl.quantity(1234) == "1.234")
        #expect(nl.amount(1234.5) != en.amount(1234.5), "amount ignores the injected locale")
        #expect(nl.quantity(2.5) != en.quantity(2.5), "quantity ignores the injected locale")
    }

    // MARK: - QA-UNIT06-DOCUMENTS-146

    /// The rendered document, not the helper: the VAT and quantity cells of
    /// both families that print them, under the locale a host passes.
    @Test("a rendered nl-BE invoice prints locale-correct VAT and quantity cells")
    func renderedInvoiceUsesDocumentLocale() {
        let invoice = InvoiceDocument(
            header: InvoiceHeader(
                invoiceNumber: "2026-000131", issueDate: "27 sep 2026", currency: "EUR"),
            supplier: InvoiceSupplier(name: "Swiftly Business Consulting"),
            client: InvoiceClient(name: "Nordwind Logistics NV"),
            lines: [
                InvoiceLine(description: "Boeken", quantity: 2.5, unit: "st",
                            unitPrice: 40, vatRate: 5.5),
                InvoiceLine(description: "Advies", quantity: 3, unit: "u",
                            unitPrice: 100, vatRate: 21),
            ],
            taxBreakdown: [
                InvoiceTaxSubtotal(ratePercent: 5.5, taxableBase: 100, taxAmount: 5.5),
                InvoiceTaxSubtotal(ratePercent: 21, taxableBase: 300, taxAmount: 63),
            ])

        for layout in [InvoiceLayoutType.modern, .classic] {
            let nl = PDF(layout: layout, invoice: invoice, locale: Self.nlBE).renderHTML()
            #expect(nl.contains("5,5%"), "\(layout): nl-BE VAT cell is not locale-formatted")
            #expect(nl.contains("21%"), "\(layout): whole VAT rate missing")
            #expect(!nl.contains("5.50%"), "\(layout): C-locale percent leaked into an nl-BE document")
            #expect(nl.contains(">2,5<"), "\(layout): nl-BE quantity cell is not locale-formatted")

            // Positive control: the same document under en_US renders the
            // other spelling, so the nl-BE assertions above can fail.
            let en = PDF(layout: layout, invoice: invoice, locale: Self.enUS).renderHTML()
            #expect(en.contains("5.5%"), "\(layout): en-US VAT cell missing")
            #expect(en.contains(">2.5<"), "\(layout): en-US quantity cell missing")
        }
    }

    // MARK: - QA-UNIT06-DOCUMENTS-147

    /// The sales kinds built their formatter with no locale at all, so their
    /// numbers followed the process locale: European digits on the server for
    /// every recipient language, device digits on the client. Every sales
    /// layout now takes the recipient locale its host already resolves.
    @Test("quote, sales-order and delivery layouts format numbers in the passed locale")
    func salesKindsUseDocumentLocale() {
        let invoice = InvoiceDocument(
            header: InvoiceHeader(invoiceNumber: "Q-2026-0134", issueDate: "27 sep 2026",
                                  currency: "EUR"),
            supplier: InvoiceSupplier(name: "Swiftly Business Consulting"),
            client: InvoiceClient(name: "Nordwind Logistics NV"),
            lines: [InvoiceLine(description: "Boeken", quantity: 2.5, unit: "st",
                                unitPrice: 1234.5, vatRate: 5.5)])

        func rendered(_ locale: Locale) -> [(String, String)] {
            [
                ("quote classic", PDF(quoteLayout: .classic, invoice: invoice, locale: locale).renderHTML()),
                ("quote minimal", PDF(quoteLayout: .minimal, invoice: invoice, locale: locale).renderHTML()),
                ("sales order classic",
                 PDF(salesOrderLayout: .classic, invoice: invoice, locale: locale).renderHTML()),
                ("sales order stacked",
                 PDF(salesOrderLayout: .stacked, invoice: invoice, locale: locale).renderHTML()),
                ("delivery", PDF(deliveryLayout: .standard, invoice: invoice, locale: locale).renderHTML()),
            ]
        }

        for (name, html) in rendered(Self.nlBE) {
            #expect(html.contains(">2,5<"), "\(name): nl-BE quantity is not locale-formatted")
            if name != "delivery" {  // a delivery note carries no pricing columns
                #expect(html.contains("1.234,50"), "\(name): nl-BE amount is not locale-formatted")
                #expect(html.contains("5,5%"), "\(name): nl-BE VAT rate is not locale-formatted")
            }
        }
        for (name, html) in rendered(Self.enUS) {
            #expect(html.contains(">2.5<"), "\(name): en-US quantity is not locale-formatted")
            if name != "delivery" {
                #expect(html.contains("1,234.50"), "\(name): en-US amount is not locale-formatted")
            }
        }
    }
}
