import Foundation

public enum EventId: String, CaseIterable, Codable, Sendable, CodingKeyRepresentable {
    case inspector = "INSPECTOR", rivalTruce = "RIVAL_TRUCE", shipmentTip = "SHIPMENT_TIP", journalist = "JOURNALIST"
    case crewDispute = "CREW_DISPUTE", sweepRumor = "SWEEP_RUMOR", clubNight = "CLUB_NIGHT", dockStrike = "DOCK_STRIKE"
    case councilFundraiser = "COUNCIL_FUNDRAISER", informant = "INFORMANT", badBatch = "BAD_BATCH", unionMuscle = "UNION_MUSCLE"
    case hilltopGala = "HILLTOP_GALA", oldDebt = "OLD_DEBT", powerCut = "POWER_CUT"
}

public struct ModTemplate: Sendable, Equatable {
    public let kind: ModKind
    public let value: Double
    public let seconds: Double
    public let districtScoped: Bool
    public let product: ProductId?

    public init(_ kind: ModKind, _ value: Double, seconds: Double, districtScoped: Bool = false, product: ProductId? = nil) {
        self.kind = kind
        self.value = value
        self.seconds = seconds
        self.districtScoped = districtScoped
        self.product = product
    }
}

/// Concrete consequences of an event branch. Amounts are already scaled for this pending event.
public struct Effects: Sendable, Equatable {
    public var dirty = 0.0
    public var clean = 0.0
    public var influence = 0.0
    public var heat = 0.0
    public var loyalty = 0.0
    public var control = 0.0
    public var suspendSeconds = 0.0
    public var stockLoss = 0.0
    public var mods: [ModTemplate] = []

    public init(dirty: Double = 0, clean: Double = 0, influence: Double = 0, heat: Double = 0, loyalty: Double = 0,
                control: Double = 0, suspendSeconds: Double = 0, stockLoss: Double = 0, mods: [ModTemplate] = []) {
        self.dirty = dirty
        self.clean = clean
        self.influence = influence
        self.heat = heat
        self.loyalty = loyalty
        self.control = control
        self.suspendSeconds = suspendSeconds
        self.stockLoss = stockLoss
        self.mods = mods
    }

    public var isEmpty: Bool {
        dirty == 0 && clean == 0 && influence == 0 && heat == 0 && loyalty == 0 && control == 0
            && suspendSeconds == 0 && stockLoss == 0 && mods.isEmpty
    }
}

public struct Outcome: Sendable, Equatable {
    public let chance: Double
    public let effects: Effects

    public init(_ chance: Double, _ effects: Effects = Effects()) {
        self.chance = chance
        self.effects = effects
    }
}

public struct EventChoice: Sendable, Equatable, Identifiable {
    public let key: String
    public let cost: Cost
    public let requiresRole: CrewRole?
    public let requiresInfluence: Double
    public let outcomes: [Outcome]

    public var id: String { key }

    public init(_ key: String, cost: Cost = Cost(), requiresRole: CrewRole? = nil, requiresInfluence: Double = 0, outcomes: [Outcome]) {
        self.key = key
        self.cost = cost
        self.requiresRole = requiresRole
        self.requiresInfluence = requiresInfluence
        self.outcomes = outcomes
    }

    public func available(_ s: GameState) -> Bool {
        cost.affordable(s) && (requiresRole.map { s.crewIn($0) != nil } ?? true) && s.influence >= requiresInfluence
    }
}

public enum Events {

    private static func unlocked(_ s: GameState, _ d: DistrictId) -> Bool { s.district(d).unlocked }
    private static func owned(_ s: GameState, _ f: FrontId) -> Bool { s.front(f).owned }

    public static func eligible(_ s: GameState, _ e: EventId) -> Bool {
        switch e {
        case .inspector: FrontId.allCases.contains { owned(s, $0) }
        case .rivalTruce: DistrictId.allCases.contains { unlocked(s, $0) && s.district($0).rival > 20 }
        case .shipmentTip: true
        case .journalist: s.campaign.chapter >= 2
        case .crewDispute: s.crew.count >= 2
        case .sweepRumor: s.heat >= 30
        case .clubNight: unlocked(s, .neonMile)
        case .dockStrike: unlocked(s, .docks)
        case .councilFundraiser: s.campaign.chapter >= 2
        case .informant: s.crew.count >= 3
        case .badBatch: s.totalStock >= 10
        case .unionMuscle: unlocked(s, .foundry) && s.district(.foundry).rival > 15
        case .hilltopGala: s.campaign.chapter >= 4
        case .oldDebt: (1...3).contains(s.campaign.chapter)
        case .powerCut: ProductId.allCases.contains { s.line($0).owned && s.line($0).running }
        }
    }

