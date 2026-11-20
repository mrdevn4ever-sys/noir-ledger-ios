import Foundation

/*
 * NOIR LEDGER 4.0: the ledger of Varnholm.
 *
 * Goods move through four visible stations: a workshop's bench makes crates, its shelf holds them, the shared fleet
 * carries them to contacts in the quarters of the city, and every delivery is booked in the ledger. The slowest
 * station limits what is sold; the shelf shows where goods pile up. Special orders pay more for a deadline and some
 * attention in a quarter; attention slows a quarter down in graded, reversible steps and fades on its own.
 *
 * Every number in this file is a balancing hypothesis from the economy simulation (docs/ECONOMY_4.md) until play
 * tests confirm it.
 */

// MARK: - Identifiers

public enum Good: String, CaseIterable, Codable, Sendable, CodingKeyRepresentable {
    case weed = "WEED", crystal = "CRYSTAL", pills = "PILLS", coke = "COKE"
}

public enum Quarter: String, CaseIterable, Codable, Sendable, CodingKeyRepresentable {
    case cellars = "CELLARS", oldTown = "OLD_TOWN", docks = "DOCKS", night = "NIGHT", crown = "CROWN"
}

/// What Leopold left besides the cellar: the player takes one of three things to start with.
public enum StartChoice: String, CaseIterable, Codable, Sendable {
    /// Starting cash for the first upgrades.
    case cashbox = "CASHBOX"
    /// The baker's back door: a better-paying contact from the start.
    case addressBook = "ADDRESS_BOOK"
    /// A better bench and a second shelf board.
    case tools = "TOOLS"
}

public enum OrderKind: String, CaseIterable, Codable, Sendable {
    /// Pays the standing price, adds no attention and calms its quarter a little.
    case quiet = "QUIET"
    /// Pays more and draws attention to its quarter.
    case loud = "LOUD"
    /// A bulk order: much more, a longer window, a lot of attention.
    case big = "BIG"
    /// A luxury order for a contact who counts reliability: trust rises when it arrives, falls when it fails.
    case trust = "TRUST"
    /// A citywide order for several goods at once.
    case city = "CITY"
    /// The last contract of the story.
    case finale = "FINALE"
}

public enum Ability: String, CaseIterable, Codable, Sendable, CodingKeyRepresentable {
    /// Workshop lead: the bench runs twice as fast for a minute.
    case doubleShift = "DOUBLE_SHIFT"
    /// Dispatcher: trips take half the time for a minute.
    case rushRun = "RUSH_RUN"
    /// Sami Okafor: a fresh set of offers, one of them better paid.
    case newWindow = "NEW_WINDOW"
    /// Anton Kraus: a quiet word takes 40 attention off the hottest quarter.
    case quietWord = "QUIET_WORD"
}

/// People who join as chapter rewards.
public enum Specialist: String, CaseIterable, Codable, Sendable {
    /// Contact person: one more order at a time, can take quiet orders on her own, opens new offer windows.
    case okafor = "OKAFOR"
    /// Bookkeeper: special orders pay 15 % more.
    case morgen = "MORGEN"
    /// Harbour muscle: attention fades half again as fast.
    case sand = "SAND"
    /// Night quarter promoter: club nights last a minute longer.
    case lind = "LIND"
    /// Lawyer: the quiet word.
    case kraus = "KRAUS"
}

public enum ChallengeId: String, CaseIterable, Codable, Sendable {
    /// Fog over the harbour: the fleet carries a third.
    case fog = "FOG"
    /// The press week: attention does not fade and every order draws twice as much.
    case pressWeek = "PRESS_WEEK"
    /// Strike at the works: benches run at half speed.
    case strike = "STRIKE"
}

// MARK: - Definitions

public struct GoodDef: Sendable, Equatable {
    public let id: Good
    /// Base price per crate.
    public let price: Double
    /// Fleet capacity one crate takes.
    public let weight: Double
    /// Seconds per bench cycle.
    public let cycle: Double
    /// Crates per cycle at bench level 1.
    public let batch: Double
    public let benchCost: Double
    public let benchGrowth: Double
    /// Shelf capacity at level 1.
    public let shelf: Double
    public let shelfCost: Double
    public let shelfGrowth: Double
    /// Price to open the workshop (0 for the cellar).
    public let openCost: Double
    public let leadCost: Double
    /// Crew id of the workshop lead.
    public let lead: String
    /// Chapter in which the workshop can be opened.
    public let chapter: Int
}

