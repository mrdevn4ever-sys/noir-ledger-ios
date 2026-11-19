import Foundation

/*
 * NOIR LEDGER 3.0: the classic idle tycoon.
 *
 * One building, four floors (weed, pills, crystal, coke), one currency (cash). Each floor sells in cycles; without a
 * manager the player taps to run a cycle, with a manager it runs on its own and keeps earning while the app is closed.
 * Every 25/50/100/... units halve a floor's cycle. Deals multiply payouts. Heat fills up while the operation runs; at
 * 100 the police pull up and must be bribed within 30 seconds or they raid a quarter of the cash. A suitcase of cash
 * turns up on the street now and then. Changing city (prestige) trades the run for reputation: +10 % on every payout.
 *
 * 3.1 adds choices: every floor sells its goods pure, cut or laced (more cash, more Heat); each floor's manager is
 * one of two candidates (the hustler sells more, the ghost draws less Heat); and the phone rings every minute or two
 * with an offer that has to be answered within 25 seconds, some of them a gamble. Laced goods keep heating up while the
 * player is away, so leaving with a hot building can end in a raid.
 *
 * Deterministic: all randomness comes from the state's own SplitMix64 stream.
 */

// MARK: - Content

public enum FloorId: String, CaseIterable, Codable, Sendable, CodingKeyRepresentable {
    case weed = "WEED", pills = "PILLS", crystal = "CRYSTAL", coke = "COKE"
}

public struct FloorDef: Sendable, Equatable {
    public let id: FloorId
    /// Price of the first unit; each further unit costs `growth` times more.
    public let unitCost: Double
    public let growth: Double
    /// Seconds per sales cycle with fewer than 25 units.
    public let cycle: Double
    /// Cash per unit per cycle, before multipliers.
    public let revenue: Double
    /// One-time price to open the floor (0 for the first).
    public let unlockCost: Double
    public let managerCost: Double
    /// Crew id of the hustler candidate for manager.
    public let managerId: String
    /// Crew id of the ghost candidate for manager.
    public let ghostId: String
}

/// How the goods of a floor are sold: pure, cut, or laced. More cash per cycle, more Heat.
public enum Cut: Int, Codable, Sendable, CaseIterable {
    case pure = 0, cut = 1, laced = 2

    public var revenue: Double { [1.0, 1.6, 2.5][rawValue] }
    public var heat: Double { [1.0, 2.0, 4.0][rawValue] }
}

/// The two kinds of manager a floor can hire.
public enum ManagerTrait: String, Codable, Sendable, CaseIterable {
    /// Sells half as much again.
    case hustler = "HUSTLER"
    /// Draws half the Heat.
    case ghost = "GHOST"
}

/// What answering a call does. Amounts in seconds are seconds of the building's full income at that moment.
public indirect enum CallEffect: Sendable, Equatable {
    case cash(seconds: Double)
    case pay(seconds: Double)
    case heat(Double)
    /// The floor (nil: every floor) sells double for `seconds`.
    case rush(FloorId?, seconds: Double)
    case favors(Int)
    case gamble(chance: Double, win: [CallEffect], lose: [CallEffect])
}

public struct CallDef: Sendable, Equatable, Identifiable {
    public let id: String
    /// Crew id of the caller, for the portrait.
    public let caller: String
    /// The call only comes once this floor is open.
    public let needs: FloorId
    /// One entry per answer; an empty list means hanging up.
    public let options: [[CallEffect]]
}

public struct DealDef: Sendable, Equatable, Identifiable {
    public let id: String
    /// The floor whose payout is multiplied; nil multiplies every floor.
    public let floor: FloorId?
    public let multiplier: Double
    public let cost: Double
}

public enum MissionKind: Sendable, Equatable {
    case own(FloorId, Int)
    case manager(FloorId)
    case earn(Double)
    case taps(Int)
    case suitcases(Int)
    case bribes(Int)
    case deals(Int)
    case prestige(Int)
    case calls(Int)
    /// Sell any floor's goods cut or laced.
    case cut
}

public struct MissionDef: Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: MissionKind
    /// Favors paid when the mission is claimed.
    public let reward: Int
}

public enum TycoonContent {
    public static let floors: [FloorDef] = [
        FloorDef(id: .weed, unitCost: 4, growth: 1.07, cycle: 1, revenue: 1, unlockCost: 0, managerCost: 1_000, managerId: "brandt", ghostId: "okafor"),
        FloorDef(id: .pills, unitCost: 60, growth: 1.15, cycle: 3, revenue: 60, unlockCost: 400, managerCost: 15_000, managerId: "varga", ghostId: "morgen"),
        FloorDef(id: .crystal, unitCost: 720, growth: 1.14, cycle: 6, revenue: 540, unlockCost: 6_000, managerCost: 100_000, managerId: "feld", ghostId: "kessler"),
        FloorDef(id: .coke, unitCost: 8_640, growth: 1.13, cycle: 12, revenue: 4_320, unlockCost: 90_000, managerCost: 500_000, managerId: "wolff", ghostId: "hollis"),
    ]

    public static func floor(_ id: FloorId) -> FloorDef { floors.first { $0.id == id }! }

    /// Unit counts at which a floor's cycle halves.
    public static let milestones = [25, 50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800, 900, 1_000]

    public static let deals: [DealDef] = [
        DealDef(id: "weed_1", floor: .weed, multiplier: 3, cost: 25_000),
        DealDef(id: "pills_1", floor: .pills, multiplier: 3, cost: 250_000),
        DealDef(id: "crystal_1", floor: .crystal, multiplier: 3, cost: 2_500_000),
        DealDef(id: "coke_1", floor: .coke, multiplier: 3, cost: 25_000_000),
        DealDef(id: "all_1", floor: nil, multiplier: 3, cost: 100_000_000),
        DealDef(id: "weed_2", floor: .weed, multiplier: 3, cost: 1e9),
        DealDef(id: "pills_2", floor: .pills, multiplier: 3, cost: 5e9),
        DealDef(id: "crystal_2", floor: .crystal, multiplier: 3, cost: 2.5e10),
        DealDef(id: "coke_2", floor: .coke, multiplier: 3, cost: 1e11),
        DealDef(id: "all_2", floor: nil, multiplier: 3, cost: 5e11),
        DealDef(id: "weed_3", floor: .weed, multiplier: 5, cost: 2e12),
        DealDef(id: "pills_3", floor: .pills, multiplier: 5, cost: 1e13),
        DealDef(id: "crystal_3", floor: .crystal, multiplier: 5, cost: 5e13),
        DealDef(id: "coke_3", floor: .coke, multiplier: 5, cost: 2.5e14),
        DealDef(id: "all_3", floor: nil, multiplier: 5, cost: 1e15),
    ]

