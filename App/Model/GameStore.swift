import Foundation
import NoirCore
import Observation

/// A transient, localised message shown after a rejected action or a save problem.
struct NoticeMessage: Equatable, Sendable, Identifiable {
    let id: Int
    let key: String
    let danger: Bool
}

/// What just happened, for sound and haptics. The store reports; `SoundEngine` and the views decide how it feels.
enum Feedback: Sendable, Equatable {
    case tap, buy, milestone, reject, claim, chapter, raid, alarm, decision, prestige, purchase, boost
}

/// A moment worth a banner: a line milestone, a finished chapter or a new start.
struct Celebration: Equatable, Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        case milestone(ProductId, stage: Int)
        case chapter(Int)
        case prestige(gain: Int)
    }

    let id: Int
    let kind: Kind
}

/// Owns the live game state: loading, offline credit, the one-second online tick, actions, autosave and reset.
/// All game rules live in `NoirCore`; this type only schedules them and persists the result.
@MainActor
@Observable
final class GameStore {
    enum Phase: Equatable {
        case loading
        case futureSave(Int)
        case ready
    }

    private(set) var phase: Phase = .loading
    private(set) var state: GameState
    /// Summary of time credited while the app was away (nil when nothing worth reporting).
    var offlineReport: OfflineReport?
    /// Set when the primary save was damaged and the backup copy was loaded.
    var restoredFromBackup = false
    private(set) var lastSavedAtMs: Int64?
    private(set) var notice: NoticeMessage?
    /// Increments on every accepted / rejected action (drives haptics).
    private(set) var acceptedCount = 0
    private(set) var rejectedCount = 0
    /// Result of the most recent final-operation attempt, for the phase feedback line.
    private(set) var lastFinalAttempt: (phase: Int, success: Bool)?
    /// Index of the outcome of the last resolved event.
    private(set) var lastEventOutcome: (event: EventId, key: String, index: Int)?
    /// The banner currently shown (milestone, chapter, new start).
    private(set) var celebration: Celebration?
    /// Increments on every tap on a line (drives the tap haptic).
    private(set) var tapCount = 0
    /// Called for every sound-worthy moment.
    @ObservationIgnored var onFeedback: ((Feedback) -> Void)?
    @ObservationIgnored private var celebrationCounter = 0

    @ObservationIgnored let saveStore: SaveStore
    @ObservationIgnored private let wallClockMs: @Sendable () -> Int64
    @ObservationIgnored private let makeSeed: @Sendable () -> UInt64
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var secondsSinceSave = 0.0
    @ObservationIgnored private var noticeCounter = 0
    /// Game seconds per real second. Always 1 in Release; the Debug-only QA accelerator may raise it.
    @ObservationIgnored var timeScale = 1.0

    static let autosaveInterval = 5.0
    /// Real seconds between online ticks: four a second keeps meters and counters moving smoothly.
    static let tickInterval = 0.25

