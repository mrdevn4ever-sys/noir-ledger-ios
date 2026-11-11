import Foundation
import NoirCore
import Testing

@Suite("Idle layer: stages, payouts, prestige, favors, rewards")
struct IdleTests {

    @Test("A new line is stage 1 and pays the base economy")
    func baseline() {
        let s = TS.briefed()
        #expect(Idle.stage(s, .glimmer) == 1)
        #expect(Idle.lineMultiplier(s, .glimmer) == 1)
        #expect(Idle.globalMultiplier(s) == 1)
        #expect(Idle.payoutRatio(s) == 1)
    }

    @Test("The one-button upgrade buys the cheapest track first and continues into mastery")
    func autoUpgrade() {
        var s = TS.rich(chapter: 3)
        let first = Idle.nextLineStep(s, .glimmer)
        #expect(first?.step == .track(.capacity))
        s = TS.ok(s, .upgradeLineAuto(.glimmer, 9))
        #expect(Idle.stage(s, .glimmer) == 10)
        #expect(Idle.lineMultiplier(s, .glimmer) == 2, "stage 10 is the first milestone")
        s.dirty = 1e15
        s = TS.ok(s, .upgradeLineAuto(.glimmer, 1_000))
        let l = s.line(.glimmer)
        #expect(l.capacityLevel == Content.maxLineLevel && l.speedLevel == Content.maxLineLevel && l.qualityLevel == Content.maxLineLevel)
        #expect(l.masteryLevel > 0, "spare cash flows into mastery")
        #expect(s.meta.bestStage == Idle.stage(s, .glimmer))
        #expect(s.dirty >= 0)
    }

    @Test("The plan matches what the action buys")
    func planMatchesAction() {
        var s = TS.rich(chapter: 3)
        s.dirty = 5_000
        let plan = Idle.lineUpgradePlan(s, .glimmer, limit: 1_000)
        let after = TS.ok(s, .upgradeLineAuto(.glimmer, 1_000))
        #expect(plan.count == Idle.stage(after, .glimmer) - Idle.stage(s, .glimmer))
        #expect(abs((s.dirty - after.dirty) - plan.cost) < 1e-6)
        #expect(TS.error(after, .upgradeLineAuto(.glimmer, 1_000)) == .notAffordable)
        #expect(TS.error(after, .upgradeLineAuto(.halo, 1)) == .locked)
    }

    @Test("Payout multipliers raise cash but leave Heat exposure alone")
    func multipliersDoNotMoveHeat() {
        var base = TS.rich(chapter: 2)
        base.dirty = 0
        var boosted = base
        boosted.meta.premium = true
        boosted.meta.reputation = 50
        boosted.meta.boostSeconds = 3600
        #expect(Idle.globalMultiplier(boosted) == 8)
        Simulation.advance(&base, seconds: 600, offline: false)
        Simulation.advance(&boosted, seconds: 600, offline: false)
        #expect(boosted.stats.dirtyEarned > base.stats.dirtyEarned * 7.9)
        #expect(abs(boosted.stats.unitsSold - base.stats.unitsSold) < 1e-6, "the same goods move")
        #expect(abs(boosted.heatTarget - base.heatTarget) < 1e-6, "exposure comes from the base economy")
        #expect(boosted.meta.boostSeconds == 3000)
        #expect(Idle.payoutRatio(boosted) == 8)
        #expect(boosted.stats.cleanLaundered > base.stats.cleanLaundered, "fronts wash boosted cash faster")
    }

    @Test("Tapping adds work to a running line only")
    func hustle() {
        var s = TS.briefed()
        let before = s.line(.glimmer).progress
        s = TS.ok(s, .hustle(.glimmer))
        #expect(s.line(.glimmer).progress == before + Idle.hustleSeconds)
        #expect(s.meta.taps == 1)
        s = TS.ok(s, .setLineRunning(.glimmer, false))
        #expect(TS.error(s, .hustle(.glimmer)) == .invalid)
        #expect(TS.error(s, .hustle(.cinder)) == .invalid)
    }

    @Test("Going to ground needs chapter 2 and enough earnings, then restarts with reputation")
    func prestige() {
        var s = TS.briefed()
        #expect(TS.error(s, .prestige) == .requirements)
        s = TS.rich(chapter: 2)
        s.stats.dirtyEarned = 250_000
        s.meta.favors = 33
        s.meta.premium = true
        #expect(Idle.prestigeGain(s) == 25)
        let fresh = TS.ok(s, .prestige)
        #expect(fresh.meta.reputation == 25)
        #expect(fresh.meta.prestiges == 1)
        #expect(fresh.meta.favors == 33 && fresh.meta.premium, "wallet and purchases survive")
        #expect(fresh.campaign.chapter == 1 && fresh.campaign.tutorial == .done)
        #expect(fresh.stats.dirtyEarned == 0)
        #expect(fresh.line(.glimmer).running)
        #expect(fresh.legacy.ngLevel == s.legacy.ngLevel)
        #expect(Idle.reputationMultiplier(fresh) == 1.5)
        #expect(Idle.achievementUnlocked(fresh, .prestige1))
        TS.expectSane(fresh)
    }

    @Test("Achievements unlock from play, stay unlocked across a restart and pay once")
    func achievements() {
        var s = TS.rich(chapter: 2)
        s.meta.lifetimeDirty = 20_000
        Simulation.advance(&s, seconds: 1, offline: false)
        #expect(Idle.achievementUnlocked(s, .earn1))
        #expect(Idle.claimableAchievements(s) >= 1)
        #expect(TS.error(s, .claimAchievement(.earn5)) == .requirements)
        let favors = s.meta.favors
        s = TS.ok(s, .claimAchievement(.earn1))
        #expect(s.meta.favors == favors + Idle.achievementReward(.earn1))
        #expect(TS.error(s, .claimAchievement(.earn1)) == .invalid)
        #expect(AchievementId.allCases.allSatisfy { Idle.achievementReward($0) > 0 && Idle.achievementTarget($0) > 0 })
    }