    public static func deal(_ id: String) -> DealDef? { deals.first { $0.id == id } }

    public static let missions: [MissionDef] = [
        MissionDef(id: "own_weed_10", kind: .own(.weed, 10), reward: 5),
        MissionDef(id: "taps_50", kind: .taps(50), reward: 5),
        MissionDef(id: "call_1", kind: .calls(1), reward: 5),
        MissionDef(id: "cut_1", kind: .cut, reward: 5),
        MissionDef(id: "own_weed_25", kind: .own(.weed, 25), reward: 5),
        MissionDef(id: "open_pills", kind: .own(.pills, 1), reward: 5),
        MissionDef(id: "mgr_weed", kind: .manager(.weed), reward: 10),
        MissionDef(id: "own_pills_25", kind: .own(.pills, 25), reward: 10),
        MissionDef(id: "earn_1e5", kind: .earn(1e5), reward: 10),
        MissionDef(id: "open_crystal", kind: .own(.crystal, 1), reward: 10),
        MissionDef(id: "suitcase_1", kind: .suitcases(1), reward: 10),
        MissionDef(id: "mgr_pills", kind: .manager(.pills), reward: 10),
        MissionDef(id: "bribe_1", kind: .bribes(1), reward: 10),
        MissionDef(id: "call_5", kind: .calls(5), reward: 10),
        MissionDef(id: "deal_1", kind: .deals(1), reward: 10),
        MissionDef(id: "own_weed_100", kind: .own(.weed, 100), reward: 15),
        MissionDef(id: "open_coke", kind: .own(.coke, 1), reward: 15),
        MissionDef(id: "earn_1e6", kind: .earn(1e6), reward: 15),
        MissionDef(id: "mgr_crystal", kind: .manager(.crystal), reward: 15),
        MissionDef(id: "own_crystal_25", kind: .own(.crystal, 25), reward: 15),
        MissionDef(id: "taps_500", kind: .taps(500), reward: 15),
        MissionDef(id: "mgr_coke", kind: .manager(.coke), reward: 20),
        MissionDef(id: "earn_1e7", kind: .earn(1e7), reward: 20),
        MissionDef(id: "own_coke_25", kind: .own(.coke, 25), reward: 20),
        MissionDef(id: "suitcase_10", kind: .suitcases(10), reward: 20),
        MissionDef(id: "call_20", kind: .calls(20), reward: 20),
        MissionDef(id: "deal_3", kind: .deals(3), reward: 20),
        MissionDef(id: "earn_1e8", kind: .earn(1e8), reward: 25),
        MissionDef(id: "prestige_1", kind: .prestige(1), reward: 50),
        MissionDef(id: "own_weed_200", kind: .own(.weed, 200), reward: 25),
        MissionDef(id: "bribe_10", kind: .bribes(10), reward: 25),
        MissionDef(id: "earn_1e9", kind: .earn(1e9), reward: 30),
        MissionDef(id: "deal_5", kind: .deals(5), reward: 30),
        MissionDef(id: "own_coke_100", kind: .own(.coke, 100), reward: 40),
        MissionDef(id: "prestige_3", kind: .prestige(3), reward: 60),
        MissionDef(id: "earn_1e11", kind: .earn(1e11), reward: 60),
        MissionDef(id: "deal_10", kind: .deals(10), reward: 80),
        MissionDef(id: "prestige_10", kind: .prestige(10), reward: 100),
        MissionDef(id: "earn_1e13", kind: .earn(1e13), reward: 100),
    ]

    public static func mission(_ id: String) -> MissionDef? { missions.first { $0.id == id } }

    /// Heat per second for a building whose floors weigh 2 together (two pure floors): about five minutes from calm to
    /// the police. One pure floor takes ten, four pure floors two and a half. See `Tycoon.heatRate`.
    public static let heatPerSecond = 100.0 / 300
    /// A hustler sells this much more; a ghost draws this share of the Heat.
    public static let hustlerRevenue = 1.5
    public static let ghostHeat = 0.5
    /// A rush doubles sales.
    public static let rushMultiplier = 2.0
    /// Calls: the first after this many seconds, then one every `callGap`; each rings this long.
    public static let firstCall = 40.0
    public static let callGap: ClosedRange<Double> = 70...120
    public static let callSeconds = 25.0

    /// The phone. Black humour, real choices: every call has a safe answer and at least one that pays more for a risk.
    public static let calls: [CallDef] = [
        CallDef(id: "stag", caller: "okafor", needs: .weed, options: [
            [.cash(seconds: 60), .heat(10)],
            [.gamble(chance: 0.6, win: [.cash(seconds: 160)], lose: [.heat(35)])],
            [],
        ]),
        CallDef(id: "student", caller: "sand", needs: .weed, options: [
            [.gamble(chance: 0.5, win: [.cash(seconds: 120)], lose: [])],
            [.cash(seconds: 25)],
        ]),
        CallDef(id: "grandma", caller: "brandt", needs: .weed, options: [
            [.favors(3)],
            [.cash(seconds: 20)],
        ]),
        CallDef(id: "dog", caller: "varga", needs: .weed, options: [
            [.pay(seconds: 5), .heat(-20)],
            [.heat(25)],
        ]),
        CallDef(id: "copper", caller: "kraus", needs: .weed, options: [
            [.pay(seconds: 30), .heat(-50)],
            [.gamble(chance: 0.5, win: [.heat(-50)], lose: [.heat(30)])],
            [],
        ]),
        CallDef(id: "books", caller: "morgen", needs: .weed, options: [
            [.pay(seconds: 15), .favors(5)],
            [.cash(seconds: 30), .heat(15)],
        ]),
        CallDef(id: "rain", caller: "morgen", needs: .weed, options: [
            [.pay(seconds: 10), .rush(nil, seconds: 120)],
            [.heat(-25)],
        ]),
        CallDef(id: "snitch", caller: "reiter", needs: .weed, options: [
            [.pay(seconds: 25), .heat(-30)],
            [.gamble(chance: 0.6, win: [.heat(-40)], lose: [.heat(40)])],
            [.heat(20)],
        ]),
        CallDef(id: "rival", caller: "sand", needs: .pills, options: [
            [.rush(nil, seconds: 90), .heat(15)],
            [.gamble(chance: 0.7, win: [.rush(nil, seconds: 180)], lose: [.heat(50)])],
            [],
        ]),
        CallDef(id: "influencer", caller: "lind", needs: .pills, options: [
            [.pay(seconds: 10), .rush(.pills, seconds: 240)],
            [],
        ]),
        CallDef(id: "festival", caller: "hollis", needs: .pills, options: [
            [.cash(seconds: 90), .heat(30)],
            [.gamble(chance: 0.75, win: [.cash(seconds: 70)], lose: [.heat(20)])],
            [],
        ]),
        CallDef(id: "chemist", caller: "kessler", needs: .crystal, options: [
            [.gamble(chance: 0.5, win: [.rush(.crystal, seconds: 300)], lose: [.heat(40)])],
            [],
        ]),
        CallDef(id: "podcast", caller: "lind", needs: .crystal, options: [
            [.gamble(chance: 0.5, win: [.favors(10)], lose: [.heat(50)])],
            [],
        ]),
        CallDef(id: "diplomat", caller: "kraus", needs: .coke, options: [
            [.cash(seconds: 180), .heat(20)],
            [],
        ]),
        CallDef(id: "bulk", caller: "wolff", needs: .coke, options: [
            [.pay(seconds: 60), .rush(.coke, seconds: 300)],
            [],
        ]),
        CallDef(id: "villa", caller: "okafor", needs: .coke, options: [
            [.cash(seconds: 120), .heat(25)],
            [.gamble(chance: 0.5, win: [.cash(seconds: 320)], lose: [.heat(60)])],
            [],
        ]),
    ]