public struct ContactDef: Sendable, Equatable, Identifiable {
    public let id: String
    public let good: Good
    public let quarter: Quarter
    /// Crates per minute at level 1.
    public let demand: Double
    /// Factor on the good's price.
    public let price: Double
    public let unlockCost: Double
    public let cost: Double
    public let growth: Double
    public let chapter: Int
    /// Club contact: buys in club nights.
    public let club: Bool
    /// Luxury contact: pays more with trust.
    public let luxury: Bool
}

public enum GoalKind: Sendable, Equatable {
    case deliveries(Int)
    case hireLead(Good)
    case hireDispatcher
    case orders(Int)
    case earn(Double)
    case unlockContact(String)
    /// Crates per minute the good sells in steady state.
    case throughput(Good, Double)
    case openGood(Good)
    case bigOrders(Int)
    /// Crates of pills sold in a single club night.
    case clubNight(Double)
    /// Contacts with at least this much trust.
    case trust(contacts: Int, level: Int)
    case cityOrders(Int)
    case finale
}

public struct GoalDef: Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: GoalKind
}

public struct ChapterDef: Sendable, Equatable, Identifiable {
    public var id: Int { number }
    public let number: Int
    public let quarter: Quarter?
    /// Crew id of the person the chapter is about.
    public let person: String
    public let goals: [GoalDef]
    /// Who joins when the chapter closes.
    public let joins: Specialist?
}

public struct ChallengeDef: Sendable, Equatable, Identifiable {
    public let id: ChallengeId
    /// Game seconds the challenge lasts.
    public let seconds: Double
    /// Favors for each of the three goals.
    public let rewards: [Int]
}

// MARK: - Content

public enum FlowContent {
    public static let goods: [GoodDef] = [
        GoodDef(id: .weed, price: 5, weight: 1, cycle: 5, batch: 1, benchCost: 20, benchGrowth: 1.15,
                shelf: 20, shelfCost: 30, shelfGrowth: 1.30, openCost: 0, leadCost: 100, lead: "brandt", chapter: 1),
        GoodDef(id: .crystal, price: 60, weight: 2, cycle: 8, batch: 4, benchCost: 2.5e4, benchGrowth: 1.13,
                shelf: 60, shelfCost: 2e4, shelfGrowth: 1.30, openCost: 4e5, leadCost: 1.5e5, lead: "feld", chapter: 3),
        GoodDef(id: .pills, price: 900, weight: 1, cycle: 6, batch: 3, benchCost: 2.5e6, benchGrowth: 1.13,
                shelf: 40, shelfCost: 2e6, shelfGrowth: 1.30, openCost: 3e7, leadCost: 1.2e7, lead: "kessler", chapter: 4),
        GoodDef(id: .coke, price: 2.4e4, weight: 0.5, cycle: 10, batch: 1, benchCost: 2.5e8, benchGrowth: 1.13,
                shelf: 15, shelfCost: 2e8, shelfGrowth: 1.30, openCost: 4e9, leadCost: 1e9, lead: "wolff", chapter: 5),
    ]

    public static func good(_ g: Good) -> GoodDef { goods.first { $0.id == g }! }

