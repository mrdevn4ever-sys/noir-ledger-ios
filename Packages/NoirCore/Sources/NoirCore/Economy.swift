import Foundation

/// Deterministic SplitMix64 stream stored inside the game state. No global randomness is ever used.
public enum Rng {
    public static func next(_ s: inout GameState) -> UInt64 {
        s.rng.raw &+= 0x9E37_79B9_7F4A_7C15
        var z = s.rng.raw
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform double in [0, 1).
    public static func unit(_ s: inout GameState) -> Double {
        Double(next(&s) >> 11) / 9_007_199_254_740_992.0
    }

    public static func range(_ s: inout GameState, _ lo: Double, _ hi: Double) -> Double {
        lo + (hi - lo) * unit(&s)
    }
}

/// Aggregated multipliers from crew, improvements, legacy perks and district specials.
public struct Mods: Sendable, Equatable {
    public var prodSpeed = 1.0
    public var unitCost = 1.0
    public var price = 1.0
    public var route = 1.0
    public var salesExposure = 1.0
    public var allExposure = 1.0
    public var coverMult = 1.0
    public var launderCap = 1.0
    public var feeDelta = 0.0
    public var launderRisk = 1.0
    public var influence = 1.0
    public var influenceFlat = 0.0
    public var heatFall = 1.0
    public var heatRise = 1.0
    public var bribeCost = 1.0
    public var raidInventoryLoss = 1.0
    public var raidCashLoss = 1.0
    public var raidControlLoss = 1.0
    public var turf = 1.0
    public var countdownBonus = 0.0
    public var clearThreshold = Content.heatClear
    public var stash = 1.0
    public var unlockCost = 1.0
    public var frontUpgradeCost = 1.0
    public var wage = 1.0

    public init() {}
}

public enum Economy {

    public static func loyaltyFactor(_ loyalty: Double) -> Double {
        if loyalty >= 50 { return 1.0 }
        if loyalty >= 25 { return 0.75 }
        return 0.4
    }

    public static func crewPower(_ m: CrewMember) -> Double {
        guard let def = m.def else { return 0 }
        return def.basePower * def.trait.powerMult * loyaltyFactor(m.loyalty)
    }

    public static func wagePerSec(_ s: GameState) -> Double {
        s.crew.reduce(0) { acc, c in
            guard let d = c.def else { return acc }
            return acc + d.wagePerMin * d.trait.wageMult / 60
        }
    }

    public static func mods(_ s: GameState) -> Mods {
        var m = Mods()
        // Crew
        for c in s.crew {
            guard let def = c.def else { continue }
            let p = crewPower(c)
            switch def.role {
            case .foreman:
                m.prodSpeed *= 1 + 0.15 * p
                m.price *= 1 + 0.05 * p
            case .courier:
                m.route *= 1 + 0.2 * p
            case .enforcer:
                m.turf *= 1 + 0.5 * p
                m.raidControlLoss *= 0.5
            case .accountant:
                m.launderCap *= 1 + 0.25 * p
                m.feeDelta -= 0.03 * p
            case .lawyer:
                m.coverMult *= 1 + 0.12 * p
                m.raidCashLoss *= max(0.3, 1 - 0.4 * p)
                m.heatFall *= 1 + 0.3 * p
            case .fixer:
                m.influence *= 1 + 0.3 * p
                m.bribeCost *= max(0.5, 1 - 0.2 * p)
            }
            switch def.trait {
            case .hothead: m.allExposure *= 1.05
            case .discreet: m.allExposure *= 0.92
            case .connected: m.influenceFlat += 0.01
            default: break
            }
        }
        // Improvements, in fixed declaration order so results never depend on purchase order.
        for u in UpgradeId.allCases where s.hasUpgrade(u) {
            switch u {
            case .bikeCouriers: m.route *= 1.15
            case .deliveryVans: m.route *= 1.35; m.salesExposure *= 1.10
            case .deadDrops: m.route *= 1.10; m.salesExposure *= 0.85
            case .distributionHub: m.route *= 1.2; m.stash *= 1.5
            case .shiftPlan: m.prodSpeed *= 1.10
            case .piecework: m.prodSpeed *= 1.30; m.unitCost *= 1.10
            case .qualityControl: m.price *= 1.15; m.prodSpeed *= 0.95
            case .supplyContracts: m.unitCost *= 0.8
            case .lookouts: m.countdownBonus += 90
            case .policeScanner: m.clearThreshold = 65; m.heatRise *= 0.9
            case .fallbackStash: m.raidInventoryLoss *= 0.5; m.raidCashLoss *= 0.75
            case .cleanHands: m.allExposure *= 0.9
            case .doubleBooks: m.feeDelta -= 0.03
            case .shellCompanies: m.launderCap *= 1.5; m.launderRisk *= 1.5
            case .taxOffice: m.feeDelta -= 0.05; m.coverMult *= 1.1
            case .privateBank: m.launderCap *= 1.25; m.frontUpgradeCost *= 0.8
            case .regularsTable: m.influence *= 1.2
            case .boughtPress: m.heatFall *= 1.3; m.influence *= 0.9
            case .councilFriends: m.unlockCost *= 0.7; m.influence *= 1.2
            case .cityCouncil: m.bribeCost *= 0.7; m.coverMult *= 1.15
            }
        }
        // Legacy perks
        let l = s.legacy
        m.influence *= 1 + 0.15 * Double(l.rank(.oldContacts))
        m.prodSpeed *= 1 + 0.10 * Double(l.rank(.efficientLines))
        m.feeDelta -= 0.02 * Double(l.rank(.cleanBooks))
        m.coverMult *= 1 + 0.15 * Double(l.rank(.coldTrail))
        m.unlockCost *= 1 - 0.10 * Double(l.rank(.knownName))
        // District specials
        if let docks = s.districts[.docks], docks.unlocked { m.unitCost *= 1 - 0.15 * docks.control / 100 }
        if let foundry = s.districts[.foundry], foundry.unlocked { m.prodSpeed *= 1 + 0.15 * foundry.control / 100 }
        return m
    }

