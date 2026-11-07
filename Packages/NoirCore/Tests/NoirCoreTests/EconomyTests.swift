import Foundation
import NoirCore
import Testing

@Suite("Economy formulas")
struct EconomyTests {

    @Test("Line upgrades cost ×1.75 per level and change batch, cycle and quality as documented")
    func lineTracks() {
        var s = TS.rich(chapter: 2)
        let m = Economy.mods(s)
        let baseBatch = Economy.batchSize(s, .glimmer)
        let baseCycle = Economy.cycleTime(s, .glimmer, m)
        let basePrice = Economy.price(s, .cellars, .glimmer, m)
        let baseCost = Economy.unitCost(s, .glimmer, m)
        let baseDemand = Economy.demand(s, .cellars, .glimmer)

        let c1 = Content.lineUpgradeCost(.glimmer, .capacity, currentLevel: s.line(.glimmer).capacityLevel)
        let c2 = Content.lineUpgradeCost(.glimmer, .capacity, currentLevel: s.line(.glimmer).capacityLevel + 1)
        #expect(abs(c2 / c1 - 1.75) < 1e-9)

        let level = s.line(.glimmer).capacityLevel
        s = TS.ok(s, .upgradeLine(.glimmer, .capacity))
        #expect(abs(Economy.batchSize(s, .glimmer) - Content.product(.glimmer).batch * (1 + 0.5 * Double(level))) < 1e-9)
        #expect(Economy.batchSize(s, .glimmer) > baseBatch)

        s = TS.ok(s, .upgradeLine(.glimmer, .speed))
        let m2 = Economy.mods(s)
        #expect(abs(Economy.cycleTime(s, .glimmer, m2) / baseCycle - 0.9) < 1e-9)

        s = TS.ok(s, .upgradeLine(.glimmer, .quality))
        let m3 = Economy.mods(s)
        #expect(abs(Economy.price(s, .cellars, .glimmer, m3) / basePrice - 1.1) < 1e-9)
        #expect(abs(Economy.unitCost(s, .glimmer, m3) / baseCost - 1.06) < 1e-9)
        #expect(abs(Economy.demand(s, .cellars, .glimmer) / baseDemand - 1.04) < 1e-9)
    }

    @Test("Track multipliers: capacity ×1, cycle ×1.25, quality ×1.5 of the line base")
    func trackCosts() {
        #expect(Content.lineUpgradeCost(.cinder, .capacity, currentLevel: 1) == 250)
        #expect(Content.lineUpgradeCost(.cinder, .speed, currentLevel: 1) == 312.5)
        #expect(Content.lineUpgradeCost(.cinder, .quality, currentLevel: 1) == 375)
    }

    @Test("Line levels stop at 10")
    func lineMax() {
        var s = TS.rich(chapter: 2)
        for _ in 0..<20 { s = Engine.apply(s, .upgradeLine(.glimmer, .speed)).state }
        #expect(s.line(.glimmer).speedLevel == 10)
        #expect(TS.error(s, .upgradeLine(.glimmer, .speed)) == .maxLevel)
    }

    @Test("Stash holds 120 units, ×1.8 per level, at most 12 levels")
    func stash() {
        #expect(Content.storageCapacity(level: 1) == 120)
        #expect(abs(Content.storageCapacity(level: 2) - 216) < 1e-9)
        var s = TS.rich(chapter: 1)
        for _ in 0..<20 { s = Engine.apply(s, .upgradeStorage).state }
        #expect(s.storageLevel == Content.maxStorageLevel)
        #expect(TS.error(s, .upgradeStorage) == .maxLevel)
    }

    @Test("Sales are min(route capacity, demand); demand scales with control")
    func salesFormula() {
        var s = TS.rich(chapter: 2)
        let m = Economy.mods(s)
        let cap = Economy.routeCapacity(s, .cellars, .glimmer, m)
        let demand = Economy.demand(s, .cellars, .glimmer)
        #expect(Economy.desiredSales(s, .cellars, .glimmer, m) == min(cap, demand))
        let control = s.district(.cellars).control
        let expected = 30.0 / 60 * 1.2 * (0.5 + 0.5 * control / 100) * Economy.qualityDemand(s, .glimmer)
        #expect(abs(demand - expected) < 1e-12)
        s.updateDistrict(.cellars) { $0.rival = 0 }
        #expect(Economy.demand(s, .cellars, .glimmer) > demand)
    }

    @Test("Route capacity grows by level and the North Quay ×1.4 modifier")
    func routeCapacity() {
        var s = TS.rich(chapter: 2)
        s = TS.ok(s, .unlockDistrict(.docks))
        s = TS.ok(s, .upgradeRoute(.docks, .glimmer))
        let m = Economy.mods(s)
        let docks = Economy.routeCapacity(s, .docks, .glimmer, m)
        #expect(abs(docks - 1 * 0.2 * 1.4 * m.route) < 1e-12)
        #expect(Content.routeCost(.docks, .glimmer, currentLevel: 1) == 40 * 1.3 * 1.55)
    }

    @Test("Presence cap is 15 + 5 × route levels, at most 85")
    func presenceCap() {
        var s = TS.rich(chapter: 1)
        s.updateDistrict(.cellars) { $0.routes = [.glimmer: 3] }
        #expect(Economy.presenceCap(s, .cellars) == 30)
        s.updateDistrict(.cellars) { $0.routes = [.glimmer: 10, .cinder: 10, .velvet: 10] }
        #expect(Economy.presenceCap(s, .cellars) == 85)
    }

