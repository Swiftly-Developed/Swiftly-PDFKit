import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - DocumentLayoutKit + totals block

extension DocumentLayoutKit {

    /// The right-aligned totals ladder: subtotal, optional document-level
    /// discount, tax, grand total, and — when a payment has been recorded — the
    /// amount already paid and the amount still owed.
    ///
    /// Rows whose value is absent are omitted rather than rendered as zero, so a
    /// document with nothing paid against it shows a four-row ladder and one
    /// with a deposit shows six.
    ///
    /// Amounts are formatted through ``DocumentFormatter/money(_:)``, which is
    /// `FormatStyle`-backed and carries the document's own ISO 4217 currency
    /// code — never the host locale's default currency.
    public static func totalsBlock(
        totals: InvoiceTotals,
        labels: CommonDocumentLabels,
        formatter: DocumentFormatter,
        theme: InvoiceTheme
    ) -> [any PDFContent] {
        var rows: [TotalsRow] = [
            TotalsRow(caption: labels.totalsSubtotalLabel, value: totals.subtotalExcl)
        ]
        if let discount = totals.globalDiscount {
            rows.append(TotalsRow(caption: labels.totalsDiscountLabel, value: discount))
        }
        rows.append(TotalsRow(caption: labels.totalsTaxLabel, value: totals.totalVat))
        rows.append(TotalsRow(caption: labels.totalsTotalLabel,
                              value: totals.totalIncl, emphasised: true))
        if let paid = totals.amountPaid {
            rows.append(TotalsRow(caption: labels.totalsAmountPaidLabel, value: paid))
            rows.append(TotalsRow(caption: labels.totalsAmountDueLabel,
                                  value: totals.amountDue, emphasised: true))
        }

        var contents: [any PDFContent] = []
        for row in rows {
            if row.emphasised {
                contents.append(Spacer(height: 2))
                contents.append(HRule(thickness: 0.5, color: theme.ruleColor))
                contents.append(Spacer(height: 2))
            }
            contents.append(
                Columns(spacing: 12) {
                    ColumnItem(width: .flex) {
                        totalsCell(row.caption, theme: theme,
                                   bold: row.emphasised, alignment: .trailing)
                    }
                    ColumnItem(width: .fixed(90)) {
                        totalsCell(formatter.money(row.value), theme: theme,
                                   bold: row.emphasised, alignment: .trailing)
                    }
                }
            )
        }
        return contents
    }

    /// One row of the totals ladder. A named type rather than a tuple, so the
    /// emphasis flag cannot be read positionally at a call site.
    private struct TotalsRow {
        let caption: String
        let value: Double
        var emphasised: Bool = false
    }

    /// One cell of the totals ladder — shared so the caption and the amount can
    /// never drift apart in weight or size.
    private static func totalsCell(
        _ string: String,
        theme: InvoiceTheme,
        bold: Bool,
        alignment: TextAlignment
    ) -> Text {
        let text = Text(string)
            .font(theme.bodyFont, size: theme.bodyFontSize)
            .alignment(alignment)
        return bold ? text.bold() : text
    }
}