    public static func timed(_ s: GameState, _ kind: ModKind, district d: DistrictId? = nil, product p: ProductId? = nil) -> Double {
        var v = 1.0
        for t in s.modifiers {
            if t.kind != kind || t.until <= s.time { continue }
            if let td = t.district, td != d { continue }
            if let tp = t.product, tp != p { continue }
            v *= t.value
        }
        return v
    }

    // MARK: Production

    public static func batchSize(_ s: GameState, _ p: ProductId) -> Double {
        Content.product(p).batch * (1 + 0.5 * Double(s.line(p).capacityLevel - 1))
    }

    public static func cycleTime(_ s: GameState, _ p: ProductId, _ m: Mods) -> Double {
        let base = Content.product(p).cycleSec * pow(0.9, Double(s.line(p).speedLevel - 1))
        let speed = m.prodSpeed * timed(s, .productionSpeed, product: p)
        return speed <= 0 ? .infinity : base / speed
    }

    public static func qualityMult(_ s: GameState, _ p: ProductId) -> Double { 1 + 0.1 * Double(s.line(p).qualityLevel - 1) }
    public static func qualityDemand(_ s: GameState, _ p: ProductId) -> Double { 1 + 0.04 * Double(s.line(p).qualityLevel - 1) }

    public static func unitCost(_ s: GameState, _ p: ProductId, _ m: Mods) -> Double {
        let q = 1 + 0.06 * Double(s.line(p).qualityLevel - 1)
        return Content.product(p).unitCost * q * m.unitCost * timed(s, .unitCost, product: p)
    }

    public static func productionRate(_ s: GameState, _ p: ProductId, _ m: Mods) -> Double {
        batchSize(s, p) / cycleTime(s, p, m)
    }

    public static func stashCapacity(_ s: GameState, _ m: Mods) -> Double {
        Content.storageCapacity(level: s.storageLevel) * m.stash
    }

    // MARK: Distribution

    public static func price(_ s: GameState, _ d: DistrictId, _ p: ProductId, _ m: Mods) -> Double {
        Content.product(p).basePrice * Content.district(d).priceMod * qualityMult(s, p) * m.price
            * timed(s, .price, district: d, product: p)
    }

    public static func routeCapacity(_ s: GameState, _ d: DistrictId, _ p: ProductId, _ m: Mods) -> Double {
        let lvl = s.district(d).route(p)
        if lvl <= 0 { return 0 }
        return Double(lvl) * Content.product(p).routeRate * Content.district(d).routeMod * m.route
            * timed(s, .routeCapacity, district: d, product: p)
    }

    public static func demand(_ s: GameState, _ d: DistrictId, _ p: ProductId) -> Double {
        let ds = s.district(d)
        let def = Content.district(d)
        return Content.product(p).demandPerMin / 60 * (def.demandMod[p] ?? 0) * (0.5 + 0.5 * ds.control / 100)
            * qualityDemand(s, p) * timed(s, .demand, district: d, product: p)
    }

    public static func salesActive(_ s: GameState, _ d: DistrictId) -> Bool {
        let ds = s.district(d)
        return ds.unlocked && !s.layLow && ds.suspendedUntil <= s.time
    }

