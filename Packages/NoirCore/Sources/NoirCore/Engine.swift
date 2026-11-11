import Foundation

public enum Action: Sendable, Equatable {
    case choosePrologue(PrologueChoice)
    case setLineRunning(ProductId, Bool)
    case buyLine(ProductId)
    case upgradeLine(ProductId, LineTrack)
    case upgradeStorage
    case unlockDistrict(DistrictId)
    case upgradeRoute(DistrictId, ProductId)
    case turf(DistrictId)
    case buyFront(FrontId)
    case upgradeFront(FrontId)
    case setFrontActive(FrontId, Bool)
    case setReserve(Int)
    case upgradeProtection
    case donate
    case bribe
    case setLayLow(Bool)
    case hire(String)
    case dismiss(String)
    case crewBonus(String)
    case buyUpgrade(UpgradeId)
    case resolveEvent(String)
    case ackTutorial
    case ackRaid
    case startFinalOp
    case finalOpChoice(String)
    case markEpilogueSeen
    case startNewGamePlus
    case buyPerk(PerkId)
    // Idle layer
    /// A tap on a running line: adds a little work.
    case hustle(ProductId)
    /// The one-button line upgrade: buys up to `count` steps (cheapest track first, then mastery).
    case upgradeLineAuto(ProductId, Int)
    /// Go to ground: end the run for reputation and start over.
    case prestige
    case claimAchievement(AchievementId)
    /// `day` is the calendar day (days since 1970 in the player's time zone), supplied by the app.
    case claimDaily(day: Int)
    case buyFavorItem(FavorItem)
    /// Books the reward of a finished sponsor video (or directly, for players who bought the ad-free upgrade).
    case adReward(AdReward, day: Int)
    /// Books a verified store purchase.
    case grant(Grant)
    /// Collects the return summary; `doubled` pays the street cash earned while away a second time.
    case collectOffline(doubled: Bool)
}

public enum ActionError: String, Sendable, Equatable, CaseIterable {
    case notAffordable, locked, maxLevel, tutorial, roleOccupied, cooldown, invalid, requirements
}

public struct ActionResult: Sendable {
    /// The resulting state. On error it is the unchanged input state.
    public let state: GameState
    public let error: ActionError?
    /// Index of the event outcome that happened (event decisions only).
    public let outcome: Int
    /// Whether a chance-based final-operation phase succeeded.
    public let success: Bool

    public var isOK: Bool { error == nil }
}

public struct OfflineReport: Sendable, Equatable {
    public var awaySeconds: Int64
    public var creditedSeconds: Int64
    public var capped: Bool
    public var clockMovedBack: Bool
    public var produced: Double
    public var sold: Double
    public var dirtyEarned: Double
    public var dirtyLaundered: Double
    public var cleanGained: Double
    public var wagesPaid: Double
    public var productionSpent: Double
    public var influenceGained: Double
    public var heatBefore: Double
    public var heatAfter: Double
}

public enum Engine {

    public static let startDirty = 150.0
    public static let reserveOptions = [0, 2, 10, 30]
    /// Online ticks never credit more than this per call; longer gaps go through `applyOffline`.
    public static let maxOnlineTick = 5.0

    /// `meta` carries the progress that outlives a run. `skipIntro` starts in chapter 1 with the first line running
    /// (New Game+ and going to ground); by default only New Game+ levels skip the prologue and the briefing.
    public static func newGame(seed: UInt64, nowMs: Int64, legacy: LegacyState = LegacyState(), meta: MetaState = MetaState(),
                               skipIntro: Bool? = nil) -> GameState {
        var s = GameState()
        s.meta = meta
        s.meta.payoutRatio = 1
        s.meta.offlineBonus = 0
        s.seed = UInt64Box(seed)
        s.rng = UInt64Box(seed)
        s.lastWallClockMs = nowMs
        s.legacy = LegacyState(ngLevel: legacy.ngLevel, points: legacy.points, perks: legacy.perks, wins: legacy.wins)
        for p in ProductId.allCases {
            s.lines[p] = LineState()
            s.inventory[p] = 0
        }
        s.lines[.glimmer]?.owned = true
        for d in DistrictId.allCases {
            s.districts[d] = DistrictState(rival: min(95, Content.district(d).startRival + Content.rivalNgBonus(ng: legacy.ngLevel)))
        }
        s.districts[.cellars]?.unlocked = true
        for f in FrontId.allCases { s.fronts[f] = FrontState() }
        s.dirty = startDirty + 2000 * Double(legacy.rank(.startingCapital))
        s.nextEventAt = 300
        if skipIntro ?? (legacy.ngLevel > 0) {
            // New Game+ and going to ground: the player already knows the ropes; skip the prologue and the briefing.
            s.campaign.prologueDone = true
            s.campaign.prologueChoice = nil
            s.campaign.tutorial = .done
            s.campaign.chapter = 1
            s.lines[.glimmer]?.running = true
            s.districts[.cellars]?.routes[.glimmer] = 1
            s.dirty += 300
        }
        return s
    }

