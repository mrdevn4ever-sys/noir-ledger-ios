import Foundation

// MARK: - Workshop, contacts, quarters

public struct WorkshopState: Codable, Sendable, Equatable {
    public var bench = 1
    public var shelf = 1
    /// Crates on the shelf.
    public var stock = 0.0
    /// Progress of the running bench cycle, 0..<1; nil while the bench stands still.
    public var cycle: Double?
    public var lead = false
    /// Game seconds the shelf has been full (for the return summary); 0 when it has room.
    public var fullFor = 0.0

    public init() {}
}

extension WorkshopState {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        bench = c.value(.bench, 1)
        shelf = c.value(.shelf, 1)
        stock = c.value(.stock, 0.0)
        cycle = c.value(.cycle, nil)
        lead = c.value(.lead, false)
        fullFor = c.value(.fullFor, 0.0)
    }
}

public struct ContactState: Codable, Sendable, Equatable {
    public var level = 1
    /// Crates the contact would take right now (demand not yet served, capped).
    public var open = 0.0
    public var trust = 0

    public init() {}
}

extension ContactState {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        level = c.value(.level, 1)
        open = c.value(.open, 0.0)
        trust = c.value(.trust, 0)
    }
}

public struct QuarterState: Codable, Sendable, Equatable {
    public var attention = 0.0
    /// The player keeps deliveries out of the quarter so it calms down faster.
    public var paused = false

    public init() {}
}

extension QuarterState {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        attention = c.value(.attention, 0.0)
        paused = c.value(.paused, false)
    }
}

// MARK: - Orders

public struct OrderOffer: Codable, Sendable, Equatable, Identifiable {
    public var id: Int
    public var kind: OrderKind
    public var quarter: Quarter
    /// The luxury contact a trust order belongs to.
    public var contact: String?
    /// Crates of each good the order needs.
    public var items: [Good: Double]
    /// Cash paid when everything has arrived.
    public var pay: Double
    /// Attention the order adds to its quarter when accepted (negative calms it).
    public var attention: Double
    /// Seconds to deliver once accepted.
    public var window: Double
    /// Game time the offer leaves the board.
    public var expiresAt: Double

    public init(id: Int, kind: OrderKind, quarter: Quarter, contact: String? = nil, items: [Good: Double], pay: Double,
                attention: Double, window: Double, expiresAt: Double) {
        self.id = id
        self.kind = kind
        self.quarter = quarter
        self.contact = contact
        self.items = items
        self.pay = pay
        self.attention = attention
        self.window = window
        self.expiresAt = expiresAt
    }

    public var crates: Double { items.values.reduce(0, +) }
}

public struct ActiveOrder: Codable, Sendable, Equatable, Identifiable {
    public var offer: OrderOffer
    public var deadline: Double
    public var delivered: [Good: Double] = [:]
    /// Crates on their way in the current trip.
    public var inTransit: [Good: Double] = [:]

    public var id: Int { offer.id }

    public init(offer: OrderOffer, deadline: Double) {
        self.offer = offer
        self.deadline = deadline
    }

    public func remaining(_ g: Good) -> Double {
        max(0, (offer.items[g] ?? 0) - (delivered[g] ?? 0) - (inTransit[g] ?? 0))
    }

    public var done: Bool {
        offer.items.allSatisfy { (delivered[$0.key] ?? 0) >= $0.value - 1e-9 }
    }

    public var progress: Double {
        let total = offer.crates
        guard total > 0 else { return 1 }
        return min(1, offer.items.keys.reduce(0) { $0 + min(offer.items[$1] ?? 0, delivered[$1] ?? 0) } / total)
    }
}

/// What the fleet carries on the current trip.
public struct Trip: Codable, Sendable, Equatable {
    /// Seconds until it arrives.
    public var left: Double
    public var duration: Double
    /// Crates for standing contacts, per good.
    public var standing: [Good: Double]
    /// Crates for accepted orders, by order id.
    public var orders: [Int: [Good: Double]]

