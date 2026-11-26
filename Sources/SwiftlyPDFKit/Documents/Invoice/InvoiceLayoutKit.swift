import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - InvoiceLayoutKit

/// The two genuinely invoice-*state* helpers behind the three reference-derived
/// layout families
/// (``InvoiceLayoutBuilder/modernLayout(invoice:theme:labels:locale:pageSize:)``
/// and its Classic / Receipt siblings).
///
/// Everything the families share with *other* document families — pagination,
/// the hairline table style, the typography scale, the muted secondary colour
/// and the footer — lives in ``DocumentLayoutKit``. What is left here reads the
/// document's settlement state, which no other family has.
enum InvoiceLayoutKit {

    /// The document title for the current payment state.
    ///
    /// Both paid reference samples (Slack, Calendly) title the page
    /// **Receipt** rather than Invoice — so this is a state question, not a
    /// family question, and Modern uses it too.
    static func title(for invoice: InvoiceDocument, fmt: DocumentFormatter) -> String {
        if case .paid = invoice.paymentState { return fmt.labels.documentTitleReceipt }
        // `documentTitle` is already the caller-resolved, already-localized
        // title (Invoice / Credit Note / Proforma) — the mapper picks it. Only
        // the settled state overrides it, because that is a *state* decision
        // the caller cannot make.
        return invoice.header.documentTitle
    }

    /// True when the document still needs paying — the discriminator behind
    /// the Receipt family's payment-block rule (an unpaid document must always
    /// carry IBAN / reference / QR, whatever the family).
    static func isOutstanding(_ invoice: InvoiceDocument) -> Bool {
        if case .paid = invoice.paymentState { return false }
        return true
    }
}
