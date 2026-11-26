import Foundation
import Testing
@testable import SwiftlyPDFKit
#if canImport(PDFKit)
import PDFKit
#endif

// MARK: - Closing-block page flow and long ids (PRINT03 §25 #48)

/// `-289` … `-293`, phase `07b-pdf-layout-polish`: the totals stay with the last
/// settled-documents row whenever they fit, only the blocks after them flow,
/// each kept whole, and the batch reference and member ids stop wrapping mid-id.
///
/// Page assignment comes from one plan, so the HTML path is asserted per page
/// box and the CoreGraphics path by reading the drawn layout back. What the HTML
/// path cannot show here is `wkhtmltopdf` honouring it: that is the Linux oracle.
extension RemittanceAdviceDocumentLayoutTests {

    // MARK: Fixtures

    /// The Step 6 `vb.pdf` reference and row values, verbatim.
    static let stepSixReference = "PI-EC97EE6896A44596AB07881BB611DAB3 / FB86180D"
    static let stepSixEndToEnd = "E2E-88E20CB2-A966-440C-937C-13C2157"
    static let stepSixPaymentInfo = "PMT-F5DD3C4E77D44488886A764F7D4F4BB"
    static let stepSixNotes = "VPMT00003: Thank you for your bills."

    /// `vb.pdf`: a batch advice with one member and one bill, not yet submitted.
    static func stepSixBatch() -> RemittanceAdviceDocument {
        RemittanceAdviceDocument(
            issuer: InvoiceSupplier(
                name: "QA Test Co [print03-step6-smoke-a]", street: "1 QA Way", city: "Testville", country: "BE",
                vatNumber: "QA-print03-step6-smoke-a", phone: "000"),
            payee: RemittanceAdvicePayee(
                party: InvoiceParty(name: "PRINT03 Batch Payee B NV", vatNumber: "BE0111222333"),
                registerNumber: "0111.222.333", paidToAccount: "•••• 7034", paidToBIC: "GEBABEBB"),
            header: RemittanceAdviceHeader(
                batchReference: stepSixReference, adviceDate: "Oct 31, 2026",
                generatedOn: "Oct 30, 2026 at 2:13 PM (Europe/Brussels)"),
            paymentFacts: [
                RemittanceAdviceFact(caption: labels.executionDateLabel, value: "Oct 31, 2026"),
                RemittanceAdviceFact(caption: labels.amountPaidLabel, value: "€200.00"),
                RemittanceAdviceFact(caption: payment.paymentMethodLabel, value: payment.paymentMeansSEPACreditTransfer),
            ],
            memberPayments: [
                RemittanceAdviceMemberPayment(
                    paymentNumber: "VPMT00003", endToEndId: stepSixEndToEnd, paymentInfoId: stepSixPaymentInfo,
                    amount: 200, currencyCode: "EUR"),
            ],
            details: [
                RemittanceAdviceDetailRow(
                    kind: .invoice, theirNumber: "THEIR-B-001", theirDate: "Oct 10, 2026", ourReference: "PINV-S6-B1",
                    documentCurrencyCode: "EUR", gross: 200, paidByOtherPayments: 0,
                    applied: 200, appliedCurrencyCode: "EUR", remaining: 0, isSettled: true,
                    paidByPaymentNumber: "VPMT00003"),
            ],
            totals: [RemittanceAdviceTotals(currencyCode: "EUR", bills: 200, transferred: 200, onAccount: 0)],
            remittanceLines: [
                RemittanceAdviceTextLine(
                    text: "Invoice THEIR-B-001", asSent: true, truncated: false, paymentNumber: "VPMT00003"),
            ],
            watermark: .notYetSubmitted, notes: stepSixNotes, contactEmail: nil,
            labels: labels, payment: payment, common: common)
    }

    /// The index of the one page box carrying `>text<`.
    static func pageIndex(of text: String, in pages: [String]) throws -> Int {
        try #require(pages.firstIndex { count(text, in: $0) > 0 }, "\(text) is on no page")
    }

