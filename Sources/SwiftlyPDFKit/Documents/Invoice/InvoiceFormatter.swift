import Foundation

// MARK: - InvoiceFormatter (internal)

/// Lightweight number/label formatting helpers used by the layout builder.
///
/// The `locale` / `currencyCode` / `labels` seams drive the locale-aware
/// ``money(_:)`` and ``date(_:)`` methods; all three default so the historical
/// `InvoiceFormatter(theme:)` call shape keeps compiling unchanged, and the
/// legacy `amount` / `quantity` / `percent` paths are byte-untouched.
struct InvoiceFormatter {
    let theme: InvoiceTheme
    /// Locale driving the new money/date methods. Explicit — never the device locale.
    var locale: Locale = Locale(identifier: "en_US")
    /// ISO 4217 currency code for ``money(_:)`` (the document's currency).
    var currencyCode: String = "EUR"
    /// Rendered-string catalog the builders read their fixed wording from.
    var labels: InvoiceLabels = .english

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        return f
    }()

    private static let quantityFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        return f
    }()

    func label(_ text: String) -> String { text }

    func amount(_ value: Double) -> String {
        Self.amountFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    func quantity(_ value: Double) -> String {
        Self.quantityFormatter.string(from: NSNumber(value: value)) ?? String(format: value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", value)
    }

    func percent(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f%%", value)
            : String(format: "%.2f%%", value)
    }

    /// Locale-aware monetary string in the injected ``currencyCode``
    /// (e.g. "€1.234,56" under a Dutch locale).
    func money(_ value: Double) -> String {
        value.formatted(.currency(code: currencyCode).locale(locale))
    }

    /// Locale-aware abbreviated date (e.g. "Aug 17, 2026" / "17 aug 2026").
    func date(_ value: Date) -> String {
        value.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }
}
