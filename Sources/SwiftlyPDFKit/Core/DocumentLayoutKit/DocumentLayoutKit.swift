import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - DocumentLayoutKit

/// The cross-family layout kit: the parts every document family composes a page
/// from, rather than copying out of a sibling builder.
///
/// Families differ in *visual grammar*, not in how a document is broken across
/// pages, styled, or footed. That arithmetic and those atoms live here once, so
/// a family file contains only design — and a new family is assembled from
/// these parts instead of being cloned from an existing one.
///
/// Everything here is composed from the existing ``PDFContent`` primitives, so
/// it inherits **both** render paths (CoreGraphics on Apple platforms,
/// hand-written HTML on Linux) for free. The one exception is
/// ``DocumentWatermark``, which is full-bleed and therefore page-level; see its
/// own documentation.
public enum DocumentLayoutKit {

    // MARK: Page planning

    /// The result of splitting a document's lines across pages.
    public struct Pagination {
        /// Line chunks, one per page. May end in an empty chunk when the
        /// closing blocks (totals, breakdown, payment) do not fit beside the
        /// last rows — that empty chunk becomes a bottom-content-only page.
        public let chunks: [[InvoiceLine]]
        /// Total page count, i.e. `chunks.count`. Feeds `Page N of M`.
        public let pageCount: Int
        /// Height reserved for the footer, including the page-number line.
        public let footerHeight: CGFloat
        /// Page margin taken from the theme.
        public let margins: CGFloat
    }

    /// Splits `invoice.lines` into per-page chunks.
    ///
    /// - Parameters:
    ///   - page1Overhead: height consumed on page 1 *before* the line table
    ///     (masthead, parties, metadata, headline …). Family-specific.
    ///   - bottomHeight: height of everything rendered after the last line row
    ///     (totals, tax breakdown, notes, payment history, bank block).
    ///
    /// Both are page-fit accounting only and carry no design authority; a
    /// family is free to be approximate, because the cost of being wrong is an
    /// early page break, never lost content.
    public static func paginate(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        pageSize: PageSize,
        page1Overhead: CGFloat,
        bottomHeight: CGFloat
    ) -> Pagination {
        let rowH         = theme.lineItemRowHeight
        let tableHeaderH = rowH
        // Caller height + the page-number line + the rule and spacer the
        // footer draws above them. Under-reserving here does not shrink the
        // footer — it lets the page-number line fall past the page edge and
        // vanish, which is exactly what the first Modern render did.
        let footerH      = (invoice.footer.map { $0.height } ?? 12) + 22
        let margins      = theme.pageMargins
        let bodyH        = pageSize.height - margins * 2 - footerH

        let p1RowsMax   = max(1, Int(floor((bodyH - page1Overhead - tableHeaderH) / rowH)))
        let contRowsMax = max(1, Int(floor((bodyH - tableHeaderH) / rowH)))

        var chunks: [[InvoiceLine]] = []
        var remaining = invoice.lines

        let p1Take = min(p1RowsMax, remaining.count)
        chunks.append(Array(remaining.prefix(p1Take)))
        remaining = Array(remaining.dropFirst(p1Take))

        while !remaining.isEmpty {
            let take = min(contRowsMax, remaining.count)
            chunks.append(Array(remaining.prefix(take)))
            remaining = Array(remaining.dropFirst(take))
        }

        let lastChunkUsed: CGFloat
        if let last = chunks.last {
            let overhead = chunks.count == 1 ? page1Overhead : 0
            lastChunkUsed = overhead + tableHeaderH + CGFloat(last.count) * rowH
        } else {
            lastChunkUsed = page1Overhead + tableHeaderH
        }
        if lastChunkUsed + bottomHeight > bodyH {
            chunks.append([])
        }

        return Pagination(chunks: chunks, pageCount: chunks.count,
                          footerHeight: footerH, margins: margins)
    }

    // MARK: Shared visual atoms

    /// Fully transparent — the references use no table fills whatsoever, so
    /// every family passes this for `headerBackground` / `borderColor` and
    /// draws its own rules instead.
    public static let clear = PDFColor(white: 1, alpha: 0)

    /// A borderless, fill-less table style. Every reference draws its line
    /// table as text between hairlines; none uses a filled header band or
    /// alternating stripes.
    public static func hairlineTableStyle(
        theme: InvoiceTheme,
        rowHeight: CGFloat? = nil,
        cellBold: Bool = false,
        headerTextColor: PDFColor? = nil,
        headerFontSize: CGFloat? = nil,
        cellFontSize: CGFloat? = nil
    ) -> TableStyle {
        TableStyle(
            headerBackground: clear,
            headerTextColor: headerTextColor ?? PDFColor(white: 0.4),
            headerFontSize: headerFontSize ?? theme.tableHeaderFontSize,
            cellFontSize: cellFontSize ?? theme.tableCellFontSize,
            rowHeight: rowHeight ?? theme.lineItemRowHeight,
            alternateRowColor: nil,
            borderColor: clear,
            borderWidth: 0,
            cellPadding: 4,
            cellBold: cellBold
        )
    }

    // MARK: Typography scale (Modern)

    /// The references render the document title at display size in **bold
    /// sans**. `InvoiceTheme.titleFont` is `.times` at 14pt and is shared with
    /// the other document families, so the invoice families carry their own
    /// scale rather than restyling a theme other documents rely on.
    public static let modernTitleSize: CGFloat = 26
    /// The paid/due headline — the loudest element after the title.
    public static let modernHeadlineSize: CGFloat = 18
    /// Section headers inside the closing blocks (e.g. Payment history).
    public static let modernSectionSize: CGFloat = 13
    /// Classic sets its title beside the document number on one line, so it
    /// runs smaller than Modern's.
    public static let classicTitleSize: CGFloat = 20
    /// Receipt's centred masthead title.
    public static let receiptTitleSize: CGFloat = 28
    /// The oversized faint acknowledgement under a settled receipt.
    public static let receiptThanksSize: CGFloat = 40

    /// The muted grey the references use for secondary text (column heads,
    /// service periods, footnotes).
    public static let mutedText = PDFColor(white: 0.42)

    /// Standard document footer: hairline, any caller-supplied lines, then the
    /// `Page N of M` template. Shared by every family.
    public static func footer(
        invoice: InvoiceDocument,
        theme: InvoiceTheme,
        fmt: DocumentFormatter,
        page: Int,
        of pageCount: Int,
        height: CGFloat,
        ruleThickness: CGFloat = 0.5,
        ruleColor: PDFColor? = nil,
        alignment: TextAlignment = .trailing
    ) -> Footer {
        // `theme.ruleColor` is shared with the other document families, so a
        // family that wants a lighter hairline passes its own rather than
        // restyling a slot other document types read.
        Footer(height: height) {
            HRule(thickness: ruleThickness, color: ruleColor ?? theme.ruleColor)
            Spacer(height: 4)
            for line in invoice.footer?.lines ?? [] {
                Text(line)
                    .font(theme.bodyFont, size: 8)
                    .alignment(alignment)
                    .color(mutedText)
            }
            Text(fmt.labels.pageNumber(page, of: pageCount))
                .font(theme.bodyFont, size: 8)
                .alignment(alignment)
                .color(mutedText)
        }
    }
}
