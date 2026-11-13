import Foundation
import NoirCore

/// Number, money, percentage and duration formatting in the active game language.
extension L10n {
    func decimal(_ v: Double, digits: Int) -> String {
        v.formatted(.number.precision(.fractionLength(0...digits)).grouping(.automatic).locale(locale))
    }

    /// Compact money/quantity: full grouping below 10,000, then k / M / B / T with one or two decimals, and powers of
    /// ten beyond that.
    func money(_ v: Double) -> String {
        let a = abs(v)
        let sign = v < -0.0049 ? "−" : ""
        let body: String
        if a < 10_000 {
            body = a < 100 ? decimal((a * 10).rounded() / 10, digits: 1) : decimal(a.rounded(), digits: 0)
        } else if a < 1_000_000 {
            body = self("num_thousand", decimal(a / 1_000, digits: 1))
        } else if a < 1_000_000_000 {
            body = self("num_million", decimal(a / 1_000_000, digits: 2))
        } else if a < 1e12 {
            body = self("num_billion", decimal(a / 1e9, digits: 2))
        } else if a < 1e15 {
            body = self("num_trillion", decimal(a / 1e12, digits: 2))
        } else {
            let exponent = Int(log10(a).rounded(.down))
            body = self("num_power", decimal(a / pow(10, Double(exponent)), digits: 2), exponent)
        }
        return sign + body
    }

    func signedMoney(_ v: Double) -> String { (v >= 0 ? "+" : "") + money(v) }

    func duration(_ seconds: Double) -> String {
        let s = Int(max(0, seconds).rounded())
        if s < 60 { return self("dur_s", s) }
        // Whole minutes and whole hours read as such ("30 min", "4 h"), never "30 min 00 s".
        if s < 3600 { return s % 60 == 0 ? self("dur_m", s / 60) : self("dur_ms", s / 60, s % 60) }
        return s % 3600 == 0 ? self("dur_h", s / 3600) : self("dur_hm", s / 3600, (s % 3600) / 60)
    }

    func percent(_ fraction: Double, digits: Int = 0) -> String {
        self("percent", decimal(fraction * 100, digits: digits))
    }

    /// Percentage points such as control (already 0–100).
    func points(_ value: Double) -> String { self("percent", decimal(value, digits: 0)) }

    func perMinute(_ perSecond: Double) -> String { self("per_min", money(perSecond * 60)) }

    func cost(_ c: Cost) -> String {
        var parts: [String] = []
        if c.dirty > 0 { parts.append(self("cost_dirty", money(c.dirty))) }
        if c.clean > 0 { parts.append(self("cost_clean", money(c.clean))) }
        if c.influence > 0 { parts.append(self("cost_influence", money(c.influence))) }
        return parts.isEmpty ? self("cost_free") : parts.joined(separator: " · ")
    }

    func relativeSaved(_ savedAtMs: Int64?, nowMs: Int64) -> String {
        guard let savedAtMs else { return "—" }
        let seconds = Double(nowMs - savedAtMs) / 1000
        if seconds < 5 { return self("time_now") }
        return self("time_ago", duration(seconds))
    }
}
