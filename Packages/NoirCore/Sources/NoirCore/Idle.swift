import Foundation

/*
 * The idle layer on top of the campaign economy: line stages with milestones, mastery levels, payout multipliers,
 * going to ground (prestige), favors (the premium currency), daily rewards, achievements and boosts.
 *
 * Design rule: every multiplier in this file changes how much cash a sale or a wash pays, never how many units move.
 * Exposure (and therefore Heat) is always computed from the un-multiplied street economy, so the tested Heat balance
 * of the campaign holds at any multiplier.
 */

public enum AchievementId: String, CaseIterable, Codable, Sendable {
    case earn1 = "EARN_1", earn2 = "EARN_2", earn3 = "EARN_3", earn4 = "EARN_4", earn5 = "EARN_5"
    case clean1 = "CLEAN_1", clean2 = "CLEAN_2", clean3 = "CLEAN_3"
    case districts2 = "DISTRICTS_2", districts5 = "DISTRICTS_5"
    case fronts3 = "FRONTS_3", fronts5 = "FRONTS_5"
    case crew3 = "CREW_3", crew6 = "CREW_6"
    case allLines = "ALL_LINES"
    case stage25 = "STAGE_25", stage50 = "STAGE_50", stage100 = "STAGE_100"
    case survivor = "SURVIVOR", raided = "RAIDED", decisions10 = "DECISIONS_10"
    case prestige1 = "PRESTIGE_1", prestige5 = "PRESTIGE_5", prestige10 = "PRESTIGE_10"
    case win1 = "WIN_1", win3 = "WIN_3"
    case taps100 = "TAPS_100", taps2500 = "TAPS_2500"
}

public enum FavorItem: String, CaseIterable, Codable, Sendable {
    case boost4h = "BOOST_4H", warp2h = "WARP_2H", warp8h = "WARP_8H", warp24h = "WARP_24H"
    case coolHeat = "COOL_HEAT", loyalty = "LOYALTY"

    public var price: Int {
        switch self {
        case .boost4h: 40
        case .warp2h: 30
        case .warp8h: 100
        case .warp24h: 250
        case .coolHeat: 25
        case .loyalty: 20
        }
    }

    /// Seconds of simulated time for the time jumps, 0 otherwise.
    public var warpSeconds: Double {
        switch self {
        case .warp2h: 2 * 3600
        case .warp8h: 8 * 3600
        case .warp24h: 24 * 3600
        default: 0
        }
    }
}

/// What a finished sponsor video pays. The app layer shows the video; the engine only books the reward.
public enum AdReward: String, CaseIterable, Codable, Sendable {
    case boost = "BOOST", coolHeat = "COOL_HEAT", favors = "FAVORS", offlineDouble = "OFFLINE_DOUBLE"
}

/// What a verified store purchase grants. The app layer verifies the transaction; the engine only books it.
public enum Grant: Sendable, Equatable {
    case favors(Int)
    case premium
    case noAds
    case starter
}

public enum DailyReward: Sendable, Equatable {
    case favors(Int)
    case boost(Double)
    case warp(Double)
}

/// Progress that outlives a single run: it survives going to ground, New Game+ and a campaign reset.
public struct MetaState: Codable, Sendable, Equatable {
    /// Premium currency.
    public var favors = 0
    /// Each point of reputation raises every payout by 2 %.
    public var reputation = 0
    public var prestiges = 0
    /// Permanent ×2 payout (store purchase).
    public var premium = false
    /// Sponsor rewards are granted without a video (store purchase).
    public var noAds = false
    public var starterBought = false
    /// Remaining game seconds of the ×2 payout boost.
    public var boostSeconds = 0.0
    /// Remaining game seconds until the sponsor Heat relief can be used again.
    public var heatAidCooldown = 0.0
    /// Calendar day (days since 1970 in the player's time zone) of the last daily claim; -1 before the first.
    public var dailyLastDay = -1
    public var dailyClaims = 0
    public var adFavorsDay = -1
    public var adFavorsToday = 0
    /// Achievements whose condition has been met at some point (unlocked), in unlock order.
    public var unlocked: [AchievementId] = []
    /// Achievements whose reward has been collected.
    public var claimed: [AchievementId] = []
    public var lifetimeDirty = 0.0
    public var lifetimeClean = 0.0
    public var taps = 0
    public var adsWatched = 0
    public var bestStage = 0
    /// Street cash earned while away that a sponsor video can pay out a second time. Cleared when collected.
    public var offlineBonus = 0.0
    /// Boosted street cash divided by base street cash in the last step with sales (at least 1).
    public var payoutRatio = 1.0

