import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - DocumentLayoutKit + supplier identity block

extension DocumentLayoutKit {

    /// The statutory letterhead: who issued this document, and the identifiers
    /// the law requires alongside the name.
    ///
    /// Every jurisdiction the product ships into asks for the same shape — legal
    /// name, registered address, VAT identification number, commercial-register
    /// number, and enough contact detail to reach the issuer — so the block is
    /// family-neutral by construction and every document family renders the same
    /// one.
    ///
    /// The register number falls back to
    /// ``DocumentLayoutKit/registerNumber(fromVATID:)`` when the supplier does
    /// not carry one explicitly; where neither is available the row is omitted
    /// rather than guessed.
    ///
    /// Composed entirely from existing primitives, so it inherits both render
    /// paths.
    public static func supplierIdentityBlock(
        supplier: InvoiceSupplier,
        labels: CommonDocumentLabels,
        theme: InvoiceTheme
    ) -> [any PDFContent] {
        var contents: [any PDFContent] = [
            Text(supplier.name)
                .font(theme.titleFont, size: theme.titleFontSize)
                .bold()
        ]

        for line in [supplier.street, supplier.city, supplier.country].compactMap({ $0 }) {
            contents.append(
                Text(line)
                    .font(theme.bodyFont, size: theme.bodyFontSize)
            )
        }

        let identifiers = [
            supplier.vatNumber.map { "\(labels.vatNumberLabel) \($0)" },
            registrationNumber(for: supplier).map { "\(labels.registrationNumberLabel) \($0)" },
        ].compactMap { $0 }

        let bank = [
            supplier.iban.map { "\(labels.ibanLabel) \($0)" },
            supplier.bic.map { "\(labels.bicLabel) \($0)" },
        ].compactMap { $0 }

        let contact = [
            supplier.phone.map { "\(labels.phoneLabel) \($0)" },
            supplier.email.map { "\(labels.emailLabel) \($0)" },
            supplier.website.map { "\(labels.websiteLabel) \($0)" },
        ].compactMap { $0 }

        for group in [identifiers, bank, contact] where !group.isEmpty {
            contents.append(Spacer(height: 4))
            contents.append(
                Text(group.joined(separator: separator))
                    .font(theme.bodyFont, size: 8)
                    .color(mutedText)
            )
        }

        return contents
    }

    /// The recorded register number, or the derived one, or nothing.
    static func registrationNumber(for supplier: InvoiceSupplier) -> String? {
        supplier.registrationNumber ?? registerNumber(fromVATID: supplier.vatNumber)
    }

    /// Joins the identifier / bank / contact runs on one line.
    static let separator = "   ·   "
}
