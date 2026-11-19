import Foundation

/// Which station limits a good right now.
public enum Bottleneck: String, Sendable, Equatable {
    /// The bench makes less than the contacts take and the fleet could carry.
    case bench
    /// The fleet carries less than is made and wanted: the shelf fills up.
    case fleet
    /// The contacts take less than is made and could be carried: the shelf fills up, the fleet waits.
    case demand
    /// The shelf holds less than one trip could carry: the fleet leaves half empty.
    case shelf
    /// Bench and demand are even.
    case balanced
}

public struct GoodForecast: Sendable, Equatable {
    public let good: Good
    /// Crates per minute the bench makes while it runs.
    public let production: Double
    /// Crates per minute the contacts take (club nights averaged).
    public let demand: Double
    /// Crates per minute the fleet carries for this good in steady state.
    public let carried: Double
    /// Crates per minute sold in steady state: the slowest station.
    public let sold: Double
    /// Cash per minute those sales bring in.
    public let income: Double
    /// Crates per minute that pile up on the shelf (0 when nothing piles up).
    public let piling: Double
    public let bottleneck: Bottleneck
}

/// Steady state of the whole operation: what every good sells once all automated stations run.
public struct Forecast: Sendable, Equatable {
    public let goods: [Good: GoodForecast]
    /// Cash per minute from standing contacts.
    public let income: Double
    /// Weight per minute the fleet could carry and the weight it actually uses.
    public let fleetCapacity: Double
    public let fleetUsed: Double

    public func good(_ g: Good) -> GoodForecast? { goods[g] }
}

extension Flow {

    // MARK: Levels

    public static func milestonesReached(_ level: Int) -> Int { FlowContent.milestones.filter { $0 <= level }.count }
    public static func nextMilestone(_ level: Int) -> Int? { FlowContent.milestones.first { $0 > level } }

    /// Capacity factor of a station level: linear, doubled at every milestone.
    public static func levelFactor(_ level: Int) -> Double {
        Double(max(1, level)) * pow(2, Double(milestonesReached(level)))
    }

    /// Price of the next `amount` levels of a station that costs `base` at level 1 and grows by `growth`.
    public static func levelsCost(base: Double, growth: Double, level: Int, amount: Int) -> Double {
        let k = Double(max(1, amount))
        return base * pow(growth, Double(level - 1)) * (pow(growth, k) - 1) / (growth - 1)
    }

    /// How many levels `cash` buys (0 when not even one), at most up to the level cap.
    public static func affordableLevels(base: Double, growth: Double, level: Int, cash: Double) -> Int {
        let first = base * pow(growth, Double(level - 1))
        guard cash >= first, first > 0 else { return 0 }
        let k = floor(log(cash * (growth - 1) / first + 1) / log(growth))
        guard k.isFinite else { return 0 }
        var levels = max(1, min(Int(min(k, 10_000)), FlowContent.maxLevel - level))
        while levels > 1 && levelsCost(base: base, growth: growth, level: level, amount: levels) > cash + 1e-9 { levels -= 1 }
        return level >= FlowContent.maxLevel ? 0 : levels
    }

    // MARK: Multipliers

    public static func closedChapters(_ s: FlowState) -> Int { min(FlowContent.chapters.count, max(0, s.chapter - 1)) }

    /// What every payout is multiplied by: closed chapters, challenges, the silent partner and the boost.
    public static func payMultiplier(_ s: FlowState) -> Double {
        pow(FlowContent.chapterBonus, Double(closedChapters(s)))
            * (1 + FlowContent.challengeBonus * Double(min(3, s.challengesDone.count)))
            * (s.meta.premium ? Idle.premiumMultiplier : 1)
            * (s.meta.boostSeconds > 0 ? Idle.boostMultiplier : 1)
    }

    // MARK: Workshops

    /// Crates one bench cycle makes.
    public static func batch(_ s: FlowState, _ g: Good) -> Double {
        guard let w = s.workshop(g) else { return 0 }
        return FlowContent.good(g).batch * levelFactor(w.bench)
    }

    /// Seconds one bench cycle takes (a double shift halves it, a strike doubles it).
    public static func cycleSeconds(_ s: FlowState, _ g: Good) -> Double {
        var t = FlowContent.good(g).cycle
        let shift = s.ability(.doubleShift)
        if shift.active > 0 && shift.good == g { t /= 2 }
        if s.challenge?.id == .strike { t *= 2 }
        return t
    }