    public static func call(_ id: String) -> CallDef? { calls.first { $0.id == id } }
    public static let policeSeconds = 30.0
    public static let raidShare = 0.25
    /// A bribe costs this many seconds of income.
    public static let bribeSeconds = 20.0
    /// A suitcase holds this many seconds of income and lies on the street this long.
    public static let suitcaseSeconds = 45.0
    public static let suitcaseLifetime = 12.0
    public static let suitcaseGap: ClosedRange<Double> = 90...180
    /// Each point of reputation adds this to every payout.
    public static let reputationBonus = 0.10
    /// Reputation for a run = floor(sqrt(cash earned this run / this)).
    public static let reputationScale = 1e6
    public static let offlineCapSeconds = 8.0 * 3600
}

// MARK: - State

public struct FloorState: Codable, Sendable, Equatable {
    public var count = 0
    public var manager = false
    /// Fraction of the current cycle, 0..<1.
    public var progress = 0.0
    public var running = false
    public var cut = Cut.pure
    /// The kind of manager hired; nil for a manager hired before 3.1 (no bonus).
    public var trait: ManagerTrait?

    public init() {}
}

extension FloorState {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        count = c.value(.count, 0)
        manager = c.value(.manager, false)
        progress = c.value(.progress, 0.0)
        running = c.value(.running, false)
        cut = c.value(.cut, Cut.pure)
        trait = c.value(.trait, nil)
    }
}

public struct Police: Codable, Sendable, Equatable {
    public var arrivedAt: Double
    public var deadline: Double

    public init(arrivedAt: Double, deadline: Double) {
        self.arrivedAt = arrivedAt
        self.deadline = deadline
    }
}

public struct Suitcase: Codable, Sendable, Equatable {
    public var amount: Double
    public var expiresAt: Double
    /// Horizontal position on the street, 0...1.
    public var position: Double

    public init(amount: Double, expiresAt: Double, position: Double) {
        self.amount = amount
        self.expiresAt = expiresAt
        self.position = position
    }
}

/// A call waiting to be answered.
public struct ActiveCall: Codable, Sendable, Equatable {
    public var id: String
    public var expiresAt: Double

    public init(id: String, expiresAt: Double) {
        self.id = id
        self.expiresAt = expiresAt
    }
}

public struct TycoonCounters: Codable, Sendable, Equatable {
    public var calls = 0
    public var suitcases = 0
    public var bribes = 0
    public var raids = 0
    public var cyclesTapped = 0

    public init() {}
}

extension TycoonCounters {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        calls = c.value(.calls, 0)
        suitcases = c.value(.suitcases, 0)
        bribes = c.value(.bribes, 0)
        raids = c.value(.raids, 0)
        cyclesTapped = c.value(.cyclesTapped, 0)
    }
}

public let tycoonSchemaVersion = 1

public struct TycoonState: Codable, Sendable, Equatable {
    public var version = tycoonSchemaVersion
    public var rng = UInt64Box(1)
    /// Game seconds, never derived from the wall clock.
    public var time = 0.0
    /// Wall clock of the last tick (ms since 1970); used only to credit time away.
    public var lastWallClockMs: Int64 = 0
    public var cash = 0.0
    /// Cash earned in this city (resets when changing city).
    public var runEarned = 0.0
    /// Cash earned in all cities.
    public var totalEarned = 0.0
    public var floors: [FloorId: FloorState] = [:]
    public var deals: [String] = []
    public var heat = 0.0
    public var police: Police?
    public var suitcase: Suitcase?
    public var nextSuitcaseAt = 60.0
    public var call: ActiveCall?
    public var nextCallAt = TycoonContent.firstCall
    /// The last call that rang, so the same one does not ring twice in a row.
    public var lastCallId: String?
    /// Seconds of double sales left per floor.
    public var rush: [FloorId: Double] = [:]
    public var claimedMissions: [String] = []
    public var counters = TycoonCounters()
    /// The four first-steps hints have all been followed once.
    public var hintsDone = false
    /// Cash lost in the last raid, shown once; nil when seen.
    public var lastRaidLoss: Double?
    /// Rolling cash per second, for display.
    public var incomeRate = 0.0
    /// Favors, reputation, purchases, boosts and the daily envelope (shared with the 2.x save).
    public var meta = MetaState()

    public init() {}

    public func floor(_ id: FloorId) -> FloorState { floors[id] ?? FloorState() }

    public mutating func updateFloor(_ id: FloorId, _ body: (inout FloorState) -> Void) {
        var f = floor(id)
        body(&f)
        floors[id] = f
    }
}