    @Test("Each crew role applies its documented effect", arguments: CrewRole.allCases)
    func crewRoleEffect(_ role: CrewRole) throws {
        var s = TS.rich(chapter: 5)
        let before = Economy.mods(s)
        let def = try #require(Content.crew.first { $0.role == role && $0.tier == 1 })
        s = TS.ok(s, .hire(def.id))
        let after = Economy.mods(s)
        let p = def.basePower * def.trait.powerMult * Economy.loyaltyFactor(60)
        switch role {
        case .foreman:
            #expect(abs(after.prodSpeed / before.prodSpeed - (1 + 0.15 * p)) < 1e-9)
            #expect(abs(after.price / before.price - (1 + 0.05 * p)) < 1e-9)
        case .courier:
            #expect(abs(after.route / before.route - (1 + 0.2 * p)) < 1e-9)
        case .enforcer:
            #expect(abs(after.turf / before.turf - (1 + 0.5 * p)) < 1e-9)
            #expect(after.raidControlLoss == before.raidControlLoss * 0.5)
        case .accountant:
            #expect(abs(after.launderCap / before.launderCap - (1 + 0.25 * p)) < 1e-9)
            #expect(abs((before.feeDelta - after.feeDelta) - 0.03 * p) < 1e-9)
        case .lawyer:
            #expect(abs(after.coverMult / before.coverMult - (1 + 0.12 * p)) < 1e-9)
            #expect(abs(after.heatFall / before.heatFall - (1 + 0.3 * p)) < 1e-9)
            #expect(after.raidCashLoss < before.raidCashLoss)
        case .fixer:
            #expect(abs(after.influence / before.influence - (1 + 0.3 * p)) < 1e-9)
            #expect(after.bribeCost < before.bribeCost)
        }
    }

    @Test("Loyalty below 50 and 25 weakens a specialist")
    func loyaltyFactor() {
        #expect(Economy.loyaltyFactor(80) == 1)
        #expect(Economy.loyaltyFactor(49) == 0.75)
        #expect(Economy.loyaltyFactor(24) == 0.4)
    }

    @Test("Tier-2 trade-off: delivery vans against dead drops")
    func deliveryVansVersusDeadDrops() {
        var vans = TS.rich(chapter: 3)
        vans = TS.ok(vans, .buyUpgrade(.bikeCouriers))
        var drops = vans
        vans = TS.ok(vans, .buyUpgrade(.deliveryVans))
        drops = TS.ok(drops, .buyUpgrade(.deadDrops))
        let mv = Economy.mods(vans)
        let md = Economy.mods(drops)
        #expect(mv.route > md.route)
        #expect(mv.salesExposure > md.salesExposure)
        #expect(abs(mv.salesExposure - 1.10) < 1e-9 && abs(md.salesExposure - 0.85) < 1e-9)
    }

    @Test("North Quay control lowers material cost by up to 15 %; Foundry Row control speeds production by up to 15 %")
    func districtSpecials() {
        var s = TS.rich(chapter: 5)
        let base = Economy.mods(s)
        s.updateDistrict(.docks) { $0.unlocked = true; $0.rival = 0 }
        s.updateDistrict(.foundry) { $0.unlocked = true; $0.rival = 0 }
        let m = Economy.mods(s)
        #expect(abs(m.unitCost / base.unitCost - 0.85) < 1e-9)
        #expect(abs(m.prodSpeed / base.prodSpeed - 1.15) < 1e-9)
    }

    @Test("Legacy perks change the economy per rank")
    func perkEffects() {
        var s = TS.rich(chapter: 1)
        let base = Economy.mods(s)
        s.legacy.perks = [.oldContacts: 2, .efficientLines: 1, .cleanBooks: 3, .coldTrail: 1, .knownName: 3]
        let m = Economy.mods(s)
        #expect(abs(m.influence / base.influence - 1.3) < 1e-9)
        #expect(abs(m.prodSpeed / base.prodSpeed - 1.1) < 1e-9)
        #expect(abs((base.feeDelta - m.feeDelta) - 0.06) < 1e-9)
        #expect(abs(m.coverMult / base.coverMult - 1.15) < 1e-9)
        #expect(abs(m.unlockCost / base.unlockCost - 0.7) < 1e-9)
    }

    @Test("Cover = 4 + front cover + protection + 2√influence")
    func coverFormula() {
        var s = GameState()
        s.influence = 100
        s.protectionLevel = 2
        s.fronts[.laundromat] = { var f = FrontState(); f.owned = true; f.level = 2; return f }()
        let expected: Double = 4.0 + 1.3 + 24.0 + 20.0
        #expect(abs(Economy.cover(s, Mods()) - expected) < 1e-9)
        #expect(Economy.heatTarget(exposure: 0, cover: 10) == 0)
        #expect(abs(Economy.heatTarget(exposure: 10, cover: 10) - 50) < 1e-9)
    }

    @Test("Influence comes from controlled districts scaled by control")
    func influenceIncome() {
        var s = GameState()
        s.districts[.cellars] = { var d = DistrictState(rival: 50); d.unlocked = true; return d }()
        #expect(abs(Economy.influencePerSec(s, Mods()) - 0.008 * 0.5) < 1e-12)
    }

    @Test("roundNice keeps two significant digits")
    func roundNice() {
        #expect(Economy.roundNice(42.4) == 42)
        #expect(Economy.roundNice(1234) == 1200)
        #expect(Economy.roundNice(98_765) == 99_000)
    }

    @Test("The random stream is deterministic and uniform in [0, 1)")
    func rng() {
        var a = GameState()
        a.rng = UInt64Box(42)
        var b = a
        let xs = (0..<1000).map { _ in Rng.unit(&a) }
        let ys = (0..<1000).map { _ in Rng.unit(&b) }
        #expect(xs == ys)
        #expect(xs.allSatisfy { $0 >= 0 && $0 < 1 })
        let mean = xs.reduce(0, +) / Double(xs.count)
        #expect(abs(mean - 0.5) < 0.05)
    }
}
