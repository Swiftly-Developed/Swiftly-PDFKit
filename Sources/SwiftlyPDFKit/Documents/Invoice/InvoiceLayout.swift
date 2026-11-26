import Foundation

// MARK: - InvoiceLayoutType

/// Built-in invoice layout families.
///
/// Each case selects a layout family rendered from the same
/// ``InvoiceDocument`` data. The three families currently share one
/// provisional arrangement rendering the full block superset; the
/// per-family visual grammar is a later reference-derived deliverable.
public enum InvoiceLayoutType: Sendable {
    /// Contemporary family: the refreshed, accent-forward invoice look.
    case modern

    /// Traditional family: the conservative single-column invoice look.
    case classic

    /// Compact family: the condensed, receipt-style invoice look.
    case receipt
}

// MARK: - PDF + Invoice factory

public extension PDF {

    /// Creates a `PDF` pre-built from an ``InvoiceDocument`` using a named layout.
    ///
    /// ```swift
    /// let pdf = PDF(layout: .classic, invoice: invoice)
    /// let data = try pdf.render()
    /// ```
    ///
    /// - Parameters:
    ///   - layout: The layout family to render.
    ///   - invoice: The data model containing all invoice content.
    ///   - theme: Visual configuration (colors, fonts, logo size). Defaults to ``InvoiceTheme/standard``.
    ///   - labels: Every fixed rendered string. Defaults to ``InvoiceLabels/english``;
    ///     hosts supply a localized instance.
    ///   - locale: Drives date, currency, number and rate formatting. Defaults to `en_US`
    ///     (the package-standalone fallback — never the device locale);
    ///     hosts pass the document's resolved locale.
    ///   - pageSize: Paper size. Defaults to A4.
    init(
        layout: InvoiceLayoutType,
        invoice: InvoiceDocument,
        theme: InvoiceTheme = .standard,
        labels: InvoiceLabels = .english,
        locale: Locale = Locale(identifier: "en_US"),
        pageSize: PageSize = .a4
    ) {
        switch layout {
        case .modern:
            self = InvoiceLayoutBuilder.modernLayout(
                invoice: invoice, theme: theme, labels: labels, locale: locale, pageSize: pageSize)
        case .classic:
            self = InvoiceLayoutBuilder.classicLayout(
                invoice: invoice, theme: theme, labels: labels, locale: locale, pageSize: pageSize)
        case .receipt:
            self = InvoiceLayoutBuilder.receiptLayout(
                invoice: invoice, theme: theme, labels: labels, locale: locale, pageSize: pageSize)
        }
    }
}