    /// Online tick. Returns a new state; the input is never mutated.
    public static func tick(_ state: GameState, dtSec: Double, nowMs: Int64) -> GameState {
        var s = state
        if s.campaign.prologueDone {
            Simulation.advance(&s, seconds: min(maxOnlineTick, max(0, dtSec)), offline: false)
        }
        s.lastWallClockMs = nowMs
        return s
    }

    /// Credits time spent away (at most eight hours). A clock set backwards credits nothing and resets the reference.
    public static func applyOffline(_ state: GameState, nowMs: Int64) -> (GameState, OfflineReport?) {
        var s = state
        let last = s.lastWallClockMs
        s.lastWallClockMs = nowMs
        if last <= 0 || !s.campaign.prologueDone { return (s, nil) }
        let elapsedMs = nowMs - last
        if elapsedMs < 0 {
            s.log(.offlineReturn, ref: "clock")
            let report = OfflineReport(awaySeconds: 0, creditedSeconds: 0, capped: false, clockMovedBack: true, produced: 0, sold: 0,
                                       dirtyEarned: 0, dirtyLaundered: 0, cleanGained: 0, wagesPaid: 0, productionSpent: 0,
                                       influenceGained: 0, heatBefore: s.heat, heatAfter: s.heat)
            return (s, report)
        }
        let away = elapsedMs / 1000
        if away < 5 { return (s, nil) }
        let cap = Idle.offlineCapSeconds(s)
        let credited = min(away, cap)
        let heatBefore = s.heat
        let r = Simulation.advance(&s, seconds: Double(credited) * Content.offlineEfficiency, offline: true, step: 2)
        if away < 60 { return (s, nil) }
        s.log(.offlineReturn, amount: Double(credited), amount2: r.dirtyEarned)
        s.meta.offlineBonus += r.dirtyEarned
        let report = OfflineReport(awaySeconds: away, creditedSeconds: credited, capped: away > cap,
                                   clockMovedBack: false, produced: r.produced, sold: r.sold, dirtyEarned: r.dirtyEarned,
                                   dirtyLaundered: r.dirtyLaundered, cleanGained: r.cleanGained, wagesPaid: r.wagesPaid,
                                   productionSpent: r.productionSpent, influenceGained: r.influenceGained,
                                   heatBefore: heatBefore, heatAfter: s.heat)
        return (s, report)
    }

    // MARK: Actions

    public static func tutorialAllows(_ s: GameState, _ a: Action) -> Bool {
        let step = s.campaign.tutorial
        if step == .done { return true }
        switch a {
        case .choosePrologue: return true
        case .setLineRunning(let p, _): return p == .glimmer
        case .upgradeRoute(let d, let p): return d == .cellars && p == .glimmer && step.ordinal >= TutorialStep.openRoute.ordinal
        case .buyFront(let f): return f == .laundromat && step.ordinal >= TutorialStep.buyFront.ordinal
        case .setFrontActive: return true
        case .ackTutorial: return step == .heatBriefing
        case .ackRaid: return true
        case .hustle(let p): return p == .glimmer
        case .claimAchievement, .claimDaily, .buyFavorItem, .adReward, .grant, .collectOffline: return true
        default: return false
        }
    }

