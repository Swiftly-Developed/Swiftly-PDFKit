import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - DocumentLayoutKit + party block

extension DocumentLayoutKit {

    /// A captioned postal/legal party block — the bill-to and ship-to shape
    /// every family renders identically.
    ///
    /// The caption is passed in rather than picked here, because which of
    /// ``CommonDocumentLabels/billToHeader`` / ``CommonDocumentLabels/shipToHeader``
    /// applies is the caller's question; `labels` supplies the VAT caption,
    /// which is not.
    ///
    /// Absent fields are dropped, so a party carrying only a name renders one
    /// line under the caption rather than a run of blanks.
    public static func partyBlock(
        party: InvoiceParty,
        header: String,
        labels: CommonDocumentLabels,
        theme: InvoiceTheme
    ) -> [any PDFContent] {
        var contents: [any PDFContent] = [
            Text(header)
                .font(theme.bodyFont, size: 8)
                .bold()
                .color(mutedText),
            Spacer(height: 3),
            Text(party.name)
                .font(theme.bodyFont, size: theme.bodyFontSize)
                .bold(),
        ]

        let lines = [
            party.attention,
            party.street,
            party.city,
            party.country,
            party.vatNumber.map { "\(labels.vatNumberLabel) \($0)" },
        ].compactMap { $0 }

        for line in lines {
            contents.append(
                Text(line)
                    .font(theme.bodyFont, size: theme.bodyFontSize)
            )
        }

        return contents
    }
}
