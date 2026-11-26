import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - DocumentLayoutKit + signature block

extension DocumentLayoutKit {

    /// A signature acknowledgement block: a heading, then three ruled fields
    /// (signature / date / printed name).
    ///
    /// This is the **localized** sibling of the internal free function of the
    /// same name in `Documents/Shared/DocumentLayoutHelpers.swift`, which still
    /// carries hard-coded English and still has its own callers. The
    /// duplication is deliberate and time-boxed: re-pointing those callers is a
    /// later phase's work, and doing it here would move rendered output on
    /// document families this phase is not allowed to touch.
    ///
    /// - Parameter heading: overrides ``CommonDocumentLabels/signatureHeader``
    ///   when a family needs its own wording (already localized by the caller).
    public static func signatureBlock(
        labels: CommonDocumentLabels,
        theme: InvoiceTheme,
        heading: String? = nil
    ) -> [any PDFContent] {
        [
            Spacer(height: 28),
            HRule(thickness: 0.5, color: theme.accentColor),
            Spacer(height: 8),
            Text(heading ?? labels.signatureHeader)
                .font(theme.titleFont, size: 10)
                .bold(),
            Spacer(height: 18),
            Columns(spacing: 20) {
                ColumnItem(width: .flex) {
                    HRule(thickness: 0.5, color: theme.ruleColor)
                    Spacer(height: 3)
                    Text(labels.signatureLabel).font(theme.bodyFont, size: 8)
                }
                ColumnItem(width: .fixed(130)) {
                    HRule(thickness: 0.5, color: theme.ruleColor)
                    Spacer(height: 3)
                    Text(labels.signatureDateLabel).font(theme.bodyFont, size: 8)
                }
                ColumnItem(width: .fixed(110)) {
                    HRule(thickness: 0.5, color: theme.ruleColor)
                    Spacer(height: 3)
                    Text(labels.signatureNameLabel).font(theme.bodyFont, size: 8)
                }
            },
        ]
    }
}
