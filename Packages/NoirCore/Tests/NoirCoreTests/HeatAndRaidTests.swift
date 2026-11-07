import Foundation
import NoirCore
import Testing

@Suite("Heat, investigations, raids and recovery")
struct HeatAndRaidTests {

    /// A state that sells hard in the Cellar Quarter with almost no cover, so Heat climbs on its own.
    private func exposed() -> GameState {
        var s = TS.rich(chapter: 2)
        s.influence = 0
        s.clean = 0
        s.fronts = s.fronts.mapValues { var f = $0; f.active = false; return f }
        s.updateDistrict(.cellars) { $0.routes = [.glimmer: 10]; $0.rival = 0 }
        s.inventory = [.glimmer: 5000]
        s.storageLevel = 12
        return s
    }

    @Test("Heat rises toward the trend with a 120 s time constant and falls with 200 s")
    func heatApproachesTrend() {
        var s = exposed()
        s.heat = 0
        var r = TickReport()
        Simulation.step(&s, dt: 1, offline: false, report: &r)
        let target = s.heatTarget
        #expect(target > 0)
        #expect(abs(s.heat - target * (1.0 / 120)) < 1e-9)

        var cool = TS.rich(chapter: 2)
        cool.heat = 60
        cool.updateLine(.glimmer) { $0.running = false }
        cool.fronts = cool.fronts.mapValues { var f = $0; f.active = false; return f }
        cool.updateDistrict(.cellars) { $0.routes = [:] }
        var r2 = TickReport()
        Simulation.step(&cool, dt: 1, offline: false, report: &r2)
        #expect(abs(cool.heat - 60 * (1 - 1.0 / 200)) < 1e-9)
    }

    @Test("Lying low stops street sales and doubles cooling")
    func layLow() {
        var s = exposed()
        s.heat = 60
        s = TS.ok(s, .setLayLow(true))
        let r = Simulation.advance(&s, seconds: 1, offline: false)
        #expect(r.sold == 0)
        #expect(abs(s.heat - 60 * (1 - 2.0 / 200)) < 1e-9)
        #expect(TS.error(s, .setLayLow(true)) == .invalid)
    }

    @Test("An investigation opens at 75 with a 180 s countdown, only from chapter 1")
    func investigationOpens() {
        var s = exposed()
        s.heat = 80
        var r = TickReport()
        Simulation.step(&s, dt: 1, offline: false, report: &r)
        let inv = s.investigation
        #expect(inv != nil)
        let window: Double = (inv?.endsAt ?? 0) - (inv?.startedAt ?? 0)
        #expect(abs(window - 180) < 1e-9)
        #expect(s.stats.investigations == 1)

        var briefing = Engine.newGame(seed: 1, nowMs: 1)
        briefing = TS.ok(briefing, .choosePrologue(.cashBox))
        briefing.heat = 90
        Simulation.step(&briefing, dt: 1, offline: false, report: &r)
        #expect(briefing.investigation == nil, "no investigations during the briefing (chapter 0)")
    }

    @Test("Lookouts add 90 seconds to the countdown")
    func lookouts() {
        var s = exposed()
        s.clean = 10_000
        s = TS.ok(s, .buyUpgrade(.lookouts))
        s.heat = 80
        var r = TickReport()
        Simulation.step(&s, dt: 1, offline: false, report: &r)
        let window: Double = (s.investigation?.endsAt ?? 0) - (s.investigation?.startedAt ?? 0)
        #expect(abs(window - 270) < 1e-9)
    }

    @Test("The case is dropped below 60 Heat (65 with the police scanner)", arguments: [false, true])
    func investigationClears(_ scanner: Bool) {
        var s = TS.rich(chapter: 3)
        if scanner {
            s = TS.ok(s, .buyUpgrade(.lookouts))
            s = TS.ok(s, .buyUpgrade(.policeScanner))
        }
        s.updateLine(.glimmer) { $0.running = false }
        s.fronts = s.fronts.mapValues { var f = $0; f.active = false; return f }
        s.updateDistrict(.cellars) { $0.routes = [:] }
        s.investigation = Investigation(startedAt: s.time, endsAt: s.time + 500, district: .cellars)
        s.heat = scanner ? 64.5 : 59.5
        var r = TickReport()
        Simulation.step(&s, dt: 1, offline: false, report: &r)
        #expect(s.investigation == nil)
        #expect(s.stats.investigationsSurvived == 1)
    }

    @Test("A bribe removes 18 Heat for clean cash and influence, then cools down for 120 s")
    func bribe() throws {
        var s = TS.rich(chapter: 2)
        s.heat = 70
        let cost = Economy.bribeCost(s, Economy.mods(s))
        let clean = s.clean
        let inf = s.influence
        s = TS.ok(s, .bribe)
        #expect(abs(s.heat - 52) < 1e-9)
        #expect(abs(clean - s.clean - cost.clean) < 1e-6)
        #expect(abs(inf - s.influence - cost.influence) < 1e-6)
        #expect(TS.error(s, .bribe) == .cooldown)
        Simulation.advance(&s, seconds: 121, offline: false)
        s.heat = max(s.heat, 10)
        #expect(TS.error(s, .bribe) == nil)
    }

