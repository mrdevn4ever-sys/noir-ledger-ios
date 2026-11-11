import Foundation

public let saveSchemaVersion = 2

// MARK: - Tolerant decoding

extension KeyedDecodingContainer {
    /// Decodes a value if present and well-formed, otherwise returns the default. Saves therefore never fail
    /// on a missing or damaged individual field; `SaveCodec.sanitize` repairs ranges afterwards.
    func value<T: Decodable>(_ key: Key, _ fallback: @autoclosure () -> T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback()
    }
}

/// 64-bit value stored as a hexadecimal string, so JSON round-trips never lose precision.
public struct UInt64Box: Codable, Sendable, Equatable {
    public var raw: UInt64
    public init(_ raw: UInt64) { self.raw = raw }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let text = try? c.decode(String.self), let v = UInt64(text, radix: 16) {
            raw = v
        } else if let n = try? c.decode(UInt64.self) {
            raw = n
        } else {
            raw = 1
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(String(raw, radix: 16))
    }
}

// MARK: - Entities

public enum LineStatus: String, Codable, Sendable, CaseIterable {
    case idle = "IDLE", running = "RUNNING", storageFull = "STORAGE_FULL", noCash = "NO_CASH", emergency = "EMERGENCY"
}

public struct LineState: Codable, Sendable, Equatable {
    public var owned = false
    public var running = false
    public var capacityLevel = 1
    public var speedLevel = 1
    public var qualityLevel = 1
    /// Levels bought after all three tracks reached their cap (see `Idle`).
    public var masteryLevel = 0
    public var progress = 0.0
    public var status: LineStatus = .idle

    public init() {}

    public func level(_ t: LineTrack) -> Int {
        switch t {
        case .capacity: capacityLevel
        case .speed: speedLevel
        case .quality: qualityLevel
        }
    }

    public var totalLevels: Int { capacityLevel + speedLevel + qualityLevel }
}

extension LineState {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        owned = c.value(.owned, false)
        running = c.value(.running, false)
        capacityLevel = c.value(.capacityLevel, 1)
        speedLevel = c.value(.speedLevel, 1)
        qualityLevel = c.value(.qualityLevel, 1)
        masteryLevel = c.value(.masteryLevel, 0)
        progress = c.value(.progress, 0.0)
        status = c.value(.status, LineStatus.idle)
    }
}

public struct DistrictState: Codable, Sendable, Equatable {
    public var unlocked = false
    public var rival = 50.0
    public var routes: [ProductId: Int] = [:]
    public var suspendedUntil = 0.0
    public var turfReadyAt = 0.0

    public init(rival: Double = 50) { self.rival = rival }

    public var control: Double { min(100, max(0, 100 - rival)) }
    public func route(_ p: ProductId) -> Int { routes[p] ?? 0 }
    public var totalRouteLevels: Int { ProductId.allCases.reduce(0) { $0 + route($1) } }
}

extension DistrictState {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        unlocked = c.value(.unlocked, false)
        rival = c.value(.rival, 50.0)
        routes = c.value(.routes, [ProductId: Int]())
        suspendedUntil = c.value(.suspendedUntil, 0.0)
        turfReadyAt = c.value(.turfReadyAt, 0.0)
    }
}

public struct FrontState: Codable, Sendable, Equatable {
    public var owned = false
    public var level = 1
    public var active = true

    public init() {}
}

extension FrontState {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        owned = c.value(.owned, false)
        level = c.value(.level, 1)
        active = c.value(.active, true)
    }
}

public struct CrewMember: Codable, Sendable, Equatable, Identifiable {
    public var defId: String
    public var loyalty: Double
    public var hiredAt: Double

    public var id: String { defId }

    public init(defId: String, loyalty: Double = 60, hiredAt: Double = 0) {
        self.defId = defId
        self.loyalty = loyalty
        self.hiredAt = hiredAt
    }

    public var def: CrewDef? { Content.crewDef(defId) }
}

extension CrewMember {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(defId: c.value(.defId, ""), loyalty: c.value(.loyalty, 60.0), hiredAt: c.value(.hiredAt, 0.0))
    }
}

public struct Investigation: Codable, Sendable, Equatable {
    public var startedAt: Double
    public var endsAt: Double
    public var district: DistrictId

    public init(startedAt: Double, endsAt: Double, district: DistrictId) {
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.district = district
    }
}

public enum ModKind: String, Codable, Sendable, CaseIterable {
    case price = "PRICE", demand = "DEMAND", unitCost = "UNIT_COST", productionSpeed = "PRODUCTION_SPEED"
    case routeCapacity = "ROUTE_CAPACITY", exposure = "EXPOSURE"
}