    init(saveStore: SaveStore,
         wallClockMs: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) },
         makeSeed: @escaping @Sendable () -> UInt64 = { UInt64.random(in: 1...UInt64.max) }) {
        self.saveStore = saveStore
        self.wallClockMs = wallClockMs
        self.makeSeed = makeSeed
        self.state = Engine.newGame(seed: 1, nowMs: 0)
    }

    var nowMs: Int64 { wallClockMs() }

    /// Calendar day in the player's time zone (days since 1970), for daily rewards and daily caps.
    var today: Int {
        let seconds = Double(wallClockMs()) / 1000 + Double(TimeZone.current.secondsFromGMT())
        return Int((seconds / 86_400).rounded(.down))
    }

    // MARK: Lifecycle

    /// Loads the save (or starts fresh) and credits the time since it was written.
    func load() {
        switch saveStore.load() {
        case .futureVersion(let v):
            phase = .futureSave(v)
            return
        case .loaded(let loaded, let restored, let savedAt):
            state = loaded
            restoredFromBackup = restored
            lastSavedAtMs = savedAt
        case .fresh:
            state = Engine.newGame(seed: makeSeed(), nowMs: wallClockMs())
        }
        phase = .ready
        creditTimeAway()
        save()
    }

    /// Credits offline time and resumes the online tick.
    func enterForeground() {
        guard phase == .ready else { return }
        creditTimeAway()
        startTicking()
    }

    /// Stops ticking and writes the save immediately.
    func enterBackground() {
        tickTask?.cancel()
        tickTask = nil
        guard phase == .ready else { return }
        state.lastWallClockMs = wallClockMs()
        save()
    }

    private func creditTimeAway() {
        let (next, report) = Engine.applyOffline(state, nowMs: wallClockMs())
        state = next
        if let report { offlineReport = report }
    }

    private func startTicking() {
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            let clock = ContinuousClock()
            var last = clock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(GameStore.tickInterval))
                guard let self, !Task.isCancelled else { return }
                let now = clock.now
                let elapsed = last.duration(to: now)
                last = now
                let dt = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                self.tick(seconds: dt)
            }
        }
    }

    /// Advances the online simulation by `seconds` of real time.
    func tick(seconds: Double) {
        guard phase == .ready else { return }
        let before = state
        let scaled = seconds * timeScale
        if timeScale > 1 {
            var s = state
            if s.campaign.prologueDone { Simulation.advance(&s, seconds: scaled, offline: false) }
            s.lastWallClockMs = wallClockMs()
            state = s
        } else {
            state = Engine.tick(state, dtSec: scaled, nowMs: wallClockMs())
        }
        observe(from: before)
        secondsSinceSave += seconds
        if secondsSinceSave >= Self.autosaveInterval { save() }
    }

    /// Reports what the simulation did since `before`: a finished chapter, a raid, a new case file or decision.
    private func observe(from before: GameState) {
        if state.campaign.chapter > before.campaign.chapter, before.campaign.chapter >= 1 {
            celebrate(.chapter(before.campaign.chapter))
            onFeedback?(.chapter)
        }
        if state.raidUnseen && !before.raidUnseen {
            onFeedback?(.raid)
        } else if state.investigation != nil && before.investigation == nil {
            onFeedback?(.alarm)
        } else if state.pendingEvent != nil && before.pendingEvent == nil {
            onFeedback?(.decision)
        }
    }

    private func celebrate(_ kind: Celebration.Kind) {
        celebrationCounter += 1
        celebration = Celebration(id: celebrationCounter, kind: kind)
    }

    func clearCelebration(_ id: Int) {
        if celebration?.id == id { celebration = nil }
    }

    // MARK: Actions

    /// Applies a player action. Returns whether the engine accepted it.
    @discardableResult
    func dispatch(_ action: Action) -> Bool {
        guard phase == .ready else { return false }
        let r = Engine.apply(state, action)
        guard r.isOK else {
            // A tap on a line that cannot take work is simply ignored: no banner, no warning buzz.
            if case .hustle = action { return false }
            rejectedCount += 1
            onFeedback?(.reject)
            if let e = r.error { show(Labels.error(e)) }
            return false
        }
        if case .hustle = action {
            // Taps come in bursts: apply them without a banner, an accepted-action haptic or a disk write.
            state = r.state
            tapCount += 1
            onFeedback?(.tap)
            return true
        }
        let before = state
        if case .finalOpChoice = action, let phase = state.campaign.finalOp?.phase {
            lastFinalAttempt = (phase, r.success)
        }
        if case .resolveEvent(let key) = action, let event = state.pendingEvent?.event {
            lastEventOutcome = (event, key, r.outcome)
        }
        if case .startNewGamePlus = action { lastFinalAttempt = nil }
        state = r.state
        acceptedCount += 1
        report(action, from: before)
        save()
        return true
    }

    private func report(_ action: Action, from before: GameState) {
        switch action {
        case .upgradeLineAuto(let p, _):
            let stage = Idle.stage(state, p)
            if Idle.milestonesReached(stage: stage) > Idle.milestonesReached(stage: Idle.stage(before, p)) {
                celebrate(.milestone(p, stage: Idle.previousMilestone(stage: stage)))
                onFeedback?(.milestone)
            } else {
                onFeedback?(.buy)
            }
        case .prestige, .startNewGamePlus:
            celebrate(.prestige(gain: state.meta.reputation - before.meta.reputation))
            onFeedback?(.prestige)
        case .claimAchievement, .claimDaily, .collectOffline, .adReward:
            onFeedback?(.claim)
        case .grant:
            onFeedback?(.purchase)
        case .buyFavorItem:
            onFeedback?(.boost)
        case .buyLine, .upgradeLine, .upgradeStorage, .unlockDistrict, .upgradeRoute, .buyFront, .upgradeFront,
             .upgradeProtection, .hire, .buyUpgrade, .buyPerk, .turf, .bribe, .donate, .crewBonus:
            onFeedback?(.buy)
        default:
            break
        }
        observe(from: before)
    }

    // MARK: Rewards and purchases

    /// Pays a sponsor reward: directly for players with the ad-free upgrade, otherwise after a finished video.
    func claimReward(_ reward: AdReward, ads: AdService) {
        if state.meta.noAds {
            dispatch(.adReward(reward, day: today))
            return
        }
        guard ads.ready else {
            show("ad_unavailable")
            return
        }
        ads.show { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .rewarded: self.dispatch(.adReward(reward, day: self.today))
            case .dismissed: self.show("ad_dismissed")
            case .unavailable: self.show("ad_unavailable")
            }
        }
    }

    /// Whether a sponsor reward can be offered right now (ad-free players never wait for a video).
    func rewardOffered(ads: AdService) -> Bool { state.meta.noAds || ads.ready }

    /// Books a verified store purchase. Purchases are booked even before the prologue.
    @discardableResult
    func deliver(_ grant: Grant) -> Bool {
        guard phase == .ready else { return false }
        return dispatch(.grant(grant))
    }

    func show(_ key: String, danger: Bool = false) {
        noticeCounter += 1
        notice = NoticeMessage(id: noticeCounter, key: key, danger: danger)
    }

    func clearNotice(_ id: Int) {
        if notice?.id == id { notice = nil }
    }

    // MARK: Persistence

    func save() {
        guard phase == .ready else { return }
        let now = wallClockMs()
        do {
            try saveStore.write(state, savedAtMs: now)
            lastSavedAtMs = now
            secondsSinceSave = 0
        } catch {
            show("save_failed", danger: true)
        }
    }

    /// Erases the save (including New Game+ progress, legacy and reputation) and starts a fresh campaign.
    /// What the player paid for stays: favors and the permanent store upgrades.
    func resetEverything() {
        var wallet = MetaState()
        if phase == .ready {
            wallet.favors = state.meta.favors
            wallet.premium = state.meta.premium
            wallet.noAds = state.meta.noAds
            wallet.starterBought = state.meta.starterBought
        }
        saveStore.erase()
        offlineReport = nil
        restoredFromBackup = false
        lastFinalAttempt = nil
        lastEventOutcome = nil
        celebration = nil
        state = Engine.newGame(seed: makeSeed(), nowMs: wallClockMs(), meta: wallet)
        phase = .ready
        save()
    }

    #if NOIR_QA
    /// Replaces the whole state. Debug/QA builds only: used by the QA accelerator and tests, never by the player UI.
    func replaceState(_ s: GameState) {
        state = s
        save()
    }
    #endif
}
