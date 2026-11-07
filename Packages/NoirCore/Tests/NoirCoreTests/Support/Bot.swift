import Foundation
import NoirCore

/// A deterministic, greedy autoplayer used to prove the campaign is completable from a fresh save through the
/// final operation, and to measure pacing. It only uses public `Engine` actions, exactly like the UI does.
struct Bot {
    var s: GameState
    private(set) var chapterTimes: [Int: Double] = [:]
    private(set) var chapterOrder: [Int] = []
    private(set) var actions = 0
    private(set) var tutorialStepsSeen: [TutorialStep] = []

    init(_ s: GameState) { self.s = s }

    @discardableResult
    private mutating func act(_ a: Action) -> Bool {
        let r = Engine.apply(s, a)
        guard r.isOK else { return false }
        s = r.state
        actions += 1
        return true
    }

    /// Plays until the campaign is won or `maxSeconds` of game time pass.
    mutating func run(maxSeconds: Double, decisionEvery: Double = 10) -> Bool {
        while s.time < maxSeconds {
            decide()
            if s.campaign.won { return true }
            Simulation.advance(&s, seconds: decisionEvery, offline: false)
            if chapterTimes[s.campaign.chapter] == nil {
                chapterTimes[s.campaign.chapter] = s.time
                chapterOrder.append(s.campaign.chapter)
            }
            if tutorialStepsSeen.last != s.campaign.tutorial { tutorialStepsSeen.append(s.campaign.tutorial) }
        }
        return s.campaign.won
    }

    private mutating func decide() {
        if !s.campaign.prologueDone {
            act(.choosePrologue(.cashBox))
            return
        }
        if s.raidUnseen { act(.ackRaid) }
        switch s.campaign.tutorial {
        case .startLine: act(.setLineRunning(.glimmer, true)); return
        case .stockUp: return
        case .openRoute: act(.upgradeRoute(.cellars, .glimmer)); return
        case .earn: return
        case .buyFront: act(.buyFront(.laundromat)); return
        case .launder: return
        case .heatBriefing: act(.ackTutorial); return
        case .done: break
        }
        if let p = s.pendingEvent {
            let choices = Events.choices(p)
            let pick = choices.first { $0.available(s) && $0.outcomes.allSatisfy { $0.effects.heat <= 0 } && !$0.cost.isFree }
                ?? choices.last { $0.available(s) }
            if let pick { act(.resolveEvent(pick.key)) }
        }
        manageHeat()
        if s.campaign.chapter >= Content.finalChapter {
            if s.campaign.finalOp == nil && Campaign.finalReady(s) { act(.startFinalOp) }
            if let phase = Campaign.currentPhase(s), (s.campaign.finalOp?.readyAt ?? 0) <= s.time {
                let choices = Campaign.finalChoices(s, phase).sorted { $0.chance > $1.chance }
                if let c = choices.first(where: { $0.available(s) && $0.chance >= 0.7 }) { act(.finalOpChoice(c.key)) }
            }
        }
        unlockStuff()
        hire()
        spend()
    }

    private mutating func manageHeat() {
        if s.heat >= 62 || s.investigation != nil { act(.bribe) }
        if s.investigation != nil && s.heat >= 70 && !s.layLow { act(.setLayLow(true)) }
        if s.layLow && s.heat < 45 { act(.setLayLow(false)) }
        if s.heatTarget > 55 && s.campaign.chapter >= 2 { act(.upgradeProtection) }
    }

    private mutating func unlockStuff() {
        for d in DistrictId.allCases where !s.district(d).unlocked { act(.unlockDistrict(d)) }
        for p in ProductId.allCases where !s.line(p).owned { act(.buyLine(p)) }
        for f in FrontId.allCases where !s.front(f).owned { act(.buyFront(f)) }
        for p in ProductId.allCases where s.line(p).owned && !s.line(p).running { act(.setLineRunning(p, true)) }
    }

    private mutating func hire() {
        for role in CrewRole.allCases {
            let candidates = Content.crew.filter { $0.role == role && $0.unlockChapter <= s.campaign.chapter }
                .sorted { $0.tier > $1.tier }
            guard let best = candidates.first else { continue }
            if let cur = s.crewIn(role) {
                if cur.defId != best.id && s.dirty > Engine.hireCost(s, best) * 3 {
                    act(.dismiss(cur.defId))
                    act(.hire(best.id))
                }
            } else {
                for c in candidates.sorted(by: { $0.hireCost < $1.hireCost }) where s.crewIn(role) == nil { act(.hire(c.id)) }
            }
            if let c = s.crewIn(role), c.loyalty < 40 { act(.crewBonus(c.defId)) }
        }
    }

    /// Big-ticket goals the bot saves up for.
    private func savingFor() -> Cost? {
        for d in DistrictId.allCases where !s.district(d).unlocked && s.campaign.chapter >= Content.district(d).unlockChapter {
            return Economy.districtUnlockCost(s, d, Economy.mods(s))
        }
        for f in FrontId.allCases where !s.front(f).owned && s.district(Content.front(f).district).unlocked {
            return Content.front(f).buy
        }
        for p in ProductId.allCases where !s.line(p).owned && s.campaign.chapter >= Content.product(p).unlockChapter {
            return Cost(dirty: Content.product(p).lineCost)
        }
        if s.campaign.chapter >= Content.finalChapter && s.campaign.finalOp == nil {
            return Cost(clean: Content.finalCleanRequired(ng: s.legacy.ngLevel), influence: Content.finalInfluenceRequired(ng: s.legacy.ngLevel))
        }
        if s.campaign.finalOp != nil { return Cost(dirty: 1_000_000, clean: 500_000) }
        return nil
    }

