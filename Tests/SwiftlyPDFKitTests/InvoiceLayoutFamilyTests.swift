import Foundation
import Testing
@testable import SwiftlyPDFKit

/// The package's first tests.
///
/// Phase 10 replaced three builders that rendered one identical arrangement
/// with three genuinely different ones. The failure mode that matters is not a
/// crash — it is a family quietly collapsing back into a sibling, or a block
/// the spec requires quietly disappearing. Both are invisible to a compiler and
/// to every existing gate, so they are asserted here.
@Suite("Invoice layout families")
struct InvoiceLayoutFamilyTests {

    // MARK: Fixture

    /// Deliberately maximal: every optional block populated, so a family that
    /// prunes one shows the prune and one that keeps it shows the keep.
    static func document(paid: Bool) -> InvoiceDocument {
        InvoiceDocument(
            header: InvoiceHeader(
                invoiceNumber: "2026-000418", documentTitle: "Invoice",
                issueDate: "13 June 2026", dueDate: "13 July 2026",
                serviceDate: "1–30 June 2026", currency: "EUR",
                paymentTerms: "30 days net", paymentReference: "+++090/9337/55493+++",
                notes: nil,
                qrPayload: paid ? nil : "BCD\n002\n1\nSCT\nGEBABEBB\nAcme\nBE68539007547034\nEUR1.00"),
            supplier: InvoiceSupplier(
                name: "Swiftly Business Consulting", street: "Posthofbrug 34",
                city: "2600 Antwerpen", country: "Belgium",
                vatNumber: "BE0778405303", registrationNumber: "0778.405.303",
                iban: "BE68 5390 0754 7034", bic: "GEBABEBB"),
            client: InvoiceClient(
                name: "Nordwind Logistics NV", attention: "Ms. A. Peeters",
                street: "Havenlaan 12", city: "1000 Brussel", country: "Belgium",
                vatNumber: "BE0123456789", clientNumber: "C-1042"),
            lines: [
                InvoiceLine(description: "Implementation", detail: "1–7 June 2026",
                            quantity: 3, unit: "days", unitPrice: 1250, vatRate: 21),
                InvoiceLine(description: "Data migration", quantity: 1, unit: "pcs",
                            unitPrice: 2400, vatRate: 0),
            ],
            footer: InvoiceFooter(lines: ["swiftly-workspace.com"], height: 14),
            shipTo: InvoiceParty(name: "Nordwind DC Oost", street: "Industrieweg 88",
                                 city: "3600 Genk", country: "Belgium"),
            taxBreakdown: [
                InvoiceTaxSubtotal(ratePercent: 21, taxableBase: 3750, taxAmount: 787.50),
                InvoiceTaxSubtotal(ratePercent: 0, taxableBase: 2400, taxAmount: 0,
                                   exemptionReason: "Reverse charge, art. 196"),
            ],
            taxNote: "Tax to be paid on a reverse-charge basis.",
            paymentState: paid ? .paid(on: Date(timeIntervalSince1970: 1_781_000_000))
                               : .due(on: Date(timeIntervalSince1970: 1_783_000_000)),
            paymentHistory: paid
                ? [InvoicePaymentRow(method: "SEPA credit transfer",
                                     date: Date(timeIntervalSince1970: 1_781_000_000),
                                     amount: 4537.50, receiptNumber: "R-2026-0091")]
                : nil)
    }

    static func html(_ layout: InvoiceLayoutType, paid: Bool = false,
                     theme: InvoiceTheme = .standard) -> String {
        PDF(layout: layout, invoice: document(paid: paid), theme: theme).renderHTML()
    }

    // MARK: The regression that matters

    @Test("the three families render three DIFFERENT documents")
    func familiesAreDistinct() {
        let m = Self.html(.modern), c = Self.html(.classic), r = Self.html(.receipt)
        #expect(m != c, "modern and classic collapsed into one arrangement")
        #expect(c != r, "classic and receipt collapsed into one arrangement")
        #expect(m != r, "modern and receipt collapsed into one arrangement")
    }

