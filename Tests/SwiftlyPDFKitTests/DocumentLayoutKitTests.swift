import Foundation
import Testing
@testable import SwiftlyPDFKit

/// `QA-UNIT06-DOCUMENTS-46` … `-49` — the parts `PRINT01` phase 00 authored.
///
/// The phase's other instrument is a render-identity oracle (`ci_scripts/pdf-render-identity.py`)
/// that proves the *promoted* atoms did not move a single byte of invoice
/// output. That oracle is **structurally silent** about everything asserted
/// here: the seven new atoms have zero consumers anywhere in `PRINT01` —
/// nothing renders them until a later phase — so no demo exercises them, and
/// an 11/11 green there is not coverage of this phase. This file is.
///
/// Two authoring rules the package's own suite doc records apply throughout:
/// assert the **rendered output**, never the construction (a block that builds
/// fine and draws nothing passes a construction-only test), and assert the
/// **omission** cases, not only the positives.
///
/// The type name deliberately carries the token `Document` so the suite
/// manifest's §2 grep reaches it.
@Suite("Document layout kit")
struct DocumentLayoutKitTests {

    // MARK: Fixtures

    /// Every optional populated, so a block that prunes one shows the prune.
    static let fullSupplier = InvoiceSupplier(
        name: "Swiftly Business Consulting",
        street: "Posthofbrug 34",
        city: "2600 Antwerpen",
        country: "Belgium",
        vatNumber: "BE0778405303",
        registrationNumber: "0778.405.303",
        phone: "+32 3 123 45 67",
        email: "billing@example.com",
        website: "example.com",
        iban: "BE68 5390 0754 7034",
        bic: "GEBABEBB"
    )

    /// The legal minimum: a name and nothing else.
    static let bareSupplier = InvoiceSupplier(name: "Sole Trader")

    static let fullParty = InvoiceParty(
        name: "Nordwind Logistics NV",
        attention: "Ms. A. Peeters",
        street: "Havenlaan 12",
        city: "1000 Brussel",
        country: "Belgium",
        vatNumber: "BE0123456789"
    )

    static let bareParty = InvoiceParty(name: "Walk-in Customer")

    static let labels = CommonDocumentLabels.english
    static let theme = InvoiceTheme.standard
    static let formatter = DocumentFormatter(theme: InvoiceTheme.standard, currencyCode: "EUR")

    // MARK: Render helpers

    /// Wraps loose contents in a one-page document — the only way to reach
    /// *both* render paths, because both live on `Page`.
    static func page(_ contents: [any PDFContent]) -> Page {
        Page {
            for content in contents { content }
        }
    }

    /// The CoreGraphics bytes a block draws, and the HTML it emits.
    static func renderBoth(_ contents: [any PDFContent]) throws -> (cg: Data, html: String) {
        let pdf = PDF(pages: [page(contents)])
        return (try pdf.render(), pdf.renderHTML())
    }

    /// A page carrying nothing — the floor every "did this draw anything?"
    /// comparison is made against.
    static func emptyRender() throws -> (cg: Data, html: String) {
        try renderBoth([])
    }

    // MARK: - QA-UNIT06-DOCUMENTS-46

    @Test("-46 the register number derives only where statute makes it the VAT id")
    func registerNumberDerivation() {
        // Positives — the two jurisdictions the derivation claims.
        #expect(DocumentLayoutKit.registerNumber(fromVATID: "BE0778405303") == "0778.405.303")
        #expect(DocumentLayoutKit.registerNumber(fromVATID: "BE 0778.405.303") == "0778.405.303")
        #expect(DocumentLayoutKit.registerNumber(fromVATID: "be0778405303") == "0778.405.303")
        #expect(DocumentLayoutKit.registerNumber(fromVATID: "FR40303265045") == "303265045")
        #expect(DocumentLayoutKit.registerNumber(fromVATID: "FR 4A 303265045") == "303265045")

        // Omissions — the half that matters. A wrong register number on a
        // statutory letterhead is worse than an absent one, so every shape the
        // derivation does not claim must return nil rather than something
        // plausible.
        #expect(DocumentLayoutKit.registerNumber(fromVATID: "NL123456789B01") == nil)
        #expect(DocumentLayoutKit.registerNumber(fromVATID: "DE123456789") == nil)
        #expect(DocumentLayoutKit.registerNumber(fromVATID: "BE077840530") == nil)     // 9 digits
        #expect(DocumentLayoutKit.registerNumber(fromVATID: "BE07784053031") == nil)   // 11 digits
        #expect(DocumentLayoutKit.registerNumber(fromVATID: "BE07784O5303") == nil)    // letter O
        #expect(DocumentLayoutKit.registerNumber(fromVATID: "FR4030326504") == nil)    // short
        #expect(DocumentLayoutKit.registerNumber(fromVATID: "FR40303265O45") == nil)   // letter O
        #expect(DocumentLayoutKit.registerNumber(fromVATID: "BE") == nil)
        #expect(DocumentLayoutKit.registerNumber(fromVATID: "") == nil)
        #expect(DocumentLayoutKit.registerNumber(fromVATID: nil) == nil)

        // An explicitly recorded register number is never overridden by the
        // derivation, even where the derivation would have produced one.
        var recorded = Self.fullSupplier
        recorded.registrationNumber = "RC-9911"
        recorded.vatNumber = "BE0778405303"
        #expect(DocumentLayoutKit.registrationNumber(for: recorded) == "RC-9911")

        // …and the derivation IS the fallback when nothing is recorded.
        var derived = recorded
        derived.registrationNumber = nil
        #expect(DocumentLayoutKit.registrationNumber(for: derived) == "0778.405.303")

        // No recorded value and nothing derivable → the block omits the row.
        var neither = derived
        neither.vatNumber = "DE123456789"
        #expect(DocumentLayoutKit.registrationNumber(for: neither) == nil)
    }

