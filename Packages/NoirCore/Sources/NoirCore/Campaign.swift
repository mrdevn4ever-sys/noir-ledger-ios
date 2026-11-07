import Foundation

public struct ObjectiveProgress: Sendable, Equatable {
    public let objective: Objective
    public let current: Double
    public let target: Double

    public var done: Bool { current >= target - 1e-9 }
    public var fraction: Double { target <= 0 ? 1 : min(1, max(0, current / target)) }
}

public enum FinalPhase: Int, CaseIterable, Codable, Sendable {
    case cityHall = 0, convoy = 1, ledger = 2
}

public struct FinalChoice: Sendable, Equatable, Identifiable {
    public let key: String
    public let cost: Cost
    public let requiresRole: CrewRole?
    public let chance: Double
    public let heat: Double

    public var id: String { key }

    public func available(_ s: GameState) -> Bool {
        cost.affordable(s) && (requiresRole.map { s.crewIn($0) != nil } ?? true)
    }
}

public struct FinalRequirement: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable {
        case control(DistrictId), clean, influence, heat
    }

    public let kind: Kind
    public let current: Double
    public let target: Double
    public let atMost: Bool

    public var id: String {
        switch kind {
        case .control(let d): "control_\(d.rawValue)"
        case .clean: "clean"
        case .influence: "influence"
        case .heat: "heat"
        }
    }

    public var met: Bool { atMost ? current < target : current >= target - 1e-9 }
}

public enum Campaign {

    public static func progress(_ s: GameState, _ o: Objective) -> ObjectiveProgress {
        switch o {
        case .earnDirty(let amount):
            ObjectiveProgress(objective: o, current: s.stats.dirtyEarned, target: amount)
        case .lineLevels(let p, let total):
            ObjectiveProgress(objective: o, current: Double(s.line(p).totalLevels), target: Double(total))
        case .crewCount(let count):
            ObjectiveProgress(objective: o, current: Double(s.crew.count), target: Double(count))
        case .launder(let amount):
            ObjectiveProgress(objective: o, current: s.stats.cleanLaundered, target: amount)
        case .unlockDistrict(let d):
            ObjectiveProgress(objective: o, current: s.district(d).unlocked ? 1 : 0, target: 1)
        case .ownLine(let p):
            ObjectiveProgress(objective: o, current: s.line(p).owned ? 1 : 0, target: 1)
        case .ownFront(let f):
            ObjectiveProgress(objective: o, current: s.front(f).owned ? 1 : 0, target: 1)
        case .control(let d, let percent):
            ObjectiveProgress(objective: o, current: s.district(d).unlocked ? s.district(d).control : 0, target: percent)
        case .upgrades(let count):
            ObjectiveProgress(objective: o, current: Double(s.upgrades.count), target: Double(count))
        case .influenceHeld(let amount):
            ObjectiveProgress(objective: o, current: s.influence, target: amount)
        }
    }

    public static func objectives(_ s: GameState) -> [ObjectiveProgress] {
        Content.objectives(chapter: s.campaign.chapter).map { progress(s, $0) }
    }

    /// Advances the briefing and chapters when their conditions are met. Idempotent.
    public static func update(_ s: inout GameState) {
        guard s.campaign.prologueDone else { return }
        switch s.campaign.tutorial {
        case .startLine:
            if s.line(.glimmer).running { s.campaign.tutorial = .stockUp }
        case .stockUp:
            if s.stock(.glimmer) >= tutorialStockTarget { s.campaign.tutorial = .openRoute }
        case .openRoute:
            if s.district(.cellars).route(.glimmer) >= 1 {
                s.campaign.tutorial = .earn
                s.stats.tutorialEarned = 0
            }
        case .earn:
            if s.stats.tutorialEarned >= tutorialEarnTarget { s.campaign.tutorial = .buyFront }
        case .buyFront:
            if s.front(.laundromat).owned {
                s.campaign.tutorial = .launder
                s.tutorialLaunderBase = s.stats.cleanLaundered
            }
        case .launder:
            if s.stats.cleanLaundered - s.tutorialLaunderBase >= tutorialLaunderTarget { s.campaign.tutorial = .heatBriefing }
        case .heatBriefing, .done:
            break
        }
        guard s.campaign.tutorial == .done else { return }
        var guardCount = 0
        while (1...5).contains(s.campaign.chapter) && guardCount < 6 {
            guardCount += 1
            let objs = objectives(s)
            if objs.isEmpty || !objs.allSatisfy(\.done) { break }
            Content.chapterReward(s.campaign.chapter).grant(&s)
            s.log(.chapterComplete, ref: String(s.campaign.chapter))
            s.campaign.chapter += 1
        }
    }

