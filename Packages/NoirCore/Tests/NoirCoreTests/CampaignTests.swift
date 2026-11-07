import Foundation
import NoirCore
import Testing

@Suite("Prologue, briefing, chapters, final operation and New Game+")
struct CampaignTests {

    @Test("The prologue choice is real and changes the start", arguments: PrologueChoice.allCases)
    func prologue(_ choice: PrologueChoice) {
        let fresh = Engine.newGame(seed: 9, nowMs: 1)
        #expect(!fresh.campaign.prologueDone)
        #expect(TS.error(fresh, .setLineRunning(.glimmer, true)) == .locked, "nothing happens before the prologue")
        let s = TS.ok(fresh, .choosePrologue(choice))
        #expect(s.campaign.prologueChoice == choice)
        switch choice {
        case .cashBox: #expect(s.dirty == fresh.dirty + 600)
        case .contacts: #expect(s.influence == 15)
        case .tools:
            #expect(s.line(.glimmer).capacityLevel == 2)
            #expect(s.line(.glimmer).speedLevel == 2)
        }
        #expect(TS.error(s, .choosePrologue(.cashBox)) == .invalid)
    }

    @Test("The seven-step briefing advances only through real play")
    func briefing() {
        var s = Engine.newGame(seed: 11, nowMs: 1)
        s = TS.ok(s, .choosePrologue(.tools))
        #expect(s.campaign.tutorial == .startLine)
        #expect(TS.error(s, .upgradeRoute(.cellars, .glimmer)) == .tutorial)
        #expect(TS.error(s, .buyFront(.laundromat)) == .tutorial)
        #expect(TS.error(s, .ackTutorial) == .tutorial)
        #expect(TS.error(s, .upgradeStorage) == .tutorial)
        s = TS.ok(s, .setLineRunning(.glimmer, true))
        #expect(s.campaign.tutorial == .stockUp)
        #expect(TS.advance(&s, until: { $0.campaign.tutorial == .openRoute }, maxSeconds: 300))
        #expect(s.stock(.glimmer) >= tutorialStockTarget)
        let dirty = s.dirty
        s = TS.ok(s, .upgradeRoute(.cellars, .glimmer))
        #expect(s.dirty == dirty, "Leopold's old corner is free")
        #expect(s.campaign.tutorial == .earn)
        #expect(TS.advance(&s, until: { $0.campaign.tutorial == .buyFront }, maxSeconds: 1800))
        s = TS.ok(s, .buyFront(.laundromat))
        #expect(s.campaign.tutorial == .launder)
        #expect(TS.advance(&s, until: { $0.campaign.tutorial == .heatBriefing }, maxSeconds: 1800))
        #expect(s.campaign.chapter == 0)
        s = TS.ok(s, .ackTutorial)
        #expect(s.campaign.tutorial == .done)
        #expect(s.campaign.chapter == 1)
        #expect(s.time < 900, "the briefing takes a few minutes")
    }

    @Test("Completing a chapter pays its reward and opens the next")
    func chapterTransition() {
        var s = TS.rich(chapter: 1)
        s.dirty = 5000
        s = TS.ok(s, .upgradeLine(.glimmer, .capacity))
        s = TS.ok(s, .upgradeLine(.glimmer, .capacity))
        s = TS.ok(s, .upgradeLine(.glimmer, .speed))
        s = TS.ok(s, .hire("brandt"))
        s.stats.dirtyEarned = 3000
        s.stats.cleanLaundered = 1499
        s = Engine.apply(s, .setReserve(0)).state
        #expect(s.campaign.chapter == 1)
        let dirty = s.dirty
        s = TS.ok(s, .hire("varga"))
        #expect(s.campaign.chapter == 1)
        s.stats.cleanLaundered = 1500
        s = TS.ok(s, .setReserve(2))
        #expect(s.campaign.chapter == 2)
        #expect(abs(s.dirty - (dirty - 350 + 1000)) < 1e-6)
        #expect(s.journal.contains { $0.kind == .chapterComplete && $0.ref == "1" })
        #expect(Campaign.objectives(s).count == 4)
    }