public struct TimedModifier: Codable, Sendable, Equatable {
    public var kind: ModKind
    public var value: Double
    public var until: Double
    public var district: DistrictId?
    public var product: ProductId?

    public init(kind: ModKind, value: Double, until: Double, district: DistrictId? = nil, product: ProductId? = nil) {
        self.kind = kind
        self.value = value
        self.until = until
        self.district = district
        self.product = product
    }
}

public struct PendingEvent: Codable, Sendable, Equatable {
    public var event: EventId
    public var district: DistrictId?
    /// Money unit (dirty) frozen when the event appeared, so the preview never changes.
    public var unit: Double
    public var cleanUnit: Double
    public var influenceUnit: Double
    public var createdAt: Double

    public init(event: EventId, district: DistrictId?, unit: Double, cleanUnit: Double, influenceUnit: Double, createdAt: Double) {
        self.event = event
        self.district = district
        self.unit = unit
        self.cleanUnit = cleanUnit
        self.influenceUnit = influenceUnit
        self.createdAt = createdAt
    }
}

public struct Stats: Codable, Sendable, Equatable {
    public var dirtyEarned = 0.0
    public var cleanLaundered = 0.0
    public var unitsProduced = 0.0
    public var unitsSold = 0.0
    public var raids = 0
    public var investigations = 0
    public var investigationsSurvived = 0
    public var eventsResolved = 0
    public var peakHeat = 0.0
    public var turfActions = 0
    public var onlineSeconds = 0.0
    public var offlineSeconds = 0.0
    public var tutorialEarned = 0.0

    public init() {}
}

extension Stats {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        dirtyEarned = c.value(.dirtyEarned, 0.0)
        cleanLaundered = c.value(.cleanLaundered, 0.0)
        unitsProduced = c.value(.unitsProduced, 0.0)
        unitsSold = c.value(.unitsSold, 0.0)
        raids = c.value(.raids, 0)
        investigations = c.value(.investigations, 0)
        investigationsSurvived = c.value(.investigationsSurvived, 0)
        eventsResolved = c.value(.eventsResolved, 0)
        peakHeat = c.value(.peakHeat, 0.0)
        turfActions = c.value(.turfActions, 0)
        onlineSeconds = c.value(.onlineSeconds, 0.0)
        offlineSeconds = c.value(.offlineSeconds, 0.0)
        tutorialEarned = c.value(.tutorialEarned, 0.0)
    }
}

public enum FinalResult: String, Codable, Sendable {
    case success = "SUCCESS", failure = "FAILURE"
}

public struct FinalOpState: Codable, Sendable, Equatable {
    public var phase = 0
    public var readyAt = 0.0
    public var failures = 0
    public var lastResult: FinalResult?

    public init() {}
}

extension FinalOpState {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        phase = c.value(.phase, 0)
        readyAt = c.value(.readyAt, 0.0)
        failures = c.value(.failures, 0)
        lastResult = c.value(.lastResult, nil)
    }
}

public enum PrologueChoice: String, Codable, Sendable, CaseIterable {
    case cashBox = "CASH_BOX", contacts = "CONTACTS", tools = "TOOLS"
}

public struct CampaignState: Codable, Sendable, Equatable {
    public var prologueDone = false
    public var prologueChoice: PrologueChoice?
    public var tutorial: TutorialStep = .startLine
    public var chapter = 0
    public var finalOp: FinalOpState?
    public var won = false
    public var wonAtTime = 0.0
    public var epilogueSeen = false
    public var legacyAwarded = 0

    public init() {}
}

extension CampaignState {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        prologueDone = c.value(.prologueDone, false)
        prologueChoice = c.value(.prologueChoice, nil)
        tutorial = c.value(.tutorial, TutorialStep.startLine)
        chapter = c.value(.chapter, 0)
        finalOp = c.value(.finalOp, nil)
        won = c.value(.won, false)
        wonAtTime = c.value(.wonAtTime, 0.0)
        epilogueSeen = c.value(.epilogueSeen, false)
        legacyAwarded = c.value(.legacyAwarded, 0)
    }
}

public struct LegacyState: Codable, Sendable, Equatable {
    public var ngLevel = 0
    public var points = 0
    public var perks: [PerkId: Int] = [:]
    public var wins = 0

    public init(ngLevel: Int = 0, points: Int = 0, perks: [PerkId: Int] = [:], wins: Int = 0) {
        self.ngLevel = ngLevel
        self.points = points
        self.perks = perks
        self.wins = wins
    }