    /// The `width:` of the column div that opens last before `>text<`.
    static func columnWidth(before text: String, in html: String) throws -> String {
        let before = try #require(html.components(separatedBy: ">" + text + "<").first)
        let width = try #require(before.range(of: "width:", options: .backwards))
        return String(before[width.upperBound...].prefix { $0 != ";" })
    }

    /// Top of the footer in PDF coordinates: nothing in the body may drop below it.
    static func footerTop(_ document: RemittanceAdviceDocument) -> CGFloat {
        let theme = InvoiceTheme.standard
        return theme.pageMargins + PaymentDocumentBlocks.footerHeight(
            lines: RemittanceAdviceLayout.footerLines(document),
            contentWidth: PageSize.a4.width - theme.pageMargins * 2)
    }

    #if canImport(PDFKit)
    /// The drawn box of `needle` on the first page that draws it once.
    static func drawnBox(of needle: String, in reader: PDFDocument) throws -> (page: Int, box: CGRect) {
        for index in 0..<reader.pageCount {
            let page = try #require(reader.page(at: index))
            if let box = drawnBounds(of: needle, on: page) { return (index, box) }
        }
        Issue.record("\(needle) is drawn on no page")
        return (0, .null)
    }
    #endif

    // MARK: Test -289

    /// `QA-UNIT06-DOCUMENTS-289`
    @Test("-289 a one-member, one-bill batch advice and the single form each render on one page")
    func everythingThatFitsStaysOnOnePage() throws {
        let document = Self.stepSixBatch()
        let pdf = RemittanceAdviceLayout.build(document)
        let html = pdf.renderHTML()
        #expect(pdf.pages.count == 1)
        #expect(Self.pageSegments(html).count == 1)
        for text in [Self.labels.remittanceTextAsSentLabel, Self.labels.notYetSubmittedNotice,
                     Self.payment.notesLabel, Self.stepSixNotes, Self.common.pageNumber(1, of: 1)] {
            #expect(Self.count(text, in: html) == 1, "\(text)")
        }

        #if canImport(PDFKit)
        let page = try Self.firstPage(pdf)
        let notes = try #require(Self.drawnBounds(of: Self.stepSixNotes, on: page))
        #expect(notes.minY > Self.footerTop(document), "the notes reach the footer: \(notes.minY) pt")
        // The accounting never claims less head than was drawn: it is what lets the plan run this close.
        let table = try #require(Self.drawnBounds(of: Self.labels.paymentsInBatchTitle, on: page))
        let theme = InvoiceTheme.standard
        let drawnHead = PageSize.a4.height - theme.pageMargins - table.maxY
        let plannedHead = RemittanceAdviceLayout.headOverhead(
            document, theme: theme, contentWidth: PageSize.a4.width - theme.pageMargins * 2)
        #expect(plannedHead >= drawnHead, "planned \(plannedHead) pt, drew \(drawnHead) pt")
        #endif

        // The single form of §6 stays on one page (`p1-single.pdf`).
        let single = RemittanceAdviceLayout.build(Self.singleForm())
        #expect(single.pages.count == 1)
        #expect(Self.count(Self.payment.notesLabel, in: single.renderHTML()) == 1)
    }

    // MARK: Test -290

