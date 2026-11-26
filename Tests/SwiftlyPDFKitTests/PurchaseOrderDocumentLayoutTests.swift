import Foundation
import Testing
@testable import SwiftlyPDFKit
#if canImport(PDFKit)
import PDFKit
#endif

/// The purchase-order family `PRINT08` phase 00 authored: its label set, its
/// model and `PurchaseOrderLayout`. `-221` (the stacked description cell's
/// drawn wrap) lives in `PurchaseOrderDocumentDescriptionWrapTests.swift`, an
/// extension of this same `@Suite`.
///
/// Authoring rules carried from `DocumentLayoutKitTests` /
/// `PaymentReceiptDocumentLayoutTests`: assert the **rendered output** of both
/// paths, never the construction; assert every **omission** with a positive
/// control on the same fixture; count **delimited** forms (`>caption<`),
/// because several captions are substrings of others or equal to each other
/// (`Discount` is both a column header and the common totals caption).
///
/// The type name deliberately carries the token `Document` so the suite
/// manifest's §2 grep reaches it.
@Suite("Purchase order document layout")
struct PurchaseOrderDocumentLayoutTests {

    // MARK: Fixtures

    static let issuer = InvoiceSupplier(
        name: "Swiftly Business Consulting",
        street: "Posthofbrug 34",
        city: "2600 Antwerpen",
        country: "Belgium",
        vatNumber: "BE0778405303",
        email: "purchasing@example.com",
        iban: "BE68 5390 0754 7034",
        bic: "GEBABEBB"
    )

    static let vendor = PurchaseOrderDocumentVendor(
        party: InvoiceParty(
            name: "Rotterdam Pump Supply BV", street: "Havenweg 12", city: "3011 AB Rotterdam",
            country: "Netherlands", vatNumber: "NL812345678B01"),
        registerNumber: "KvK 12345678",
        vendorNumber: "V-00042")

    static let deliverTo = PurchaseOrderDocumentDeliverTo(
        warehouse: InvoiceParty(
            name: "Antwerp Central Warehouse", street: "Dokweg 7", city: "2030 Antwerp", country: "Belgium"),
        warehouseCode: "WH-ANT",
        deliveryAddress: "Loading dock 3, Dokweg 7, 2030 Antwerp, Belgium")

    static let header = PurchaseOrderDocumentHeader(
        orderNumber: nil, orderDate: "2026-10-26", revision: 1, generatedOn: "2026-10-26 14:05")

    static let labels = PurchaseOrderLabels.english

    static let metadataRows = [
        PurchaseOrderDocumentMetadataRow(caption: labels.requestedByLabel, value: "Jane Doe"),
        PurchaseOrderDocumentMetadataRow(caption: labels.vendorReferenceLabel, value: "Q-2026-118"),
        PurchaseOrderDocumentMetadataRow(caption: labels.expectedDeliveryDateLabel, value: "2026-11-15"),
        PurchaseOrderDocumentMetadataRow(
            caption: labels.paymentTermsLabel, value: labels.paymentTermsDays(name: "Net 30", days: "30")),
        PurchaseOrderDocumentMetadataRow(caption: labels.currencyLabel, value: "EUR"),
    ]

    static let serviceDescription = "Installation and commissioning on site, including alignment of pump "
        + "and motor, a pressure test and a written handover report"
    static let serviceNote = "Technician to report to the warehouse gate"

    /// One stock line, one service line (long, wrapping, with an expected date
    /// and a note), one expense line.
    static let lines = [
        PurchaseOrderDocumentLine(
            itemSKU: "PMP-4410", itemName: "Centrifugal pump 4 kW",
            description: "Stainless steel housing, 400 V three-phase motor",
            quantity: 2, unitOfMeasure: "pcs", unitCost: 1_250, discountPercent: 5,
            taxRatePercent: 21, lineTotal: 2_375),
        PurchaseOrderDocumentLine(
            description: serviceDescription, quantity: 1, unitCost: 680, taxRatePercent: 21,
            lineTotal: 680, expectedDelivery: "2026-11-20", note: serviceNote),
        PurchaseOrderDocumentLine(
            description: "Printed safety documentation (NL / FR)", quantity: 3, unitOfMeasure: "sets",
            unitCost: 12.5, taxRatePercent: 6, lineTotal: 37.5),
    ]

    static let taxRows = [
        PurchaseOrderDocumentTaxRow(ratePercent: 21, taxableBase: 3_055, taxAmount: 641.55),
        PurchaseOrderDocumentTaxRow(ratePercent: 6, taxableBase: 37.5, taxAmount: 2.25),
    ]

