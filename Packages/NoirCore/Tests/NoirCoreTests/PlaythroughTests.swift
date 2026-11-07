import Foundation
import NoirCore
import Testing

/// End-to-end balance proof: a greedy autoplayer starting from a fresh save plays the prologue and the briefing,
/// reaches every chapter in order, completes the final operation and then wins again in New Game+.
@Suite("Deterministic campaign playthroughs")
struct PlaythroughTests {

    static let maxGameSeconds = 30.0 * 3600

    @Test("A fresh campaign is winnable and paced within 4–20 hours", arguments: [UInt64(1), 42, 2024])
    func campaign(seed: UInt64) {
        var bot = Bot(Engine.newGame(seed: seed, nowMs: 1))
        let won = bot.run(maxSeconds: Self.maxGameSeconds)
        #expect(won, "seed \(seed) must win (stuck in chapter \(bot.s.campaign.chapter))")
        let hours = bot.s.time / 3600
        #expect(hours > 4, "seed \(seed) campaign too short: \(hours) h")
        #expect(hours < 20, "seed \(seed) campaign too long: \(hours) h")
        #expect(bot.chapterOrder.filter { $0 >= 1 } == [1, 2, 3, 4, 5, 6], "every chapter is reached, in order")
        #expect(bot.tutorialStepsSeen.contains(.done))
        #expect(bot.s.campaign.prologueChoice == .cashBox)
        #expect(bot.s.campaign.finalOp?.phase == FinalPhase.allCases.count)
        #expect(bot.s.legacy.points == Content.legacyAward(bot.s))
        #expect(bot.s.stats.investigations >= 1, "Heat is a real constraint")
        #expect(DistrictId.allCases.allSatisfy { bot.s.district($0).unlocked })
        #expect(FrontId.allCases.allSatisfy { bot.s.front($0).owned })
        #expect(ProductId.allCases.allSatisfy { bot.s.line($0).owned })
        TS.expectSane(bot.s)

        // The epilogue can be seen and New Game+ started from the won state.
        var s = TS.ok(bot.s, .markEpilogueSeen)
        s = TS.ok(s, .startNewGamePlus)
        #expect(s.legacy.ngLevel == 1)
        #expect(s.campaign.chapter == 1)
        print("seed=\(seed) won after \(String(format: "%.2f", hours)) h, raids=\(bot.s.stats.raids), "
              + "investigations=\(bot.s.stats.investigations), legacy=\(bot.s.legacy.points)")
    }

    @Test("The same seed always produces the same campaign")
    func determinism() {
        var a = Bot(Engine.newGame(seed: 77, nowMs: 1))
        var b = Bot(Engine.newGame(seed: 77, nowMs: 1))
        _ = a.run(maxSeconds: 3 * 3600)
        _ = b.run(maxSeconds: 3 * 3600)
        #expect(a.s == b.s)
    }

    @Test("New Game+ with bought perks is winnable and records a second win")
    func newGamePlus() {
        var first = Bot(Engine.newGame(seed: 11, nowMs: 1))
        #expect(first.run(maxSeconds: Self.maxGameSeconds))
        var s = TS.ok(first.s, .markEpilogueSeen)
        s = TS.ok(s, .startNewGamePlus)
        #expect(s.legacy.ngLevel == 1)
        while s.legacy.points > 0 {
            guard let perk = PerkId.allCases.first(where: {
                s.legacy.rank($0) < $0.maxRank && Content.perkCost(currentRank: s.legacy.rank($0)) <= s.legacy.points
            }) else { break }
            s = TS.ok(s, .buyPerk(perk))
        }
        #expect(PerkId.allCases.contains { s.legacy.rank($0) > 0 })
        var second = Bot(s)
        #expect(second.run(maxSeconds: Self.maxGameSeconds), "New Game+ must be winnable")
        #expect(second.s.legacy.wins == 2)
        #expect(second.s.legacy.ngLevel == 1)
        let hours = (second.s.time - s.time) / 3600
        #expect(hours > 2 && hours < 20, "New Game+ took \(hours) h")
        TS.expectSane(second.s)
        print("NG+ won after \(String(format: "%.2f", hours)) h")
    }
}