extension TycoonState {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        version = c.value(.version, tycoonSchemaVersion)
        rng = c.value(.rng, UInt64Box(1))
        time = c.value(.time, 0.0)
        lastWallClockMs = c.value(.lastWallClockMs, Int64(0))
        cash = c.value(.cash, 0.0)
        runEarned = c.value(.runEarned, 0.0)
        totalEarned = c.value(.totalEarned, 0.0)
        floors = c.value(.floors, [FloorId: FloorState]())
        deals = c.value(.deals, [String]())
        heat = c.value(.heat, 0.0)
        police = c.value(.police, nil)
        suitcase = c.value(.suitcase, nil)
        nextSuitcaseAt = c.value(.nextSuitcaseAt, 60.0)
        call = c.value(.call, nil)
        nextCallAt = c.value(.nextCallAt, TycoonContent.firstCall)
        lastCallId = c.value(.lastCallId, nil)
        rush = c.value(.rush, [FloorId: Double]())
        claimedMissions = c.value(.claimedMissions, [String]())
        counters = c.value(.counters, TycoonCounters())
        hintsDone = c.value(.hintsDone, false)
        lastRaidLoss = c.value(.lastRaidLoss, nil)
        incomeRate = c.value(.incomeRate, 0.0)
        meta = c.value(.meta, MetaState())
    }
}

// MARK: - Rules

public enum TycoonHint: Int, Sendable, CaseIterable {
    case tapWeed, buyWeed, openPills, hireManager
}

public struct TycoonOffline: Sendable, Equatable {
    public var awaySeconds: Double
    public var creditedSeconds: Double
    public var capped: Bool
    public var earned: Double
    public var clockMovedBack: Bool
    /// Cash the police took while the player was away (laced goods kept heating up).
    public var raidLoss = 0.0
}

public enum Tycoon {

    // MARK: Start

    /// A fresh city: one weed plant, empty pockets. `meta` carries what outlives a city.
    public static func newCity(seed: UInt64, nowMs: Int64, meta: MetaState = MetaState()) -> TycoonState {
        var s = TycoonState()
        s.rng = UInt64Box(seed == 0 ? 1 : seed)
        s.lastWallClockMs = nowMs
        s.meta = meta
        s.meta.offlineBonus = 0
        for f in FloorId.allCases { s.floors[f] = FloorState() }
        s.updateFloor(.weed) { $0.count = 1 }
        s.nextSuitcaseAt = 60
        return s
    }

    // MARK: Randomness

    static func nextRandom(_ s: inout TycoonState) -> Double {
        s.rng.raw &+= 0x9E37_79B9_7F4A_7C15
        var z = s.rng.raw
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / 9_007_199_254_740_992.0
    }

    // MARK: Numbers

    public static func milestonesReached(_ count: Int) -> Int { TycoonContent.milestones.filter { $0 <= count }.count }
    public static func nextMilestone(_ count: Int) -> Int? { TycoonContent.milestones.first { $0 > count } }

    public static func cycleTime(_ s: TycoonState, _ f: FloorId) -> Double {
        TycoonContent.floor(f).cycle / pow(2, Double(milestonesReached(s.floor(f).count)))
    }

    public static func reputationMultiplier(_ s: TycoonState) -> Double {
        1 + TycoonContent.reputationBonus * Double(s.meta.reputation)
    }

    public static func globalMultiplier(_ s: TycoonState) -> Double {
        reputationMultiplier(s) * (s.meta.premium ? Idle.premiumMultiplier : 1) * (s.meta.boostSeconds > 0 ? Idle.boostMultiplier : 1)
    }

    public static func dealMultiplier(_ s: TycoonState, _ f: FloorId) -> Double {
        s.deals.compactMap(TycoonContent.deal).filter { $0.floor == nil || $0.floor == f }.reduce(1) { $0 * $1.multiplier }
    }

    /// What the floor's cut and manager do to its payout.
    public static func choiceMultiplier(_ s: TycoonState, _ f: FloorId) -> Double {
        let fl = s.floor(f)
        return fl.cut.revenue * (fl.manager && fl.trait == .hustler ? TycoonContent.hustlerRevenue : 1)
    }

    public static func rushMultiplier(_ s: TycoonState, _ f: FloorId) -> Double {
        (s.rush[f] ?? 0) > 0 ? TycoonContent.rushMultiplier : 1
    }

    /// Cash one cycle of the floor pays.
    public static func revenuePerCycle(_ s: TycoonState, _ f: FloorId) -> Double {
        TycoonContent.floor(f).revenue * Double(s.floor(f).count) * dealMultiplier(s, f) * choiceMultiplier(s, f)
            * rushMultiplier(s, f) * globalMultiplier(s)
    }

    /// How much Heat a floor draws: its cut, halved by a ghost.
    public static func heatWeight(_ s: TycoonState, _ f: FloorId) -> Double {
        let fl = s.floor(f)
        guard fl.count > 0 else { return 0 }
        return fl.cut.heat * (fl.manager && fl.trait == .ghost ? TycoonContent.ghostHeat : 1)
    }

    /// Heat per second while playing, from the floors that are selling right now.
    public static func heatRate(_ s: TycoonState) -> Double {
        let weight = FloorId.allCases.filter { s.floor($0).count > 0 && (s.floor($0).running || s.floor($0).manager) }
            .reduce(0) { $0 + heatWeight(s, $1) }
        return TycoonContent.heatPerSecond * 0.5 * weight
    }

    /// Heat per second while away: only what managed floors draw above a pure, plain floor.
    public static func offlineHeatRate(_ s: TycoonState) -> Double {
        let excess = FloorId.allCases.filter { s.floor($0).manager }.reduce(0) { $0 + max(0, heatWeight(s, $1) - 1) }
        return TycoonContent.heatPerSecond * 0.25 * excess
    }

    /// The cash one second of income is worth for calls (never less than a few dollars).
    public static func callUnit(_ s: TycoonState) -> Double {
        var plain = s
        plain.rush = [:]
        return max(5, fullRate(plain))
    }

    /// Cash per second the floor makes while it runs without pause.
    public static func floorRate(_ s: TycoonState, _ f: FloorId) -> Double {
        guard s.floor(f).count > 0 else { return 0 }
        return revenuePerCycle(s, f) / cycleTime(s, f)
    }

    /// Cash per second of the whole building if every open floor ran without pause.
    public static func fullRate(_ s: TycoonState) -> Double { FloorId.allCases.reduce(0) { $0 + floorRate(s, $1) } }