    /// `QA-UNIT06-DOCUMENTS-290`
    @Test("-290 the totals sit on the last row's page whenever they fit; only later blocks flow, each whole")
    func totalsStayWithTheLastRow() throws {
        var labels = RemittanceAdviceLabels()
        labels.totalTransferredLabel = "SENTINEL-TRANSFERRED"
        labels.notYetSubmittedNotice = "SENTINEL-NOTICE"
        let payment = Self.payment
        let remittance = "RF18 5390 0754 7034"
        var stayedAndFlowed = 0
        var movedToOwnPage = 0

        for rows in 1...24 {
            let document = Self.singleForm(details: Self.longDetails(rows), watermark: .notYetSubmitted, labels: labels)
            let pdf = RemittanceAdviceLayout.build(document)
            let html = pdf.renderHTML()
            let pages = Self.pageSegments(html)
            #expect(pages.count == pdf.pages.count, "\(rows) rows")
            for text in ["SENTINEL-TRANSFERRED", "SENTINEL-NOTICE", remittance, "Thank you."] {
                #expect(Self.count(text, in: html) == 1, "\(rows) rows: \(text)")
            }
            let lastRow = try #require(Self.longDetails(rows).last?.theirNumber)
            let rowPage = try Self.pageIndex(of: lastRow, in: pages)
            let totalsPage = try Self.pageIndex(of: "SENTINEL-TRANSFERRED", in: pages)
            let captionPage = try Self.pageIndex(of: payment.remittanceInformationLabel, in: pages)
            let linePage = try Self.pageIndex(of: remittance, in: pages)
            let noticePage = try Self.pageIndex(of: "SENTINEL-NOTICE", in: pages)
            let notesCaptionPage = try Self.pageIndex(of: payment.notesLabel, in: pages)
            let notesPage = try Self.pageIndex(of: "Thank you.", in: pages)

            #expect(captionPage == linePage, "\(rows) rows: the remittance caption left its line")
            #expect(notesCaptionPage == notesPage, "\(rows) rows: the notes caption left its text")
            #expect(totalsPage <= linePage && linePage <= noticePage && noticePage <= notesPage, "\(rows) rows")
            #expect(notesPage == pages.count - 1, "\(rows) rows: a page after the last block")

            if totalsPage == rowPage {
                if notesPage > totalsPage { stayedAndFlowed += 1 }
            } else {
                movedToOwnPage += 1
                #expect(totalsPage == rowPage + 1, "\(rows) rows")
                #expect(!pages[totalsPage].contains(">THEIR-"), "\(rows) rows: rows on the closing page")
            }

            #if canImport(PDFKit)
            let reader = try #require(PDFDocument(data: try pdf.render()))
            let top = Self.footerTop(document)
            for needle in ["SENTINEL-TRANSFERRED", "SENTINEL-NOTICE", "Thank you."] {
                let drawn = try Self.drawnBox(of: needle, in: reader)
                #expect(drawn.box.minY > top, "\(rows) rows: \(needle) at \(drawn.box.minY) pt")
            }
            if totalsPage != rowPage {
                // It was pushed because it did not fit, not by an estimate far off the drawn page.
                // `free` reads from the row's first line, about 30 pt above the row's bottom edge.
                let drawnRow = try Self.drawnBox(of: lastRow, in: reader)
                let free = drawnRow.box.minY - top
                let totalsH = RemittanceAdviceLayout.totalsUnit(document, theme: .standard, locale: Locale(identifier: "en_US")).height
                #expect(free < totalsH + 60, "\(rows) rows: \(free) pt free, the totals need \(totalsH) pt")
            }
            #endif
        }
        // Both arms ran, so neither branch above is vacuous.
        #expect(stayedAndFlowed > 0, "no row count kept the totals and flowed a later block")
        #expect(movedToOwnPage > 0, "no row count pushed the totals to a page of their own")
    }

    // MARK: Test -291