    public static let contacts: [ContactDef] = [
        ContactDef(id: "muehlgasse", good: .weed, quarter: .cellars, demand: 10, price: 1.0, unlockCost: 0, cost: 25, growth: 1.17, chapter: 1, club: false, luxury: false),
        ContactDef(id: "baeckerei", good: .weed, quarter: .cellars, demand: 8, price: 1.5, unlockCost: 400, cost: 60, growth: 1.17, chapter: 1, club: false, luxury: false),
        ContactDef(id: "altmarkt", good: .weed, quarter: .oldTown, demand: 30, price: 1.3, unlockCost: 3e3, cost: 400, growth: 1.13, chapter: 2, club: false, luxury: false),
        ContactDef(id: "uni", good: .weed, quarter: .oldTown, demand: 45, price: 1.1, unlockCost: 2e4, cost: 2e3, growth: 1.13, chapter: 2, club: false, luxury: false),
        ContactDef(id: "kai7", good: .crystal, quarter: .docks, demand: 40, price: 1.0, unlockCost: 0, cost: 3e4, growth: 1.13, chapter: 3, club: false, luxury: false),
        ContactDef(id: "werk", good: .crystal, quarter: .docks, demand: 80, price: 0.9, unlockCost: 2e6, cost: 2e5, growth: 1.13, chapter: 3, club: false, luxury: false),
        ContactDef(id: "club", good: .pills, quarter: .night, demand: 30, price: 1.0, unlockCost: 0, cost: 3e6, growth: 1.13, chapter: 4, club: true, luxury: false),
        ContactDef(id: "variete", good: .pills, quarter: .night, demand: 40, price: 1.2, unlockCost: 1e8, cost: 2e7, growth: 1.13, chapter: 4, club: true, luxury: false),
        ContactDef(id: "villa", good: .coke, quarter: .crown, demand: 6, price: 1.0, unlockCost: 0, cost: 3e8, growth: 1.13, chapter: 5, club: false, luxury: true),
        ContactDef(id: "senat", good: .coke, quarter: .crown, demand: 8, price: 1.4, unlockCost: 2e10, cost: 4e9, growth: 1.13, chapter: 5, club: false, luxury: true),
    ]

    public static func contact(_ id: String) -> ContactDef? { contacts.first { $0.id == id } }

    public static let chapters: [ChapterDef] = [
        ChapterDef(number: 1, quarter: .cellars, person: "brandt", goals: [
            GoalDef(id: "c1_deliver", kind: .deliveries(1)),
            GoalDef(id: "c1_lead", kind: .hireLead(.weed)),
            GoalDef(id: "c1_order", kind: .orders(1)),
            GoalDef(id: "c1_dispatcher", kind: .hireDispatcher),
            GoalDef(id: "c1_earn", kind: .earn(6_000)),
        ], joins: .okafor),
        ChapterDef(number: 2, quarter: .oldTown, person: "okafor", goals: [
            GoalDef(id: "c2_altmarkt", kind: .unlockContact("altmarkt")),
            GoalDef(id: "c2_orders", kind: .orders(5)),
            GoalDef(id: "c2_flow", kind: .throughput(.weed, 60)),
            GoalDef(id: "c2_earn", kind: .earn(6e4)),
        ], joins: .morgen),
        ChapterDef(number: 3, quarter: .docks, person: "feld", goals: [
            GoalDef(id: "c3_open", kind: .openGood(.crystal)),
            GoalDef(id: "c3_lead", kind: .hireLead(.crystal)),
            GoalDef(id: "c3_big", kind: .bigOrders(1)),
            GoalDef(id: "c3_earn", kind: .earn(5e7)),
        ], joins: .sand),
        ChapterDef(number: 4, quarter: .night, person: "lind", goals: [
            GoalDef(id: "c4_open", kind: .openGood(.pills)),
            GoalDef(id: "c4_lead", kind: .hireLead(.pills)),
            GoalDef(id: "c4_club", kind: .clubNight(150)),
            GoalDef(id: "c4_earn", kind: .earn(2e10)),
        ], joins: .lind),
        ChapterDef(number: 5, quarter: .crown, person: "kraus", goals: [
            GoalDef(id: "c5_open", kind: .openGood(.coke)),
            GoalDef(id: "c5_lead", kind: .hireLead(.coke)),
            GoalDef(id: "c5_trust", kind: .trust(contacts: 1, level: 3)),
            GoalDef(id: "c5_earn", kind: .earn(6e11)),
        ], joins: .kraus),
        ChapterDef(number: 6, quarter: nil, person: "kessler", goals: [
            GoalDef(id: "c6_city", kind: .cityOrders(3)),
            GoalDef(id: "c6_earn", kind: .earn(1e13)),
            GoalDef(id: "c6_finale", kind: .finale),
        ], joins: nil),
    ]