    /// Cash per second that keeps coming in without the player: floors with a manager.
    public static func managedRate(_ s: TycoonState) -> Double {
        FloorId.allCases.filter { s.floor($0).manager }.reduce(0) { $0 + floorRate(s, $1) }
    }

    /// Price of the next `amount` units of a floor.
    public static func unitsCost(_ s: TycoonState, _ f: FloorId, _ amount: Int) -> Double {
        let def = TycoonContent.floor(f)
        let n = Double(s.floor(f).count)
        let k = Double(max(1, amount))
        return def.unitCost * pow(def.growth, n) * (pow(def.growth, k) - 1) / (def.growth - 1)
    }

    /// How many units the cash buys right now (0 when not even one).
    public static func affordableUnits(_ s: TycoonState, _ f: FloorId) -> Int {
        let def = TycoonContent.floor(f)
        let first = def.unitCost * pow(def.growth, Double(s.floor(f).count))
        guard s.cash >= first, first > 0 else { return 0 }
        let k = floor(log(s.cash * (def.growth - 1) / first + 1) / log(def.growth))
        guard k.isFinite else { return 0 }
        var units = max(1, Int(min(k, 100_000)))
        // Guard against rounding at the boundary.
        while units > 1 && unitsCost(s, f, units) > s.cash + 1e-9 { units -= 1 }
        return units
    }

    public static func isOpen(_ s: TycoonState, _ f: FloorId) -> Bool { s.floor(f).count > 0 }

    /// A floor can be opened once the floor below it is open.
    public static func canOpen(_ s: TycoonState, _ f: FloorId) -> Bool {
        guard let i = FloorId.allCases.firstIndex(of: f), i > 0 else { return true }
        return isOpen(s, FloorId.allCases[i - 1])
    }

    public static func bribeCost(_ s: TycoonState) -> Double { max(10, fullRate(s) * TycoonContent.bribeSeconds) }

    public static func reputationGain(_ s: TycoonState) -> Int {
        let g = (max(0, s.runEarned) / TycoonContent.reputationScale).squareRoot()
        return g.isFinite ? Int(min(g, 1e9)) : 0
    }

    /// The first-steps hint to show, if any.
    public static func hint(_ s: TycoonState) -> TycoonHint? {
        if s.hintsDone { return nil }
        if s.counters.cyclesTapped == 0 { return .tapWeed }
        if s.floor(.weed).count < 5 { return .buyWeed }
        if !isOpen(s, .pills) { return .openPills }
        if !FloorId.allCases.contains(where: { s.floor($0).manager }) { return .hireManager }
        return nil
    }

    // MARK: Missions

    public static func missionProgress(_ s: TycoonState, _ m: MissionDef) -> (current: Double, target: Double) {
        switch m.kind {
        case .own(let f, let n): return (Double(s.floor(f).count), Double(n))
        case .manager(let f): return (s.floor(f).manager ? 1 : 0, 1)
        case .earn(let amount): return (s.totalEarned, amount)
        case .taps(let n): return (Double(s.meta.taps), Double(n))
        case .suitcases(let n): return (Double(s.counters.suitcases), Double(n))
        case .bribes(let n): return (Double(s.counters.bribes), Double(n))
        case .deals(let n): return (Double(s.deals.count), Double(n))
        case .prestige(let n): return (Double(s.meta.prestiges), Double(n))
        case .calls(let n): return (Double(s.counters.calls), Double(n))
        case .cut: return (FloorId.allCases.contains { s.floor($0).cut != .pure } ? 1 : 0, 1)
        }
    }

    public static func missionDone(_ s: TycoonState, _ m: MissionDef) -> Bool {
        let p = missionProgress(s, m)
        return p.current >= p.target - 1e-9
    }

    /// The three missions on the board: the first unclaimed ones in order.
    public static func activeMissions(_ s: TycoonState) -> [MissionDef] {
        Array(TycoonContent.missions.filter { !s.claimedMissions.contains($0.id) }.prefix(3))
    }

    public static func claimableMissions(_ s: TycoonState) -> Int { activeMissions(s).filter { missionDone(s, $0) }.count }

    // MARK: Simulation

    /// Advances the city by `seconds`. Online the police and suitcases come and go; while away (`offline`) only floors
    /// with a manager work, Heat stands still and an arrived police car waits.
    public static func advance(_ s: inout TycoonState, seconds: Double, offline: Bool, step: Double = 0.25) {
        var remaining = max(0, seconds)
        while remaining > 1e-9 {
            let dt = min(step, remaining)
            self.step(&s, dt: dt, offline: offline)
            remaining -= dt
        }
    }

    static func step(_ s: inout TycoonState, dt: Double, offline: Bool) {
        s.time += dt
        if s.meta.boostSeconds > 0 { s.meta.boostSeconds = max(0, s.meta.boostSeconds - dt) }
        if s.meta.heatAidCooldown > 0 { s.meta.heatAidCooldown = max(0, s.meta.heatAidCooldown - dt) }
        if !offline && !s.rush.isEmpty {
            for (f, left) in s.rush { s.rush[f] = left - dt > 0 ? left - dt : nil }
        }
        var earned = 0.0
        var anyRunning = false
        for f in FloorId.allCases {
            var fl = s.floor(f)
            guard fl.count > 0 else { continue }
            if fl.manager { fl.running = true }
            if offline && !fl.manager {
                s.floors[f] = fl
                continue
            }
            if fl.running {
                anyRunning = true
                fl.progress += dt / cycleTime(s, f)
                if fl.progress >= 1 {
                    let cycles = fl.manager ? floor(fl.progress) : 1
                    earned += cycles * revenuePerCycle(s, f)
                    if fl.manager {
                        fl.progress -= cycles
                    } else {
                        fl.progress = 0
                        fl.running = false
                    }
                }
            }
            s.floors[f] = fl
        }
        if earned > 0 { credit(&s, earned) }
        s.incomeRate += (earned / dt - s.incomeRate) * min(1, dt / 20)

        if offline {
            if s.police != nil { s.police?.deadline += dt }
            return
        }
        // Heat and the police.
        if let p = s.police {
            if s.time >= p.deadline { raid(&s) }
        } else if anyRunning {
            s.heat = min(100, s.heat + heatRate(s) * dt)
            if s.heat >= 100 { policeArrive(&s) }
        }
        // The phone.
        if let c = s.call, s.time >= c.expiresAt { s.call = nil }
        if s.call == nil && s.time >= s.nextCallAt && anyRunning {
            let eligible = TycoonContent.calls.filter { isOpen(s, $0.needs) && $0.id != s.lastCallId }
            if !eligible.isEmpty {
                let pick = eligible[min(eligible.count - 1, Int(nextRandom(&s) * Double(eligible.count)))]
                s.call = ActiveCall(id: pick.id, expiresAt: s.time + TycoonContent.callSeconds)
                s.lastCallId = pick.id
            }
            let gap = TycoonContent.callGap
            s.nextCallAt = s.time + TycoonContent.callSeconds + gap.lowerBound + (gap.upperBound - gap.lowerBound) * nextRandom(&s)
        }
        // A suitcase on the street.
        if let c = s.suitcase, s.time >= c.expiresAt { s.suitcase = nil }
        if s.suitcase == nil && s.time >= s.nextSuitcaseAt && anyRunning {
            let amount = max(25, fullRate(s) * TycoonContent.suitcaseSeconds)
            s.suitcase = Suitcase(amount: amount, expiresAt: s.time + TycoonContent.suitcaseLifetime, position: 0.15 + 0.6 * nextRandom(&s))
            let gap = TycoonContent.suitcaseGap
            s.nextSuitcaseAt = s.time + gap.lowerBound + (gap.upperBound - gap.lowerBound) * nextRandom(&s)
        }
        if !s.hintsDone && hint(s) == nil { s.hintsDone = true }
    }