    /// Current/target for the briefing steps that measure progress.
    public static func tutorialProgress(_ s: GameState) -> (current: Double, target: Double)? {
        switch s.campaign.tutorial {
        case .stockUp: return (current: s.stock(.glimmer), target: tutorialStockTarget)
        case .earn: return (current: s.stats.tutorialEarned, target: tutorialEarnTarget)
        case .launder: return (current: s.stats.cleanLaundered - s.tutorialLaunderBase, target: tutorialLaunderTarget)
        default: return nil
        }
    }

    // MARK: Final operation

    public static func finalRequirements(_ s: GameState) -> [FinalRequirement] {
        let ng = s.legacy.ngLevel
        var list: [FinalRequirement] = DistrictId.allCases.map { d in
            let ds = s.district(d)
            return FinalRequirement(kind: .control(d), current: ds.unlocked ? ds.control : 0, target: Content.finalControlRequired, atMost: false)
        }
        list.append(FinalRequirement(kind: .clean, current: s.clean, target: Content.finalCleanRequired(ng: ng), atMost: false))
        list.append(FinalRequirement(kind: .influence, current: s.influence, target: Content.finalInfluenceRequired(ng: ng), atMost: false))
        list.append(FinalRequirement(kind: .heat, current: s.heat, target: Content.finalHeatMax, atMost: true))
        return list
    }

    public static func finalReady(_ s: GameState) -> Bool {
        s.campaign.chapter >= Content.finalChapter && s.campaign.finalOp == nil && !s.campaign.won
            && finalRequirements(s).allSatisfy(\.met)
    }

    /// War chest paid when the operation begins.
    public static func finalWarChest(_ s: GameState) -> Cost {
        let ng = s.legacy.ngLevel
        return Cost(clean: Content.finalCleanRequired(ng: ng) * 0.5, influence: Content.finalInfluenceRequired(ng: ng) * 0.4)
    }

    public static func finalChoices(_ s: GameState, _ phase: FinalPhase) -> [FinalChoice] {
        let f = 1 + 0.25 * Double(s.legacy.ngLevel)
        switch phase {
        case .cityHall:
            return [
                FinalChoice(key: "votes", cost: Cost(clean: 300_000 * f), requiresRole: nil, chance: 1.0, heat: 0),
                FinalChoice(key: "leverage", cost: Cost(influence: 300 * f), requiresRole: .fixer, chance: 1.0, heat: 0),
                FinalChoice(key: "blackmail", cost: Cost(), requiresRole: nil, chance: 0.45, heat: 12),
            ]
        case .convoy:
            return [
                FinalChoice(key: "enforcer", cost: Cost(dirty: 150_000 * f), requiresRole: .enforcer, chance: 0.85, heat: 12),
                FinalChoice(key: "courier", cost: Cost(dirty: 150_000 * f), requiresRole: .courier, chance: 0.7, heat: 4),
                FinalChoice(key: "payoff", cost: Cost(dirty: 500_000 * f), requiresRole: nil, chance: 1.0, heat: 0),
            ]
        case .ledger:
            return [
                FinalChoice(key: "lawyer", cost: Cost(clean: 250_000 * f), requiresRole: .lawyer, chance: 0.85, heat: 0),
                FinalChoice(key: "fixer", cost: Cost(influence: 250 * f), requiresRole: .fixer, chance: 0.75, heat: 0),
                FinalChoice(key: "burn", cost: Cost(dirty: 400_000 * f), requiresRole: nil, chance: 0.6, heat: 20),
            ]
        }
    }

    public static func currentPhase(_ s: GameState) -> FinalPhase? {
        guard let op = s.campaign.finalOp else { return nil }
        return FinalPhase(rawValue: op.phase)
    }
}