    public func rank(_ p: PerkId) -> Int { perks[p] ?? 0 }
}

extension LegacyState {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(ngLevel: c.value(.ngLevel, 0), points: c.value(.points, 0),
                  perks: c.value(.perks, [PerkId: Int]()), wins: c.value(.wins, 0))
    }
}

public enum JournalKind: String, Codable, Sendable, CaseIterable {
    case chapterComplete = "CHAPTER_COMPLETE", districtUnlocked = "DISTRICT_UNLOCKED", lineBought = "LINE_BOUGHT"
    case frontBought = "FRONT_BOUGHT", crewHired = "CREW_HIRED", crewLeft = "CREW_LEFT", crewDismissed = "CREW_DISMISSED"
    case investigationStarted = "INVESTIGATION_STARTED", investigationCleared = "INVESTIGATION_CLEARED", raid = "RAID"
    case heatWarning = "HEAT_WARNING", eventResolved = "EVENT_RESOLVED", turf = "TURF", bribe = "BRIBE", upgrade = "UPGRADE"
    case finalPhaseWon = "FINAL_PHASE_WON", finalPhaseLost = "FINAL_PHASE_LOST", campaignWon = "CAMPAIGN_WON"
    case newGamePlus = "NEW_GAME_PLUS", offlineReturn = "OFFLINE_RETURN", layLowOn = "LAY_LOW_ON", layLowOff = "LAY_LOW_OFF"
    case protection = "PROTECTION", wagesUnpaid = "WAGES_UNPAID", donation = "DONATION"
    case prestige = "PRESTIGE", milestone = "MILESTONE"
}

public struct JournalEntry: Codable, Sendable, Equatable, Identifiable {
    /// Monotonic booking number, stable across saves (used as list identity).
    public var seq: Int
    public var time: Double
    public var kind: JournalKind
    public var ref: String
    public var amount: Double
    public var amount2: Double

    public var id: Int { seq }

    public init(seq: Int = 0, time: Double, kind: JournalKind, ref: String = "", amount: Double = 0, amount2: Double = 0) {
        self.seq = seq
        self.time = time
        self.kind = kind
        self.ref = ref
        self.amount = amount
        self.amount2 = amount2
    }
}

extension JournalEntry {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(seq: c.value(.seq, 0), time: c.value(.time, 0.0), kind: c.value(.kind, JournalKind.chapterComplete),
                  ref: c.value(.ref, ""), amount: c.value(.amount, 0.0), amount2: c.value(.amount2, 0.0))
    }
}

public struct RaidReport: Codable, Sendable, Equatable {
    public var district: DistrictId
    public var inventoryLost: Double
    public var dirtyLost: Double
    public var controlLost: Double
    public var time: Double

    public init(district: DistrictId, inventoryLost: Double, dirtyLost: Double, controlLost: Double, time: Double) {
        self.district = district
        self.inventoryLost = inventoryLost
        self.dirtyLost = dirtyLost
        self.controlLost = controlLost
        self.time = time
    }
}

// MARK: - Game state

public struct GameState: Codable, Sendable, Equatable {
    public var version = saveSchemaVersion
    public var seed = UInt64Box(1)
    public var rng = UInt64Box(1)
    /// Simulated game time in seconds. Never derived from the wall clock.
    public var time = 0.0
    /// Wall clock of the last tick (ms since 1970); used only to credit time away.
    public var lastWallClockMs: Int64 = 0
    public var dirty = 0.0
    public var clean = 0.0
    public var influence = 0.0
    public var heat = 0.0
    public var heatTarget = 0.0
    public var layLow = false
    public var warned = false
    public var investigation: Investigation?
    public var lastRaid: RaidReport?
    public var storageLevel = 1
    public var protectionLevel = 0
    public var lines: [ProductId: LineState] = [:]
    public var inventory: [ProductId: Double] = [:]
    public var districts: [DistrictId: DistrictState] = [:]
    public var fronts: [FrontId: FrontState] = [:]
    public var crew: [CrewMember] = []
    public var departed: [String] = []
    /// Owned improvements in purchase order.
    public var upgrades: [UpgradeId] = []
    public var modifiers: [TimedModifier] = []
    public var pendingEvent: PendingEvent?
    public var nextEventAt = 300.0
    public var eventLastSeen: [EventId: Double] = [:]
    public var bribeReadyAt = 0.0
    public var wagesUnpaid = false
    public var raidUnseen = false
    public var tutorialLaunderBase = 0.0
    /// Fronts only launder dirty cash above this many minutes of street income.
    public var reserveMinutes = 2
    /// Exponential moving averages (per second) used for scaling and display.
    public var incomeRate = 0.0
    public var cleanRate = 0.0
    public var influenceRateEma = 0.0
    public var stats = Stats()
    public var campaign = CampaignState()
    public var legacy = LegacyState()
    /// Progress that outlives the run: favors, reputation, purchases, boosts, daily rewards and achievements.
    public var meta = MetaState()
    /// Newest first, at most 60 entries.
    public var journal: [JournalEntry] = []
    /// Number of bookings ever written (the next entry's sequence number).
    public var journalCount = 0