    @Test("every family renders through both paths without throwing")
    func bothRenderPathsSurvive() throws {
        for layout in [InvoiceLayoutType.modern, .classic, .receipt] {
            for paid in [true, false] {
                let pdf = PDF(layout: layout, invoice: Self.document(paid: paid))
                #expect(!pdf.renderHTML().isEmpty)
                #if canImport(CoreGraphics)
                let data = try pdf.render()
                #expect(data.count > 1000)
                #expect(data.prefix(5) == Data("%PDF-".utf8), "not a PDF")
                #endif
            }
        }
    }

    // MARK: Per-family grammar

    @Test("only Modern carries the full-bleed accent bar")
    func onlyModernHasAccentBar() {
        #expect(Self.html(.modern).contains("top-accent-bar"))
        #expect(!Self.html(.classic).contains("top-accent-bar"))
        #expect(!Self.html(.receipt).contains("top-accent-bar"))
    }

    /// Owner decision D1: the spec requires these blocks and no reference has
    /// them, so nothing but a test stops a future "reference fidelity" edit
    /// from deleting them and silently orphaning the mapper's enrichment.
    @Test("Modern and Classic keep ship-to, the VAT breakdown and the bank block")
    func d1BlocksSurvive() {
        for layout in [InvoiceLayoutType.modern, .classic] {
            let h = Self.html(layout)
            #expect(h.contains("Nordwind DC Oost"), "\(layout): ship-to pruned")
            #expect(h.contains("Reverse charge, art. 196"), "\(layout): VAT breakdown pruned")
            #expect(h.contains("BE68 5390 0754 7034"), "\(layout): bank block pruned")
        }
    }

    /// Owner decision D2 — the load-bearing one. `document_layout_preference`
    /// is company-wide, so a Receipt tenant gets this family for unpaid
    /// invoices too; pruning the payment block unconditionally would emit an
    /// unpayable document.
    @Test("an UNPAID Receipt still carries IBAN, reference and QR")
    func d2UnpaidReceiptIsPayable() {
        let due = Self.html(.receipt, paid: false)
        #expect(due.contains("BE68 5390 0754 7034"), "unpaid receipt has no IBAN — unpayable")
        #expect(due.contains("+++090/9337/55493+++"), "unpaid receipt has no payment reference")
        #expect(due.contains("13 July 2026"), "unpaid receipt has no due date")
    }

    @Test("a PAID Receipt prunes the payment block and shows the acknowledgement")
    func d2PaidReceiptPrunes() {
        let paid = Self.html(.receipt, paid: true)
        #expect(!paid.contains("BE68 5390 0754 7034"), "settled receipt still shows a bank block")
        #expect(paid.contains(InvoiceLabels.english.thankYouNote))
    }

    /// Both paid reference samples title the page "Receipt" — a state
    /// question, not a family question.
    @Test("the settled state retitles the document in every family")
    func settledStateRetitles() {
        for layout in [InvoiceLayoutType.modern, .classic, .receipt] {
            #expect(Self.html(layout, paid: true).contains(InvoiceLabels.english.documentTitleReceipt),
                    "\(layout): settled document not retitled")
        }
    }

    /// Slack is a paid sample with no history table, so the rule is
    /// "render when rows exist", not "render when paid".
    @Test("payment history renders only when rows exist")
    func paymentHistoryIsConditional() {
        #expect(Self.html(.modern, paid: true).contains("R-2026-0091"))
        #expect(!Self.html(.modern, paid: false).contains(InvoiceLabels.english.paymentHistoryHeader))
    }

    // MARK: Theme + accent

    @Test("applyingAccent repoints every preset's accent")
    func accentOverrideReachesTheBar() {
        let brand = PDFColor(red: 0, green: 0.42, blue: 0.36)
        for preset in [InvoiceTheme.standard, .gold, .corporate] {
            let overridden = preset.applyingAccent(brand)
            #expect(overridden.accentColor.cssRGBA == brand.cssRGBA)
            #expect(Self.html(.modern, theme: overridden).contains(brand.cssRGBA),
                    "the brand accent never reached the rendered bar")
        }
    }

    // MARK: Labels

    @Test("the label set the families render is the frozen 49")
    func labelCardinality() {
        #expect(Mirror(reflecting: InvoiceLabels.english).children.count == 49)
    }
}