    private static func pickFrom(_ s: inout GameState, _ list: [DistrictId]) -> DistrictId? {
        guard !list.isEmpty else { return nil }
        let i = Int(Rng.unit(&s) * Double(list.count))
        return list[min(max(i, 0), list.count - 1)]
    }

    public static func pickDistrict(_ s: inout GameState, _ e: EventId) -> DistrictId? {
        switch e {
        case .clubNight: return .neonMile
        case .dockStrike: return .docks
        case .unionMuscle: return .foundry
        case .hilltopGala: return .crownHill
        case .rivalTruce:
            let list = DistrictId.allCases.filter { s.district($0).unlocked && s.district($0).rival > 20 }
            return pickFrom(&s, list)
        case .sweepRumor:
            let list = DistrictId.allCases.filter { s.district($0).unlocked }
            return pickFrom(&s, list)
        default: return nil
        }
    }

    /// Builds the pending event, freezing the scaling units so the preview never changes.
    public static func create(_ s: inout GameState, _ e: EventId) -> PendingEvent {
        let unit = Economy.roundNice(max(60, s.incomeRate * 60))
        let cleanUnit = Economy.roundNice(max(40, s.cleanRate * 60))
        let infUnit = 5 * (1 + Double(s.campaign.chapter))
        let district = pickDistrict(&s, e)
        return PendingEvent(event: e, district: district, unit: unit, cleanUnit: cleanUnit, influenceUnit: infUnit, createdAt: s.time)
    }

    public static func choices(_ p: PendingEvent) -> [EventChoice] {
        let u = p.unit
        let c = p.cleanUnit
        let i = p.influenceUnit
        switch p.event {
        case .inspector:
            return [
                EventChoice("pay", cost: Cost(clean: 2 * c), outcomes: [Outcome(1)]),
                EventChoice("fixer", cost: Cost(influence: i), requiresRole: .fixer, outcomes: [Outcome(1, Effects(heat: -4))]),
                EventChoice("refuse", outcomes: [Outcome(1, Effects(heat: 8))]),
            ]
        case .rivalTruce:
            return [
                EventChoice("accept", cost: Cost(dirty: 4 * u), outcomes: [Outcome(1, Effects(control: 10))]),
                EventChoice("refuse", outcomes: [Outcome(0.6, Effects(heat: 6, control: 15)), Outcome(0.4, Effects(heat: 6, control: -10))]),
            ]
        case .shipmentTip:
            return [
                EventChoice("buy", cost: Cost(dirty: 3 * u), outcomes: [Outcome(1, Effects(mods: [ModTemplate(.unitCost, 0.75, seconds: 1800)]))]),
                EventChoice("pass", outcomes: [Outcome(1)]),
            ]
        case .journalist:
            return [
                EventChoice("payoff", cost: Cost(clean: 4 * c), outcomes: [Outcome(1, Effects(heat: -6))]),
                EventChoice("story", cost: Cost(influence: 2 * i), outcomes: [Outcome(1, Effects(heat: -12))]),
                EventChoice("ignore", outcomes: [Outcome(1, Effects(heat: 10))]),
            ]
        case .crewDispute:
            return [
                EventChoice("bonus", cost: Cost(dirty: 2 * u), outcomes: [Outcome(1, Effects(loyalty: 8))]),
                EventChoice("letbe", outcomes: [Outcome(1, Effects(loyalty: -6))]),
            ]
        case .sweepRumor:
            return [
                EventChoice("close", outcomes: [Outcome(1, Effects(heat: -10, suspendSeconds: 300))]),
                EventChoice("continue", outcomes: [Outcome(0.5, Effects(heat: 15)), Outcome(0.5)]),
            ]
        case .clubNight:
            return [
                EventChoice("sponsor", cost: Cost(clean: 3 * c),
                            outcomes: [Outcome(1, Effects(mods: [ModTemplate(.demand, 1.4, seconds: 1200, districtScoped: true)]))]),
                EventChoice("skip", outcomes: [Outcome(1)]),
            ]
        case .dockStrike:
            return [
                EventChoice("fund", cost: Cost(dirty: 3 * u), outcomes: [Outcome(1, Effects(influence: 2 * i))]),
                EventChoice("exploit", outcomes: [Outcome(1, Effects(heat: 8, mods: [ModTemplate(.routeCapacity, 1.3, seconds: 600, districtScoped: true)]))]),
            ]
        case .councilFundraiser:
            return [
                EventChoice("donate", cost: Cost(clean: 5 * c), outcomes: [Outcome(1, Effects(influence: 5 * i))]),
                EventChoice("decline", outcomes: [Outcome(1)]),
            ]
        case .informant:
            return [
                EventChoice("enforcer", requiresRole: .enforcer, outcomes: [Outcome(1, Effects(heat: -10, loyalty: 5))]),
                EventChoice("investigate", cost: Cost(dirty: 2 * u),
                            outcomes: [Outcome(0.5, Effects(heat: -10, loyalty: 5)), Outcome(0.5, Effects(loyalty: -5))]),
                EventChoice("ignore", outcomes: [Outcome(0.4, Effects(heat: 20)), Outcome(0.6)]),
            ]
        case .badBatch:
            return [
                EventChoice("recall", outcomes: [Outcome(1, Effects(influence: i, stockLoss: 0.3))]),
                EventChoice("sell", outcomes: [Outcome(1, Effects(heat: 5, mods: [ModTemplate(.price, 0.8, seconds: 900)]))]),
            ]
        case .unionMuscle:
            return [
                EventChoice("hire", cost: Cost(dirty: 4 * u), outcomes: [Outcome(1, Effects(control: 12))]),
                EventChoice("refuse", outcomes: [Outcome(1, Effects(control: -8))]),
            ]
        case .hilltopGala:
            return [
                EventChoice("attend", cost: Cost(clean: 6 * c), outcomes: [Outcome(1, Effects(influence: 8 * i))]),
                EventChoice("gift", cost: Cost(dirty: 3 * u), outcomes: [Outcome(1, Effects(influence: 3 * i, heat: 3))]),
                EventChoice("decline", outcomes: [Outcome(1)]),
            ]
        case .oldDebt:
            return [
                EventChoice("repay", cost: Cost(dirty: 2 * u), outcomes: [Outcome(1, Effects(influence: i, loyalty: 5))]),
                EventChoice("refuse", outcomes: [Outcome(0.5, Effects(heat: 6)), Outcome(0.5)]),
            ]
        case .powerCut:
            return [
                EventChoice("generator", cost: Cost(dirty: u), outcomes: [Outcome(1)]),
                EventChoice("wait", outcomes: [Outcome(1, Effects(mods: [ModTemplate(.productionSpeed, 0, seconds: 120)]))]),
            ]
        }
    }