    @Test("Objective progress reports current and target")
    func objectiveProgress() {
        let s = TS.rich(chapter: 2)
        let objs = Campaign.objectives(s)
        #expect(objs.map(\.objective) == Content.objectives(chapter: 2))
        #expect(objs.allSatisfy { $0.fraction >= 0 && $0.fraction <= 1 })
        #expect(!objs[0].done)
    }

    @Test("Districts open by chapter, clean money and an influence threshold that is not spent")
    func districtUnlock() {
        var s = TS.rich(chapter: 2)
        #expect(TS.error(s, .unlockDistrict(.neonMile)) == .locked)
        s.campaign.chapter = 3
        s.influence = 10
        #expect(TS.error(s, .unlockDistrict(.neonMile)) == .requirements)
        s.influence = 60
        s = TS.ok(s, .unlockDistrict(.neonMile))
        #expect(s.influence == 60)
        #expect(TS.error(s, .unlockDistrict(.neonMile)) == .invalid)
    }

    @Test("Lines open by chapter; fronts need a foothold in their district")
    func linesAndFronts() {
        var s = TS.rich(chapter: 1)
        #expect(TS.error(s, .buyLine(.cinder)) == .locked)
        #expect(TS.error(s, .buyFront(.taxi)) == .locked)
        s.campaign.chapter = 2
        s = TS.ok(s, .buyLine(.cinder))
        #expect(s.line(.cinder).running)
        s = TS.ok(s, .unlockDistrict(.docks))
        s = TS.ok(s, .buyFront(.taxi))
        #expect(s.front(.taxi).owned)
        #expect(TS.error(s, .buyFront(.taxi)) == .invalid)
    }

    private func finalReady(ng: Int = 0) -> GameState {
        var s = TS.rich(chapter: 6)
        s.legacy.ngLevel = ng
        for d in DistrictId.allCases { s.updateDistrict(d) { $0.unlocked = true; $0.rival = 20 } }
        s.clean = Content.finalCleanRequired(ng: ng) * 2
        s.influence = Content.finalInfluenceRequired(ng: ng) * 2
        s.dirty = 3_000_000
        s.heat = 10
        s.crew = ["kessler", "hollis", "sand", "reiter", "kraus", "lind"].map { CrewMember(defId: $0, loyalty: 85) }
        return s
    }

    @Test("The final operation needs 70 % control everywhere, clean cash, influence and Heat below 50")
    func finalRequirements() {
        var s = finalReady()
        #expect(Campaign.finalReady(s))
        s.heat = 50
        #expect(!Campaign.finalReady(s))
        #expect(TS.error(s, .startFinalOp) == .requirements)
        s.heat = 10
        s.updateDistrict(.foundry) { $0.rival = 31 }
        #expect(!Campaign.finalReady(s))
        s.updateDistrict(.foundry) { $0.rival = 20 }
        let clean = s.clean
        let influence = s.influence
        s = TS.ok(s, .startFinalOp)
        #expect(s.campaign.finalOp?.phase == 0)
        #expect(abs(clean - s.clean - 600_000) < 1e-6, "war chest: half the clean requirement")
        #expect(abs(influence - s.influence - 480) < 1e-6, "war chest: 40 % of the influence requirement")
    }

    @Test("Three phases with certain and risky choices lead to a real win, epilogue and legacy points")
    func finalOperationWin() {
        var s = TS.ok(finalReady(), .startFinalOp)
        #expect(Campaign.currentPhase(s) == .cityHall)
        s = TS.ok(s, .finalOpChoice("votes"))
        #expect(Campaign.currentPhase(s) == .convoy)
        s = TS.ok(s, .finalOpChoice("payoff"))
        #expect(Campaign.currentPhase(s) == .ledger)
        var attempts = 0
        while !s.campaign.won && attempts < 20 {
            attempts += 1
            let r = Engine.apply(s, .finalOpChoice("lawyer"))
            #expect(r.error == nil)
            s = r.state
            if !r.success {
                #expect(s.campaign.finalOp?.lastResult == .failure)
                #expect(TS.error(s, .finalOpChoice("lawyer")) == .cooldown)
                Simulation.advance(&s, seconds: Content.finalPhaseCooldown + 1, offline: false)
            }
        }
        #expect(s.campaign.won)
        #expect(s.campaign.legacyAwarded == Content.legacyAward(s))
        #expect(s.legacy.points == s.campaign.legacyAwarded)
        #expect(s.legacy.wins == 1)
        #expect(TS.error(s, .finalOpChoice("lawyer")) == .invalid)
        #expect(!s.campaign.epilogueSeen)
        s = TS.ok(s, .markEpilogueSeen)
        #expect(s.campaign.epilogueSeen)
    }