    private mutating func spend() {
        let goal = savingFor()
        let dirtyBudget = (goal.map { $0.dirty > 0 } ?? false) ? s.dirty * 0.08 : s.dirty
        let cleanBudget = (goal.map { $0.clean > 0 } ?? false) ? s.clean * 0.08 : s.clean
        let infBudget = (goal.map { $0.influence > 0 } ?? false) ? 0 : s.influence
        let savingDirty = goal.map { $0.dirty > 0 && $0.dirty > s.dirty } ?? false
        for f in FrontId.allCases where s.front(f).owned && s.front(f).active == savingDirty {
            act(.setFrontActive(f, !savingDirty))
        }

        var guardCount = 0
        while guardCount < 40 {
            guardCount += 1
            var opts: [(Action, Cost)] = []
            let m = Economy.mods(s)
            for p in ProductId.allCases {
                let l = s.line(p)
                guard l.owned else { continue }
                let prod = Economy.productionRate(s, p, m)
                let want = DistrictId.allCases.reduce(0.0) { acc, d in
                    let ds = s.district(d)
                    return acc + ((ds.unlocked && ds.route(p) > 0) ? Economy.desiredSales(s, d, p, m) : 0)
                }
                if prod < want * 1.3 {
                    for t in [LineTrack.capacity, .speed] where l.level(t) < Content.maxLineLevel {
                        opts.append((.upgradeLine(p, t), Cost(dirty: Content.lineUpgradeCost(p, t, currentLevel: l.level(t)))))
                    }
                }
                for d in DistrictId.allCases {
                    let ds = s.district(d)
                    guard ds.unlocked else { continue }
                    let lvl = ds.route(p)
                    guard lvl < Content.maxRouteLevel else { continue }
                    if Economy.routeCapacity(s, d, p, m) < Economy.demand(s, d, p) * 1.05 || lvl == 0 {
                        opts.append((.upgradeRoute(d, p), Cost(dirty: Content.routeCost(d, p, currentLevel: lvl))))
                    }
                }
                if l.qualityLevel < Content.maxLineLevel {
                    opts.append((.upgradeLine(p, .quality), Cost(dirty: Content.lineUpgradeCost(p, .quality, currentLevel: l.qualityLevel))))
                }
            }
            for o in Campaign.objectives(s) where !o.done {
                if case .lineLevels(let p, _) = o.objective {
                    let l = s.line(p)
                    for t in LineTrack.allCases where l.level(t) < Content.maxLineLevel {
                        opts.append((.upgradeLine(p, t), Cost(dirty: Content.lineUpgradeCost(p, t, currentLevel: l.level(t)))))
                    }
                }
            }
            if s.totalStock > Economy.stashCapacity(s, m) * 0.8 && s.storageLevel < Content.maxStorageLevel {
                opts.append((.upgradeStorage, Cost(dirty: Content.storageCost(currentLevel: s.storageLevel))))
            }
            for f in FrontId.allCases {
                let fs = s.front(f)
                if fs.owned && fs.level < Content.maxFrontLevel && s.incomeRate > Economy.launderCapacity(s, m) * 0.9 {
                    opts.append((.upgradeFront(f), Cost(clean: Content.frontUpgradeCost(f, currentLevel: fs.level) * m.frontUpgradeCost)))
                }
            }
            for u in UpgradeId.allCases where Engine.upgradeStatus(s, u) == .available {
                opts.append((.buyUpgrade(u), Content.upgradeCost(u)))
            }
            if s.campaign.chapter >= 2 && s.protectionLevel < Content.maxProtectionLevel && s.heatTarget > 45 {
                opts.append((.upgradeProtection, Cost(clean: Content.protectionCost(currentLevel: s.protectionLevel))))
            }
            for d in DistrictId.allCases {
                let ds = s.district(d)
                if ds.unlocked && ds.control < 78 && ds.turfReadyAt <= s.time && s.heat < 55 {
                    opts.append((.turf(d), Economy.turfCost(s, d)))
                }
            }
            if s.campaign.chapter >= 2 && s.clean > Economy.donationCost(s) * 6 && (goal == nil || goal!.clean <= 0) {
                opts.append((.donate, Cost(clean: Economy.donationCost(s))))
            }

            let current = s
            let affordable = opts.filter { pair in
                let c = pair.1
                return c.dirty <= dirtyBudget && c.clean <= cleanBudget && c.influence <= infBudget && c.affordable(current)
            }
            guard let pick = affordable.min(by: { a, b in
                (a.1.dirty + a.1.clean * 1.5 + a.1.influence * 200) < (b.1.dirty + b.1.clean * 1.5 + b.1.influence * 200)
            }) else { break }
            if !act(pick.0) { break }
        }
    }
}
