import Foundation
import Testing
@testable import SwiftlyPDFKit

/// QA-UNIT06-DOCUMENTS `-125` / `-126` — the regression guards for
/// `docs/fixes/2026-09-12-vendor-document-pdf-vendor-address.md` in the
/// package lane.
///
/// A purchase-order-typed vendor document prints through the invoice layouts,
/// so the package gained two members:
///   • `InvoiceDocument.hidesSettlement` (`-125`) — a document that requests
///     no payment must render no due-date row, no due/paid headline, no closing
///     "Amount due" totals row and no payment block, in EVERY family.
///   • `InvoiceClient.registrationNumber` (`-126`) — the bill-to party's
///     registration id, rendered under the existing `registrationIdLabel`.
///
/// Oracle shape (TESTING.md §2.1 — an absence is only evidence beside a
/// control): every "absent when hidden" assertion is paired with the SAME
/// marker asserted PRESENT on the same fixture with `hidesSettlement == false`.
/// The fixture keeps `header.dueDate` populated in both arms, so the prune is
/// provably the package's gate and not missing data (the Shared mapper also
/// nils the due date for a PO; that half is `-123`, not re-proven here).
/// The registration row is measured as a label-COUNT DELTA: the supplier block
/// already prints the same label, so value-presence alone would not notice an
/// empty client row rendered for `nil`.
@Suite("Invoice settlement suppression + client registration number")
struct InvoiceSettlementAndRegistrationTests {

    static let families: [InvoiceLayoutType] = [.modern, .classic, .receipt]

    /// The maximal family fixture (every optional block populated), UNPAID —
    /// the state in which every settlement block normally renders.
    static func document(hidesSettlement: Bool, registration: String? = nil) -> InvoiceDocument {
        var doc = InvoiceLayoutFamilyTests.document(paid: false)
        doc.hidesSettlement = hidesSettlement
        doc.client.registrationNumber = registration
        return doc
    }

    static func html(_ layout: InvoiceLayoutType, hidesSettlement: Bool, registration: String? = nil) -> String {
        PDF(layout: layout, invoice: document(hidesSettlement: hidesSettlement, registration: registration))
            .renderHTML()
    }

    static func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.lowercased().components(separatedBy: needle.lowercased()).count - 1
    }

    // Markers — each lives ONLY in the block it stands for (re-derived from the
    // layout sources, not from rendered output):
    static let dueDateValue = "13 July 2026"                     // header.dueDate — the due-date row/column
    static let amountDue = InvoiceLabels.english.amountDueLabel   // the closing totals row ("AMOUNT DUE" in Classic)
    static let iban = "BE68 5390 0754 7034"                       // supplier.iban — the payment block
    /// The literal core of the Modern due headline template ("{amount} due by {date}").
    static let dueHeadlineCore = " due by "

    @Test("QA-UNIT06-DOCUMENTS-125: hidesSettlement prunes the due date, the closing amount-due row and the payment block in every family — each marker present on the same fixture when false")
    func hidesSettlementPrunesEveryFamily() {
        for layout in Self.families {
            let shown = Self.html(layout, hidesSettlement: false)
            let hidden = Self.html(layout, hidesSettlement: true)

            // CONTROL — the default (false) still renders every settlement block.
            #expect(shown.contains(Self.dueDateValue), "\(layout): control lost the due date — fixture no longer exercises the gate")
            #expect(Self.occurrences(of: Self.amountDue, in: shown) >= 1, "\(layout): control lost the closing amount-due row")
            #expect(shown.contains(Self.iban), "\(layout): control lost the payment block")

            // GATE — hidden, with header.dueDate still populated.
            #expect(!hidden.contains(Self.dueDateValue), "\(layout): due date still rendered with hidesSettlement")
            #expect(Self.occurrences(of: Self.amountDue, in: hidden) == 0, "\(layout): amount-due row still rendered with hidesSettlement")
            #expect(!hidden.contains(Self.iban), "\(layout): payment block still rendered with hidesSettlement")

            // The prune must not take the document with it.
            #expect(hidden.contains("Implementation"), "\(layout): line table vanished")
            #expect(hidden.contains(InvoiceLabels.english.totalLabel), "\(layout): grand total vanished")
        }

        // Modern is the only family with a due/paid headline.
        #expect(Self.html(.modern, hidesSettlement: false).contains(Self.dueHeadlineCore), "modern control lost the due headline")
        #expect(!Self.html(.modern, hidesSettlement: true).contains(Self.dueHeadlineCore), "modern due headline still rendered with hidesSettlement")
    }

    @Test("QA-UNIT06-DOCUMENTS-126: a client registrationNumber adds exactly one registration-id row in every family; nil adds none")
    func clientRegistrationNumberRow() {
        let value = "CLIENT-REG-4242"
        let label = InvoiceLabels.english.registrationIdLabel
        for layout in Self.families {
            let without = Self.html(layout, hidesSettlement: false, registration: nil)
            let with = Self.html(layout, hidesSettlement: false, registration: value)

            #expect(with.contains(value), "\(layout): client registration value not rendered")
            #expect(!without.contains(value), "\(layout): fixture already carries the sentinel value")
            // The supplier block prints the same label, so assert the DELTA:
            // nil must render no (empty) client row, a value exactly one.
            #expect(
                Self.occurrences(of: label, in: with) == Self.occurrences(of: label, in: without) + 1,
                "\(layout): expected exactly one extra '\(label)' row for the client registration"
            )
        }
    }
}