    /// `QA-UNIT06-DOCUMENTS-291`
    @Test("-291 a remittance list longer than a page flows line by line and never reaches the footer")
    func remittanceListFlowsLineByLine() throws {
        let labels = Self.labels
        let numbers = (1...80).map { "LINE-" + String(repeating: "0", count: 4 - String($0).count) + String($0) }
        let lines = numbers.enumerated().map { index, number in
            RemittanceAdviceTextLine(text: number, asSent: true, truncated: index == 0, paymentNumber: "VPMT00041")
        }
        let document = Self.batchForm(lines: lines)
        let pdf = RemittanceAdviceLayout.build(document)
        let html = pdf.renderHTML()
        let pages = Self.pageSegments(html)
        #expect(pages.count == pdf.pages.count)
        #expect(pages.count >= 3)

        #expect(Self.count(labels.remittanceTextAsSentLabel, in: html) == 1)
        #expect(Self.count(labels.remittanceTruncatedNotice, in: html) == 1)
        let linePages = try numbers.map { try Self.pageIndex(of: "VPMT00041 · " + $0, in: pages) }
        #expect(linePages == linePages.sorted())
        #expect(try Self.pageIndex(of: labels.remittanceTextAsSentLabel, in: pages) == linePages[0])
        #expect(try Self.pageIndex(of: labels.remittanceTruncatedNotice, in: pages) == linePages[0])
        #expect(try Self.pageIndex(of: labels.totalTransferredLabel, in: pages)
            == Self.pageIndex(of: "CN-DE-0907", in: pages))
        #expect(try Self.pageIndex(of: Self.payment.notesLabel, in: pages) >= (linePages.last ?? 0))
        #expect(try Self.pageIndex(of: labels.notYetSubmittedNotice, in: pages) >= (linePages.last ?? 0))