    public static func apply(_ state: GameState, _ a: Action) -> ActionResult {
        if !state.campaign.prologueDone {
            switch a {
            case .choosePrologue, .grant: break
            default: return err(state, .locked)
            }
        }
        if !tutorialAllows(state, a) { return err(state, .tutorial) }
        var s = state
        let m = Economy.mods(s)

        switch a {
        case .choosePrologue(let choice):
            if s.campaign.prologueDone { return err(state, .invalid) }
            s.campaign.prologueDone = true
            s.campaign.prologueChoice = choice
            switch choice {
            case .cashBox: s.dirty += 600
            case .contacts: s.influence += 15
            case .tools:
                s.updateLine(.glimmer) { l in
                    l.capacityLevel = 2
                    l.speedLevel = 2
                }
            }

        case .setLineRunning(let p, let running):
            guard s.line(p).owned else { return err(state, .locked) }
            s.updateLine(p) { l in
                l.running = running
                l.status = running ? .running : .idle
            }

        case .buyLine(let p):
            let def = Content.product(p)
            if s.line(p).owned { return err(state, .invalid) }
            if s.campaign.chapter < def.unlockChapter { return err(state, .locked) }
            guard pay(Cost(dirty: def.lineCost), from: &s) else { return err(state, .notAffordable) }
            s.updateLine(p) { l in
                l.owned = true
                l.running = true
                l.status = .running
            }
            s.log(.lineBought, ref: p.rawValue, amount: def.lineCost)

        case .upgradeLine(let p, let track):
            let l = s.line(p)
            guard l.owned else { return err(state, .locked) }
            let lvl = l.level(track)
            if lvl >= Content.maxLineLevel { return err(state, .maxLevel) }
            guard pay(Cost(dirty: Content.lineUpgradeCost(p, track, currentLevel: lvl)), from: &s) else { return err(state, .notAffordable) }
            s.updateLine(p) { l in
                switch track {
                case .capacity: l.capacityLevel += 1
                case .speed: l.speedLevel += 1
                case .quality: l.qualityLevel += 1
                }
            }

        case .upgradeStorage:
            if s.storageLevel >= Content.maxStorageLevel { return err(state, .maxLevel) }
            guard pay(Cost(dirty: Content.storageCost(currentLevel: s.storageLevel)), from: &s) else { return err(state, .notAffordable) }
            s.storageLevel += 1

        case .unlockDistrict(let d):
            let def = Content.district(d)
            if s.district(d).unlocked { return err(state, .invalid) }
            if s.campaign.chapter < def.unlockChapter { return err(state, .locked) }
            if s.influence < def.unlockInfluence { return err(state, .requirements) }
            guard pay(Economy.districtUnlockCost(s, d, m), from: &s) else { return err(state, .notAffordable) }
            s.updateDistrict(d) { $0.unlocked = true }
            s.log(.districtUnlocked, ref: d.rawValue)

        case .upgradeRoute(let d, let p):
            let ds = s.district(d)
            guard ds.unlocked, s.line(p).owned else { return err(state, .locked) }
            let lvl = ds.route(p)
            if lvl >= Content.maxRouteLevel { return err(state, .maxLevel) }
            let free = s.campaign.tutorial != .done && lvl == 0
            if !free {
                guard pay(Cost(dirty: Content.routeCost(d, p, currentLevel: lvl)), from: &s) else { return err(state, .notAffordable) }
            }
            s.updateDistrict(d) { $0.routes[p] = lvl + 1 }

        case .turf(let d):
            let ds = s.district(d)
            guard ds.unlocked else { return err(state, .locked) }
            if ds.turfReadyAt > s.time { return err(state, .cooldown) }
            if ds.rival <= 0 { return err(state, .maxLevel) }
            guard pay(Economy.turfCost(s, d), from: &s) else { return err(state, .notAffordable) }
            let gain = Economy.turfGain(s, d, m)
            let readyAt = s.time + Content.turfCooldown
            s.updateDistrict(d) { ds in
                ds.rival = max(0, ds.rival - gain)
                ds.turfReadyAt = readyAt
            }
            s.heat = min(100, s.heat + Economy.turfHeat(d) * m.allExposure)
            s.stats.turfActions += 1
            s.log(.turf, ref: d.rawValue, amount: gain)

        case .buyFront(let f):
            let def = Content.front(f)
            if s.front(f).owned { return err(state, .invalid) }
            guard s.district(def.district).unlocked else { return err(state, .locked) }
            guard pay(def.buy, from: &s) else { return err(state, .notAffordable) }
            s.updateFront(f) { fs in
                fs.owned = true
                fs.active = true
            }
            s.log(.frontBought, ref: f.rawValue)

        case .upgradeFront(let f):
            let fs = s.front(f)
            guard fs.owned else { return err(state, .locked) }
            if fs.level >= Content.maxFrontLevel { return err(state, .maxLevel) }
            guard pay(Cost(clean: Content.frontUpgradeCost(f, currentLevel: fs.level) * m.frontUpgradeCost), from: &s) else {
                return err(state, .notAffordable)
            }
            s.updateFront(f) { $0.level += 1 }

        case .setFrontActive(let f, let active):
            guard s.front(f).owned else { return err(state, .locked) }
            s.updateFront(f) { $0.active = active }

        case .setReserve(let minutes):
            guard reserveOptions.contains(minutes) else { return err(state, .invalid) }
            s.reserveMinutes = minutes

        case .upgradeProtection:
            if s.campaign.chapter < 2 { return err(state, .locked) }
            if s.protectionLevel >= Content.maxProtectionLevel { return err(state, .maxLevel) }
            guard pay(Cost(clean: Content.protectionCost(currentLevel: s.protectionLevel)), from: &s) else { return err(state, .notAffordable) }
            s.protectionLevel += 1
            s.log(.protection, amount: Double(s.protectionLevel))

        case .donate:
            if s.campaign.chapter < 2 { return err(state, .locked) }
            let c = Economy.donationCost(s)
            guard pay(Cost(clean: c), from: &s) else { return err(state, .notAffordable) }
            let gained = Economy.donationInfluence(s, clean: c)
            s.influence += gained
            s.log(.donation, amount: c, amount2: gained)

        case .bribe:
            if s.campaign.chapter < 1 { return err(state, .locked) }
            if s.bribeReadyAt > s.time { return err(state, .cooldown) }
            if s.heat <= 0.5 { return err(state, .invalid) }
            guard pay(Economy.bribeCost(s, m), from: &s) else { return err(state, .notAffordable) }
            s.heat = max(0, s.heat - Economy.bribeHeat)
            s.bribeReadyAt = s.time + Content.bribeCooldown
            s.log(.bribe, amount: Economy.bribeHeat)

        case .setLayLow(let on):
            if s.layLow == on { return err(state, .invalid) }
            s.layLow = on
            s.log(on ? .layLowOn : .layLowOff)

        case .hire(let crewId):
            guard let def = Content.crewDef(crewId) else { return err(state, .invalid) }
            if s.crew.contains(where: { $0.defId == crewId }) { return err(state, .invalid) }
            if s.campaign.chapter < def.unlockChapter { return err(state, .locked) }
            if s.crewIn(def.role) != nil { return err(state, .roleOccupied) }
            guard pay(Cost(dirty: hireCost(s, def)), from: &s) else { return err(state, .notAffordable) }
            s.crew.append(CrewMember(defId: def.id, loyalty: s.departed.contains(crewId) ? 45 : 60, hiredAt: s.time))
            s.log(.crewHired, ref: def.id)

        case .dismiss(let crewId):
            guard s.crew.contains(where: { $0.defId == crewId }) else { return err(state, .invalid) }
            s.crew.removeAll { $0.defId == crewId }
            if !s.departed.contains(crewId) { s.departed.append(crewId) }
            for i in s.crew.indices { s.crew[i].loyalty = max(0, s.crew[i].loyalty - 3) }
            s.log(.crewDismissed, ref: crewId)

        case .crewBonus(let crewId):
            guard let idx = s.crew.firstIndex(where: { $0.defId == crewId }) else { return err(state, .invalid) }
            if s.crew[idx].loyalty >= 100 { return err(state, .maxLevel) }
            guard pay(Cost(dirty: bonusCost(s.crew[idx])), from: &s) else { return err(state, .notAffordable) }
            s.crew[idx].loyalty = min(100, s.crew[idx].loyalty + 15)

        case .buyUpgrade(let u):
            switch upgradeStatus(s, u) {
            case .owned: return err(state, .invalid)
            case .excluded, .needsPrevious: return err(state, .requirements)
            case .chapterLocked: return err(state, .locked)
            case .available: break
            }
            guard pay(Content.upgradeCost(u), from: &s) else { return err(state, .notAffordable) }
            s.upgrades.append(u)
            s.log(.upgrade, ref: u.rawValue)

        case .resolveEvent(let key):
            guard let idx = Events.resolve(&s, choiceKey: key) else { return err(state, .notAffordable) }
            return ok(&s, outcome: idx)

        case .ackTutorial:
            s.campaign.tutorial = .done
            s.campaign.chapter = 1
            s.nextEventAt = s.time + 240

        case .ackRaid:
            s.raidUnseen = false

        case .startFinalOp:
            guard Campaign.finalReady(s) else { return err(state, .requirements) }
            Campaign.finalWarChest(s).pay(&s)
            s.campaign.finalOp = FinalOpState()

        case .finalOpChoice(let key):
            guard let op = s.campaign.finalOp else { return err(state, .invalid) }
            if s.campaign.won { return err(state, .invalid) }
            if op.readyAt > s.time { return err(state, .cooldown) }
            guard let phase = Campaign.currentPhase(s),
                  let choice = Campaign.finalChoices(s, phase).first(where: { $0.key == key }) else { return err(state, .invalid) }
            if let role = choice.requiresRole, s.crewIn(role) == nil { return err(state, .requirements) }
            guard pay(choice.cost, from: &s) else { return err(state, .notAffordable) }
            s.heat = min(100, s.heat + choice.heat)
            let roll = choice.chance >= 1 ? 0 : Rng.unit(&s)
            let success = roll < choice.chance
            if success {
                s.campaign.finalOp?.lastResult = .success
                s.log(.finalPhaseWon, ref: String(phase.rawValue))
                s.campaign.finalOp?.phase += 1
                if (s.campaign.finalOp?.phase ?? 0) >= FinalPhase.allCases.count { win(&s) }
            } else {
                s.campaign.finalOp?.lastResult = .failure
                s.campaign.finalOp?.failures += 1
                let readyAt = s.time + Content.finalPhaseCooldown
                s.campaign.finalOp?.readyAt = readyAt
                s.heat = min(100, s.heat + 10)
                s.log(.finalPhaseLost, ref: String(phase.rawValue))
            }
            return ok(&s, success: success)

        case .markEpilogueSeen:
            guard s.campaign.won else { return err(state, .invalid) }
            s.campaign.epilogueSeen = true

        case .startNewGamePlus:
            guard s.campaign.won else { return err(state, .requirements) }
            var fresh = restart(s, ngLevel: s.legacy.ngLevel + 1)
            fresh.log(.newGamePlus, amount: Double(fresh.legacy.ngLevel))
            return ActionResult(state: fresh, error: nil, outcome: 0, success: true)

        case .buyPerk(let perk):
            let rank = s.legacy.rank(perk)
            if rank >= perk.maxRank { return err(state, .maxLevel) }
            let cost = Content.perkCost(currentRank: rank)
            if s.legacy.points < cost { return err(state, .notAffordable) }
            s.legacy.points -= cost
            s.legacy.perks[perk] = rank + 1

        case .hustle(let p):
            let l = s.line(p)
            guard l.owned, l.running, l.status != .storageFull, l.status != .noCash else { return err(state, .invalid) }
            s.updateLine(p) { $0.progress += Idle.hustleSeconds }
            s.meta.taps += 1

        case .upgradeLineAuto(let p, let count):
            guard s.line(p).owned else { return err(state, .locked) }
            guard Idle.nextLineStep(s, p) != nil else { return err(state, .maxLevel) }
            let milestonesBefore = Idle.milestonesReached(stage: Idle.stage(s, p))
            var bought = 0
            while bought < max(1, count), let next = Idle.nextLineStep(s, p), pay(Cost(dirty: next.cost), from: &s) {
                Idle.applyLineStep(&s, p, next.step)
                bought += 1
            }
            if bought == 0 { return err(state, .notAffordable) }
            if Idle.milestonesReached(stage: Idle.stage(s, p)) > milestonesBefore {
                s.log(.milestone, ref: p.rawValue, amount: Double(Idle.previousMilestone(stage: Idle.stage(s, p))))
            }

        case .prestige:
            guard Idle.canPrestige(s) else { return err(state, .requirements) }
            return ActionResult(state: restart(s, ngLevel: s.legacy.ngLevel), error: nil, outcome: 0, success: true)

        case .claimAchievement(let a):
            Idle.refreshAchievements(&s)
            guard Idle.achievementUnlocked(s, a) else { return err(state, .requirements) }
            if Idle.achievementClaimed(s, a) { return err(state, .invalid) }
            s.meta.claimed.append(a)
            s.meta.favors += Idle.achievementReward(a)

        case .claimDaily(let day):
            guard Idle.dailyAvailable(s, day: day) else { return err(state, .cooldown) }
            let reward = Idle.dailyReward(claims: s.meta.dailyClaims)
            s.meta.dailyLastDay = day
            s.meta.dailyClaims += 1
            switch reward {
            case .favors(let n): s.meta.favors += n
            case .boost(let seconds): Idle.addBoost(&s, seconds: seconds)
            case .warp(let seconds): warp(&s, seconds: seconds)
            }

        case .buyFavorItem(let item):
            if s.meta.favors < item.price { return err(state, .notAffordable) }
            switch item {
            case .boost4h:
                if s.meta.boostSeconds >= Idle.boostCapSeconds - 1 { return err(state, .maxLevel) }
                Idle.addBoost(&s, seconds: 4 * 3600)
            case .warp2h, .warp8h, .warp24h:
                warp(&s, seconds: item.warpSeconds)
            case .coolHeat:
                if s.heat <= 0.5 && s.investigation == nil { return err(state, .invalid) }
                relieveHeat(&s, by: Idle.favorHeatRelief, mods: m)
            case .loyalty:
                if s.crew.isEmpty || s.crew.allSatisfy({ $0.loyalty >= 100 }) { return err(state, .invalid) }
                for i in s.crew.indices { s.crew[i].loyalty = 100 }
            }
            s.meta.favors -= item.price

        case .adReward(let reward, let day):
            switch reward {
            case .boost:
                if s.meta.boostSeconds >= Idle.boostCapSeconds - 1 { return err(state, .maxLevel) }
                Idle.addBoost(&s, seconds: Idle.adBoostSeconds)
            case .coolHeat:
                if s.meta.heatAidCooldown > 0 { return err(state, .cooldown) }
                if s.heat <= 0.5 && s.investigation == nil { return err(state, .invalid) }
                relieveHeat(&s, by: Idle.adHeatRelief, mods: m)
                s.meta.heatAidCooldown = Idle.adHeatCooldown
            case .favors:
                if Idle.adFavorsLeft(s, day: day) <= 0 { return err(state, .cooldown) }
                if s.meta.adFavorsDay != day {
                    s.meta.adFavorsDay = day
                    s.meta.adFavorsToday = 0
                }
                s.meta.adFavorsToday += 1
                s.meta.favors += Idle.adFavors
            case .offlineDouble:
                if s.meta.offlineBonus <= 0 { return err(state, .invalid) }
                s.dirty += s.meta.offlineBonus
                s.meta.offlineBonus = 0
            }
            s.meta.adsWatched += 1

        case .grant(let grant):
            switch grant {
            case .favors(let n):
                if n <= 0 { return err(state, .invalid) }
                s.meta.favors += n
            case .premium:
                s.meta.premium = true
            case .noAds:
                s.meta.noAds = true
            case .starter:
                if s.meta.starterBought { return ok(&s) }
                s.meta.starterBought = true
                s.meta.favors += Idle.starterFavors
                Idle.addBoost(&s, seconds: Idle.starterBoostSeconds)
            }

        case .collectOffline(let doubled):
            if doubled { s.dirty += s.meta.offlineBonus }
            s.meta.offlineBonus = 0
        }
        return ok(&s)
    }