    public init() {}
}

extension MetaState {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        favors = c.value(.favors, 0)
        reputation = c.value(.reputation, 0)
        prestiges = c.value(.prestiges, 0)
        premium = c.value(.premium, false)
        noAds = c.value(.noAds, false)
        starterBought = c.value(.starterBought, false)
        boostSeconds = c.value(.boostSeconds, 0.0)
        heatAidCooldown = c.value(.heatAidCooldown, 0.0)
        dailyLastDay = c.value(.dailyLastDay, -1)
        dailyClaims = c.value(.dailyClaims, 0)
        adFavorsDay = c.value(.adFavorsDay, -1)
        adFavorsToday = c.value(.adFavorsToday, 0)
        unlocked = c.value(.unlocked, [AchievementId]())
        claimed = c.value(.claimed, [AchievementId]())
        lifetimeDirty = c.value(.lifetimeDirty, 0.0)
        lifetimeClean = c.value(.lifetimeClean, 0.0)
        taps = c.value(.taps, 0)
        adsWatched = c.value(.adsWatched, 0)
        bestStage = c.value(.bestStage, 0)
        offlineBonus = c.value(.offlineBonus, 0.0)
        payoutRatio = c.value(.payoutRatio, 1.0)
    }
}

public enum LineStep: Sendable, Equatable {
    case track(LineTrack)
    case mastery
}

public enum Idle {

    // MARK: Line stages, mastery and milestones

    /// Mastery levels continue a line after all three tracks are at their cap.
    public static let maxMastery = 473
    public static let masteryPayout = 1.08
    /// Stages at which a line's payout doubles.
    public static let milestones = [10, 25, 50, 75, 100, 150, 200, 250, 300, 400, 500]
    /// Seconds of work one tap adds to a running line.
    public static let hustleSeconds = 1.0

    /// One number for a line's progress: 1 for a new line, +1 per track level and per mastery level.
    public static func stage(_ l: LineState) -> Int { l.totalLevels - 2 + l.masteryLevel }

    public static func stage(_ s: GameState, _ p: ProductId) -> Int { stage(s.line(p)) }

    public static func milestonesReached(stage: Int) -> Int { milestones.filter { $0 <= stage }.count }

    public static func nextMilestone(stage: Int) -> Int? { milestones.first { $0 > stage } }

    public static func previousMilestone(stage: Int) -> Int { milestones.last { $0 <= stage } ?? 1 }

    /// Payout multiplier of one line from its mastery levels and milestones.
    public static func lineMultiplier(_ l: LineState) -> Double {
        pow(masteryPayout, Double(l.masteryLevel)) * pow(2, Double(milestonesReached(stage: stage(l))))
    }

    public static func lineMultiplier(_ s: GameState, _ p: ProductId) -> Double { lineMultiplier(s.line(p)) }

    public static func masteryCost(_ p: ProductId, currentLevel: Int) -> Double {
        Content.product(p).lineUpgradeBase * 250 * pow(1.25, Double(currentLevel))
    }

    /// The next purchase of the one-button upgrade: the cheapest open track, then mastery. Nil when everything is maxed.
    public static func nextLineStep(_ s: GameState, _ p: ProductId) -> (step: LineStep, cost: Double)? {
        let l = s.line(p)
        guard l.owned else { return nil }
        var best: (step: LineStep, cost: Double)?
        for t in LineTrack.allCases where l.level(t) < Content.maxLineLevel {
            let c = Content.lineUpgradeCost(p, t, currentLevel: l.level(t))
            if best == nil || c < best!.cost { best = (step: LineStep.track(t), cost: c) }
        }
        if let best { return best }
        if l.masteryLevel < maxMastery { return (step: LineStep.mastery, cost: masteryCost(p, currentLevel: l.masteryLevel)) }
        return nil
    }