    @Test("Role-gated final choices need the specialist")
    func finalRoleGate() {
        var s = finalReady()
        s.crew = []
        s = TS.ok(s, .startFinalOp)
        #expect(TS.error(s, .finalOpChoice("leverage")) == .requirements)
        #expect(TS.error(s, .finalOpChoice("nonsense")) == .invalid)
    }

    @Test("A failed phase costs the stake, adds Heat and imposes a 120 s regroup")
    func finalFailure() {
        var s = TS.ok(finalReady(), .startFinalOp)
        // Find a seed state in which the 45 % gamble fails.
        var failed = false
        for _ in 0..<40 {
            let r = Engine.apply(s, .finalOpChoice("blackmail"))
            if !r.success {
                #expect(r.state.campaign.finalOp?.failures == 1)
                #expect(abs(r.state.heat - (s.heat + 12 + 10)) < 1e-9)
                #expect(abs((r.state.campaign.finalOp?.readyAt ?? 0) - (s.time + 120)) < 1e-9)
                failed = true
                break
            }
            _ = Rng.next(&s)
        }
        #expect(failed)
    }

    @Test("Legacy points: 10 + improvements/2 (max 8) + 3 without raids + investigations survived (max 4)")
    func legacyFormula() {
        var s = GameState()
        #expect(Content.legacyAward(s) == 13)
        s.upgrades = Array(UpgradeId.allCases.prefix(20))
        s.stats.raids = 2
        s.stats.investigationsSurvived = 9
        #expect(Content.legacyAward(s) == 10 + 8 + 0 + 4)
    }

    @Test("New Game+ keeps legacy, skips the prologue and briefing, and strengthens rivals and the final operation")
    func newGamePlus() {
        var s = TS.ok(finalReady(), .startFinalOp)
        s.campaign.won = true
        s.legacy.points = 20
        s.legacy.wins = 1
        s.legacy.perks = [.startingCapital: 1]
        #expect(TS.error(TS.rich(chapter: 6), .startNewGamePlus) == .requirements)
        let ng = TS.ok(s, .startNewGamePlus)
        #expect(ng.legacy.ngLevel == 1)
        #expect(ng.legacy.points == 20)
        #expect(ng.legacy.rank(.startingCapital) == 1)
        #expect(ng.campaign.prologueDone)
        #expect(ng.campaign.tutorial == .done)
        #expect(ng.campaign.chapter == 1)
        #expect(!ng.campaign.won)
        #expect(ng.dirty == Engine.startDirty + 2000 + 300)
        #expect(ng.district(.docks).rival == 70)
        #expect(ng.upgrades.isEmpty && ng.crew.isEmpty)
        #expect(ng.line(.glimmer).running)
        #expect(ng.district(.cellars).route(.glimmer) == 1)
        #expect(Content.finalCleanRequired(ng: 1) == 1_500_000)
        #expect(Campaign.finalChoices(ng, .cityHall).first?.cost == Cost(clean: 375_000))
        #expect(ng.journal.first?.kind == .newGamePlus)
    }

    @Test("Perks cost rank + 1 points and stop at their maximum rank")
    func perkPurchase() {
        var s = TS.rich(chapter: 1)
        s.legacy.points = 3
        s = TS.ok(s, .buyPerk(.knownName))
        s = TS.ok(s, .buyPerk(.knownName))
        #expect(s.legacy.points == 0)
        #expect(TS.error(s, .buyPerk(.knownName)) == .notAffordable)
        s.legacy.points = 100
        s = TS.ok(s, .buyPerk(.knownName))
        #expect(TS.error(s, .buyPerk(.knownName)) == .maxLevel)
        #expect(s.legacy.points == 97)
    }
}