    public var crates: Double { standing.values.reduce(0, +) + orders.values.reduce(0) { $0 + $1.values.reduce(0, +) } }
}

// MARK: - Ledger

public enum LedgerKind: String, Codable, Sendable {
    case delivery = "DELIVERY"
    case order = "ORDER"
    case orderFailed = "ORDER_FAILED"
    case away = "AWAY"
}

public struct LedgerEntry: Codable, Sendable, Equatable, Identifiable {
    public var id: Int
    public var time: Double
    public var kind: LedgerKind
    /// Contact id for deliveries, order kind raw value for orders.
    public var subject: String
    public var good: Good?
    public var crates: Double
    public var amount: Double
}

// MARK: - Crew, challenges, counters

public struct AbilityState: Codable, Sendable, Equatable {
    /// Game seconds the effect still runs.
    public var active = 0.0
    /// Game seconds until it can be used again.
    public var cooldown = 0.0
    /// The workshop a double shift runs in.
    public var good: Good?

    public init() {}
}

public struct ChallengeState: Codable, Sendable, Equatable {
    public var id: ChallengeId
    public var endsAt: Double
    public var startEarned: Double
    public var startOrders: Int
    /// Highest attention any quarter reached during the challenge.
    public var peakAttention: Double
    /// Cash to earn during the challenge (set from the income when it starts).
    public var target: Double
    public var startDeliveries: Int
    public var goalsDone: [Bool] = [false, false, false]
}

public struct FlowCounters: Codable, Sendable, Equatable {
    public var deliveries = 0
    public var crates = 0.0
    public var orders = 0
    public var failed = 0
    public var loud = 0
    public var quiet = 0
    public var big = 0
    public var city = 0
    public var purchases = 0
    public var taps = 0
    /// Pills sold in the current club night and the best night so far.
    public var clubNow = 0.0
    public var clubBest = 0.0
    public var finale = false

    public init() {}
}

extension FlowCounters {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        deliveries = c.value(.deliveries, 0)
        crates = c.value(.crates, 0.0)
        orders = c.value(.orders, 0)
        failed = c.value(.failed, 0)
        loud = c.value(.loud, 0)
        quiet = c.value(.quiet, 0)
        big = c.value(.big, 0)
        city = c.value(.city, 0)
        purchases = c.value(.purchases, 0)
        taps = c.value(.taps, 0)
        clubNow = c.value(.clubNow, 0.0)
        clubBest = c.value(.clubBest, 0.0)
        finale = c.value(.finale, false)
    }
}

/// Summary of time away, kept in the state so showing it again never pays twice.
public struct FlowReturn: Codable, Sendable, Equatable {
    public var away: Double
    public var credited: Double
    public var capped: Bool
    public var earned: Double
    public var deliveries: Int
    public var ordersDone: Int
    public var ordersFailed: Int
    /// Goods whose shelf was full when the player came back.
    public var fullShelves: [Good]
    public var clockMovedBack: Bool
}

// MARK: - State

public let flowSchemaVersion = 1