    /// Units/s actually wanted by the street (ignoring stock).
    public static func desiredSales(_ s: GameState, _ d: DistrictId, _ p: ProductId, _ m: Mods) -> Double {
        salesActive(s, d) ? min(routeCapacity(s, d, p, m), demand(s, d, p)) : 0
    }

    /// Passive control cap from route presence in a district.
    public static func presenceCap(_ s: GameState, _ d: DistrictId) -> Double {
        min(85, 15 + 5 * Double(s.district(d).totalRouteLevels))
    }

    // MARK: Laundering

    public static func frontCapacity(_ s: GameState, _ f: FrontId, _ m: Mods) -> Double {
        let fs = s.front(f)
        guard fs.owned else { return 0 }
        return baseFrontCapacity(s, f, m) * Idle.payoutRatio(s)
    }

    /// Washing capacity in the base economy, before payout multipliers. Exposure is computed from this scale.
    public static func baseFrontCapacity(_ s: GameState, _ f: FrontId, _ m: Mods) -> Double {
        let fs = s.front(f)
        guard fs.owned else { return 0 }
        return Content.front(f).capacity * (1 + 0.5 * Double(fs.level - 1)) * m.launderCap
    }

    public static func frontFee(_ s: GameState, _ f: FrontId, _ m: Mods) -> Double {
        min(0.6, max(0.03, Content.front(f).fee + m.feeDelta))
    }

    public static func launderCapacity(_ s: GameState, _ m: Mods) -> Double {
        FrontId.allCases.filter { s.front($0).owned && s.front($0).active }.reduce(0) { $0 + frontCapacity(s, $1, m) }
    }

    // MARK: Heat

    public static func cover(_ s: GameState, _ m: Mods) -> Double {
        var k = 4.0
        for f in FrontId.allCases {
            let fs = s.front(f)
            if fs.owned { k += Content.front(f).cover * (1 + 0.3 * Double(fs.level - 1)) }
        }
        k += Content.protectionCover(level: s.protectionLevel)
        k += 2 * max(0, s.influence).squareRoot()
        return k * m.coverMult
    }

    public static func heatTarget(exposure: Double, cover: Double) -> Double {
        exposure <= 0 ? 0 : 100 * exposure / (exposure + cover)
    }

    public static let bribeHeat = 18.0

    public static func bribeCost(_ s: GameState, _ m: Mods) -> Cost {
        let inf = (10 + 8 * Double(s.campaign.chapter)) * m.bribeCost
        let clean = max(50, s.cleanRate * 90) * m.bribeCost
        return Cost(clean: clean, influence: inf)
    }

    // MARK: Influence

    public static func influencePerSec(_ s: GameState, _ m: Mods) -> Double {
        var r = 0.0
        for d in DistrictId.allCases {
            let ds = s.district(d)
            guard ds.unlocked else { continue }
            r += Content.district(d).influenceRate * ds.control / 100
        }
        return (r + m.influenceFlat) * m.influence
    }

    public static let donationCleanPerInfluence = 40.0

    public static func donationCost(_ s: GameState) -> Double { roundNice(max(300, s.cleanRate * 120)) }

    public static func donationInfluence(_ s: GameState, clean: Double) -> Double {
        clean / (donationCleanPerInfluence * (1 + 0.5 * Double(s.campaign.chapter)))
    }

    // MARK: Turf

    public static func turfCost(_ s: GameState, _ d: DistrictId) -> Cost {
        let tier = Content.district(d).tier
        let dirty = 150 * tier * tier * (1 + Double(s.campaign.chapter) * 0.8)
        return Cost(dirty: roundNice(dirty), influence: roundNice(4 * tier))
    }

    public static func turfGain(_ s: GameState, _ d: DistrictId, _ m: Mods) -> Double {
        (d == .foundry ? 6 : 9) * m.turf
    }

    public static func turfHeat(_ d: DistrictId) -> Double { 4 * Content.district(d).police }

    public static func districtUnlockCost(_ s: GameState, _ d: DistrictId, _ m: Mods) -> Cost {
        Cost(clean: Content.district(d).unlockClean * m.unlockCost)
    }

    /// Rounds to two significant digits above 100 (e.g. 1,234 → 1,200), so authored amounts read cleanly.
    public static func roundNice(_ v: Double) -> Double {
        if v < 100 { return v.rounded(.toNearestOrEven) }
        let mag = pow(10, floor(log10(v)) - 1)
        return (v / mag).rounded(.toNearestOrEven) * mag
    }
}