    // MARK: - QA-UNIT06-DOCUMENTS-47

    /// One block under test: what it built, and strings its HTML must carry.
    struct BlockCase {
        let name: String
        let contents: [any PDFContent]
        let expected: [String]
    }

    /// Every composition block, fully populated. Lifted out of the `@Test` body
    /// so the assertions read as assertions.
    static var populatedBlocks: [BlockCase] {
        [
            BlockCase(
                name: "supplierIdentityBlock",
                contents: DocumentLayoutKit.supplierIdentityBlock(
                    supplier: fullSupplier, labels: labels, theme: theme),
                expected: ["Swiftly Business Consulting", "Posthofbrug 34", "BE0778405303",
                           "0778.405.303", "BE68 5390 0754 7034", "billing@example.com"]),
            BlockCase(
                name: "partyBlock",
                contents: DocumentLayoutKit.partyBlock(
                    party: fullParty, header: labels.billToHeader,
                    labels: labels, theme: theme),
                expected: ["Bill to", "Nordwind Logistics NV", "Ms. A. Peeters", "BE0123456789"]),
            BlockCase(
                name: "metadataGrid",
                contents: DocumentLayoutKit.metadataGrid(
                    rows: [("Invoice No.", "2026-000418"), ("Date", "13 June 2026"),
                           ("Due", "13 July 2026")],
                    theme: theme),
                expected: ["Invoice No.", "2026-000418", "13 July 2026"]),
            BlockCase(
                name: "signatureBlock",
                contents: DocumentLayoutKit.signatureBlock(labels: labels, theme: theme),
                expected: ["Acknowledgement of receipt", "Signature", "Print name"]),
            BlockCase(
                name: "totalsBlock",
                contents: DocumentLayoutKit.totalsBlock(
                    totals: InvoiceTotals(subtotalExcl: 6150, totalVat: 787.5,
                                          totalIncl: 6937.5, amountPaid: 1000),
                    labels: labels, formatter: formatter, theme: theme),
                expected: ["Subtotal", "Tax", "Total", "Amount paid", "Amount due"]),
        ]
    }

