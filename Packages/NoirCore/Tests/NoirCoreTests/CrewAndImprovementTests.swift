import Foundation
import NoirCore
import Testing

@Suite("Crew, wages, loyalty and improvements")
struct CrewAndImprovementTests {

    @Test("Hiring pays the fee, fills one role, and respects the chapter")
    func hiring() {
        var s = TS.rich(chapter: 1)
        let dirty = s.dirty
        s = TS.ok(s, .hire("brandt"))
        #expect(s.dirty == dirty - 300)
        #expect(s.crewIn(.foreman)?.loyalty == 60)
        #expect(TS.error(s, .hire("kessler")) == .locked)
        s.campaign.chapter = 3
        #expect(TS.error(s, .hire("kessler")) == .roleOccupied)
        #expect(TS.error(s, .hire("brandt")) == .invalid)
        #expect(TS.error(s, .hire("nobody")) == .invalid)
    }

    @Test("Dismissing upsets the crew; a returning specialist costs 1.5× and starts at 45 loyalty")
    func dismissAndRehire() {
        var s = TS.rich(chapter: 1)
        s = TS.ok(s, .hire("brandt"))
        s = TS.ok(s, .hire("varga"))
        s = TS.ok(s, .dismiss("brandt"))
        #expect(s.crewIn(.foreman) == nil)
        #expect(s.departed.contains("brandt"))
        #expect(s.crewIn(.courier)?.loyalty == 57)
        let def = Content.crewDef("brandt")!
        #expect(Engine.hireCost(s, def) == 450)
        let dirty = s.dirty
        s = TS.ok(s, .hire("brandt"))
        #expect(s.dirty == dirty - 450)
        #expect(s.crewIn(.foreman)?.loyalty == 45)
    }

    @Test("Paid wages raise loyalty toward 80; unpaid wages lower it 3 per minute until the specialist leaves")
    func wagesAndLoyalty() {
        var s = TS.rich(chapter: 1)
        s = TS.ok(s, .hire("varga"))
        Simulation.advance(&s, seconds: 600, offline: false)
        #expect(s.crewIn(.courier)!.loyalty > 60)
        #expect(s.crewIn(.courier)!.loyalty <= 80)

        s.dirty = 0
        s.updateLine(.glimmer) { $0.running = false }
        s.updateDistrict(.cellars) { $0.routes = [:] }
        let before = s.crewIn(.courier)!.loyalty
        Simulation.advance(&s, seconds: 60, offline: false)
        #expect(s.wagesUnpaid)
        #expect(abs(before - s.crewIn(.courier)!.loyalty - 3) < 0.2)
        Simulation.advance(&s, seconds: 60 * 40, offline: false)
        #expect(s.crewIn(.courier) == nil, "an unpaid specialist walks out at zero loyalty")
        #expect(s.departed.contains("varga"))
        #expect(s.journal.contains { $0.kind == .crewLeft })
    }

    @Test("Loyal specialists lose loyalty at half speed")
    func loyalTrait() {
        var s = TS.rich(chapter: 1)
        s = TS.ok(s, .hire("morgen"))
        s.dirty = 0
        s.updateLine(.glimmer) { $0.running = false }
        s.updateDistrict(.cellars) { $0.routes = [:] }
        Simulation.advance(&s, seconds: 60, offline: false)
        #expect(abs(60 - s.crewIn(.accountant)!.loyalty - 1.5) < 0.1)
    }

    @Test("A bonus costs ten minutes of wages and adds 15 loyalty")
    func bonus() {
        var s = TS.rich(chapter: 1)
        s = TS.ok(s, .hire("okafor"))
        let member = s.crewIn(.fixer)!
        #expect(Engine.bonusCost(member) == 15 * 1.1 * 10)
        s = TS.ok(s, .crewBonus("okafor"))
        #expect(s.crewIn(.fixer)?.loyalty == 75)
        s.crew[0].loyalty = 100
        #expect(TS.error(s, .crewBonus("okafor")) == .maxLevel)
    }

    @Test("Improvements: tier 1 from chapter 1, tier 2 from chapter 3, tier 3 from chapter 4, in order")
    func improvementGating() {
        var s = TS.rich(chapter: 1)
        #expect(Engine.upgradeStatus(s, .deliveryVans) == .chapterLocked)
        s = TS.ok(s, .buyUpgrade(.bikeCouriers))
        #expect(TS.error(s, .buyUpgrade(.bikeCouriers)) == .invalid)
        s.campaign.chapter = 3
        #expect(Engine.upgradeStatus(s, .shellCompanies) == .needsPrevious)
        #expect(Engine.upgradeStatus(s, .deliveryVans) == .available)
        #expect(Engine.upgradeStatus(s, .distributionHub) == .chapterLocked)
        s = TS.ok(s, .buyUpgrade(.deliveryVans))
        #expect(Engine.upgradeStatus(s, .deadDrops) == .excluded)
        #expect(TS.error(s, .buyUpgrade(.deadDrops)) == .requirements)
        s.campaign.chapter = 4
        #expect(Engine.upgradeStatus(s, .distributionHub) == .available)
        s = TS.ok(s, .buyUpgrade(.distributionHub))
        #expect(s.upgrades == [.bikeCouriers, .deliveryVans, .distributionHub])
    }

    @Test("Every improvement can be bought along one valid path of its branch", arguments: UpgradeBranch.allCases)
    func branchPaths(_ branch: UpgradeBranch) {
        let nodes = UpgradeId.inBranch(branch)
        for pick in nodes.filter({ $0.tier == 2 }) {
            var s = TS.rich(chapter: 4)
            for u in nodes where u.tier == 1 || u == pick || u.tier == 3 { s = TS.ok(s, .buyUpgrade(u)) }
            #expect(s.upgrades.count == 3)
            #expect(Economy.mods(s) != Economy.mods(TS.rich(chapter: 4)))
        }
    }

    @Test("Shift work: piecework speeds the lines but raises material cost; quality control raises prices")
    func productionChoice() {
        var a = TS.rich(chapter: 3)
        a = TS.ok(a, .buyUpgrade(.shiftPlan))
        var b = a
        a = TS.ok(a, .buyUpgrade(.piecework))
        b = TS.ok(b, .buyUpgrade(.qualityControl))
        #expect(Economy.mods(a).prodSpeed > Economy.mods(b).prodSpeed)
        #expect(Economy.mods(a).unitCost > Economy.mods(b).unitCost)
        #expect(Economy.mods(b).price > Economy.mods(a).price)
    }
}