    /// Pays `c` if affordable. Returns false (and changes nothing) otherwise.
    private static func pay(_ c: Cost, from s: inout GameState) -> Bool {
        guard c.affordable(s) else { return false }
        c.pay(&s)
        return true
    }

    private static func err(_ s: GameState, _ e: ActionError) -> ActionResult {
        ActionResult(state: s, error: e, outcome: 0, success: false)
    }

    /// Ends the run: books the reputation it earned and starts a fresh city that keeps legacy and meta progress.
    private static func restart(_ state: GameState, ngLevel: Int) -> GameState {
        var s = state
        Idle.refreshAchievements(&s)
        let gain = Idle.prestigeGain(s)
        var meta = s.meta
        meta.reputation += gain
        meta.prestiges += 1
        let legacy = LegacyState(ngLevel: ngLevel, points: s.legacy.points, perks: s.legacy.perks, wins: s.legacy.wins)
        let seed = Rng.next(&s)
        var fresh = newGame(seed: seed, nowMs: s.lastWallClockMs, legacy: legacy, meta: meta, skipIntro: true)
        fresh.log(.prestige, amount: Double(gain), amount2: Double(meta.reputation))
        Idle.refreshAchievements(&fresh)
        return fresh
    }

    /// A paid time jump: simulated like time away (no events, no raids), without the offline cap.
    private static func warp(_ s: inout GameState, seconds: Double) {
        guard s.campaign.prologueDone else { return }
        Simulation.advance(&s, seconds: seconds, offline: true, step: 2)
    }

