import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - RemittanceAdviceLayout + page plan

/// Where the member list, the detail table and the closing blocks go. Split out
/// of `RemittanceAdviceLayout.swift` only to keep each file and type body inside
/// the lint limits; it is the same enum.
extension RemittanceAdviceLayout {

    // MARK: Page plan

    /// Where every page's rows go. `chunks[i]` is page `i`'s detail rows (empty
    /// on a member-only page); `memberChunks[i]` is page `i`'s member rows;
    /// `detailStart` is the page the detail table starts on. `closingPages[k]`
    /// is the closing units page `closingStart + k` carries.
    struct PagePlan {
        var chunks: [[[[String]]]]
        var memberChunks: [[[[String]]]]
        var detailStart: Int
        var closingStart: Int
        var closingPages: [[Int]]
    }

    /// Kept free under the closing units: a small bias to break early, because
    /// the units' heights are estimates. Page-fit accounting, no design authority.
    static let closingSlack: CGFloat = 4

    /// Columns the member list's payment cell spans (payment, date, total and
    /// other-payments), so an id stays on one line; its amount stays in the
    /// applied column.
    static let memberDocumentSpan = 4

    // Nine parameters on purpose: `build` is the one caller and has already computed every value,
    // so a parameter struct would only restate them (the 03a / 03b suppression, same rule).
    /// Two passes (PRINT03 phase 00 D10): the batch form's member list first —
    /// it paginates and never overflows the footer — then the detail table,
    /// starting on the member list's last page when the facts grid, the
    /// table's overhead and its first group fit beside it, else on a fresh page.
    /// The table is paged by its own rows; ``closingFlow(heights:firstPageUsed:bodyH:)``
    /// then places the closing units after it, the totals first (§25 #48).
    static func pagePlan( // swiftlint:disable:this function_parameter_count
        _ document: RemittanceAdviceDocument,
        groups: [[[[String]]]],
        memberRows: [[[String]]],
        detailHeader: [[String]],
        isBatch: Bool,
        bodyH: CGFloat,
        theme: InvoiceTheme,
        contentWidth: CGFloat,
        closingHeights: [CGFloat]
    ) -> PagePlan {
        let rowHeight = { PaymentDocumentBlocks.allocationRowHeight(stacked: $0, contentWidth: contentWidth) }
        let memberRowHeight = {
            PaymentDocumentBlocks.allocationRowHeight(
                stacked: $0, contentWidth: contentWidth, documentSpan: memberDocumentSpan)
        }
        let detailOverhead = PaymentDocumentBlocks.allocationTableOverhead(
            title: document.labels.settledDocumentsTitle, header: detailHeader, contentWidth: contentWidth)
        let factsH = factsHeight(document, theme: theme, contentWidth: contentWidth)
        let emptyStateH = emptyStateHeight(theme: theme)
        let headOverhead = headOverhead(document, theme: theme, contentWidth: contentWidth)

        var memberChunkList: [[[[String]]]] = []
        var detailP1Overhead = headOverhead + factsH
        var detailStart = 0
        if isBatch {
            let memberOverhead = PaymentDocumentBlocks.allocationTableOverhead(
                title: document.labels.paymentsInBatchTitle,
                header: memberPaymentHeader(labels: document.labels, payment: document.payment),
                contentWidth: contentWidth, documentSpan: memberDocumentSpan)
            let firstGroupH = groups.first.map { $0.reduce(CGFloat(0)) { $0 + rowHeight($1) } }
                ?? emptyStateH
            let memberBottom = memberTableGap + factsH + detailOverhead + firstGroupH
            let (chunks, freshPage) = memberChunks(
                memberRows: memberRows, rowHeight: memberRowHeight, bodyH: bodyH, headOverhead: headOverhead,
                memberOverhead: memberOverhead, memberBottom: memberBottom)
            memberChunkList = chunks
            if freshPage {
                detailStart = chunks.count
                detailP1Overhead = factsH
            } else {
                detailStart = chunks.count - 1
                let lastRowsH = (chunks.last ?? []).reduce(CGFloat(0)) { $0 + memberRowHeight($1) }
                let used = (detailStart == 0 ? headOverhead : 0) + memberOverhead
                    + (lastRowsH > 0 ? lastRowsH : theme.lineItemRowHeight)
                detailP1Overhead = used + memberTableGap + factsH
            }
        }

        let detailChunks = PaymentDocumentBlocks.paginate(
            rowGroups: groups,
            rowHeight: rowHeight,
            emptyStateHeight: emptyStateH,
            bodyHeight: bodyH,
            page1Overhead: detailP1Overhead,
            tableOverhead: detailOverhead,
            bottomHeight: 0)

        // What the last detail chunk leaves used; a closing-only page starts at 0.
        let lastRows = detailChunks.last ?? []
        var lastUsed: CGFloat = 0
        if !lastRows.isEmpty || detailChunks.count == 1 {
            let rowsH = lastRows.reduce(CGFloat(0)) { $0 + rowHeight($1) }
            lastUsed = (detailChunks.count == 1 ? detailP1Overhead : 0) + detailOverhead
                + (lastRows.isEmpty ? emptyStateH : rowsH)
        }
        let closingPages = closingFlow(heights: closingHeights, firstPageUsed: lastUsed, bodyH: bodyH)
        let chunks = Array(repeating: [[[String]]](), count: detailStart) + detailChunks
            + Array(repeating: [[[String]]](), count: closingPages.count - 1)
        return PagePlan(
            chunks: chunks, memberChunks: memberChunkList, detailStart: detailStart,
            closingStart: detailStart + detailChunks.count - 1, closingPages: closingPages)
    }

    /// Places the closing units in order: each on the current page while it
    /// fits, else at the top of a new page, so a unit is never split. A unit
    /// taller than a whole page still gets a page of its own (long free-text
    /// notes); nothing here can shorten it.
    static func closingFlow(heights: [CGFloat], firstPageUsed: CGFloat, bodyH: CGFloat) -> [[Int]] {
        var pages: [[Int]] = [[]]
        var used = firstPageUsed
        for (index, height) in heights.enumerated() {
            if used > 0, used + height + closingSlack > bodyH {
                pages.append([])
                used = 0
            }
            pages[pages.count - 1].append(index)
            used += height
        }
        return pages
    }

    /// The member pass: one row per group (a member is never split), the head
    /// blocks on page 1, and the facts grid, the detail table's overhead and
    /// its first group as the bottom. When that bottom does not fit beside the
    /// last member chunk the planner's empty closing chunk is dropped and
    /// `freshPage` says the detail table starts on a page of its own.
    static func memberChunks(
        memberRows: [[[String]]],
        rowHeight: ([[String]]) -> CGFloat,
        bodyH: CGFloat,
        headOverhead: CGFloat,
        memberOverhead: CGFloat,
        memberBottom: CGFloat
    ) -> (chunks: [[[[String]]]], freshPage: Bool) {
        let memberChunks = PaymentDocumentBlocks.paginate(
            rowGroups: memberRows.map { [$0] },
            rowHeight: rowHeight,
            emptyStateHeight: 0,
            bodyHeight: bodyH,
            page1Overhead: headOverhead,
            tableOverhead: memberOverhead,
            bottomHeight: memberBottom)
        guard memberChunks.count > 1, memberChunks.last?.isEmpty == true else {
            return (memberChunks, false)
        }
        return (Array(memberChunks.dropLast()), true)
    }
}
