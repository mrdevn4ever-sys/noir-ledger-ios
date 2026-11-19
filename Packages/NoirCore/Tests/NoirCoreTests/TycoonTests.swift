import Foundation
@testable import NoirCore
import Testing

@Suite("Tycoon 3.0: floors, managers, heat, suitcases, missions, change of city")
struct TycoonTests {

    static func ok(_ s: TycoonState, _ a: TycoonAction, sourceLocation: SourceLocation = #_sourceLocation) -> TycoonState {
        let r = Tycoon.apply(s, a)
        #expect(r.error == nil, "action \(a) failed with \(String(describing: r.error))", sourceLocation: sourceLocation)
        return r.state
    }

    static func error(_ s: TycoonState, _ a: TycoonAction) -> ActionError? { Tycoon.apply(s, a).error }

    @Test("A new city has one weed plant, no cash, nothing running")
    func newCity() {
        let s = Tycoon.newCity(seed: 1, nowMs: 1)
        #expect(s.floor(.weed).count == 1)
        #expect(s.cash == 0)
        #expect(!s.floor(.weed).running)
        #expect(Tycoon.hint(s) == .tapWeed)
        #expect(Tycoon.fullRate(s) == 1)
    }

    @Test("Without a manager a tap runs exactly one cycle")
    func tapRunsOneCycle() {
        var s = Tycoon.newCity(seed: 1, nowMs: 1)
        Tycoon.advance(&s, seconds: 5, offline: false)
        #expect(s.cash == 0, "nothing happens without a tap")
        s = Self.ok(s, .tapFloor(.weed))
        Tycoon.advance(&s, seconds: 5, offline: false)
        #expect(s.cash == 1, "one cycle, one unit, one dollar")
        #expect(!s.floor(.weed).running)
        #expect(s.meta.taps == 1)
    }

    @Test("A manager keeps the floor running, also while away")
    func manager() {
        var s = Tycoon.newCity(seed: 1, nowMs: 1_000)
        s.cash = 1_000
        s = Self.ok(s, .hireManager(.weed, .ghost))
        #expect(s.cash == 0)
        #expect(s.floor(.weed).trait == .ghost)
        Tycoon.advance(&s, seconds: 10, offline: false)
        #expect(abs(s.cash - 10) < 1e-9)
        let (back, report) = Tycoon.applyOffline(s, nowMs: 1_000 + 3_600_000)
        let r = try! #require(report)
        #expect(abs(r.earned - 3_600) < 1e-6)
        #expect(abs(back.cash - s.cash - 3_600) < 1e-6)
        #expect(back.meta.offlineBonus == r.earned)
        #expect(Self.error(back, .hireManager(.weed)) == .invalid)
    }

    @Test("Prices grow geometrically and MAX buys as many as the cash allows")
    func buying() {
        var s = Tycoon.newCity(seed: 1, nowMs: 1)
        let one = Tycoon.unitsCost(s, .weed, 1)
        #expect(abs(one - 4 * 1.07) < 1e-9)
        #expect(abs(Tycoon.unitsCost(s, .weed, 3) - (4 * 1.07 + 4 * pow(1.07, 2) + 4 * pow(1.07, 3))) < 1e-9)
        s.cash = 1_000
        let units = Tycoon.affordableUnits(s, .weed)
        #expect(units > 1)
        #expect(Tycoon.unitsCost(s, .weed, units) <= 1_000)
        #expect(Tycoon.unitsCost(s, .weed, units + 1) > 1_000)
        s = Self.ok(s, .buy(.weed, 0))
        #expect(s.floor(.weed).count == 1 + units)
        #expect(s.cash >= 0)
        #expect(Self.error(s, .buy(.pills, 1)) == .locked)
    }

    @Test("Every milestone halves the cycle")
    func milestones() {
        var s = Tycoon.newCity(seed: 1, nowMs: 1)
        #expect(Tycoon.cycleTime(s, .weed) == 1)
        s.updateFloor(.weed) { $0.count = 25 }
        #expect(Tycoon.cycleTime(s, .weed) == 0.5)
        s.updateFloor(.weed) { $0.count = 100 }
        #expect(Tycoon.cycleTime(s, .weed) == 0.125)
        #expect(Tycoon.nextMilestone(100) == 150)
    }

    @Test("Floors open in order")
    func opening() {
        var s = Tycoon.newCity(seed: 1, nowMs: 1)
        s.cash = 1e9
        #expect(Self.error(s, .open(.crystal)) == .locked)
        s = Self.ok(s, .open(.pills))
        s = Self.ok(s, .open(.crystal))
        #expect(s.floor(.crystal).count == 1)
        #expect(Self.error(s, .open(.crystal)) == .invalid)
    }