    @Test("-47 the composition blocks render through BOTH paths, and prune")
    func compositionBlocksRender() throws {
        let floor = try Self.emptyRender()

        for block in Self.populatedBlocks {
            #expect(!block.contents.isEmpty, "\(block.name) built nothing")
            let rendered = try Self.renderBoth(block.contents)

            // Both paths, asserted independently — they share no fallback, so a
            // block that draws on one and not the other must fail here.
            #expect(rendered.cg.count > floor.cg.count,
                    "\(block.name) drew no CoreGraphics ink")
            #expect(rendered.html.count > floor.html.count,
                    "\(block.name) emitted no HTML")
            for needle in block.expected {
                #expect(rendered.html.contains(needle),
                        "\(block.name) HTML is missing \(needle)")
            }
        }

        // Pruning. An empty row list is the one shape that renders nothing at
        // all; the two party-shaped blocks shrink rather than vanish, because a
        // name is never optional.
        #expect(DocumentLayoutKit.metadataGrid(rows: [], theme: Self.theme).isEmpty)

        let fullSupplierHTML = try Self.renderBoth(
            DocumentLayoutKit.supplierIdentityBlock(
                supplier: Self.fullSupplier, labels: Self.labels, theme: Self.theme)).html
        let bareSupplierHTML = try Self.renderBoth(
            DocumentLayoutKit.supplierIdentityBlock(
                supplier: Self.bareSupplier, labels: Self.labels, theme: Self.theme)).html
        #expect(bareSupplierHTML.count < fullSupplierHTML.count)
        #expect(bareSupplierHTML.contains("Sole Trader"))
        #expect(!bareSupplierHTML.contains(Self.labels.ibanLabel))
        #expect(!bareSupplierHTML.contains(Self.labels.vatNumberLabel))

        let barePartyHTML = try Self.renderBoth(
            DocumentLayoutKit.partyBlock(
                party: Self.bareParty, header: Self.labels.shipToHeader,
                labels: Self.labels, theme: Self.theme)).html
        #expect(barePartyHTML.contains("Ship to"))
        #expect(barePartyHTML.contains("Walk-in Customer"))
        #expect(!barePartyHTML.contains(Self.labels.vatNumberLabel))

        // A settled-nothing document shows the four-row ladder, not six.
        let unpaidHTML = try Self.renderBoth(
            DocumentLayoutKit.totalsBlock(
                totals: InvoiceTotals(subtotalExcl: 100, totalVat: 21, totalIncl: 121),
                labels: Self.labels, formatter: Self.formatter, theme: Self.theme)).html
        #expect(unpaidHTML.contains(Self.labels.totalsTotalLabel))
        #expect(!unpaidHTML.contains(Self.labels.totalsAmountPaidLabel))
        #expect(!unpaidHTML.contains(Self.labels.totalsDiscountLabel))
    }

    // MARK: - QA-UNIT06-DOCUMENTS-48

    @Test("-48 the watermark is page-level and full-bleed, not body content")
    func watermarkIsPageLevel() throws {
        let mark = DocumentWatermark(text: "COPY")

        // It is pulled out of the content list by type, exactly as the accent
        // bar is — so it never reaches the margin-inset body cursor.
        let page = Page {
            Text("body")
            mark
        }
        #expect(page.watermark != nil)
        #expect(page.bodyContents.count == 1)
        #expect(page.bodyContents.allSatisfy { !($0 is DocumentWatermark) })

        // Its own two render methods are inert by design: whatever it draws, it
        // is `Page` that draws it.
        var cursor: CGFloat = 800
        #expect(mark.renderHTML(bounds: CGRect(x: 0, y: 0, width: 500, height: 800),
                                cursor: &cursor).isEmpty)
        #expect(cursor == 800, "the marker must not consume the body cursor")

        // BOTH of Page's render arms emit it. A primitive implementing only one
        // renders a different document on the server than in the client
        // preview, which is the defect class this assertion exists to close.
        let plain = PDF(pages: [Page { Text("body") }])
        let marked = PDF(pages: [page])
        #expect(try marked.render().count > plain.render().count,
                "the CoreGraphics arm drew no watermark ink")

        let html = marked.renderHTML()
        #expect(!plain.renderHTML().contains("class=\"watermark\""))
        #expect(html.contains("class=\"watermark\""))
        #expect(html.contains(">COPY<"))
        // Full-bleed and page-anchored: positioned against the page box, not
        // inside the padding box, and rotated.
        #expect(html.contains("position:absolute"))
        #expect(html.contains("width:100%"))
        #expect(html.contains("rotate("))
        // CSS measures clockwise where CoreGraphics measures counter-clockwise,
        // so a positive CG rotation must emit a negative CSS one.
        #expect(html.contains("rotate(-"))

        // The watermark div is emitted AFTER the body div, so both paths agree
        // on paint order (body, then watermark, then accent bar and footer).
        let bodyIndex = try #require(html.range(of: "class=\"body\""))
        let markIndex = try #require(html.range(of: "class=\"watermark\""))
        #expect(bodyIndex.lowerBound < markIndex.lowerBound)
    }

    // MARK: - QA-UNIT06-DOCUMENTS-49

    @Test("-49 the common label set is total and frozen at 24 members")
    func commonLabelsAreFrozen() {
        let labels = CommonDocumentLabels()

        // The count assertion is what stops a later phase quietly growing a
        // struct whose whole contract is that its member LIST never grows.
        #expect(Mirror(reflecting: labels).children.count == 24)

        // Total: every member carries a non-empty English default, so a caller
        // that overrides nothing still renders words rather than blanks.
        for child in Mirror(reflecting: labels).children {
            let value = try? #require(child.value as? String)
            #expect(value?.isEmpty == false, "\(child.label ?? "?") has no default")
        }

        // `CommonDocumentLabels()` is `.english`.
        #expect(labels.pageNumberTemplate == CommonDocumentLabels.english.pageNumberTemplate)

        // The one `LabelSet` requirement, expanding both tokens.
        #expect(labels.pageNumber(2, of: 7) == "Page 2 of 7")
        var reordered = labels
        reordered.pageNumberTemplate = "{pages} pagina's — nr. {page}"
        #expect(reordered.pageNumber(2, of: 7) == "7 pagina's — nr. 2")

        // Both label structs satisfy the protocol, and the invoice one does so
        // through an ADDITIVE empty extension — it is public with consumers
        // outside this package, so the conformance may add no surface.
        let sets: [any LabelSet] = [labels, InvoiceLabels.english]
        for set in sets {
            #expect(!set.pageNumber(1, of: 1).isEmpty)
        }
        #expect(InvoiceLabels.english.pageNumber(3, of: 4) == "Page 3 of 4")
    }
}
