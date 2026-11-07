import Foundation

/// Raw JSON object used by migrations (schema N → N+1) before the typed decode.
public typealias JSONObject = [String: Any]
public typealias SaveMigration = @Sendable (JSONObject) throws -> JSONObject

/// Versioned save format. A save file is an envelope:
/// `{"schema": <int>, "savedAt": <epoch ms>, "state": { ...GameState... }}`.
///
/// Migrations transform the raw JSON object of schema N into schema N+1 before decoding, so old saves never need
/// old Swift types. Schema 1 is the first shipped format; the registry is therefore empty today, and the migration
/// pipeline is exercised by tests with an injected registry.
public struct SaveCodec: Sendable {
    public enum Decoded: Sendable {
        case ok(GameState, migratedFrom: Int?)
        case futureVersion(Int)
        case corrupt(String)
    }

    public let currentVersion: Int
    public let migrations: [Int: SaveMigration]

    public static let shippedMigrations: [Int: SaveMigration] = [:]

    public init(currentVersion: Int = saveSchemaVersion, migrations: [Int: SaveMigration] = SaveCodec.shippedMigrations) {
        self.currentVersion = currentVersion
        self.migrations = migrations
    }

    static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return e
    }

    static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return d
    }

    private struct CurrentEnvelope: Decodable {
        let state: GameState
    }

    private struct Envelope: Encodable {
        let schema: Int
        let savedAt: Int64
        let state: GameState
    }

    public func encode(_ state: GameState, savedAtMs: Int64) throws -> Data {
        var s = state
        s.version = currentVersion
        return try Self.makeEncoder().encode(Envelope(schema: currentVersion, savedAt: savedAtMs, state: s))
    }

    public func decode(_ data: Data) -> Decoded {
        guard let raw = try? JSONSerialization.jsonObject(with: data), let envelope = raw as? JSONObject else {
            return .corrupt("parse")
        }
        guard let schema = (envelope["schema"] as? NSNumber)?.intValue else { return .corrupt("missing schema") }
        if schema > currentVersion { return .futureVersion(schema) }
        if schema < 1 { return .corrupt("bad schema \(schema)") }
        guard var stateObject = envelope["state"] as? JSONObject else { return .corrupt("missing state") }
        if schema == currentVersion {
            // Common path: decode the original bytes directly, no re-serialization.
            guard var state = try? Self.makeDecoder().decode(CurrentEnvelope.self, from: data).state else {
                return .corrupt("decode")
            }
            Self.sanitize(&state)
            state.version = currentVersion
            return .ok(state, migratedFrom: nil)
        }
        var v = schema
        while v < currentVersion {
            guard let migration = migrations[v] else { return .corrupt("no migration from \(v)") }
            do {
                stateObject = try migration(stateObject)
            } catch {
                return .corrupt("migration \(v) failed")
            }
            v += 1
        }
        guard JSONSerialization.isValidJSONObject(stateObject),
              let stateData = try? JSONSerialization.data(withJSONObject: stateObject),
              var state = try? Self.makeDecoder().decode(GameState.self, from: stateData) else {
            return .corrupt("decode")
        }
        Self.sanitize(&state)
        state.version = currentVersion
        return .ok(state, migratedFrom: schema != currentVersion ? schema : nil)
    }

    public func savedAt(_ data: Data) -> Int64? {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? JSONObject else { return nil }
        return (raw["savedAt"] as? NSNumber)?.int64Value
    }

    private static func fix(_ v: Double, _ lo: Double = 0, _ hi: Double = .greatestFiniteMagnitude) -> Double {
        if v.isNaN || v.isInfinite { return lo }
        return min(hi, max(lo, v))
    }

    private static func clampInt(_ v: Int, _ lo: Int, _ hi: Int) -> Int { min(hi, max(lo, v)) }

    /// Repairs any out-of-range or missing values so a damaged save can never crash or dead-lock the game.
    public static func sanitize(_ s: inout GameState) {
        s.dirty = fix(s.dirty)
        s.clean = fix(s.clean)
        s.influence = fix(s.influence)
        s.heat = fix(s.heat, 0, 100)
        s.heatTarget = fix(s.heatTarget, 0, 100)
        s.time = fix(s.time)
        s.incomeRate = fix(s.incomeRate)
        s.cleanRate = fix(s.cleanRate)
        s.influenceRateEma = fix(s.influenceRateEma)
        for p in ProductId.allCases {
            var l = s.lines[p] ?? LineState()
            l.capacityLevel = clampInt(l.capacityLevel, 1, Content.maxLineLevel)
            l.speedLevel = clampInt(l.speedLevel, 1, Content.maxLineLevel)
            l.qualityLevel = clampInt(l.qualityLevel, 1, Content.maxLineLevel)
            l.progress = fix(l.progress, -1000, 1000)
            s.lines[p] = l
            s.inventory[p] = fix(s.inventory[p] ?? 0)
        }
        s.lines[.glimmer]?.owned = true
        for d in DistrictId.allCases {
            var ds = s.districts[d] ?? DistrictState(rival: Content.district(d).startRival)
            ds.rival = fix(ds.rival, 0, 100)
            for (p, lvl) in ds.routes { ds.routes[p] = clampInt(lvl, 0, Content.maxRouteLevel) }
            s.districts[d] = ds
        }
        s.districts[.cellars]?.unlocked = true
        for f in FrontId.allCases {
            var fs = s.fronts[f] ?? FrontState()
            fs.level = clampInt(fs.level, 1, Content.maxFrontLevel)
            s.fronts[f] = fs
        }
        s.crew.removeAll { Content.crewDef($0.defId) == nil }
        var seenRoles = Set<CrewRole>()
        s.crew = s.crew.filter { member in
            guard let role = member.def?.role, !seenRoles.contains(role) else { return false }
            seenRoles.insert(role)
            return true
        }
        for i in s.crew.indices { s.crew[i].loyalty = fix(s.crew[i].loyalty, 0, 100) }
        var seenUpgrades = Set<UpgradeId>()
        s.upgrades = s.upgrades.filter { seenUpgrades.insert($0).inserted }
        s.storageLevel = clampInt(s.storageLevel, 1, Content.maxStorageLevel)
        s.protectionLevel = clampInt(s.protectionLevel, 0, Content.maxProtectionLevel)
        s.campaign.chapter = clampInt(s.campaign.chapter, 0, Content.finalChapter)
        if !Engine.reserveOptions.contains(s.reserveMinutes) { s.reserveMinutes = 2 }
        if s.lastWallClockMs < 0 { s.lastWallClockMs = 0 }
        if s.journal.count > 60 { s.journal.removeLast(s.journal.count - 60) }
        for (p, v) in s.legacy.perks { s.legacy.perks[p] = clampInt(v, 0, p.maxRank) }
        s.legacy.points = max(0, s.legacy.points)
        s.legacy.ngLevel = max(0, s.legacy.ngLevel)
    }
}