    static func credit(_ s: inout TycoonState, _ amount: Double) {
        guard amount.isFinite, amount > 0 else { return }
        s.cash += amount
        s.runEarned += amount
        s.totalEarned += amount
        s.meta.lifetimeDirty += amount
    }

    static func policeArrive(_ s: inout TycoonState) {
        s.heat = 100
        if s.police == nil { s.police = Police(arrivedAt: s.time, deadline: s.time + TycoonContent.policeSeconds) }
    }

    static func raid(_ s: inout TycoonState) {
        let loss = s.cash * TycoonContent.raidShare
        s.cash -= loss
        s.lastRaidLoss = loss
        s.police = nil
        s.heat = 0
        s.counters.raids += 1
    }

    /// Cash the managed floors make in `seconds`, with the running boost counted for as long as it lasts.
    static func managedEarnings(_ s: TycoonState, seconds: Double) -> Double {
        var plain = s
        plain.meta.boostSeconds = 0
        plain.rush = [:]
        let base = managedRate(plain)
        let boosted = min(max(0, s.meta.boostSeconds), seconds)
        return base * (seconds + boosted * (Idle.boostMultiplier - 1))
    }

    /// Credits time spent away: only floors with a manager earn, up to the offline cap.
    public static func applyOffline(_ state: TycoonState, nowMs: Int64) -> (TycoonState, TycoonOffline?) {
        var s = state
        let last = s.lastWallClockMs
        s.lastWallClockMs = nowMs
        if last <= 0 { return (s, nil) }
        let elapsed = Double(nowMs - last) / 1000
        if elapsed < 0 {
            return (s, TycoonOffline(awaySeconds: 0, creditedSeconds: 0, capped: false, earned: 0, clockMovedBack: true))
        }
        if elapsed < 5 { return (s, nil) }
        let cap = TycoonContent.offlineCapSeconds * (s.meta.premium ? 2 : 1)
        let credited = min(elapsed, cap)
        let heatUp = s.police == nil ? offlineHeatRate(s) * credited : 0
        let earned = passTime(&s, seconds: credited)
        var raidLoss = 0.0
        if heatUp > 0 {
            s.heat = min(100, s.heat + heatUp)
            if s.heat >= 100 {
                raid(&s)
                raidLoss = s.lastRaidLoss ?? 0
            }
        }
        if elapsed < 60 && raidLoss == 0 { return (s, nil) }
        s.meta.offlineBonus = earned
        return (s, TycoonOffline(awaySeconds: elapsed, creditedSeconds: credited, capped: elapsed > cap, earned: earned,
                                 clockMovedBack: false, raidLoss: raidLoss))
    }

    /// Lets `seconds` pass as time away: managed floors earn, timers run, nothing else happens. Returns the cash earned.
    @discardableResult
    static func passTime(_ s: inout TycoonState, seconds: Double) -> Double {
        let earned = managedEarnings(s, seconds: seconds)
        credit(&s, earned)
        s.time += seconds
        s.meta.boostSeconds = max(0, s.meta.boostSeconds - seconds)
        s.meta.heatAidCooldown = max(0, s.meta.heatAidCooldown - seconds)
        if s.police != nil { s.police?.deadline += seconds }
        s.nextSuitcaseAt = max(s.nextSuitcaseAt, s.time + 20)
        s.suitcase = nil
        // A ringing call keeps ringing through a short trip to another app; after a long absence it has hung up.
        if let c = s.call, s.time >= c.expiresAt { s.call = nil }
        s.nextCallAt = max(s.nextCallAt, s.time + 20)
        s.rush = [:]
        return earned
    }
}

// MARK: - Actions

public enum TycoonAction: Sendable, Equatable {
    /// A tap on a floor: runs one cycle (without a manager).
    case tapFloor(FloorId)
    /// Buys `amount` units; 0 buys as many as the cash allows.
    case buy(FloorId, Int)
    case open(FloorId)
    case hireManager(FloorId, ManagerTrait = .hustler)
    /// Sell a floor's goods pure, cut or laced.
    case setCut(FloorId, Cut)
    /// Answer the ringing call with option `index`.
    case answerCall(Int)
    /// Hang up without an answer.
    case declineCall
    case buyDeal(String)
    case bribe
    case grabSuitcase
    case claimMission(String)
    /// Change city: trade this run for reputation.
    case changeCity
    case ackRaid
    case claimDaily(day: Int)
    case buyFavorItem(FavorItem)
    case adReward(AdReward, day: Int)
    case grant(Grant)
    case collectOffline(doubled: Bool)
}

public struct TycoonResult: Sendable {
    public let state: TycoonState
    public let error: ActionError?
    /// Cash the action paid out (taps, suitcases, missions), for floaters.
    public let gained: Double
    /// For a call with a gamble: whether it paid off.
    public var won: Bool? = nil

    public var isOK: Bool { error == nil }
}