    static let totals = PurchaseOrderDocumentTotals(
        currencyCode: "EUR", subtotal: 3_092.5, discount: nil, shipping: 85, tax: 643.80, total: 3_821.30)

    static let instructions = "Deliver between 08:00 and 16:00. Quote the order number on every delivery note."

    static func document(
        issuer: InvoiceSupplier = issuer,
        deliverTo: PurchaseOrderDocumentDeliverTo? = deliverTo,
        header: PurchaseOrderDocumentHeader = header,
        lines: [PurchaseOrderDocumentLine] = lines,
        closedShortOmittedCount: Int = 1,
        taxRows: [PurchaseOrderDocumentTaxRow] = taxRows,
        totals: PurchaseOrderDocumentTotals = totals,
        specialInstructions: String? = instructions,
        watermark: PurchaseOrderDocumentWatermark = .draft,
        labels: PurchaseOrderLabels = labels,
        common: CommonDocumentLabels = .english
    ) -> PurchaseOrderDocument {
        PurchaseOrderDocument(
            issuer: issuer, vendor: vendor, deliverTo: deliverTo, header: header,
            metadataRows: metadataRows, lines: lines, closedShortOmittedCount: closedShortOmittedCount,
            taxRows: taxRows, totals: totals, specialInstructions: specialInstructions,
            watermark: watermark, labels: labels, common: common)
    }

    /// `count` lines with zero-padded SKUs `SKU-0001` … — enough to paginate.
    static func manyLines(_ count: Int) -> [PurchaseOrderDocumentLine] {
        (1...count).map { index in
            let number = String(index)
            return PurchaseOrderDocumentLine(
                itemSKU: "SKU-" + String(repeating: "0", count: 4 - number.count) + number,
                description: "Spare part", quantity: 1, unitCost: 10, taxRatePercent: 21, lineTotal: 10)
        }
    }

    /// `>text<` occurrences — the delimited form of a rendered caption or cell.
    static func count(_ text: String, in html: String) -> Int {
        html.components(separatedBy: ">" + text + "<").count - 1
    }

    /// The HTML of each page, split on the page-box marker `Page.renderHTML` emits.
    static func pageSegments(_ html: String) -> [String] {
        Array(html.components(separatedBy: "<div class=\"page\"").dropFirst())
    }

    // MARK: Test -214

    /// `QA-UNIT06-DOCUMENTS-214`
    @Test("-214 the label set has exactly 38 non-empty members and its helpers expand their tokens")
    func labelSetShapeAndHelpers() {
        let children = Mirror(reflecting: Self.labels).children
        #expect(children.count == 38)
        for child in children {
            let value = child.value as? String
            #expect(value != nil, "\(child.label ?? "?") is not a String")
            #expect(value?.isEmpty == false, "\(child.label ?? "?") is empty")
            #expect(value?.contains("%@") == false, "\(child.label ?? "?") carries %@")
            #expect(value?.contains("%lld") == false, "\(child.label ?? "?") carries %lld")
        }

        let labels = Self.labels
        #expect(labels.paymentTermsDays(name: "Net 30", days: "30") == "Net 30 (30-day term)")
        #expect(labels.incoterm(rule: "FCA", place: "Antwerp") == "FCA Antwerp")
        #expect(labels.incoterm(rule: "FCA", place: "") == "FCA")
        #expect(labels.lineExpectedDelivery(date: "2026-11-20") == "Expected 2026-11-20")
        #expect(labels.closedShortLinesOmitted(count: "3") == "Closed lines not shown: 3")
        #expect(labels.cancelledNotice(date: "2026-10-01") == "This order was cancelled on 2026-10-01.")

        var reordered = PurchaseOrderLabels()
        reordered.paymentTermsDaysFormat = "{days} days — {name}"
        reordered.incotermFormat = "{place} ({rule})"
        reordered.lineExpectedDeliveryFormat = "{date} expected"
        reordered.closedShortLinesOmittedFormat = "{count} closed"
        reordered.cancelledNoticeFormat = "{date}: cancelled"
        #expect(reordered.paymentTermsDays(name: "Net 30", days: "30") == "30 days — Net 30")
        #expect(reordered.incoterm(rule: "FCA", place: "Antwerp") == "Antwerp (FCA)")
        #expect(reordered.lineExpectedDelivery(date: "D") == "D expected")
        #expect(reordered.closedShortLinesOmitted(count: "3") == "3 closed")
        #expect(reordered.cancelledNotice(date: "D") == "D: cancelled")
    }

