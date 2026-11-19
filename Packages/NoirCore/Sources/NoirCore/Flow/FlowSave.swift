import Foundation

/// Versioned, crash-safe save of the ledger: `{"schema": 1, "savedAt": ms, "state": {...}}`, written atomically with
/// the previous good file kept as a backup.
public struct FlowSaveStore: Sendable {
    public enum Loaded: Sendable {
        case fresh
        case loaded(FlowState, restoredFromBackup: Bool)
        case futureVersion(Int)
    }

    public let directory: URL
    public var primaryURL: URL { directory.appendingPathComponent("noir_flow.save") }
    public var backupURL: URL { directory.appendingPathComponent("noir_flow.save.bak") }
    var tempURL: URL { directory.appendingPathComponent("noir_flow.save.tmp") }

    public init(directory: URL) {
        self.directory = directory
    }

    private struct Envelope: Codable {
        let schema: Int
        let savedAt: Int64
        let state: FlowState
    }

    private enum Read {
        case ok(FlowState), future(Int), bad
    }

    private func read(_ url: URL) -> Read? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return .bad }
        if let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let schema = (raw["schema"] as? NSNumber)?.intValue, schema > flowSchemaVersion {
            return .future(schema)
        }
        guard let env = try? JSONDecoder().decode(Envelope.self, from: data) else { return .bad }
        var s = env.state
        Self.sanitize(&s)
        return .ok(s)
    }

    public func load() -> Loaded {
        let primary = read(primaryURL)
        switch primary {
        case .some(.ok(let s)): return .loaded(s, restoredFromBackup: false)
        case .some(.future(let v)): return .futureVersion(v)
        default: break
        }
        switch read(backupURL) {
        case .some(.ok(let s)): return .loaded(s, restoredFromBackup: primary != nil)
        case .some(.future(let v)): return .futureVersion(v)
        default: return .fresh
        }
    }

    public func write(_ state: FlowState, savedAtMs: Int64) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        var s = state
        s.version = flowSchemaVersion
        let data = try encoder.encode(Envelope(schema: flowSchemaVersion, savedAt: savedAtMs, state: s))
        try data.write(to: tempURL, options: [.atomic])
        if fm.fileExists(atPath: primaryURL.path) {
            if case .some(.ok) = read(primaryURL) {
                if fm.fileExists(atPath: backupURL.path) { try fm.removeItem(at: backupURL) }
                try fm.moveItem(at: primaryURL, to: backupURL)
            } else {
                try fm.removeItem(at: primaryURL)
            }
        }
        try fm.moveItem(at: tempURL, to: primaryURL)
    }

    public func erase() {
        for url in [primaryURL, backupURL, tempURL] where FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func fix(_ v: Double, _ lo: Double = 0, _ hi: Double = .greatestFiniteMagnitude) -> Double {
        v.isFinite ? min(hi, max(lo, v)) : lo
    }

    /// Repairs out-of-range values so a damaged save can never crash or dead-lock the game.
    public static func sanitize(_ s: inout FlowState) {
        s.cash = fix(s.cash)
        s.earned = fix(s.earned)
        s.time = fix(s.time)
        s.chapter = min(FlowContent.chapters.count + 1, max(1, s.chapter))
        s.fleet = min(FlowContent.maxLevel, max(1, s.fleet))
        if s.workshops[.weed] == nil { s.workshops[.weed] = WorkshopState() }
        for (g, var w) in s.workshops {
            w.bench = min(FlowContent.maxLevel, max(1, w.bench))
            w.shelf = min(FlowContent.maxLevel, max(1, w.shelf))
            w.stock = fix(w.stock, 0, Flow.shelfCapacity(s, g) * 4 + 1)
            if let c = w.cycle { w.cycle = fix(c, 0, 0.999_999) }
            w.fullFor = fix(w.fullFor)
            s.workshops[g] = w
        }
        s.contacts = s.contacts.filter { FlowContent.contact($0.key) != nil }
        if s.contacts["muehlgasse"] == nil { s.contacts["muehlgasse"] = ContactState() }
        for (id, var c) in s.contacts {
            c.level = min(FlowContent.maxLevel, max(1, c.level))
            c.open = fix(c.open)
            c.trust = min(FlowContent.maxTrust, max(0, c.trust))
            s.contacts[id] = c
        }
        for (q, var st) in s.quarters {
            st.attention = fix(st.attention, 0, 100)
            s.quarters[q] = st
        }
        if Set(s.priority) != Set(Good.allCases) || s.priority.count != Good.allCases.count { s.priority = Good.allCases }
        s.orders = s.orders.filter { o in o.offer.items.allSatisfy { $0.value.isFinite && $0.value >= 0 } && o.offer.pay.isFinite }
        s.offers = s.offers.filter { o in o.items.allSatisfy { $0.value.isFinite && $0.value >= 0 } && o.pay.isFinite }
        if let t = s.trip, !(t.left.isFinite && t.left >= 0) { s.trip = nil }
        if s.ledger.count > FlowContent.ledgerSize { s.ledger.removeFirst(s.ledger.count - FlowContent.ledgerSize) }
        s.meta.favors = max(0, s.meta.favors)
        s.meta.boostSeconds = fix(s.meta.boostSeconds, 0, Idle.boostCapSeconds)
        s.meta.offlineBonus = fix(s.meta.offlineBonus)
        if s.lastWallClockMs < 0 { s.lastWallClockMs = 0 }
    }
}