    public init() {}

    public func line(_ p: ProductId) -> LineState { lines[p] ?? LineState() }
    public func district(_ d: DistrictId) -> DistrictState { districts[d] ?? DistrictState(rival: Content.district(d).startRival) }
    public func front(_ f: FrontId) -> FrontState { fronts[f] ?? FrontState() }
    public func stock(_ p: ProductId) -> Double { inventory[p] ?? 0 }
    public var totalStock: Double { ProductId.allCases.reduce(0) { $0 + stock($1) } }
    public func crewIn(_ role: CrewRole) -> CrewMember? { crew.first { Content.crewDef($0.defId)?.role == role } }
    public func hasUpgrade(_ u: UpgradeId) -> Bool { upgrades.contains(u) }

    public mutating func updateLine(_ p: ProductId, _ body: (inout LineState) -> Void) {
        var l = line(p)
        body(&l)
        lines[p] = l
    }

    public mutating func updateDistrict(_ d: DistrictId, _ body: (inout DistrictState) -> Void) {
        var ds = district(d)
        body(&ds)
        districts[d] = ds
    }

    public mutating func updateFront(_ f: FrontId, _ body: (inout FrontState) -> Void) {
        var fs = front(f)
        body(&fs)
        fronts[f] = fs
    }

    public mutating func log(_ kind: JournalKind, ref: String = "", amount: Double = 0, amount2: Double = 0) {
        journalCount += 1
        journal.insert(JournalEntry(seq: journalCount, time: time, kind: kind, ref: ref, amount: amount, amount2: amount2), at: 0)
        if journal.count > 60 { journal.removeLast(journal.count - 60) }
    }
}

extension GameState {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        version = c.value(.version, saveSchemaVersion)
        seed = c.value(.seed, UInt64Box(1))
        rng = c.value(.rng, UInt64Box(1))
        time = c.value(.time, 0.0)
        lastWallClockMs = c.value(.lastWallClockMs, Int64(0))
        dirty = c.value(.dirty, 0.0)
        clean = c.value(.clean, 0.0)
        influence = c.value(.influence, 0.0)
        heat = c.value(.heat, 0.0)
        heatTarget = c.value(.heatTarget, 0.0)
        layLow = c.value(.layLow, false)
        warned = c.value(.warned, false)
        investigation = c.value(.investigation, nil)
        lastRaid = c.value(.lastRaid, nil)
        storageLevel = c.value(.storageLevel, 1)
        protectionLevel = c.value(.protectionLevel, 0)
        lines = c.value(.lines, [ProductId: LineState]())
        inventory = c.value(.inventory, [ProductId: Double]())
        districts = c.value(.districts, [DistrictId: DistrictState]())
        fronts = c.value(.fronts, [FrontId: FrontState]())
        crew = c.value(.crew, [CrewMember]())
        departed = c.value(.departed, [String]())
        upgrades = c.value(.upgrades, [UpgradeId]())
        modifiers = c.value(.modifiers, [TimedModifier]())
        pendingEvent = c.value(.pendingEvent, nil)
        nextEventAt = c.value(.nextEventAt, 300.0)
        eventLastSeen = c.value(.eventLastSeen, [EventId: Double]())
        bribeReadyAt = c.value(.bribeReadyAt, 0.0)
        wagesUnpaid = c.value(.wagesUnpaid, false)
        raidUnseen = c.value(.raidUnseen, false)
        tutorialLaunderBase = c.value(.tutorialLaunderBase, 0.0)
        reserveMinutes = c.value(.reserveMinutes, 2)
        incomeRate = c.value(.incomeRate, 0.0)
        cleanRate = c.value(.cleanRate, 0.0)
        influenceRateEma = c.value(.influenceRateEma, 0.0)
        stats = c.value(.stats, Stats())
        campaign = c.value(.campaign, CampaignState())
        legacy = c.value(.legacy, LegacyState())
        meta = c.value(.meta, MetaState())
        journal = c.value(.journal, [JournalEntry]())
        journalCount = c.value(.journalCount, journal.map(\.seq).max() ?? 0)
    }
}
