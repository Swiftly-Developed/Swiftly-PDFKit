import Foundation

// MARK: - DocumentFormatter

/// Lightweight number/label formatting helpers used by the layout builders.
///
/// Every number and date method formats through `locale` — the document's
/// resolved locale, never the process or device locale — so the client preview
/// and the Linux email attachment print the same digits. `currencyCode` drives
/// ``money(_:)`` and `labels` the builders' fixed wording. All three default, so
/// a caller that supplies only a theme keeps compiling unchanged.
///
/// Public because ``DocumentLayoutKit/footer(invoice:theme:fmt:page:of:height:ruleThickness:ruleColor:alignment:)``
/// takes one, and a public composition atom cannot name an internal type.
public struct DocumentFormatter: Sendable {
    public let theme: InvoiceTheme
    /// Locale driving every number and date method. Explicit — never the device locale.
    public var locale: Locale = Locale(identifier: "en_US")
    /// ISO 4217 currency code for ``money(_:)`` (the document's currency).
    public var currencyCode: String = "EUR"
    /// Rendered-string catalog the builders read their fixed wording from.
    public var labels: InvoiceLabels = .english

    public init(
        theme: InvoiceTheme,
        locale: Locale = Locale(identifier: "en_US"),
        currencyCode: String = "EUR",
        labels: InvoiceLabels = .english
    ) {
        self.theme = theme
        self.locale = locale
        self.currencyCode = currencyCode
        self.labels = labels
    }

    public func label(_ text: String) -> String { text }

    /// Two-decimal number without a currency symbol (the layouts name the
    /// currency in the column or row label), e.g. "1.234,50" under nl-BE.
    public func amount(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)).locale(locale))
    }

    /// Up to two decimals, none for a whole quantity, e.g. "2,5" / "3" under nl-BE.
    public func quantity(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }

    /// `value` is a 0–100 rate (`21` means 21 %), the shape every layout passes;
    /// `.percent` expects 0–1, hence the division. E.g. "5,5%" under nl-BE.
    public func percent(_ value: Double) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(0...2)).locale(locale))
    }

    /// Locale-aware monetary string in the injected ``currencyCode``
    /// (e.g. "€1.234,56" under a Dutch locale).
    public func money(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode).locale(locale))
    }

    /// Locale-aware abbreviated date (e.g. "Aug 17, 2026" / "17 aug 2026").
    public func date(_ value: Date) -> String {
        value.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }
}

// MARK: - Legacy spelling

/// Source-compatibility alias for the pre-`PRINT01` name. In-package callers are
/// all re-pointed; this exists so a stale reference fails loudly at the rename
/// rather than silently at a later phase.
public typealias InvoiceFormatter = DocumentFormatter