    @Test("The daily reward can be claimed once per calendar day and cycles")
    func daily() {
        var s = TS.briefed()
        #expect(Idle.dailyAvailable(s, day: 20_000))
        s = TS.ok(s, .claimDaily(day: 20_000))
        #expect(s.meta.favors == 10)
        #expect(TS.error(s, .claimDaily(day: 20_000)) == .cooldown)
        #expect(TS.error(s, .claimDaily(day: 19_999)) == .cooldown, "a clock set back claims nothing")
        s = TS.ok(s, .claimDaily(day: 20_001))
        #expect(s.meta.boostSeconds == 3600)
        #expect(Idle.dailyReward(claims: 7) == Idle.dailyReward(claims: 0))
    }

    @Test("Favor items: boost, time jump, Heat relief and loyalty")
    func favorItems() {
        var s = TS.rich(chapter: 2)
        #expect(TS.error(s, .buyFavorItem(.boost4h)) == .notAffordable)
        s.meta.favors = 1_000
        s = TS.ok(s, .buyFavorItem(.boost4h))
        #expect(s.meta.boostSeconds == 4 * 3600 && s.meta.favors == 960)
        let t = s.time
        s = TS.ok(s, .buyFavorItem(.warp2h))
        #expect(abs(s.time - t - 7200) < 1e-6)
        #expect(s.stats.raids == 0, "a time jump is as safe as time away")
        s.heat = 80
        s.investigation = Investigation(startedAt: s.time, endsAt: s.time + 100, district: .cellars)
        s = TS.ok(s, .buyFavorItem(.coolHeat))
        #expect(s.heat == 50)
        #expect(s.investigation == nil)
        #expect(TS.error(s, .buyFavorItem(.loyalty)) == .invalid, "no crew, nothing to buy")
        TS.expectSane(s)
    }

    @Test("Sponsor rewards respect their caps and cooldowns")
    func adRewards() {
        var s = TS.rich(chapter: 2)
        s = TS.ok(s, .adReward(.boost, day: 1))
        #expect(s.meta.boostSeconds == Idle.adBoostSeconds)
        s.meta.boostSeconds = Idle.boostCapSeconds
        #expect(TS.error(s, .adReward(.boost, day: 1)) == .maxLevel)
        for _ in 0..<Idle.adFavorsPerDay { s = TS.ok(s, .adReward(.favors, day: 1)) }
        #expect(TS.error(s, .adReward(.favors, day: 1)) == .cooldown)
        #expect(Idle.adFavorsLeft(s, day: 2) == Idle.adFavorsPerDay)
        s.heat = 60
        s = TS.ok(s, .adReward(.coolHeat, day: 1))
        #expect(s.heat == 45)
        #expect(TS.error(s, .adReward(.coolHeat, day: 1)) == .cooldown)
        #expect(TS.error(s, .adReward(.offlineDouble, day: 1)) == .invalid)
    }

    @Test("Store grants are booked once and survive a restart; they work before the prologue")
    func grants() {
        var s = Engine.newGame(seed: 5, nowMs: 1)
        s = TS.ok(s, .grant(.premium))
        s = TS.ok(s, .grant(.starter))
        s = TS.ok(s, .grant(.starter))
        s = TS.ok(s, .grant(.favors(80)))
        s = TS.ok(s, .grant(.noAds))
        #expect(s.meta.premium && s.meta.noAds && s.meta.starterBought)
        #expect(s.meta.favors == Idle.starterFavors + 80)
        #expect(Idle.offlineCapSeconds(s) == 2 * Content.offlineCapSeconds)
        #expect(TS.error(s, .grant(.favors(0))) == .invalid)
    }

    @Test("Time away leaves a bonus that a sponsor video can double exactly once")
    func offlineBonus() {
        var s = TS.rich(chapter: 2)
        s.dirty = 0
        s.lastWallClockMs = 1_000
        let (back, report) = Engine.applyOffline(s, nowMs: 1_000 + 3_600_000)
        let r = try! #require(report)
        #expect(back.meta.offlineBonus == r.dirtyEarned && r.dirtyEarned > 0)
        let doubled = TS.ok(back, .adReward(.offlineDouble, day: 1))
        #expect(abs(doubled.dirty - back.dirty - r.dirtyEarned) < 1e-6)
        #expect(doubled.meta.offlineBonus == 0)
        let plain = TS.ok(back, .collectOffline(doubled: false))
        #expect(plain.dirty == back.dirty && plain.meta.offlineBonus == 0)
    }

    @Test("Meta progress round-trips through the save and old saves gain defaults")
    func save() throws {
        var s = TS.rich(chapter: 3)
        s.meta.favors = 77
        s.meta.reputation = 12
        s.meta.unlocked = [.earn1, .crew3]
        s.meta.claimed = [.earn1]
        s = TS.ok(s, .upgradeLineAuto(.glimmer, 5))
        let codec = SaveCodec()
        guard case .ok(let decoded, _) = codec.decode(try codec.encode(s, savedAtMs: 1)) else {
            Issue.record("decode failed")
            return
        }
        #expect(decoded == s)
        let old = try SaveCodec(currentVersion: 1).encode(TS.briefed(), savedAtMs: 1)
        guard case .ok(let migrated, let from) = codec.decode(old) else {
            Issue.record("schema 1 must migrate")
            return
        }
        #expect(from == 1)
        #expect(migrated.meta.payoutRatio == 1 && migrated.line(.glimmer).masteryLevel == 0)
    }
}