extension Tycoon {
    public static func apply(_ state: TycoonState, _ action: TycoonAction) -> TycoonResult {
        var s = state
        func fail(_ e: ActionError) -> TycoonResult { TycoonResult(state: state, error: e, gained: 0) }
        func done(_ gained: Double = 0) -> TycoonResult { TycoonResult(state: s, error: nil, gained: gained) }

        switch action {
        case .tapFloor(let f):
            let fl = s.floor(f)
            guard fl.count > 0 else { return fail(.locked) }
            s.meta.taps += 1
            if fl.manager || fl.running { return done() }
            s.updateFloor(f) { $0.running = true }
            s.counters.cyclesTapped += 1
            return done()

        case .buy(let f, let amount):
            guard isOpen(s, f) else { return fail(.locked) }
            let units = amount <= 0 ? affordableUnits(s, f) : amount
            guard units > 0 else { return fail(.notAffordable) }
            let cost = unitsCost(s, f, units)
            guard s.cash >= cost - 1e-9 else { return fail(.notAffordable) }
            s.cash -= cost
            s.updateFloor(f) { $0.count += units }
            return done()

        case .open(let f):
            guard !isOpen(s, f) else { return fail(.invalid) }
            guard canOpen(s, f) else { return fail(.locked) }
            let cost = TycoonContent.floor(f).unlockCost
            guard s.cash >= cost - 1e-9 else { return fail(.notAffordable) }
            s.cash -= cost
            s.updateFloor(f) { $0.count = 1 }
            return done()

        case .hireManager(let f, let trait):
            guard isOpen(s, f) else { return fail(.locked) }
            guard !s.floor(f).manager else { return fail(.invalid) }
            let cost = TycoonContent.floor(f).managerCost
            guard s.cash >= cost - 1e-9 else { return fail(.notAffordable) }
            s.cash -= cost
            s.updateFloor(f) { $0.manager = true; $0.running = true; $0.trait = trait }
            return done()

        case .setCut(let f, let cut):
            guard isOpen(s, f) else { return fail(.locked) }
            guard s.floor(f).cut != cut else { return fail(.invalid) }
            s.updateFloor(f) { $0.cut = cut }
            return done()

        case .answerCall(let index):
            guard let c = s.call, s.time < c.expiresAt, let def = TycoonContent.call(c.id) else { return fail(.invalid) }
            guard def.options.indices.contains(index) else { return fail(.invalid) }
            let effects = def.options[index]
            let price = cashCost(effects, unit: callUnit(s))
            guard s.cash >= price - 1e-9 else { return fail(.notAffordable) }
            s.call = nil
            s.counters.calls += 1
            var won: Bool?
            let unit = callUnit(s)
            let gained = apply(effects, to: &s, unit: unit, won: &won)
            return TycoonResult(state: s, error: nil, gained: gained, won: won)

        case .declineCall:
            guard s.call != nil else { return fail(.invalid) }
            s.call = nil
            return done()

        case .buyDeal(let id):
            guard let d = TycoonContent.deal(id) else { return fail(.invalid) }
            guard !s.deals.contains(id) else { return fail(.invalid) }
            if let f = d.floor, !isOpen(s, f) { return fail(.locked) }
            guard s.cash >= d.cost - 1e-9 else { return fail(.notAffordable) }
            s.cash -= d.cost
            s.deals.append(id)
            return done()

        case .bribe:
            guard s.police != nil || s.heat > 0.5 else { return fail(.invalid) }
            let cost = bribeCost(s)
            guard s.cash >= cost - 1e-9 else { return fail(.notAffordable) }
            s.cash -= cost
            s.police = nil
            s.heat = 0
            s.counters.bribes += 1
            return done()

        case .grabSuitcase:
            guard let c = s.suitcase, s.time < c.expiresAt else { return fail(.invalid) }
            s.suitcase = nil
            credit(&s, c.amount)
            s.counters.suitcases += 1
            return done(c.amount)

        case .claimMission(let id):
            guard let m = TycoonContent.mission(id), activeMissions(s).contains(m) else { return fail(.invalid) }
            guard missionDone(s, m) else { return fail(.requirements) }
            s.claimedMissions.append(id)
            s.meta.favors += m.reward
            return done()

        case .changeCity:
            let gain = reputationGain(s)
            guard gain >= 1 else { return fail(.requirements) }
            var meta = s.meta
            meta.reputation += gain
            meta.prestiges += 1
            var fresh = newCity(seed: s.rng.raw &+ 0x5851_F42D_4C95_7F2D, nowMs: s.lastWallClockMs, meta: meta)
            fresh.time = s.time
            fresh.totalEarned = s.totalEarned
            fresh.claimedMissions = s.claimedMissions
            fresh.counters = s.counters
            fresh.hintsDone = true
            fresh.nextSuitcaseAt = s.time + 60
            fresh.nextCallAt = s.time + TycoonContent.firstCall
            s = fresh
            return done()

        case .ackRaid:
            s.lastRaidLoss = nil
            return done()

        case .claimDaily(let day):
            guard day > s.meta.dailyLastDay else { return fail(.cooldown) }
            let reward = Idle.dailyReward(claims: s.meta.dailyClaims)
            s.meta.dailyLastDay = day
            s.meta.dailyClaims += 1
            switch reward {
            case .favors(let n): s.meta.favors += n
            case .boost(let seconds): s.meta.boostSeconds = min(Idle.boostCapSeconds, s.meta.boostSeconds + seconds)
            case .warp(let seconds): passTime(&s, seconds: seconds)
            }
            return done()

        case .buyFavorItem(let item):
            guard s.meta.favors >= item.price else { return fail(.notAffordable) }
            switch item {
            case .boost4h:
                guard s.meta.boostSeconds < Idle.boostCapSeconds - 1 else { return fail(.maxLevel) }
                s.meta.boostSeconds = min(Idle.boostCapSeconds, s.meta.boostSeconds + 4 * 3600)
            case .warp2h, .warp8h, .warp24h:
                guard managedRate(s) > 0 else { return fail(.requirements) }
                passTime(&s, seconds: item.warpSeconds)
            case .coolHeat:
                guard s.police != nil || s.heat > 0.5 else { return fail(.invalid) }
                s.police = nil
                s.heat = 0
            case .loyalty:
                return fail(.invalid)
            }
            s.meta.favors -= item.price
            return done()

        case .adReward(let reward, let day):
            switch reward {
            case .boost:
                guard s.meta.boostSeconds < Idle.boostCapSeconds - 1 else { return fail(.maxLevel) }
                s.meta.boostSeconds = min(Idle.boostCapSeconds, s.meta.boostSeconds + Idle.adBoostSeconds)
            case .coolHeat:
                guard s.meta.heatAidCooldown <= 0 else { return fail(.cooldown) }
                guard s.police != nil || s.heat > 0.5 else { return fail(.invalid) }
                s.police = nil
                s.heat = 0
                s.meta.heatAidCooldown = Idle.adHeatCooldown
            case .favors:
                if s.meta.adFavorsDay != day {
                    s.meta.adFavorsDay = day
                    s.meta.adFavorsToday = 0
                }
                guard s.meta.adFavorsToday < Idle.adFavorsPerDay else { return fail(.cooldown) }
                s.meta.adFavorsToday += 1
                s.meta.favors += Idle.adFavors
            case .offlineDouble:
                guard s.meta.offlineBonus > 0 else { return fail(.invalid) }
                let bonus = s.meta.offlineBonus
                credit(&s, bonus)
                s.meta.offlineBonus = 0
                s.meta.adsWatched += 1
                return done(bonus)
            }
            s.meta.adsWatched += 1
            return done()

        case .grant(let grant):
            switch grant {
            case .favors(let n):
                guard n > 0 else { return fail(.invalid) }
                s.meta.favors += n
            case .premium:
                s.meta.premium = true
            case .noAds:
                s.meta.noAds = true
            case .starter:
                if !s.meta.starterBought {
                    s.meta.starterBought = true
                    s.meta.favors += Idle.starterFavors
                    s.meta.boostSeconds = min(Idle.boostCapSeconds, s.meta.boostSeconds + Idle.starterBoostSeconds)
                }
            }
            return done()

        case .collectOffline(let doubled):
            var gained = 0.0
            if doubled && s.meta.offlineBonus > 0 {
                gained = s.meta.offlineBonus
                credit(&s, gained)
            }
            s.meta.offlineBonus = 0
            return done(gained)
        }
    }
}