    @Test("Deals multiply their floor or every floor")
    func deals() {
        var s = Tycoon.newCity(seed: 1, nowMs: 1)
        s.cash = 1e12
        s = Self.ok(s, .open(.pills))
        let before = Tycoon.revenuePerCycle(s, .weed)
        s = Self.ok(s, .buyDeal("weed_1"))
        #expect(Tycoon.revenuePerCycle(s, .weed) == 3 * before)
        let pills = Tycoon.revenuePerCycle(s, .pills)
        s = Self.ok(s, .buyDeal("all_1"))
        #expect(Tycoon.revenuePerCycle(s, .pills) == 3 * pills)
        #expect(Self.error(s, .buyDeal("all_1")) == .invalid)
        #expect(Self.error(s, .buyDeal("coke_1")) == .locked)
    }

    @Test("Heat brings the police; a bribe sends them away, ignoring them costs a quarter of the cash")
    func police() {
        var s = Tycoon.newCity(seed: 1, nowMs: 1)
        s.cash = 1_000
        s = Self.ok(s, .hireManager(.weed))
        s.cash = 10_000
        let calm = 100 / Tycoon.heatRate(s)
        #expect(abs(calm - 600) < 1, "one plain floor takes ten minutes to bring the police")
        Tycoon.advance(&s, seconds: calm - 2, offline: false)
        #expect(s.police == nil)
        Tycoon.advance(&s, seconds: 3, offline: false)
        #expect(s.police != nil)
        let bribed = Self.ok(s, .bribe)
        #expect(bribed.police == nil && bribed.heat == 0 && bribed.counters.bribes == 1)
        let cash = s.cash
        Tycoon.advance(&s, seconds: TycoonContent.policeSeconds + 1, offline: false)
        #expect(s.police == nil)
        #expect(s.counters.raids == 1)
        #expect(s.cash < cash)
        #expect(s.lastRaidLoss != nil)
        s = Self.ok(s, .ackRaid)
        #expect(s.lastRaidLoss == nil)
    }

    @Test("While away Heat stands still and the police wait")
    func offlineIsSafe() {
        var s = Tycoon.newCity(seed: 1, nowMs: 1_000)
        s.cash = 1_000
        s = Self.ok(s, .hireManager(.weed))
        s.police = Police(arrivedAt: 0, deadline: 10)
        s.time = 5
        let (back, _) = Tycoon.applyOffline(s, nowMs: 1_000 + 7_200_000)
        #expect(back.counters.raids == 0)
        #expect(back.police != nil)
        #expect(back.police!.deadline - back.time > 4)
    }

    @Test("A suitcase turns up on the street and pays when grabbed")
    func suitcase() {
        var s = Tycoon.newCity(seed: 7, nowMs: 1)
        s.cash = 1_000
        s = Self.ok(s, .hireManager(.weed))
        Tycoon.advance(&s, seconds: 61, offline: false)
        let c = try! #require(s.suitcase)
        #expect(c.amount >= 25)
        let before = s.cash
        let r = Tycoon.apply(s, .grabSuitcase)
        #expect(r.isOK && r.gained == c.amount)
        #expect(abs(r.state.cash - before - c.amount) < 1e-9)
        #expect(Self.error(r.state, .grabSuitcase) == .invalid)
    }

    @Test("Missions sit on the board three at a time and pay favors once")
    func missions() {
        var s = Tycoon.newCity(seed: 1, nowMs: 1)
        #expect(Tycoon.activeMissions(s).count == 3)
        #expect(Self.error(s, .claimMission("own_weed_10")) == .requirements)
        s.updateFloor(.weed) { $0.count = 10 }
        s = Self.ok(s, .claimMission("own_weed_10"))
        #expect(s.meta.favors == 5)
        #expect(Self.error(s, .claimMission("own_weed_10")) == .invalid)
        #expect(!Tycoon.activeMissions(s).map(\.id).contains("own_weed_10"))
        #expect(Set(TycoonContent.missions.map(\.id)).count == TycoonContent.missions.count)
    }

