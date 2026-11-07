import Foundation
import NoirCore
import Testing

@Suite("Offline progress and clock protection")
struct OfflineTests {

    private func base() -> GameState {
        var s = TS.rich(chapter: 2)
        s.lastWallClockMs = 1_700_000_000_000
        return s
    }

    @Test("Time away is credited up to eight hours")
    func cap() throws {
        let s = base()
        let (after, report) = Engine.applyOffline(s, nowMs: s.lastWallClockMs + 20 * 3600 * 1000)
        let r = try #require(report)
        #expect(r.awaySeconds == 20 * 3600)
        #expect(r.creditedSeconds == 8 * 3600)
        #expect(r.capped)
        #expect(!r.clockMovedBack)
        #expect(abs(after.time - s.time - 8 * 3600) < 1e-6)
        #expect(abs(after.stats.offlineSeconds - s.stats.offlineSeconds - 8 * 3600) < 1e-6)
        #expect(after.lastWallClockMs == s.lastWallClockMs + 20 * 3600 * 1000)
        #expect(r.dirtyEarned > 0)
        #expect(after.journal.first?.kind == .offlineReturn)
    }

    @Test("A clock set backwards credits nothing and resets the reference")
    func backwardsClock() throws {
        let s = base()
        let (after, report) = Engine.applyOffline(s, nowMs: s.lastWallClockMs - 3_600_000)
        let r = try #require(report)
        #expect(r.clockMovedBack)
        #expect(r.creditedSeconds == 0)
        #expect(after.time == s.time)
        #expect(after.dirty == s.dirty)
        #expect(after.lastWallClockMs == s.lastWallClockMs - 3_600_000)
        // Returning to the correct time later credits only the real gap from the new reference.
        let (later, laterReport) = Engine.applyOffline(after, nowMs: after.lastWallClockMs + 120_000)
        #expect(laterReport?.creditedSeconds == 120)
        #expect(abs(later.time - s.time - 120) < 1e-6)
    }

    @Test("An absurd forward jump is capped at eight hours")
    func absurdJump() throws {
        let s = base()
        let (after, report) = Engine.applyOffline(s, nowMs: s.lastWallClockMs + 50 * 365 * 24 * 3_600_000)
        let r = try #require(report)
        #expect(r.creditedSeconds == Content.offlineCapSeconds)
        #expect(abs(after.time - s.time - 8 * 3600) < 1e-6)
    }

    @Test("Short gaps are credited silently; under five seconds nothing happens")
    func shortGaps() {
        let s = base()
        let (a, ra) = Engine.applyOffline(s, nowMs: s.lastWallClockMs + 30_000)
        #expect(ra == nil)
        #expect(abs(a.time - s.time - 30) < 1e-6)
        let (b, rb) = Engine.applyOffline(s, nowMs: s.lastWallClockMs + 3_000)
        #expect(rb == nil)
        #expect(b.time == s.time)
    }

    @Test("While away: no events, no raids, Heat stays below 74, the countdown pauses, loyalty never falls below 10")
    func awayRules() {
        var s = base()
        s.heat = 70
        s.investigation = Investigation(startedAt: s.time, endsAt: s.time + 60, district: .cellars)
        s.crew = [CrewMember(defId: "varga", loyalty: 30)]
        s.dirty = 0
        s.wagesUnpaid = true
        s.fronts = s.fronts.mapValues { var f = $0; f.active = false; return f }
        s.updateDistrict(.cellars) { $0.routes = [.glimmer: 10]; $0.rival = 0 }
        s.inventory = [.glimmer: 5000]
        s.influence = 0
        s.storageLevel = 12
        s.nextEventAt = s.time
        let (after, report) = Engine.applyOffline(s, nowMs: s.lastWallClockMs + 4 * 3600 * 1000)
        #expect(report != nil)
        #expect(after.pendingEvent == nil)
        #expect(after.stats.raids == 0)
        #expect(after.heat <= 74 + 1e-9)
        let inv = after.investigation
        #expect(inv != nil)
        let ends: Double = inv?.endsAt ?? 0
        let started: Double = inv?.startedAt ?? 0
        let window: Double = ends - started
        #expect(abs(window - 14_460) < 1e-6, "the case file does not move while away")
        #expect((after.crewIn(.courier)?.loyalty ?? 0) >= 10)
    }

    @Test("Offline time without a finished prologue credits nothing")
    func beforePrologue() {
        let s = Engine.newGame(seed: 1, nowMs: 1000)
        let (after, report) = Engine.applyOffline(s, nowMs: 1000 + 3_600_000)
        #expect(report == nil)
        #expect(after.time == 0)
    }

    @Test("Online ticks never credit more than five seconds at once")
    func onlineTickClamp() {
        let s = base()
        let after = Engine.tick(s, dtSec: 3600, nowMs: s.lastWallClockMs + 3_600_000)
        #expect(abs(after.time - s.time - 5) < 1e-9)
        let negative = Engine.tick(s, dtSec: -10, nowMs: s.lastWallClockMs)
        #expect(negative.time == s.time)
    }
}
