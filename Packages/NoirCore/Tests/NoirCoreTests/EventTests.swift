import Foundation
import NoirCore
import Testing

@Suite("Decisions (events)")
struct EventTests {

    /// A late-game state in which every one of the fifteen events is eligible.
    private func everythingEligible() -> GameState {
        var s = TS.rich(chapter: 3)
        for d in DistrictId.allCases { s.updateDistrict(d) { $0.unlocked = true; $0.rival = 40 } }
        s.crew = [CrewMember(defId: "brandt"), CrewMember(defId: "varga"), CrewMember(defId: "okafor"), CrewMember(defId: "feld")]
        s.inventory = [.glimmer: 50]
        s.heat = 35
        return s
    }

    @Test("Every authored event has a reachable eligibility rule", arguments: EventId.allCases)
    func eligibility(_ e: EventId) {
        var s = everythingEligible()
        if e == .hilltopGala { s.campaign.chapter = 4 }
        #expect(Events.eligible(s, e))
    }

    @Test("Eligibility rules exclude events that make no sense yet")
    func ineligible() {
        let s = TS.briefed()
        #expect(!Events.eligible(s, .journalist))
        #expect(!Events.eligible(s, .clubNight))
        #expect(!Events.eligible(s, .dockStrike))
        #expect(!Events.eligible(s, .unionMuscle))
        #expect(!Events.eligible(s, .hilltopGala))
        #expect(!Events.eligible(s, .informant))
        #expect(Events.eligible(s, .shipmentTip))
    }

    @Test("Every choice of every event resolves, pays its cost and applies a stated outcome", arguments: EventId.allCases)
    func resolveAllChoices(_ e: EventId) {
        var base = everythingEligible()
        if e == .hilltopGala { base.campaign.chapter = 4 }
        let created = Events.create(&base, e)
        base.pendingEvent = created
        let pending = base.pendingEvent!
        for choice in Events.choices(pending) {
            let before = base
            let r = Engine.apply(before, .resolveEvent(choice.key))
            guard choice.available(before) else {
                #expect(r.error == .notAffordable)
                continue
            }
            #expect(r.error == nil, "\(e):\(choice.key)")
            let s = r.state
            #expect(s.pendingEvent == nil)
            #expect(s.stats.eventsResolved == before.stats.eventsResolved + 1)
            #expect(s.eventLastSeen[e] == before.time)
            #expect(r.outcome >= 0 && r.outcome < choice.outcomes.count)
            let effects = choice.outcomes[r.outcome].effects
            if effects.heat == 0 && effects.dirty == 0 {
                #expect(abs(s.dirty - (before.dirty - choice.cost.dirty)) < 1e-6)
            }
            if !effects.mods.isEmpty {
                #expect(s.modifiers.count == before.modifiers.count + effects.mods.count)
            }
            TS.expectSane(s)
            // Deterministic: the same state and choice always lead to the same outcome.
            #expect(Engine.apply(before, .resolveEvent(choice.key)).state == s)
        }
    }

    @Test("Amounts scale with income and are frozen when the event appears")
    func frozenUnits() {
        var s = TS.rich(chapter: 2)
        s.incomeRate = 50
        s.cleanRate = 20
        let p = Events.create(&s, .shipmentTip)
        #expect(p.unit == 3000)
        #expect(p.cleanUnit == 1200)
        #expect(p.influenceUnit == 15)
        s.pendingEvent = p
        s.incomeRate = 500
        #expect(Events.choices(s.pendingEvent!).first?.cost == Cost(dirty: 9000))
    }

    @Test("Events arrive every 4–7 minutes of active play, never during the briefing or while away")
    func timing() {
        var s = TS.briefed()
        #expect(s.pendingEvent == nil)
        #expect(abs(s.nextEventAt - (s.time + 240)) < 1e-9)
        var away = s
        Simulation.advance(&away, seconds: 3600, offline: true, step: 2)
        #expect(away.pendingEvent == nil, "no decisions while away")
        TS.advance(&s, until: { $0.pendingEvent != nil }, maxSeconds: 400)
        #expect(s.pendingEvent != nil)
        let gap = s.nextEventAt - s.time
        #expect(gap >= 240 - 1e-9 && gap <= 420 + 1e-9)

        var fresh = Engine.newGame(seed: 5, nowMs: 1)
        fresh = TS.ok(fresh, .choosePrologue(.contacts))
        Simulation.advance(&fresh, seconds: 900, offline: false)
        #expect(fresh.pendingEvent == nil, "no decisions during the briefing")
    }

    @Test("A choice that needs a role or money is refused when it is not available")
    func unavailableChoice() {
        var s = TS.rich(chapter: 2)
        s.crew = []
        let created = Events.create(&s, .inspector)
        s.pendingEvent = created
        #expect(TS.error(s, .resolveEvent("fixer")) == .notAffordable)
        #expect(TS.error(s, .resolveEvent("unknown")) == .notAffordable)
        #expect(TS.error(s, .resolveEvent("refuse")) == nil)
    }

    @Test("Timed modifiers expire")
    func modifiersExpire() {
        var s = TS.rich(chapter: 2)
        let created = Events.create(&s, .powerCut)
        s.pendingEvent = created
        s = TS.ok(s, .resolveEvent("wait"))
        #expect(Economy.cycleTime(s, .glimmer, Economy.mods(s)).isInfinite)
        Simulation.advance(&s, seconds: 121, offline: false)
        #expect(s.modifiers.isEmpty)
        #expect(Economy.cycleTime(s, .glimmer, Economy.mods(s)).isFinite)
    }
}