        #if canImport(PDFKit)
        let reader = try #require(PDFDocument(data: try pdf.render()))
        let top = Self.footerTop(document)
        var found = 0
        for number in numbers {
            let drawn = try Self.drawnBox(of: number, in: reader)
            #expect(drawn.box.minY > top, "\(number) at \(drawn.box.minY) pt")
            found += 1
        }
        // Positive anchor: the reader found every line, so the bound above is not vacuous.
        #expect(found == numbers.count)
        #endif
    }

    // MARK: Test -292

    /// `QA-UNIT06-DOCUMENTS-292`
    @Test("-292 the batch reference stays on one line on both paths; the single form's grid is unchanged")
    func batchReferenceDoesNotWrap() throws {
        let width = PageSize.a4.width - InvoiceTheme.standard.pageMargins * 2
        // A pain.001 message id at its 35-character limit, in the widest face it can take.
        let longest = "MSG-" + String(repeating: "W", count: 31) + " / V-0000017"
        for reference in [Self.stepSixReference, longest] {
            var document = Self.stepSixBatch()
            document.header.batchReference = reference
            let pdf = RemittanceAdviceLayout.build(document)
            let html = pdf.renderHTML()
            #expect(Self.count(reference, in: html) == 1, "\(reference)")
            #expect(try Self.columnWidth(before: reference, in: html) == "\(width)pt", "\(reference)")

            #if canImport(PDFKit)
            let page = try Self.firstPage(pdf)
            let box = try #require(Self.drawnBounds(of: reference, on: page), "\(reference)")
            #expect(box.height < InvoiceTheme.standard.bodyFontSize * 1.5, "\(reference): \(box.height) pt")
            #endif
        }

        // Red control: the same reader over the three-to-a-row grid sees it wrap.
        #if canImport(PDFKit)
        let control = try Self.firstPage(PDF(pages: [Page {
            for item in DocumentLayoutKit.metadataGrid(
                rows: [(caption: "Reference", value: Self.stepSixReference),
                       (caption: "Date", value: "x"), (caption: "Generated", value: "y")],
                theme: .standard, columns: 3) { item }
        }]))
        let wrapped = try #require(Self.drawnBounds(of: Self.stepSixReference, on: control))
        #expect(wrapped.height > InvoiceTheme.standard.bodyFontSize * 1.5, "the control did not wrap: \(wrapped.height) pt")
        #endif

        // The reference precedes the rest of the header, and the rest keeps its three-column grid.
        let batch = Self.html(Self.stepSixBatch())
        let reference = try #require(batch.range(of: ">" + Self.stepSixReference + "<"))
        let date = try #require(batch.range(of: ">" + Self.labels.adviceDateLabel + "<"))
        #expect(reference.lowerBound < date.lowerBound)
        #expect(try Self.columnWidth(before: Self.labels.adviceDateLabel, in: batch) == "\((width - 24) / 3)pt")
        let single = Self.html(Self.singleForm())
        #expect(try Self.columnWidth(before: "VPMT00041", in: single) == "\((width - 24) / 3)pt")
    }

    // MARK: Test -293

    /// `QA-UNIT06-DOCUMENTS-293`
    @Test("-293 a member's ids stay on one line in the wider cell and its amount stays in the applied column")
    func memberIdsDoNotWrap() throws {
        let contentWidth = PageSize.a4.width - InvoiceTheme.standard.pageMargins * 2
        let span = RemittanceAdviceLayout.memberDocumentSpan
        let member = RemittanceAdviceMemberPayment(
            paymentNumber: "VPMT00003", endToEndId: Self.stepSixEndToEnd, paymentInfoId: Self.stepSixPaymentInfo,
            amount: 1_234, currencyCode: "EUR")
        let detail = RemittanceAdviceDetailRow(
            kind: .invoice, theirNumber: "THEIR-B-001", theirDate: "2026-10-10", ourReference: "PINV-S6-B1",
            documentCurrencyCode: "EUR", gross: 1_500, paidByOtherPayments: 0,
            applied: 1_233, appliedCurrencyCode: "EUR", remaining: 267, isSettled: false,
            paidByPaymentNumber: "VPMT00003")
        let document = Self.batchForm(members: [member], details: [detail])
        let rows = RemittanceAdviceLayout.memberPaymentRows(document, locale: Locale(identifier: "en_US"))
        let row = try #require(rows.first)

        // One line per id: the row's estimate is exactly three lines plus the padding.
        let oneLinePerId = PaymentDocumentBlocks.allocationCellFontSize * 1.25
            + PaymentDocumentBlocks.allocationSubLineFontSize * 1.25 * 2
            + PaymentDocumentBlocks.allocationRowPadding * 2
        #expect(PaymentDocumentBlocks.allocationRowHeight(
            stacked: row, contentWidth: contentWidth, documentSpan: span) == oneLinePerId)
        #expect(PaymentDocumentBlocks.allocationRowHeight(stacked: row, contentWidth: contentWidth) > oneLinePerId)

        let html = Self.html(document)
        #expect(try Self.columnWidth(before: Self.stepSixEndToEnd, in: html)
            == "\(contentWidth - PaymentDocumentBlocks.allocationAmountWidth * 2 - PaymentDocumentBlocks.allocationGutter * 2)pt")

        #if canImport(PDFKit)
        let page = try Self.firstPage(RemittanceAdviceLayout.build(document))
        for id in [Self.stepSixEndToEnd, Self.stepSixPaymentInfo] {
            let box = try #require(Self.drawnBounds(of: id, on: page), "\(id)")
            #expect(box.height < PaymentDocumentBlocks.allocationSubLineFontSize * 1.5, "\(id): \(box.height) pt")
        }
        let amount = try #require(Self.drawnBounds(of: "1,234.00 EUR", on: page))
        let applied = try #require(Self.drawnBounds(of: "1,233.00 EUR", on: page))
        #expect(abs(amount.maxX - applied.maxX) < 1, "\(amount.maxX) vs \(applied.maxX)")

        // Red control: the same row in the plain six-column atom wraps.
        let plain = try Self.firstPage(PDF(pages: [Page {
            for item in PaymentDocumentBlocks.allocationTable(
                stackedRows: [row], title: "x", header: RemittanceAdviceLayout.memberPaymentHeader(
                    labels: Self.labels, payment: Self.payment),
                emptyRow: "", common: Self.common, theme: .standard, continued: false) { item }
        }]))
        let wrapped = try #require(Self.drawnBounds(of: Self.stepSixEndToEnd, on: plain))
        #expect(wrapped.height > PaymentDocumentBlocks.allocationSubLineFontSize * 1.5, "\(wrapped.height) pt")
        #endif
    }
}
