import Foundation

enum Format {
    static func usd(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }

    /// Prices below $1 show four decimals (e.g. $0.0452); tiny meme-coin prices get more.
    static func price(_ value: Double) -> String {
        let magnitude = abs(value)
        if magnitude >= 1 || value == 0 { return usd(value) }
        let digits = magnitude >= 0.01 ? 4 : (magnitude >= 0.0001 ? 6 : 8)
        return value.formatted(.currency(code: "USD").precision(.fractionLength(digits)))
    }

    /// $1.23T / $4.56B / $7.89M / $12.30K (works on iOS 17).
    static func compactUSD(_ value: Double) -> String {
        let magnitude = Swift.abs(value)
        let units: [(size: Double, suffix: String)] = [(1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")]
        for unit in units where magnitude >= unit.size {
            return "$" + (value / unit.size).formatted(.number.precision(.fractionLength(2))) + unit.suffix
        }
        return usd(value)
    }

    static func signedUSD(_ value: Double) -> String {
        (value >= 0 ? "+" : "-") + usd(abs(value))
    }

    static func percent(_ value: Double) -> String {
        (value >= 0 ? "+" : "") + value.formatted(.number.precision(.fractionLength(2))) + "%"
    }

    static func plainPercent(_ value: Double) -> String {
        abs(value).formatted(.number.precision(.fractionLength(2))) + "%"
    }

    static func quantity(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...6)))
    }

    /// Number without grouping separators, for text fields.
    static func plain(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...8)))
    }

    static func parse(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }
}

extension String {
    /// "9xQe…VFin"
    var shortAddress: String {
        guard count > 10 else { return self }
        return "\(prefix(4))…\(suffix(4))"
    }
}
