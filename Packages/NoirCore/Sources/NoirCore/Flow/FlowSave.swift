import Foundation

/// Upgrades a decoded state from the schema it was written with to `flowSchemaVersion`. Old saves never need old
/// Swift types: the state decodes leniently (missing fields take safe defaults), then each step fixes meaning.
public enum FlowMigration {
    public static func migrate(_ s: inout FlowState, fromSchema schema: Int) {
        if schema < 2 {
            // Schema 1 knew no estate pickup. Only an untouched prologue gets it; a business already in play (or any
            // save that booked anything) never receives it afterwards.
            let untouched = s.start == nil && s.earned <= 0 && s.ledger.isEmpty && s.counters.deliveries == 0
            s.estate = untouched ? .waiting : .notOffered
        }
        s.version = flowSchemaVersion
    }
}

/// Versioned, crash-safe save of the ledger: `{"schema": 2, "savedAt": ms, "state": {...}}`, written atomically with
/// the previous good file kept as a backup. A save from an older schema is copied once, untouched, before it is
/// migrated; a file that cannot be read at all is set aside instead of being overwritten.
public struct FlowSaveStore: Sendable {
    public enum Loaded: Sendable {
        case fresh
        case loaded(FlowState, restoredFromBackup: Bool)
        case futureVersion(Int)
        case unavailable
    }

    public let directory: URL
    public var primaryURL: URL { directory.appendingPathComponent("noir_flow.save") }
    public var backupURL: URL { directory.appendingPathComponent("noir_flow.save.bak") }
    /// The untouched file of the last older schema that was migrated (last resort when primary and backup fail).
    public var archiveURL: URL { directory.appendingPathComponent("noir_flow.save.pre-migration") }
    /// An unreadable primary save, set aside before a new game is written.
    public var damagedURL: URL { directory.appendingPathComponent("noir_flow.save.damaged") }
    var tempURL: URL { directory.appendingPathComponent("noir_flow.save.tmp") }
    var resetURL: URL { directory.appendingPathComponent("noir_flow.save.reset") }

    public init(directory: URL) {
        self.directory = directory
    }

    private struct Envelope: Codable {
        let schema: Int
        let savedAt: Int64
        let state: FlowState
    }

    private enum Read {
        case ok(FlowState, schema: Int), future(Int), bad
    }

    private func read(_ url: URL) -> Read? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return .bad }
        let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let schema = (raw?["schema"] as? NSNumber)?.intValue ?? 1
        if schema > flowSchemaVersion { return .future(schema) }
        guard let env = try? JSONDecoder().decode(Envelope.self, from: data) else { return .bad }
        var s = env.state
        FlowMigration.migrate(&s, fromSchema: schema)
        Self.sanitize(&s)
        return .ok(s, schema: schema)
    }

    private struct Header: Decodable { let schema: Int }
    private enum SaveError: Error { case newer(Int), unreadableReset }

    // Check recovery copies too: a valid older primary is not permission to rotate a newer backup away.
    // Missing is normal on first launch. A file that exists but cannot be read is not a missing save.
    private func checkVersions() throws {
        for url in [primaryURL, backupURL, archiveURL, resetURL] {
            let data: Data
            do { data = try Data(contentsOf: url) }
            catch let error as CocoaError where error.code == .fileReadNoSuchFile { continue }
            if let header = try? JSONDecoder().decode(Header.self, from: data), header.schema > flowSchemaVersion {
                throw SaveError.newer(header.schema)
            }
        }
    }

    public func load() -> Loaded {
        do {
            try checkVersions()
            if let pending = read(resetURL) {
                guard case .ok(let state, _) = pending else { return .unavailable }
                // The journal is already the committed game. A full disk can delay housekeeping, not undo the reset.
                try? installCommittedReset()
                return .loaded(state, restoredFromBackup: false)
            }
        } catch SaveError.newer(let version) { return .futureVersion(version) }
        catch { return .unavailable }
        let primary = read(primaryURL)
        switch primary {
        case .some(.ok(let s, let schema)):
            if schema < flowSchemaVersion { archive(primaryURL) }
            return .loaded(s, restoredFromBackup: false)
        case .some(.future(let v)):
            return .futureVersion(v)
        default:
            break
        }
        switch read(backupURL) {
        case .some(.ok(let s, let schema)):
            if schema < flowSchemaVersion { archive(backupURL) }
            return .loaded(s, restoredFromBackup: primary != nil)
        case .some(.future(let v)):
            return .futureVersion(v)
        default:
            break
        }
        if case .some(.ok(let s, _)) = read(archiveURL) {
            return .loaded(s, restoredFromBackup: true)
        }
        if primary != nil { setAside(primaryURL) }
        return .fresh
    }

    /// Keeps the first untouched copy of an older-schema save.
    private func archive(_ url: URL) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: archiveURL.path) else { return }
        try? fm.copyItem(at: url, to: archiveURL)
    }

    private func setAside(_ url: URL) {
        let fm = FileManager.default
        if fm.fileExists(atPath: damagedURL.path) { try? fm.removeItem(at: damagedURL) }
        try? fm.copyItem(at: url, to: damagedURL)
    }

    private func encoded(_ state: FlowState, savedAtMs: Int64) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        var s = state
        s.version = flowSchemaVersion
        return try encoder.encode(Envelope(schema: flowSchemaVersion, savedAt: savedAtMs, state: s))
    }

    private func installCommittedReset() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: resetURL.path) else { return }
        guard case .some(.ok) = read(resetURL) else { throw SaveError.unreadableReset }
        let data = try Data(contentsOf: resetURL)
        // Idempotent after an interruption at any line. The journal is retired last.
        try data.write(to: primaryURL, options: .atomic)
        try data.write(to: backupURL, options: .atomic)
        if fm.fileExists(atPath: archiveURL.path) {
            let retired = directory.appendingPathComponent("noir_flow.retired-\(UUID().uuidString)")
            try fm.moveItem(at: archiveURL, to: retired)
        }
        try fm.removeItem(at: resetURL)
    }

    /// Before the journal rename, no file belonging to the live business changes. After it, the new wallet wins.
    public func commitReset(_ state: FlowState, savedAtMs: Int64) throws {
        try checkVersions()
        try installCommittedReset()
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoded(state, savedAtMs: savedAtMs).write(to: tempURL, options: .atomic)
        try fm.moveItem(at: tempURL, to: resetURL)
        try? installCommittedReset()
    }

    public func write(_ state: FlowState, savedAtMs: Int64) throws {
        try checkVersions()
        try installCommittedReset()
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoded(state, savedAtMs: savedAtMs)
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

    /// QA fixture isolation only. A player reset must use commitReset instead.
    public func erase() {
        for url in [primaryURL, backupURL, tempURL, archiveURL, resetURL] where FileManager.default.fileExists(atPath: url.path) {
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