    @Test("Changing city trades the run for reputation and keeps what was paid for")
    func changeCity() {
        var s = Tycoon.newCity(seed: 1, nowMs: 1)
        #expect(Self.error(s, .changeCity) == .requirements)
        s.runEarned = 1e8
        s.totalEarned = 1e8
        s.cash = 5e7
        s.meta.favors = 40
        s.meta.premium = true
        s.claimedMissions = ["own_weed_10"]
        #expect(Tycoon.reputationGain(s) == 10)
        let fresh = Self.ok(s, .changeCity)
        #expect(fresh.meta.reputation == 10 && fresh.meta.prestiges == 1)
        #expect(fresh.cash == 0 && fresh.floor(.weed).count == 1 && fresh.floor(.pills).count == 0)
        #expect(fresh.meta.favors == 40 && fresh.meta.premium)
        #expect(fresh.totalEarned == 1e8 && fresh.runEarned == 0)
        #expect(fresh.claimedMissions == ["own_weed_10"])
        #expect(Tycoon.reputationMultiplier(fresh) == 2)
    }

    @Test("Favor items, sponsor rewards and store grants work in the tycoon")
    func monetization() {
        var s = Tycoon.newCity(seed: 1, nowMs: 1)
        s = Self.ok(s, .grant(.starter))
        #expect(s.meta.favors == Idle.starterFavors && s.meta.boostSeconds > 0)
        #expect(Tycoon.globalMultiplier(s) == 2)
        #expect(Self.error(s, .buyFavorItem(.warp2h)) == .requirements, "nothing would earn during a jump")
        s.cash = 1_000
        s = Self.ok(s, .hireManager(.weed))
        let cash = s.cash
        s = Self.ok(s, .buyFavorItem(.warp2h))
        #expect(s.cash - cash > 7_200, "two hours of a boosted weed floor")
        s = Self.ok(s, .adReward(.favors, day: 3))
        #expect(Self.error(s, .buyFavorItem(.loyalty)) != nil)
        s.heat = 60
        s = Self.ok(s, .adReward(.coolHeat, day: 3))
        #expect(s.heat == 0)
    }