public struct FlowState: Codable, Sendable, Equatable {
    public var version = flowSchemaVersion
    public var rng = UInt64Box(1)
    /// Game seconds, never derived from the wall clock.
    public var time = 0.0
    /// Wall clock of the last tick (ms since 1970); used only to credit time away.
    public var lastWallClockMs: Int64 = 0
    /// nil until the player picks what to take from Leopold's things.
    public var start: StartChoice?
    public var chapter = 1
    /// The story moment of the last closed chapter is still to be shown.
    public var chapterNews: Int?
    public var cash = 0.0
    public var earned = 0.0
    public var workshops: [Good: WorkshopState] = [:]
    public var fleet = 1
    public var dispatcher = false
    public var trip: Trip?
    /// The order the fleet serves goods in after their base share.
    public var priority: [Good] = Good.allCases
    /// Accepted orders go out before standing contacts.
    public var ordersFirst = true
    public var contacts: [String: ContactState] = [:]
    public var quarters: [Quarter: QuarterState] = [:]
    public var offers: [OrderOffer] = []
    public var orders: [ActiveOrder] = []
    /// Game time of the next offer; -1 until the order board opens.
    public var nextOfferAt = -1.0
    public var nextOrderId = 1
    /// Sami Okafor takes quiet orders on her own.
    public var autoQuiet = false
    public var specialists: [Specialist] = []
    public var abilities: [Ability: AbilityState] = [:]
    public var challenge: ChallengeState?
    public var challengesDone: [ChallengeId] = []
    public var ledger: [LedgerEntry] = []
    public var nextLedgerId = 1
    public var counters = FlowCounters()
    /// The summary of the last time away, until the player has seen it.
    public var welcome: FlowReturn?
    /// Favors, purchases, boosts and the daily envelope (shared with earlier versions).
    public var meta = MetaState()

    public init() {}

    public func workshop(_ g: Good) -> WorkshopState? { workshops[g] }
    public func isOpen(_ g: Good) -> Bool { workshops[g] != nil }
    public func quarter(_ q: Quarter) -> QuarterState { quarters[q] ?? QuarterState() }
    public func ability(_ a: Ability) -> AbilityState { abilities[a] ?? AbilityState() }
    public func has(_ s: Specialist) -> Bool { specialists.contains(s) }
    public var openGoods: [Good] { Good.allCases.filter { workshops[$0] != nil } }

    public mutating func updateWorkshop(_ g: Good, _ body: (inout WorkshopState) -> Void) {
        guard var w = workshops[g] else { return }
        body(&w)
        workshops[g] = w
    }

    public mutating func updateContact(_ id: String, _ body: (inout ContactState) -> Void) {
        guard var c = contacts[id] else { return }
        body(&c)
        contacts[id] = c
    }

    public mutating func updateQuarter(_ q: Quarter, _ body: (inout QuarterState) -> Void) {
        var s = quarter(q)
        body(&s)
        quarters[q] = s
    }
}

extension FlowState {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        version = c.value(.version, flowSchemaVersion)
        rng = c.value(.rng, UInt64Box(1))
        time = c.value(.time, 0.0)
        lastWallClockMs = c.value(.lastWallClockMs, Int64(0))
        start = c.value(.start, nil)
        chapter = c.value(.chapter, 1)
        chapterNews = c.value(.chapterNews, nil)
        cash = c.value(.cash, 0.0)
        earned = c.value(.earned, 0.0)
        workshops = c.value(.workshops, [Good: WorkshopState]())
        fleet = c.value(.fleet, 1)
        dispatcher = c.value(.dispatcher, false)
        trip = c.value(.trip, nil)
        priority = c.value(.priority, Good.allCases)
        ordersFirst = c.value(.ordersFirst, true)
        contacts = c.value(.contacts, [String: ContactState]())
        quarters = c.value(.quarters, [Quarter: QuarterState]())
        offers = c.value(.offers, [OrderOffer]())
        orders = c.value(.orders, [ActiveOrder]())
        nextOfferAt = c.value(.nextOfferAt, -1.0)
        nextOrderId = c.value(.nextOrderId, 1)
        autoQuiet = c.value(.autoQuiet, false)
        specialists = c.value(.specialists, [Specialist]())
        abilities = c.value(.abilities, [Ability: AbilityState]())
        challenge = c.value(.challenge, nil)
        challengesDone = c.value(.challengesDone, [ChallengeId]())
        ledger = c.value(.ledger, [LedgerEntry]())
        nextLedgerId = c.value(.nextLedgerId, 1)
        counters = c.value(.counters, FlowCounters())
        welcome = c.value(.welcome, nil)
        meta = c.value(.meta, MetaState())
    }
}