    @Test("When the countdown runs out the raid seizes 50 % stock and 20 % dirty cash and is recoverable")
    func raidOutcome() {
        var s = TS.rich(chapter: 2)
        s.crew = [CrewMember(defId: "brandt", loyalty: 60)]
        s.inventory = [.glimmer: 100]
        s.dirty = 1000
        let clean = s.clean
        let rivalBefore = s.district(.cellars).rival
        let lines = s.lines
        let fronts = s.fronts
        let routes = s.district(.cellars).routes
        s.heat = 90
        s.investigation = Investigation(startedAt: s.time, endsAt: s.time + 0.5, district: .cellars)
        var r = TickReport()
        Simulation.step(&s, dt: 1, offline: false, report: &r)
        #expect(r.raids == 1)
        #expect(s.stats.raids == 1)
        let report = s.lastRaid
        #expect(report?.district == .cellars)
        #expect(abs((report?.controlLost ?? 0) - 15) < 1e-9)
        #expect(s.raidUnseen)
        #expect(s.heat == 40)
        #expect(s.investigation == nil)
        #expect(abs(s.district(.cellars).rival - min(100, rivalBefore + 15)) < 0.1)
        #expect(s.district(.cellars).suspendedUntil > s.time + 100)
        #expect(s.crew.first?.loyalty ?? 0 < 60 - 7)
        #expect(s.clean >= clean - 1e-6, "clean money is untouched")
        #expect(s.lines.mapValues(\.owned) == lines.mapValues(\.owned))
        #expect(s.fronts == fronts)
        #expect(s.district(.cellars).routes == routes)

        // Streets reopen and money flows again: a raid is always recoverable.
        s = TS.ok(s, .ackRaid)
        #expect(!s.raidUnseen)
        let earned = s.stats.dirtyEarned
        Simulation.advance(&s, seconds: 200, offline: false)
        #expect(s.stats.dirtyEarned > earned)
    }

    @Test("Raid losses: exact fractions, Muscle halves the control loss, Fallback stash and Counsel shrink seizures")
    func raidModifiers() {
        let rich = TS.rich(chapter: 3)
        var base = rich
        base.inventory = [.glimmer: 100]
        base.dirty = 1000
        var plain = base
        Simulation.raid(&plain, district: .cellars)
        #expect(abs(plain.stock(.glimmer) - 50) < 1e-9)
        #expect(abs(plain.dirty - 800) < 1e-9)

        var guarded = rich
        guarded = TS.ok(guarded, .buyUpgrade(.lookouts))
        guarded = TS.ok(guarded, .buyUpgrade(.fallbackStash))
        guarded = TS.ok(guarded, .hire("feld"))
        guarded = TS.ok(guarded, .hire("wolff"))
        guarded.inventory = [.glimmer: 100]
        guarded.dirty = 1000
        Simulation.raid(&guarded, district: .cellars)
        #expect(abs(guarded.stock(.glimmer) - 75) < 1e-9)
        #expect(guarded.dirty > 800)
        #expect(abs((guarded.lastRaid?.controlLost ?? 0) - 7.5) < 1e-9)
    }

    @Test("Pushing rivals costs dirty and influence, gains 9 control (6 in Foundry Row), adds Heat and cools down 60 s")
    func turf() {
        var s = TS.rich(chapter: 4)
        s.updateDistrict(.cellars) { $0.rival = 50 }
        s.heat = 0
        s = TS.ok(s, .turf(.cellars))
        #expect(abs(s.district(.cellars).rival - 41) < 1e-9)
        #expect(abs(s.heat - 4 * 0.7) < 1e-9)
        #expect(TS.error(s, .turf(.cellars)) == .cooldown)
        s = TS.ok(s, .unlockDistrict(.docks))
        s = TS.ok(s, .unlockDistrict(.neonMile))
        s = TS.ok(s, .unlockDistrict(.foundry))
        let foundryRival = s.district(.foundry).rival
        s = TS.ok(s, .turf(.foundry))
        #expect(abs(foundryRival - s.district(.foundry).rival - 6) < 1e-9)
        #expect(TS.error(s, .turf(.crownHill)) == .locked)
    }

    @Test("A visible warning is logged at Heat 50 and resets below 45")
    func warning() {
        var s = exposed()
        s.heat = 50.5
        s.warned = false
        var r = TickReport()
        Simulation.step(&s, dt: 1, offline: false, report: &r)
        #expect(s.warned)
        #expect(s.journal.first { $0.kind == .heatWarning } != nil)
        s.heat = 44
        Simulation.step(&s, dt: 1, offline: false, report: &r)
        #expect(!s.warned)
    }

    @Test("Protection network costs clean cash, adds cover and opens in chapter 2")
    func protection() {
        var s = TS.rich(chapter: 1)
        #expect(TS.error(s, .upgradeProtection) == .locked)
        s.campaign.chapter = 2
        let before = Economy.cover(s, Economy.mods(s))
        s = TS.ok(s, .upgradeProtection)
        #expect(abs(Economy.cover(s, Economy.mods(s)) - before - 8) < 1e-9)
    }
}