    @Test("Saves round-trip and damaged values are repaired")
    func save() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tycoon-\(UUID().uuidString)")
        let store = TycoonSaveStore(directory: dir)
        var s = Tycoon.newCity(seed: 9, nowMs: 5)
        s.cash = 123
        s.deals = ["weed_1", "weed_1", "nope"]
        try store.write(s, savedAtMs: 5)
        guard case .loaded(let loaded, let restored) = store.load() else {
            Issue.record("load failed")
            return
        }
        #expect(!restored)
        #expect(loaded.cash == 123)
        #expect(loaded.deals == ["weed_1"])
        try store.write(loaded, savedAtMs: 6)
        try Data("damaged".utf8).write(to: store.primaryURL)
        guard case .loaded(let backup, let fromBackup) = store.load() else {
            Issue.record("backup failed")
            return
        }
        #expect(fromBackup && backup.cash == 123)
        store.erase()
        guard case .fresh = store.load() else {
            Issue.record("erase failed")
            return
        }
    }

    @Test("Cut and laced goods pay more and draw more Heat")
    func cuts() {
        var s = Tycoon.newCity(seed: 1, nowMs: 1)
        s.cash = 1e6
        s = Self.ok(s, .hireManager(.weed, .ghost))
        let pure = Tycoon.revenuePerCycle(s, .weed)
        let pureHeat = Tycoon.heatRate(s)
        #expect(Self.error(s, .setCut(.weed, .pure)) == .invalid)
        #expect(Self.error(s, .setCut(.pills, .cut)) == .locked)
        #expect(!Tycoon.missionDone(s, TycoonContent.mission("cut_1")!))
        s = Self.ok(s, .setCut(.weed, .cut))
        #expect(abs(Tycoon.revenuePerCycle(s, .weed) - 1.6 * pure) < 1e-9)
        #expect(Tycoon.missionDone(s, TycoonContent.mission("cut_1")!))
        s = Self.ok(s, .setCut(.weed, .laced))
        #expect(abs(Tycoon.revenuePerCycle(s, .weed) - 2.5 * pure) < 1e-9)
        #expect(Tycoon.heatRate(s) > 2 * pureHeat)
    }

    @Test("The hustler sells half as much again, the ghost draws half the Heat")
    func managerTraits() {
        var s = Tycoon.newCity(seed: 1, nowMs: 1)
        s.cash = 1e6
        let plain = Tycoon.revenuePerCycle(s, .weed)
        let hustler = Self.ok(s, .hireManager(.weed, .hustler))
        let ghost = Self.ok(s, .hireManager(.weed, .ghost))
        #expect(abs(Tycoon.revenuePerCycle(hustler, .weed) - 1.5 * plain) < 1e-9)
        #expect(Tycoon.revenuePerCycle(ghost, .weed) == plain)
        #expect(Tycoon.heatWeight(ghost, .weed) == 0.5 && Tycoon.heatWeight(hustler, .weed) == 1)
        #expect(Tycoon.heatRate(ghost) < Tycoon.heatRate(hustler))
        let lacedGhost = Self.ok(ghost, .setCut(.weed, .laced))
        #expect(Tycoon.heatWeight(lacedGhost, .weed) == 2)
    }

    @Test("Laced goods keep heating up while away and can end in a raid; pure goods are safe")
    func offlineRaid() {
        var s = Tycoon.newCity(seed: 1, nowMs: 1_000)
        s.cash = 1_000
        s = Self.ok(s, .hireManager(.weed))
        #expect(Tycoon.offlineHeatRate(s) == 0)
        let (safe, safeReport) = Tycoon.applyOffline(s, nowMs: 1_000 + 7_200_000)
        #expect(safe.counters.raids == 0 && (safeReport?.raidLoss ?? 0) == 0)
        s = Self.ok(s, .setCut(.weed, .laced))
        #expect(Tycoon.offlineHeatRate(s) > 0)
        let (hot, report) = Tycoon.applyOffline(s, nowMs: 1_000 + 7_200_000)
        let r = try! #require(report)
        #expect(hot.counters.raids == 1)
        #expect(r.raidLoss > 0 && hot.lastRaidLoss == r.raidLoss)
        #expect(hot.heat == 0 && hot.police == nil)
        #expect(r.earned > safeReport!.earned, "laced goods still paid more while they lasted")
    }

    @Test("The phone rings, waits 25 seconds and pays what the answer says")
    func calls() {
        var s = Tycoon.newCity(seed: 4, nowMs: 1)
        s.cash = 1_000
        s = Self.ok(s, .hireManager(.weed, .ghost))
        #expect(Self.error(s, .answerCall(0)) == .invalid)
        Tycoon.advance(&s, seconds: TycoonContent.firstCall + 1, offline: false)
        let c = try! #require(s.call)
        let def = try! #require(TycoonContent.call(c.id))
        #expect(def.needs == .weed, "only calls for open floors ring")
        #expect(c.expiresAt - s.time <= TycoonContent.callSeconds)
        #expect(Self.error(s, .answerCall(def.options.count)) == .invalid)
        // Hanging up.
        let hung = Self.ok(s, .declineCall)
        #expect(hung.call == nil && hung.counters.calls == 0)
        // Letting it ring out.
        var rang = s
        Tycoon.advance(&rang, seconds: TycoonContent.callSeconds + 1, offline: false)
        #expect(rang.call?.id != c.id)
        // A plain cash answer.
        var t = s
        t.call = ActiveCall(id: "stag", expiresAt: t.time + 20)
        t.heat = 0
        let unit = Tycoon.callUnit(t)
        let r = Tycoon.apply(t, .answerCall(0))
        #expect(r.isOK && r.won == nil)
        #expect(abs(r.gained - 60 * unit) < 1e-6)
        #expect(r.state.heat == 10 && r.state.call == nil && r.state.counters.calls == 1)
        // A rush doubles sales for a while.
        var u = s
        u.call = ActiveCall(id: "rain", expiresAt: u.time + 20)
        u.cash = 1e6
        let before = Tycoon.revenuePerCycle(u, .weed)
        u = Self.ok(u, .answerCall(0))
        #expect(Tycoon.revenuePerCycle(u, .weed) == 2 * before)
        Tycoon.advance(&u, seconds: 121, offline: false)
        #expect(Tycoon.revenuePerCycle(u, .weed) == before)
        // A payment needs the cash.
        var poor = s
        poor.call = ActiveCall(id: "copper", expiresAt: poor.time + 20)
        poor.cash = 0
        #expect(Self.error(poor, .answerCall(0)) == .notAffordable)
        // A short trip to another app does not hang up; a long one does.
        let (brief, _) = Tycoon.applyOffline(s, nowMs: s.lastWallClockMs + 8_000)
        #expect(brief.call == s.call)
        let (long, _) = Tycoon.applyOffline(s, nowMs: s.lastWallClockMs + 600_000)
        #expect(long.call == nil)
        // Heat from a call can bring the police.
        var hot = s
        hot.call = ActiveCall(id: "dog", expiresAt: hot.time + 20)
        hot.heat = 90
        hot = Self.ok(hot, .answerCall(1))
        #expect(hot.police != nil)
    }

    @Test("A gamble can go either way, decided by the city's own dice")
    func gambles() {
        var wins = 0, losses = 0
        for seed in UInt64(1)...40 {
            var s = Tycoon.newCity(seed: seed, nowMs: 1)
            s.call = ActiveCall(id: "stag", expiresAt: 100)
            let r = Tycoon.apply(s, .answerCall(1))
            #expect(r.isOK)
            if r.won == true { wins += 1; #expect(r.gained > 0) } else { losses += 1; #expect(r.state.heat == 35) }
        }
        #expect(wins > 10 && losses > 5)
        for call in TycoonContent.calls {
            #expect(call.options.count >= 2 && call.options.count <= 3, "\(call.id)")
            #expect(Content.crewDef(call.caller) != nil, "\(call.id) has a caller with a portrait")
        }
        #expect(Set(TycoonContent.calls.map(\.id)).count == TycoonContent.calls.count)
    }

    /// A greedy player who taps every idle floor, hires managers and deals as soon as possible and otherwise buys the
    /// units with the best price per income. Mirrors the pacing model the content was tuned with.
    struct Player {
        var s: TycoonState
        var firsts: [String: Double] = [:]

        mutating func play(minutes: Double) {
            let end = s.time + minutes * 60
            while s.time < end {
                for f in FloorId.allCases where Tycoon.isOpen(s, f) && !s.floor(f).running {
                    s = Tycoon.apply(s, .tapFloor(f)).state
                }
                if s.police != nil { s = Tycoon.apply(s, .bribe).state }
                if s.suitcase != nil { s = Tycoon.apply(s, .grabSuitcase).state }
                for f in FloorId.allCases where Tycoon.isOpen(s, f) && !s.floor(f).manager {
                    let r = Tycoon.apply(s, .hireManager(f))
                    if r.isOK { s = r.state; firsts["manager_\(f.rawValue)", default: s.time] = firsts["manager_\(f.rawValue)"] ?? s.time }
                }
                for d in TycoonContent.deals where !s.deals.contains(d.id) {
                    let r = Tycoon.apply(s, .buyDeal(d.id))
                    if r.isOK { s = r.state }
                }
                for f in FloorId.allCases where !Tycoon.isOpen(s, f) {
                    let r = Tycoon.apply(s, .open(f))
                    if r.isOK { s = r.state; firsts["open_\(f.rawValue)"] = s.time }
                }
                while true {
                    var best: (value: Double, floor: FloorId)?
                    for f in FloorId.allCases where Tycoon.isOpen(s, f) {
                        let cost = Tycoon.unitsCost(s, f, 1)
                        guard cost <= s.cash else { continue }
                        var next = s
                        next.updateFloor(f) { $0.count += 1 }
                        let gain = Tycoon.floorRate(next, f) - Tycoon.floorRate(s, f)
                        let value = cost / max(gain, 1e-9)
                        if best == nil || value < best!.value { best = (value, f) }
                    }
                    guard let pick = best else { break }
                    s = Tycoon.apply(s, .buy(pick.floor, 1)).state
                }
                Tycoon.advance(&s, seconds: 0.25, offline: false)
            }
        }
    }

    @Test("The first half hour opens every floor and earns a first change of city")
    func pacing() {
        var p = Player(s: Tycoon.newCity(seed: 3, nowMs: 1))
        p.play(minutes: 35)
        let open = p.firsts.filter { $0.key.hasPrefix("open_") }
        print("pacing:", p.firsts.sorted { $0.value < $1.value }.map { "\($0.key)=\(String(format: "%.1f", $0.value / 60))min" }.joined(separator: " "),
              "earned=\(p.s.runEarned) reputation=\(Tycoon.reputationGain(p.s))")
        #expect((p.firsts["open_PILLS"] ?? .infinity) < 3 * 60, "pills within three minutes")
        #expect((p.firsts["open_CRYSTAL"] ?? .infinity) < 6 * 60, "crystal within six minutes")
        #expect((p.firsts["open_COKE"] ?? .infinity) < 12 * 60, "coke within twelve minutes")
        #expect(open.count == 3)
        #expect(FloorId.allCases.allSatisfy { p.s.floor($0).manager }, "every floor has a manager after half an hour")
        #expect(Tycoon.reputationGain(p.s) >= 5, "a change of city is worth it after half an hour")
        #expect(p.s.cash.isFinite && p.s.cash >= 0)
    }
}