    /// Applies the chosen branch. Returns the index of the outcome that happened, or nil if the choice is not allowed.
    public static func resolve(_ s: inout GameState, choiceKey: String) -> Int? {
        guard let p = s.pendingEvent,
              let choice = choices(p).first(where: { $0.key == choiceKey }),
              choice.available(s) else { return nil }
        choice.cost.pay(&s)
        let roll = choice.outcomes.count == 1 ? 0 : Rng.unit(&s)
        var acc = 0.0
        var idx = choice.outcomes.count - 1
        for (k, o) in choice.outcomes.enumerated() {
            acc += o.chance
            if roll < acc {
                idx = k
                break
            }
        }
        apply(&s, choice.outcomes[idx].effects, district: p.district)
        s.pendingEvent = nil
        s.eventLastSeen[p.event] = s.time
        s.stats.eventsResolved += 1
        s.log(.eventResolved, ref: "\(p.event.rawValue):\(choice.key):\(idx)")
        return idx
    }

    public static func apply(_ s: inout GameState, _ e: Effects, district: DistrictId?) {
        s.dirty = max(0, s.dirty + e.dirty)
        s.clean = max(0, s.clean + e.clean)
        s.influence = max(0, s.influence + e.influence)
        s.heat = min(100, max(0, s.heat + e.heat))
        if e.loyalty != 0 {
            for i in s.crew.indices { s.crew[i].loyalty = min(100, max(0, s.crew[i].loyalty + e.loyalty)) }
        }
        if let d = district {
            let now = s.time
            s.updateDistrict(d) { ds in
                if e.control != 0 { ds.rival = min(100, max(0, ds.rival - e.control)) }
                if e.suspendSeconds > 0 { ds.suspendedUntil = max(ds.suspendedUntil, now + e.suspendSeconds) }
            }
        }
        if e.stockLoss > 0 {
            for p in ProductId.allCases { s.inventory[p] = s.stock(p) * (1 - e.stockLoss) }
        }
        for t in e.mods {
            s.modifiers.append(TimedModifier(kind: t.kind, value: t.value, until: s.time + t.seconds,
                                             district: t.districtScoped ? district : nil, product: t.product))
        }
    }

    /// Picks the next eligible event deterministically, preferring ones not seen in the last 20 minutes.
    public static func pickNext(_ s: inout GameState) -> EventId? {
        let pool = EventId.allCases.filter { e in eligible(s, e) && s.time - (s.eventLastSeen[e] ?? -1e9) > 1200 }
        guard !pool.isEmpty else { return nil }
        let i = Int(Rng.unit(&s) * Double(pool.count))
        return pool[min(max(i, 0), pool.count - 1)]
    }

    public static func nextGap(_ s: inout GameState) -> Double { Rng.range(&s, 240, 420) }
}