    /// Crates per second the bench makes while it runs.
    public static func benchRate(_ s: FlowState, _ g: Good) -> Double {
        guard s.isOpen(g) else { return 0 }
        return batch(s, g) / cycleSeconds(s, g)
    }

    public static func shelfCapacity(_ s: FlowState, _ g: Good) -> Double {
        guard let w = s.workshop(g) else { return 0 }
        return FlowContent.good(g).shelf * levelFactor(w.shelf)
    }

    // MARK: Fleet

    /// Weight one trip carries (fog over the harbour leaves a third).
    public static func fleetCapacity(_ s: FlowState) -> Double {
        FlowContent.fleetCapacity * levelFactor(s.fleet) * (s.challenge?.id == .fog ? 1.0 / 3 : 1)
    }

    /// Seconds a trip takes (a rush run halves it).
    public static func tripSeconds(_ s: FlowState) -> Double {
        FlowContent.tripSeconds / (s.ability(.rushRun).active > 0 ? 2 : 1)
    }

    /// Weight per second the fleet moves when it never stands still.
    public static func fleetRate(_ s: FlowState) -> Double { fleetCapacity(s) / tripSeconds(s) }

    /// Splits a trip between goods: every good with a need gets a base share, the priority order fills the rest.
    public static func allocate(need: [Good: Double], capacity: Double, priority: [Good]) -> [Good: Double] {
        var out: [Good: Double] = [:]
        let order = priority + Good.allCases.filter { !priority.contains($0) }
        let wanting = order.filter { (need[$0] ?? 0) > 1e-9 }
        guard !wanting.isEmpty, capacity > 0 else { return out }
        var left = capacity
        if wanting.count > 1 {
            let share = capacity * FlowContent.baseShare
            for g in wanting {
                let w = FlowContent.good(g).weight
                let x = min(need[g] ?? 0, share / w)
                out[g] = x
                left -= x * w
            }
        }
        for g in wanting where left > 1e-12 {
            let w = FlowContent.good(g).weight
            let x = min((need[g] ?? 0) - (out[g] ?? 0), left / w)
            if x > 0 {
                out[g, default: 0] += x
                left -= x * w
            }
        }
        return out
    }

    // MARK: Attention

    /// 0 calm, 1 watched, 2 hot, 3 underground.
    public static func tier(_ attention: Double) -> Int {
        if attention >= FlowContent.underground { return 3 }
        if attention >= FlowContent.hot { return 2 }
        if attention >= FlowContent.watched { return 1 }
        return 0
    }

    public static func tier(_ s: FlowState, _ q: Quarter) -> Int { tier(s.quarter(q).attention) }

    /// Share of their usual demand the contacts of a quarter take at this tier.
    public static func demandFactor(tier: Int) -> Double { [1, 0.75, 0.5, 0][max(0, min(3, tier))] }
    /// Share of the usual price they pay.
    public static func priceFactor(tier: Int) -> Double { [1, 1, 0.85, 0.85][max(0, min(3, tier))] }

    /// Attention lost per second in a quarter.
    public static func fadeRate(_ s: FlowState, _ q: Quarter) -> Double {
        if s.challenge?.id == .pressWeek { return 0 }
        var rate = FlowContent.fadePerMinute / 60
        if s.quarter(q).paused { rate *= FlowContent.pausedFade }
        if s.has(.sand) { rate *= FlowContent.sandFade }
        return rate
    }

    // MARK: Club nights

    public static func clubSeconds(_ s: FlowState) -> Double {
        FlowContent.clubSeconds + (s.has(.lind) ? FlowContent.lindExtra : 0)
    }

    /// Whether a club night is on, and the seconds until it ends (or starts).
    public static func clubNight(_ s: FlowState) -> (on: Bool, left: Double) {
        let phase = s.time.truncatingRemainder(dividingBy: FlowContent.clubCycle)
        let length = clubSeconds(s)
        return phase < length ? (true, length - phase) : (false, FlowContent.clubCycle - phase)
    }

