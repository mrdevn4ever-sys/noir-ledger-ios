import Foundation
import NoirCore
import Testing

@Suite("Production, distribution and laundering")
struct SimulationTests {

    @Test("A running line pays materials per batch in dirty cash and fills the stash")
    func productionPaysMaterials() {
        var s = TS.rich(chapter: 1)
        s.inventory = [:]
        s.updateDistrict(.cellars) { $0.routes = [:] }
        let dirty = s.dirty
        let r = Simulation.advance(&s, seconds: 80, offline: false)
        #expect(r.produced > 0)
        #expect(abs(s.stock(.glimmer) - r.produced) < 1e-9)
        #expect(abs((dirty - s.dirty) - r.productionSpent - r.wagesPaid - r.dirtyLaundered) < 1e-6)
        #expect(r.productionSpent > 0)
    }

    @Test("Output stops when the shared stash is full")
    func stashFullStops() {
        var s = TS.rich(chapter: 1)
        s.updateDistrict(.cellars) { $0.routes = [:] }
        let cap = Economy.stashCapacity(s, Economy.mods(s))
        s.inventory[.glimmer] = cap
        Simulation.advance(&s, seconds: 30, offline: false)
        #expect(s.line(.glimmer).status == .storageFull)
        #expect(s.totalStock <= cap + 1e-6)
    }

    @Test("Without cash a line stops, but the starter line switches to free scrap mode at half speed")
    func noCashAndScrapMode() {
        var s = TS.rich(chapter: 3)
        s = TS.ok(s, .buyLine(.cinder))
        s.dirty = 0
        s.crew = []
        s.fronts = s.fronts.mapValues { var f = $0; f.active = false; return f }
        for d in DistrictId.allCases { s.updateDistrict(d) { $0.routes = [:] } }
        s.inventory = [:]
        let r = Simulation.advance(&s, seconds: 120, offline: false)
        #expect(s.line(.cinder).status == .noCash)
        #expect(s.stock(.cinder) == 0)
        #expect(s.line(.glimmer).status == .emergency)
        #expect(s.stock(.glimmer) > 0, "the starter line still produces without cash")
        #expect(r.productionSpent == 0)
        let normalRate = Economy.productionRate(s, .glimmer, Economy.mods(s))
        #expect(s.stock(.glimmer) <= normalRate * 120 * 0.5 + Economy.batchSize(s, .glimmer) + 1e-6)
    }

    @Test("Stock is shared fairly between districts that want the same product")
    func fairShare() {
        var s = TS.rich(chapter: 2)
        s = TS.ok(s, .unlockDistrict(.docks))
        s = TS.ok(s, .upgradeRoute(.docks, .glimmer))
        s.updateLine(.glimmer) { $0.running = false }
        s.inventory = [.glimmer: 0.05]
        var report = TickReport()
        Simulation.step(&s, dt: 1, offline: false, report: &report)
        #expect(report.sold > 0)
        #expect(abs(report.sold - 0.05) < 1e-9, "all scarce stock is sold, split across both districts")
        #expect(s.stock(.glimmer) < 1e-9)
    }

    @Test("Selling pushes rivals back slowly, never past the presence cap")
    func passivePresence() {
        var s = TS.rich(chapter: 1)
        s.updateDistrict(.cellars) { $0.rival = 90; $0.routes = [.glimmer: 1] }
        s.inventory = [.glimmer: 100]
        s.storageLevel = 6
        Simulation.advance(&s, seconds: 100, offline: false)
        #expect(s.district(.cellars).rival < 90)
        s.updateDistrict(.cellars) { $0.rival = 80 }
        Simulation.advance(&s, seconds: 600, offline: false)
        #expect(s.district(.cellars).control <= Economy.presenceCap(s, .cellars) + 1e-9)
    }

    @Test("Fronts wash dirty cash at capacity minus their fee and add exposure")
    func laundering() {
        var s = TS.rich(chapter: 1)
        s.reserveMinutes = 0
        s.dirty = 10_000
        s.crew = []
        s.updateLine(.glimmer) { $0.running = false }
        s.updateDistrict(.cellars) { $0.routes = [:] }
        let cleanBefore = s.clean
        let r = Simulation.advance(&s, seconds: 10, offline: false)
        #expect(abs(r.dirtyLaundered - 1.5 * 10) < 1e-9)
        #expect(abs((s.clean - cleanBefore) - 15 * 0.7) < 1e-9)
        #expect(s.heatTarget > 0)
    }

    @Test("A paused front washes nothing")
    func pausedFront() {
        var s = TS.rich(chapter: 1)
        s = TS.ok(s, .setFrontActive(.laundromat, false))
        let r = Simulation.advance(&s, seconds: 10, offline: false)
        #expect(r.dirtyLaundered == 0)
    }

    @Test("The working reserve keeps minutes of street income as dirty cash", arguments: [0, 2, 10, 30])
    func workingReserve(_ minutes: Int) {
        var s = TS.rich(chapter: 1)
        s = TS.ok(s, .setReserve(minutes))
        s.incomeRate = 5
        s.dirty = 1000
        s.updateLine(.glimmer) { $0.running = false }
        s.crew = []
        s.updateDistrict(.cellars) { $0.routes = [:] }
        var report = TickReport()
        Simulation.step(&s, dt: 1, offline: false, report: &report)
        let reserve = 5.0 * 60 * Double(minutes)
        let expected = min(1.5, max(0, 1000 - reserve))
        #expect(abs(report.dirtyLaundered - expected) < 1e-9)
        #expect(TS.error(s, .setReserve(7)) == .invalid)
    }

    @Test("Fees are clamped between 3 % and 60 %")
    func feeClamp() {
        let s = GameState()
        var m = Mods()
        m.feeDelta = -1
        #expect(Economy.frontFee(s, .gallery, m) == 0.03)
        m.feeDelta = 1
        #expect(Economy.frontFee(s, .laundromat, m) == 0.6)
    }

    @Test("Front capacity grows +50 % per level")
    func frontCapacity() {
        var s = TS.rich(chapter: 1)
        let m = Economy.mods(s)
        let base = Economy.frontCapacity(s, .laundromat, m)
        s = TS.ok(s, .upgradeFront(.laundromat))
        #expect(abs(Economy.frontCapacity(s, .laundromat, Economy.mods(s)) / base - 1.5) < 1e-9)
    }
}