// MARK: - Calls

extension Tycoon {
    /// Cash an answer costs up front (only certain payments; a gamble never costs).
    public static func cashCost(_ effects: [CallEffect], unit: Double) -> Double {
        effects.reduce(0) { total, e in
            if case .pay(let seconds) = e { return total + seconds * unit }
            return total
        }
    }

    /// Applies the effects and returns the cash they paid out.
    static func apply(_ effects: [CallEffect], to s: inout TycoonState, unit: Double, won: inout Bool?) -> Double {
        var gained = 0.0
        for e in effects {
            switch e {
            case .cash(let seconds):
                let amount = seconds * unit
                credit(&s, amount)
                gained += amount
            case .pay(let seconds):
                s.cash = max(0, s.cash - seconds * unit)
            case .heat(let delta):
                s.heat = min(100, max(0, s.heat + delta))
                if s.heat >= 100 { policeArrive(&s) }
            case .rush(let floor, let seconds):
                for f in FloorId.allCases where isOpen(s, f) && (floor == nil || floor == f) {
                    s.rush[f] = (s.rush[f] ?? 0) + seconds
                }
            case .favors(let n):
                s.meta.favors += n
            case .gamble(let chance, let win, let lose):
                let ok = nextRandom(&s) < chance
                won = ok
                gained += apply(ok ? win : lose, to: &s, unit: unit, won: &won)
                won = ok
            }
        }
        return gained
    }
}

// MARK: - Save

/// Versioned, crash-safe save of a city: `{"schema": 1, "savedAt": ms, "state": {...}}`, written atomically with the
/// previous good file kept as a backup.
public struct TycoonSaveStore: Sendable {
    public enum Loaded: Sendable {
        case fresh
        case loaded(TycoonState, restoredFromBackup: Bool)
        case futureVersion(Int)
    }

    public let directory: URL
    public var primaryURL: URL { directory.appendingPathComponent("noir_tycoon.save") }
    public var backupURL: URL { directory.appendingPathComponent("noir_tycoon.save.bak") }
    var tempURL: URL { directory.appendingPathComponent("noir_tycoon.save.tmp") }

    public init(directory: URL) {
        self.directory = directory
    }

    private struct Envelope: Codable {
        let schema: Int
        let savedAt: Int64
        let state: TycoonState
    }

    private enum Read {
        case ok(TycoonState), future(Int), bad
    }

    private func read(_ url: URL) -> Read? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return .bad }
        if let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let schema = (raw["schema"] as? NSNumber)?.intValue, schema > tycoonSchemaVersion {
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

    public func write(_ state: TycoonState, savedAtMs: Int64) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        var s = state
        s.version = tycoonSchemaVersion
        let data = try encoder.encode(Envelope(schema: tycoonSchemaVersion, savedAt: savedAtMs, state: s))
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
    public static func sanitize(_ s: inout TycoonState) {
        s.cash = fix(s.cash)
        s.runEarned = fix(s.runEarned)
        s.totalEarned = fix(s.totalEarned)
        s.time = fix(s.time)
        s.heat = fix(s.heat, 0, 100)
        s.incomeRate = fix(s.incomeRate)
        for f in FloorId.allCases {
            var fl = s.floors[f] ?? FloorState()
            fl.count = min(1_000_000, max(0, fl.count))
            fl.progress = fix(fl.progress, 0, 0.999_999)
            if fl.count == 0 { fl.manager = false; fl.running = false }
            s.floors[f] = fl
        }
        if s.floor(.weed).count == 0 { s.updateFloor(.weed) { $0.count = 1 } }
        var seen = Set<String>()
        s.deals = s.deals.filter { TycoonContent.deal($0) != nil && seen.insert($0).inserted }
        var seenMissions = Set<String>()
        s.claimedMissions = s.claimedMissions.filter { TycoonContent.mission($0) != nil && seenMissions.insert($0).inserted }
        s.meta.favors = max(0, s.meta.favors)
        s.meta.reputation = max(0, s.meta.reputation)
        s.meta.boostSeconds = fix(s.meta.boostSeconds, 0, Idle.boostCapSeconds)
        s.meta.offlineBonus = fix(s.meta.offlineBonus)
        if let c = s.call, TycoonContent.call(c.id) == nil { s.call = nil }
        s.nextCallAt = fix(s.nextCallAt)
        s.rush = s.rush.filter { $0.value.isFinite && $0.value > 0 }.mapValues { min($0, 3_600) }
        if s.lastWallClockMs < 0 { s.lastWallClockMs = 0 }
    }
}