    /// How many steps of the one-button upgrade `budget` dirty cash buys (at most `limit`), and their total cost.
    public static func lineUpgradePlan(_ s: GameState, _ p: ProductId, limit: Int) -> (count: Int, cost: Double) {
        var sim = s
        var count = 0
        var total = 0.0
        while count < limit, let next = nextLineStep(sim, p), sim.dirty >= next.cost - 1e-9 {
            sim.dirty -= next.cost
            total += next.cost
            applyLineStep(&sim, p, next.step)
            count += 1
        }
        return (count, total)
    }

    static func applyLineStep(_ s: inout GameState, _ p: ProductId, _ step: LineStep) {
        s.updateLine(p) { l in
            switch step {
            case .track(.capacity): l.capacityLevel += 1
            case .track(.speed): l.speedLevel += 1
            case .track(.quality): l.qualityLevel += 1
            case .mastery: l.masteryLevel += 1
            }
        }
        s.meta.bestStage = max(s.meta.bestStage, stage(s, p))
    }

    // MARK: Payout multipliers

    public static let reputationPayout = 0.02
    public static let boostMultiplier = 2.0
    public static let premiumMultiplier = 2.0

    public static func reputationMultiplier(_ s: GameState) -> Double { 1 + reputationPayout * Double(s.meta.reputation) }
    public static func boostActive(_ s: GameState) -> Bool { s.meta.boostSeconds > 0 }

    /// Multiplier on every payout from reputation, the permanent premium upgrade and a running boost.
    public static func globalMultiplier(_ s: GameState) -> Double {
        reputationMultiplier(s) * (s.meta.premium ? premiumMultiplier : 1) * (boostActive(s) ? boostMultiplier : 1)
    }

    /// How much more a unit of street business pays than in the base economy. Fronts wash this much faster too.
    public static func payoutRatio(_ s: GameState) -> Double { max(1, s.meta.payoutRatio) }

    // MARK: Going to ground (prestige)

    public static let prestigeMinChapter = 2
    public static let prestigeMinGain = 10

    /// Reputation earned by ending the current run now.
    public static func prestigeGain(_ s: GameState) -> Int {
        let earned = max(0, s.stats.dirtyEarned)
        if earned <= 0 { return 0 }
        var gain = 25 * pow(earned / 250_000, 0.4)
        if s.campaign.won { gain *= 1.5 }
        return gain.isFinite ? Int(min(gain, 1_000_000)) : 0
    }

    public static func canPrestige(_ s: GameState) -> Bool {
        s.campaign.tutorial == .done && s.campaign.chapter >= prestigeMinChapter && prestigeGain(s) >= prestigeMinGain
    }

    // MARK: Boosts and sponsor rewards

    public static let adBoostSeconds = 30.0 * 60
    public static let boostCapSeconds = 8.0 * 3600
    public static let adHeatRelief = 15.0
    public static let adHeatCooldown = 600.0
    public static let favorHeatRelief = 30.0
    public static let adFavors = 3
    public static let adFavorsPerDay = 5
    public static let starterFavors = 200
    public static let starterBoostSeconds = 4.0 * 3600
    public static let chapterFavors = 10

    public static func addBoost(_ s: inout GameState, seconds: Double) {
        s.meta.boostSeconds = min(boostCapSeconds, max(0, s.meta.boostSeconds) + seconds)
    }

    public static func adFavorsLeft(_ s: GameState, day: Int) -> Int {
        s.meta.adFavorsDay == day ? max(0, adFavorsPerDay - s.meta.adFavorsToday) : adFavorsPerDay
    }

    public static func offlineCapSeconds(_ s: GameState) -> Int64 {
        s.meta.premium ? 2 * Content.offlineCapSeconds : Content.offlineCapSeconds
    }

    // MARK: Daily rewards