    public static func chapter(_ n: Int) -> ChapterDef? { chapters.first { $0.number == n } }

    public static let challenges: [ChallengeDef] = [
        ChallengeDef(id: .fog, seconds: 15 * 60, rewards: [20, 30, 50]),
        ChallengeDef(id: .pressWeek, seconds: 15 * 60, rewards: [20, 30, 50]),
        ChallengeDef(id: .strike, seconds: 15 * 60, rewards: [20, 30, 50]),
    ]

    public static func challenge(_ id: ChallengeId) -> ChallengeDef { challenges.first { $0.id == id }! }

    // MARK: Stations

    /// Levels at which a station's capacity doubles (the scene shows a visible rebuild at each).
    public static let milestones = [10, 25, 50, 100, 150, 200, 300, 400, 500, 750, 1_000]
    public static let maxLevel = 1_500

    public static let fleetCost = 20.0
    public static let fleetGrowth = 1.14
    /// Weight units one trip carries at fleet level 1.
    public static let fleetCapacity = 1.0
    public static let tripSeconds = 10.0
    public static let dispatcherCost = 300.0
    /// Crew id of the dispatcher.
    public static let dispatcher = "varga"
    /// With two or more goods each gets at least this share of a trip before the priority order fills the rest.
    public static let baseShare = 0.2
    /// Contacts keep this many seconds of unmet demand open.
    public static let demandMemory = 120.0

    // MARK: Attention

    public static let watched = 30.0
    public static let hot = 60.0
    public static let underground = 85.0
    /// Attention fading per minute; a paused quarter fades three times as fast.
    public static let fadePerMinute = 3.0
    public static let pausedFade = 3.0

    // MARK: Orders

    public static let quietPay = 1.0
    public static let loudPay = 1.45
    public static let bigPay = 1.9
    public static let trustPay = 1.6
    public static let cityPay = 2.5
    public static let finalePay = 3.0
    public static let quietAttention = -5.0
    public static let loudAttention = 20.0
    public static let bigAttention = 35.0
    public static let trustAttention = 10.0
    public static let cityAttention = 15.0
    /// Seconds an offer stays on the board.
    public static let offerSeconds = 150.0
    /// Seconds between new offers while the board has room.
    public static let offerGap = 45.0

    // MARK: Club nights and trust

    /// A club night starts every `clubCycle` seconds and lasts `clubSeconds` (one minute more with Greta Lind).
    public static let clubCycle = 480.0
    public static let clubSeconds = 180.0
    public static let clubDemand = 3.0
    public static let clubPrice = 1.5
    public static let offNightDemand = 0.4
    public static let maxTrust = 5
    public static let trustPrice = 0.1

    // MARK: Crew

    public static let abilitySeconds = 60.0
    public static let abilityCooldown: [Ability: Double] = [.doubleShift: 600, .rushRun: 600, .newWindow: 900, .quietWord: 1_200]
    /// Abilities become available with this chapter.
    public static let abilityChapter = 3
    public static let morganBonus = 1.15
    public static let sandFade = 1.5
    public static let lindExtra = 60.0
    public static let quietWord = 40.0

    // MARK: Progress

    /// Every closed chapter raises every payout by half (Leopold's network grows).
    public static let chapterBonus = 1.5
    /// Each completed challenge adds this much to every payout, at most three times.
    public static let challengeBonus = 0.1
    /// Time away is credited up to this many seconds (twice with the silent partner).
    public static let offlineCap = 12.0 * 3600
    public static let ledgerSize = 40

    // MARK: Start

    /// The one-time estate pickup at the cellar door: a buyer with a signed slip for exactly one crate. It is not a
    /// standing contact and never recurs; the ordinary per-crate price stays `good(.weed).price`. The amount is the
    /// smallest that makes the first ordinary van level (`fleetCost`) affordable for every start
    /// (scripts/qa/estate_opening.py).
    public static let estatePickupCash = 20.0
    public static let estatePickupCrates = 1.0
    /// Verified store transactions remembered in the save so a redelivered one is never booked twice.
    public static let receiptMemory = 1_000

    public static let cashboxCash = 60.0
    public static let toolsBench = 3
    public static let toolsShelf = 2
}