    /// Lowers Heat and drops an open investigation once Heat is under its clearing threshold.
    private static func relieveHeat(_ s: inout GameState, by amount: Double, mods m: Mods) {
        s.heat = max(0, s.heat - amount)
        if let inv = s.investigation, s.heat < m.clearThreshold {
            s.investigation = nil
            s.stats.investigationsSurvived += 1
            s.log(.investigationCleared, ref: inv.district.rawValue)
        }
    }

    private static func ok(_ s: inout GameState, outcome: Int = 0, success: Bool = true) -> ActionResult {
        Campaign.update(&s)
        Idle.refreshAchievements(&s)
        return ActionResult(state: s, error: nil, outcome: outcome, success: success)
    }

    private static func win(_ s: inout GameState) {
        s.campaign.won = true
        s.campaign.wonAtTime = s.time
        let award = Content.legacyAward(s)
        s.campaign.legacyAwarded = award
        s.legacy.points += award
        s.legacy.wins += 1
        s.investigation = nil
        s.log(.campaignWon, amount: Double(award))
    }

    public static func hireCost(_ s: GameState, _ def: CrewDef) -> Double {
        def.hireCost * (s.departed.contains(def.id) ? 1.5 : 1.0)
    }

    public static func bonusCost(_ c: CrewMember) -> Double {
        guard let d = c.def else { return 0 }
        return d.wagePerMin * d.trait.wageMult * 10
    }

    public enum UpgradeStatus: Sendable, Equatable {
        case owned, available, excluded, needsPrevious, chapterLocked
    }

    public static func upgradeStatus(_ s: GameState, _ u: UpgradeId) -> UpgradeStatus {
        if s.hasUpgrade(u) { return .owned }
        if let ex = u.exclusive, s.hasUpgrade(ex) { return .excluded }
        let branch = UpgradeId.inBranch(u.branch)
        let prevOk: Bool = switch u.tier {
        case 1: true
        case 2: branch.contains { $0.tier == 1 && s.hasUpgrade($0) }
        default: branch.contains { $0.tier == 2 && s.hasUpgrade($0) }
        }
        if s.campaign.chapter < Content.upgradeAvailableChapter(u) { return .chapterLocked }
        if !prevOk { return .needsPrevious }
        return .available
    }
}