    /// Club demand factor averaged over a whole cycle.
    static func clubAverage(_ s: FlowState) -> (demand: Double, price: Double) {
        let f = clubSeconds(s) / FlowContent.clubCycle
        let on = FlowContent.clubDemand * f
        let off = FlowContent.offNightDemand * (1 - f)
        return (on + off, (on * FlowContent.clubPrice + off) / (on + off))
    }

    // MARK: Contacts

    public static func contactBaseRate(_ s: FlowState, _ id: String) -> Double {
        guard let def = FlowContent.contact(id), let c = s.contacts[id] else { return 0 }
        let q = s.quarter(def.quarter)
        if q.paused { return 0 }
        return def.demand / 60 * levelFactor(c.level) * demandFactor(tier: tier(q.attention))
    }

    /// Crates per second the contact takes right now.
    public static func contactRate(_ s: FlowState, _ id: String) -> Double {
        guard let def = FlowContent.contact(id) else { return 0 }
        let base = contactBaseRate(s, id)
        guard def.club else { return base }
        return base * (clubNight(s).on ? FlowContent.clubDemand : FlowContent.offNightDemand)
    }

    /// Crates per second the contact takes on average (club nights spread over the cycle).
    public static func contactAverageRate(_ s: FlowState, _ id: String) -> Double {
        guard let def = FlowContent.contact(id) else { return 0 }
        let base = contactBaseRate(s, id)
        return def.club ? base * clubAverage(s).demand : base
    }

    /// Cash one crate pays at this contact right now.
    public static func contactPrice(_ s: FlowState, _ id: String, average: Bool = false) -> Double {
        guard let def = FlowContent.contact(id), let c = s.contacts[id] else { return 0 }
        var p = FlowContent.good(def.good).price * def.price * priceFactor(tier: tier(s, def.quarter))
        if def.luxury { p *= 1 + FlowContent.trustPrice * Double(c.trust) }
        if def.club { p *= average ? clubAverage(s).price : (clubNight(s).on ? FlowContent.clubPrice : 1) }
        return p * payMultiplier(s)
    }

    /// Contacts of a good, best-paying first (deliveries go to them first).
    public static func contacts(_ s: FlowState, of g: Good) -> [String] {
        FlowContent.contacts.filter { $0.good == g && s.contacts[$0.id] != nil }
            .sorted { contactPrice(s, $0.id, average: true) > contactPrice(s, $1.id, average: true) }
            .map(\.id)
    }

    // MARK: Forecast

    /// Steady state with every station running: what sells, where it stops, what it earns.
    public static func forecast(_ s: FlowState) -> Forecast {
        let trip = tripSeconds(s)
        var need: [Good: Double] = [:]
        var production: [Good: Double] = [:]
        var demand: [Good: Double] = [:]
        for g in s.openGoods {
            production[g] = benchRate(s, g)
            demand[g] = contacts(s, of: g).reduce(0) { $0 + contactAverageRate(s, $1) }
            // A trip can only take what the shelf holds when it leaves.
            need[g] = min(min(production[g] ?? 0, demand[g] ?? 0) * trip, shelfCapacity(s, g))
        }
        let perTrip = allocate(need: need, capacity: fleetCapacity(s), priority: s.priority)
        var goods: [Good: GoodForecast] = [:]
        var income = 0.0
        var used = 0.0
        for g in s.openGoods {
            let p = production[g] ?? 0
            let d = demand[g] ?? 0
            let carried = (perTrip[g] ?? 0) / trip
            let sold = min(carried, p, d)
            var left = sold
            var cash = 0.0
            for id in contacts(s, of: g) where left > 1e-12 {
                let x = min(left, contactAverageRate(s, id))
                cash += x * contactPrice(s, id, average: true)
                left -= x
            }
            let eps = 1e-9 + 1e-6 * max(p, d)
            let neck: Bottleneck
            let shelfLimited = shelfCapacity(s, g) < min(p, d) * trip - 1e-9 && (perTrip[g] ?? 0) >= shelfCapacity(s, g) - 1e-9
            if carried + eps < min(p, d) { neck = shelfLimited ? .shelf : .fleet }
            else if p + eps < d { neck = .bench }
            else if d + eps < p { neck = .demand }
            else { neck = .balanced }
            goods[g] = GoodForecast(good: g, production: p * 60, demand: d * 60, carried: carried * 60, sold: sold * 60,
                                    income: cash * 60, piling: max(0, p - sold) * 60, bottleneck: neck)
            income += cash * 60
            used += sold * FlowContent.good(g).weight * 60
        }
        return Forecast(goods: goods, income: income, fleetCapacity: fleetRate(s) * 60, fleetUsed: used)
    }

