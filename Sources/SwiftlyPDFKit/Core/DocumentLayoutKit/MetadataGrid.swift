import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - DocumentLayoutKit + metadata grid

extension DocumentLayoutKit {

    /// The document-meta grid — a run of caption/value pairs laid out in
    /// balanced columns.
    ///
    /// The grid owns **no** captions of its own and therefore has no member on
    /// ``CommonDocumentLabels``: which rows a family shows (document number,
    /// issue date, due date, order reference …) is a family decision, so the
    /// caller supplies the pairs already resolved and already localized.
    ///
    /// Returns `[]` for an empty row list, so a family can pass the rows it has
    /// without guarding the call.
    ///
    /// - Parameters:
    ///   - rows: caption/value pairs, in reading order.
    ///   - columns: how many pairs sit side by side. Clamped to at least 1.
    public static func metadataGrid(
        rows: [(caption: String, value: String)],
        theme: InvoiceTheme,
        columns: Int = 2
    ) -> [any PDFContent] {
        guard !rows.isEmpty else { return [] }

        let perRow = max(1, columns)
        var contents: [any PDFContent] = []

        for start in stride(from: 0, to: rows.count, by: perRow) {
            let slice = Array(rows[start..<min(start + perRow, rows.count)])
            contents.append(
                Columns(spacing: 12) {
                    for cell in slice {
                        ColumnItem(width: .flex) {
                            Text(cell.caption)
                                .font(theme.bodyFont, size: 8)
                                .color(mutedText)
                            Text(cell.value)
                                .font(theme.bodyFont, size: theme.bodyFontSize)
                        }
                    }
                    // Pad a short final row so its cells keep the grid's column
                    // width instead of stretching across the page.
                    for _ in slice.count..<perRow {
                        ColumnItem(width: .flex) {
                            Spacer(height: 0)
                        }
                    }
                }
            )
            contents.append(Spacer(height: 6))
        }

        return contents
    }
}