    public static let dailyCycle: [DailyReward] = [
        .favors(10), .boost(3600), .favors(15), .warp(3600), .favors(20), .boost(2 * 3600), .favors(50),
    ]

    public static func dailyReward(claims: Int) -> DailyReward { dailyCycle[((claims % dailyCycle.count) + dailyCycle.count) % dailyCycle.count] }

    public static func dailyAvailable(_ s: GameState, day: Int) -> Bool {
        s.campaign.prologueDone && day > s.meta.dailyLastDay
    }

    // MARK: Achievements

    public static func achievementReward(_ a: AchievementId) -> Int {
        switch a {
        case .earn1, .clean1, .districts2, .taps100: 5
        case .earn2, .fronts3, .crew3, .stage25, .survivor, .raided, .decisions10: 10
        case .clean2, .allLines, .prestige1, .taps2500: 15
        case .earn3, .crew6, .stage50: 20
        case .districts5, .fronts5: 25
        case .prestige5: 30
        case .earn4, .clean3, .stage100: 40
        case .win1: 50
        case .prestige10: 60
        case .earn5: 80
        case .win3: 100
        }
    }

    public static func achievementTarget(_ a: AchievementId) -> Double {
        switch a {
        case .earn1: 10_000
        case .earn2: 1_000_000
        case .earn3: 100_000_000
        case .earn4: 10_000_000_000
        case .earn5: 1_000_000_000_000
        case .clean1: 5_000
        case .clean2: 1_000_000
        case .clean3: 1_000_000_000
        case .districts2: 2
        case .districts5: 5
        case .fronts3: 3
        case .fronts5: 5
        case .crew3: 3
        case .crew6: 6
        case .allLines: 4
        case .stage25: 25
        case .stage50: 50
        case .stage100: 100
        case .survivor: 1
        case .raided: 1
        case .decisions10: 10
        case .prestige1: 1
        case .prestige5: 5
        case .prestige10: 10
        case .win1: 1
        case .win3: 3
        case .taps100: 100
        case .taps2500: 2_500
        }
    }

    public static func achievementCurrent(_ s: GameState, _ a: AchievementId) -> Double {
        switch a {
        case .earn1, .earn2, .earn3, .earn4, .earn5: s.meta.lifetimeDirty
        case .clean1, .clean2, .clean3: s.meta.lifetimeClean
        case .districts2, .districts5: Double(DistrictId.allCases.filter { s.district($0).unlocked }.count)
        case .fronts3, .fronts5: Double(FrontId.allCases.filter { s.front($0).owned }.count)
        case .crew3, .crew6: Double(s.crew.count)
        case .allLines: Double(ProductId.allCases.filter { s.line($0).owned }.count)
        case .stage25, .stage50, .stage100: Double(s.meta.bestStage)
        case .survivor: Double(s.stats.investigationsSurvived)
        case .raided: Double(s.stats.raids)
        case .decisions10: Double(s.stats.eventsResolved)
        case .prestige1, .prestige5, .prestige10: Double(s.meta.prestiges)
        case .win1, .win3: Double(s.legacy.wins)
        case .taps100, .taps2500: Double(s.meta.taps)
        }
    }

    public static func achievementUnlocked(_ s: GameState, _ a: AchievementId) -> Bool { s.meta.unlocked.contains(a) }
    public static func achievementClaimed(_ s: GameState, _ a: AchievementId) -> Bool { s.meta.claimed.contains(a) }

    /// Number of unlocked achievements whose reward is still waiting.
    public static func claimableAchievements(_ s: GameState) -> Int {
        s.meta.unlocked.filter { !s.meta.claimed.contains($0) }.count
    }

    /// Records achievements whose condition is met now, so they stay claimable after the run ends. Idempotent.
    public static func refreshAchievements(_ s: inout GameState) {
        if s.meta.unlocked.count >= AchievementId.allCases.count { return }
        for a in AchievementId.allCases where !s.meta.unlocked.contains(a) {
            if achievementCurrent(s, a) >= achievementTarget(a) - 1e-9 { s.meta.unlocked.append(a) }
        }
    }
}