    // MARK: Test -215

    /// `QA-UNIT06-DOCUMENTS-215`
    @Test("-215 the full order renders through both paths with every block present")
    func fullOrderRendersBothPaths() throws {
        let pdf = PurchaseOrderLayout.build(Self.document())
        let floor = try PDF(pages: [Page {}]).render()
        let cgBytes = try pdf.render()
        let html = pdf.renderHTML()
        let labels = Self.labels
        let common = CommonDocumentLabels.english

        #expect(cgBytes.count > floor.count)
        #expect(!html.isEmpty)

        var expected = [
            labels.purchaseOrderTitle, labels.draftNumberPlaceholder,
            labels.buyerHeader, labels.vendorHeader, Self.vendor.party.name,
            "\(labels.vendorNumberLabel) V-00042", "\(common.registrationNumberLabel) KvK 12345678",
            labels.deliverToHeader, "\(labels.warehouseLabel) WH-ANT", Self.deliverTo.deliveryAddress ?? "",
            "PMP-4410", "Centrifugal pump 4 kW", "Stainless steel housing, 400 V three-phase motor",
            Self.serviceDescription, "Printed safety documentation (NL / FR)",
            labels.lineExpectedDelivery(date: "2026-11-20"), Self.serviceNote,
            labels.taxBreakdownHeader, "21%", "6%",
            common.totalsSubtotalLabel, labels.shippingLabel, common.totalsTaxLabel, common.totalsTotalLabel,
            Self.instructions, labels.confirmationRequestFooter, labels.indicativeTaxFooter,
            common.pageNumber(1, of: pdf.pages.count),
        ]
        expected += Self.metadataRows.map(\.caption)
        expected += [
            labels.linesColumnItem, labels.linesColumnDescription, labels.linesColumnQuantity,
            labels.linesColumnUnitCost, labels.linesColumnDiscount, labels.linesColumnTaxRate,
            labels.linesColumnLineTotal,
        ]
        for text in expected {
            #expect(Self.count(text, in: html) >= 1, "missing \(text)")
        }
        #expect(html.contains("3,821.30 EUR<"), "the total does not carry its ISO code")

        let numbered = PurchaseOrderLayout.build(Self.document(header: PurchaseOrderDocumentHeader(
            orderNumber: "PO00042", orderDate: "2026-10-26", revision: 1))).renderHTML()
        #expect(Self.count("PO00042", in: numbered) == 1)
        #expect(Self.count(labels.draftNumberPlaceholder, in: numbered) == 0)
    }

    // MARK: Test -216