    // MARK: Prices of stations

    public static func benchCost(_ s: FlowState, _ g: Good, _ amount: Int) -> Double {
        let def = FlowContent.good(g)
        return levelsCost(base: def.benchCost, growth: def.benchGrowth, level: s.workshop(g)?.bench ?? 1, amount: amount)
    }

    public static func shelfCost(_ s: FlowState, _ g: Good, _ amount: Int) -> Double {
        let def = FlowContent.good(g)
        return levelsCost(base: def.shelfCost, growth: def.shelfGrowth, level: s.workshop(g)?.shelf ?? 1, amount: amount)
    }

    public static func fleetCost(_ s: FlowState, _ amount: Int) -> Double {
        levelsCost(base: FlowContent.fleetCost, growth: FlowContent.fleetGrowth, level: s.fleet, amount: amount)
    }

    public static func contactCost(_ s: FlowState, _ id: String, _ amount: Int) -> Double {
        guard let def = FlowContent.contact(id) else { return .infinity }
        return levelsCost(base: def.cost, growth: def.growth, level: s.contacts[id]?.level ?? 1, amount: amount)
    }

    /// Levels the cash buys for a station (MAX).
    public static func affordable(_ s: FlowState, _ station: Station) -> Int {
        switch station {
        case .bench(let g):
            let d = FlowContent.good(g)
            return affordableLevels(base: d.benchCost, growth: d.benchGrowth, level: s.workshop(g)?.bench ?? 1, cash: s.cash)
        case .shelf(let g):
            let d = FlowContent.good(g)
            return affordableLevels(base: d.shelfCost, growth: d.shelfGrowth, level: s.workshop(g)?.shelf ?? 1, cash: s.cash)
        case .fleet:
            return affordableLevels(base: FlowContent.fleetCost, growth: FlowContent.fleetGrowth, level: s.fleet, cash: s.cash)
        case .contact(let id):
            guard let d = FlowContent.contact(id) else { return 0 }
            return affordableLevels(base: d.cost, growth: d.growth, level: s.contacts[id]?.level ?? 1, cash: s.cash)
        }
    }

    public static func cost(_ s: FlowState, _ station: Station, _ amount: Int) -> Double {
        switch station {
        case .bench(let g): benchCost(s, g, amount)
        case .shelf(let g): shelfCost(s, g, amount)
        case .fleet: fleetCost(s, amount)
        case .contact(let id): contactCost(s, id, amount)
        }
    }

    public static func level(_ s: FlowState, _ station: Station) -> Int {
        switch station {
        case .bench(let g): s.workshop(g)?.bench ?? 0
        case .shelf(let g): s.workshop(g)?.shelf ?? 0
        case .fleet: s.fleet
        case .contact(let id): s.contacts[id]?.level ?? 0
        }
    }

    /// The state after buying `amount` levels (no cash taken), for previews.
    public static func upgraded(_ s: FlowState, _ station: Station, _ amount: Int) -> FlowState {
        var t = s
        let k = max(1, amount)
        switch station {
        case .bench(let g): t.updateWorkshop(g) { $0.bench = min(FlowContent.maxLevel, $0.bench + k) }
        case .shelf(let g): t.updateWorkshop(g) { $0.shelf = min(FlowContent.maxLevel, $0.shelf + k) }
        case .fleet: t.fleet = min(FlowContent.maxLevel, t.fleet + k)
        case .contact(let id): t.updateContact(id) { $0.level = min(FlowContent.maxLevel, $0.level + k) }
        }
        return t
    }

    /// What an upgrade changes: income per minute before and after, in steady state.
    public static func preview(_ s: FlowState, _ station: Station, _ amount: Int) -> (before: Forecast, after: Forecast) {
        (forecast(s), forecast(upgraded(s, station, amount)))
    }
}

/// A station the player can upgrade.
public enum Station: Sendable, Equatable, Hashable {
    case bench(Good)
    case shelf(Good)
    case fleet
    case contact(String)
}
