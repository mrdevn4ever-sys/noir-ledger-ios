import Foundation
import NoirCore
import Testing

enum TS {
    /// Applies an action and records an issue if the engine rejects it.
    @discardableResult
    static func ok(_ s: GameState, _ a: Action, sourceLocation: SourceLocation = #_sourceLocation) -> GameState {
        let r = Engine.apply(s, a)
        #expect(r.error == nil, "action \(a) failed with \(String(describing: r.error))", sourceLocation: sourceLocation)
        return r.state
    }

    static func error(_ s: GameState, _ a: Action) -> ActionError? { Engine.apply(s, a).error }

    /// Advances online until `condition` holds or `maxSeconds` pass. Returns whether the condition was met.
    @discardableResult
    static func advance(_ s: inout GameState, until condition: (GameState) -> Bool, maxSeconds: Double) -> Bool {
        var t = 0.0
        while t < maxSeconds {
            if condition(s) { return true }
            Simulation.advance(&s, seconds: 1, offline: false)
            t += 1
        }
        return condition(s)
    }

    /// A fresh campaign played through the prologue and the seven-step briefing with real actions.
    static func briefed(seed: UInt64 = 7, choice: PrologueChoice = .cashBox) -> GameState {
        var s = Engine.newGame(seed: seed, nowMs: 1_000)
        s = ok(s, .choosePrologue(choice))
        s = ok(s, .setLineRunning(.glimmer, true))
        advance(&s, until: { $0.campaign.tutorial == .openRoute }, maxSeconds: 600)
        s = ok(s, .upgradeRoute(.cellars, .glimmer))
        advance(&s, until: { $0.campaign.tutorial == .buyFront }, maxSeconds: 3600)
        s = ok(s, .buyFront(.laundromat))
        advance(&s, until: { $0.campaign.tutorial == .heatBriefing }, maxSeconds: 3600)
        s = ok(s, .ackTutorial)
        return s
    }

    /// A rich mid-game state for formula tests: briefing done, chosen chapter, plenty of every currency.
    static func rich(chapter: Int, seed: UInt64 = 3) -> GameState {
        var s = briefed(seed: seed)
        s.campaign.chapter = chapter
        s.dirty = 10_000_000
        s.clean = 10_000_000
        s.influence = 50_000
        s.pendingEvent = nil
        s.nextEventAt = 1e12
        return s
    }

    /// State with every number finite and inside its legal range.
    static func expectSane(_ s: GameState, sourceLocation: SourceLocation = #_sourceLocation) {
        let values = [s.dirty, s.clean, s.influence, s.heat, s.time, s.incomeRate, s.cleanRate] + s.inventory.values.map { $0 }
        #expect(values.allSatisfy(\.isFinite), "non-finite value", sourceLocation: sourceLocation)
        #expect(s.dirty >= -1e-6 && s.clean >= -1e-6 && s.influence >= -1e-6, "negative currency", sourceLocation: sourceLocation)
        #expect(s.heat >= 0 && s.heat <= 100, "heat out of range", sourceLocation: sourceLocation)
        #expect(s.inventory.values.allSatisfy { $0 >= -1e-6 }, "negative stock", sourceLocation: sourceLocation)
        let roles = s.crew.compactMap { $0.def?.role }
        #expect(Set(roles).count == roles.count, "duplicate crew role", sourceLocation: sourceLocation)
    }
}