    /// `QA-UNIT06-DOCUMENTS-216`
    @Test("-216 every optional block is omitted when empty and present when set")
    func omissionsWithPositiveControls() {
        let labels = Self.labels
        func html(_ document: PurchaseOrderDocument) -> String {
            PurchaseOrderLayout.build(document).renderHTML()
        }

        #expect(Self.count(labels.deliverToHeader, in: html(Self.document(deliverTo: nil))) == 0)
        #expect(Self.count(labels.deliverToHeader, in: html(Self.document())) == 1)

        #expect(Self.count(labels.taxBreakdownHeader, in: html(Self.document(taxRows: []))) == 0)
        #expect(Self.count(labels.taxBreakdownHeader, in: html(Self.document())) == 1)

        func totals(discount: Double? = nil, shipping: Double? = nil, tax: Double = 643.80)
            -> PurchaseOrderDocumentTotals {
            PurchaseOrderDocumentTotals(
                currencyCode: "EUR", subtotal: 3_092.5, discount: discount, shipping: shipping,
                tax: tax, total: 3_821.30)
        }
        for shipping in [nil, 0] as [Double?] {
            #expect(Self.count(labels.shippingLabel, in: html(Self.document(totals: totals(shipping: shipping)))) == 0)
        }
        #expect(Self.count(labels.shippingLabel, in: html(Self.document(totals: totals(shipping: 85)))) == 1)

        // `Discount` is also the lines column header, so the totals caption is sentinelled.
        var common = CommonDocumentLabels()
        common.totalsDiscountLabel = "SENTINEL-DISCOUNT"
        for discount in [nil, 0] as [Double?] {
            let rendered = html(Self.document(totals: totals(discount: discount), common: common))
            #expect(Self.count("SENTINEL-DISCOUNT", in: rendered) == 0)
        }
        #expect(Self.count("SENTINEL-DISCOUNT",
                           in: html(Self.document(totals: totals(discount: 50), common: common))) == 1)

        let zeroTax = html(Self.document(taxRows: [], totals: totals(tax: 0)))
        #expect(Self.count(CommonDocumentLabels.english.totalsTaxLabel, in: zeroTax) == 1)

        let unrevised = PurchaseOrderDocumentHeader(orderDate: "2026-10-26")
        #expect(Self.count(labels.revisionLabel, in: html(Self.document(header: unrevised))) == 0)
        #expect(Self.count(labels.revisionLabel, in: html(Self.document())) == 1)

        #expect(Self.count(labels.specialInstructionsHeader,
                           in: html(Self.document(specialInstructions: "  \n"))) == 0)
        #expect(Self.count(labels.specialInstructionsHeader, in: html(Self.document())) == 1)

        // A zero discount and a nil tax rate print no percentage; a zero tax rate does.
        func oneLine(taxRate: Double?) -> PurchaseOrderDocument {
            Self.document(lines: [PurchaseOrderDocumentLine(
                description: "Gasket", quantity: 1, unitCost: 10, discountPercent: 0,
                taxRatePercent: taxRate, lineTotal: 10)], taxRows: [])
        }
        #expect(Self.count("0%", in: html(oneLine(taxRate: nil))) == 0)
        #expect(Self.count("0%", in: html(oneLine(taxRate: 0))) == 1)
    }

    // MARK: Test -217

    /// `QA-UNIT06-DOCUMENTS-217`
    @Test("-217 the draft and cancelled watermarks sit on every page; the notice needs a date")
    func watermarkByState() {
        let labels = Self.labels
        let common = CommonDocumentLabels.english

        let draftPDF = PurchaseOrderLayout.build(Self.document(lines: Self.manyLines(60), watermark: .draft))
        let draft = draftPDF.renderHTML()
        let pageCount = Self.pageSegments(draft).count
        #expect(pageCount > 1)
        #expect(draft.components(separatedBy: "class=\"watermark\"").count - 1 == pageCount)
        #expect(Self.count(common.watermarkDraft, in: draft) == pageCount)

        let notice = labels.cancelledNotice(date: "2026-10-01")
        let cancelled = PurchaseOrderLayout.build(
            Self.document(watermark: .cancelled(cancelledOn: "2026-10-01"))).renderHTML()
        #expect(cancelled.contains("class=\"watermark\""))
        #expect(Self.count(labels.cancelledWatermark, in: cancelled) >= 1)
        #expect(Self.count(notice, in: cancelled) == 1)

        var sentinel = PurchaseOrderLabels()
        sentinel.cancelledNoticeFormat = "SENTINEL-NOTICE {date}"
        let undated = PurchaseOrderLayout.build(
            Self.document(watermark: .cancelled(cancelledOn: nil), labels: sentinel)).renderHTML()
        #expect(undated.contains("class=\"watermark\""))
        #expect(Self.count(sentinel.cancelledWatermark, in: undated) >= 1)
        #expect(!undated.contains("SENTINEL-NOTICE"))
        // Control: the same sentinel with a date does print.
        let dated = PurchaseOrderLayout.build(
            Self.document(watermark: .cancelled(cancelledOn: "2026-10-01"), labels: sentinel)).renderHTML()
        #expect(Self.count("SENTINEL-NOTICE 2026-10-01", in: dated) == 1)

        let plain = PurchaseOrderLayout.build(Self.document(watermark: .none)).renderHTML()
        #expect(!plain.contains("class=\"watermark\""))
        #expect(Self.count(common.watermarkDraft, in: plain) == 0)
        #expect(Self.count(labels.cancelledWatermark, in: plain) == 0)
    }

    // MARK: Test -218

    /// `QA-UNIT06-DOCUMENTS-218`
    @Test("-218 the issuer's bank line is never printed, on either path")
    func bankLineNeverPrinted() throws {
        let common = CommonDocumentLabels.english
        let iban = try #require(Self.issuer.iban)
        let bic = try #require(Self.issuer.bic)
        let pdf = PurchaseOrderLayout.build(Self.document(watermark: .none))

        let html = pdf.renderHTML()
        for needle in [iban, bic, common.ibanLabel + " ", common.bicLabel + " "] {
            #expect(!html.contains(needle), "\(needle) printed")
        }

        #if canImport(PDFKit)
        let document = try #require(PDFDocument(data: try pdf.render()))
        let text = try #require(document.page(at: 0)?.string)
        #expect(!text.contains(iban))
        #expect(!text.contains(bic))
        #endif

        // Positive control: the kit block alone, with the same issuer, prints both.
        let control = PDF(pages: [Page {
            for item in DocumentLayoutKit.supplierIdentityBlock(
                supplier: Self.issuer, labels: common, theme: .standard) { item }
        }])
        let controlHTML = control.renderHTML()
        #expect(controlHTML.contains(iban))
        #expect(controlHTML.contains(common.ibanLabel + " "))
        #if canImport(PDFKit)
        let controlDocument = try #require(PDFDocument(data: try control.render()))
        #expect(controlDocument.page(at: 0)?.string?.contains(iban) == true)
        #endif
    }

    // MARK: Test -219

    /// `QA-UNIT06-DOCUMENTS-219`
    @Test("-219 the empty state and the closed-lines count render as stated")
    func emptyStateAndOmittedCount() throws {
        let labels = Self.labels
        var sentinel = PurchaseOrderLabels()
        sentinel.closedShortLinesOmittedFormat = "SENTINEL {count}"

        let empty = PurchaseOrderLayout.build(
            Self.document(lines: [], closedShortOmittedCount: 0, labels: sentinel)).renderHTML()
        #expect(Self.count(labels.linesEmptyRow, in: empty) == 1)
        for caption in [
            labels.linesColumnItem, labels.linesColumnDescription, labels.linesColumnQuantity,
            labels.linesColumnUnitCost, labels.linesColumnDiscount, labels.linesColumnTaxRate,
            labels.linesColumnLineTotal,
        ] {
            #expect(Self.count(caption, in: empty) >= 1, "missing column \(caption)")
        }
        #expect(!empty.contains("SENTINEL"))

        let emptyOmitted = PurchaseOrderLayout.build(
            Self.document(lines: [], closedShortOmittedCount: 3, labels: sentinel)).renderHTML()
        #expect(Self.count(labels.linesEmptyRow, in: emptyOmitted) == 1)
        #expect(Self.count("SENTINEL 3", in: emptyOmitted) == 1)

        let two = PurchaseOrderLayout.build(Self.document(
            lines: Array(Self.lines.prefix(2)), closedShortOmittedCount: 1, labels: sentinel)).renderHTML()
        #expect(Self.count("SENTINEL 1", in: two) == 1)
        let last = try #require(Self.pageSegments(two).last)
        #expect(Self.count("SENTINEL 1", in: last) == 1)
    }

    // MARK: Test -220

    /// `QA-UNIT06-DOCUMENTS-220`
    @Test("-220 a long order paginates with a repeated header, the footer reads common, totals close it")
    func footerAndPagination() throws {
        var common = CommonDocumentLabels()
        common.pageNumberTemplate = "Blz {page}/{pages}"
        common.totalsSubtotalLabel = "SENTINEL-SUBTOTAL"
        common.totalsTaxLabel = "SENTINEL-TAX"
        common.totalsTotalLabel = "SENTINEL-TOTAL"
        var labels = PurchaseOrderLabels()
        labels.shippingLabel = "SENTINEL-SHIPPING"

        let many = Self.manyLines(60)
        let pdf = PurchaseOrderLayout.build(Self.document(
            lines: many, totals: Self.totals, labels: labels, common: common))
        let html = pdf.renderHTML()
        let pages = Self.pageSegments(html)
        let pageCount = pages.count

        #expect(pageCount > 1)
        #expect(pageCount == pdf.pages.count)
        #expect(Self.count("Blz 1/\(pageCount)", in: html) == 1)
        #expect(Self.count("Blz \(pageCount)/\(pageCount)", in: html) == 1)
        #expect(Self.count(common.continuedLabel, in: html) >= 1)

        for (index, page) in pages.enumerated() {
            let carriesRows = page.contains(">SKU-0")
            #expect(Self.count(labels.linesColumnDescription, in: page) == (carriesRows ? 1 : 0),
                    "page \(index + 1)")
        }
        let last = try #require(pages.last)
        for caption in ["SENTINEL-SUBTOTAL", "SENTINEL-SHIPPING", "SENTINEL-TAX", "SENTINEL-TOTAL"] {
            #expect(Self.count(caption, in: html) == 1, "\(caption)")
            #expect(Self.count(caption, in: last) == 1, "\(caption) not on the last page")
        }
        for line in many {
            let sku = try #require(line.itemSKU)
            #expect(Self.count(sku, in: html) == 1, "\(sku) lost")
        }
    }
}
