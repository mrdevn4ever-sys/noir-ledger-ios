import Foundation
import NoirCore
import Observation

/// A transient, localised message shown after a rejected action or a save problem.
struct NoticeMessage: Equatable, Sendable, Identifiable {
    let id: Int
    let key: String
    let danger: Bool
}

/// What just happened, for sound and haptics.
enum Feedback: Sendable, Equatable {
    case tap, buy, milestone, reject, claim, chapter, raid, alarm, decision, prestige, purchase, boost
}

/// A moment worth a banner.
struct Celebration: Equatable, Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        case milestone(FloorId, Int)
        case opened(FloorId)
        case manager(FloorId)
        case newCity(Int)
    }

    let id: Int
    let kind: Kind
}

/// Owns the live city: loading, time away, the online tick, actions, autosave and reset. All rules live in
/// `NoirCore.Tycoon`; this type only schedules them and persists the result.
@MainActor
@Observable
final class TycoonStore {
    enum Phase: Equatable {
        case loading
        case futureSave(Int)
        case ready
    }

    private(set) var phase: Phase = .loading
    private(set) var state: TycoonState
    /// Summary of the time credited while away (nil when nothing worth reporting).
    var offline: TycoonOffline?
    var restoredFromBackup = false
    private(set) var lastSavedAtMs: Int64?
    private(set) var notice: NoticeMessage?
    private(set) var celebration: Celebration?
    private(set) var acceptedCount = 0
    private(set) var rejectedCount = 0
    private(set) var tapCount = 0
    /// Cash a floor paid out with its last cycle, for floaters (floor → amount and a counter that changes each time).
    private(set) var payouts: [FloorId: (amount: Double, seq: Int)] = [:]

    @ObservationIgnored var onFeedback: (@MainActor (Feedback) -> Void)?
    @ObservationIgnored let saveStore: TycoonSaveStore
    /// The 2.x save, read once to carry favors and purchases over into the first city.
    @ObservationIgnored let legacyStore: SaveStore?
    @ObservationIgnored private let wallClockMs: @Sendable () -> Int64
    @ObservationIgnored private let makeSeed: @Sendable () -> UInt64
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var secondsSinceSave = 0.0
    @ObservationIgnored private var noticeCounter = 0
    @ObservationIgnored private var celebrationCounter = 0
    @ObservationIgnored private var payoutCounter = 0
    /// Game seconds per real second. Always 1 in Release; the Debug-only QA accelerator may raise it.
    @ObservationIgnored var timeScale = 1.0

    static let autosaveInterval = 5.0
    static let tickInterval = 0.25
    static let maxOnlineTick = 5.0

    init(saveStore: TycoonSaveStore, legacyStore: SaveStore? = nil,
         wallClockMs: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) },
         makeSeed: @escaping @Sendable () -> UInt64 = { UInt64.random(in: 1...UInt64.max) }) {
        self.saveStore = saveStore
        self.legacyStore = legacyStore
        self.wallClockMs = wallClockMs
        self.makeSeed = makeSeed
        self.state = Tycoon.newCity(seed: 1, nowMs: 0)
    }

    var nowMs: Int64 { wallClockMs() }

    /// Calendar day in the player's time zone (days since 1970), for daily rewards and caps.
    var today: Int {
        let seconds = Double(wallClockMs()) / 1000 + Double(TimeZone.current.secondsFromGMT())
        return Int((seconds / 86_400).rounded(.down))
    }

    // MARK: Lifecycle

    func load() {
        switch saveStore.load() {
        case .futureVersion(let v):
            phase = .futureSave(v)
            return
        case .loaded(let s, let restored):
            state = s
            restoredFromBackup = restored
        case .fresh:
            state = Tycoon.newCity(seed: makeSeed(), nowMs: wallClockMs(), meta: carriedWallet())
        }
        phase = .ready
        creditTimeAway()
        save()
    }

    /// Favors, purchases and the daily envelope from a 2.x save, so nothing the player paid for is lost.
    private func carriedWallet() -> MetaState {
        var meta = MetaState()
        guard let legacyStore, case .loaded(let old, _, _) = legacyStore.load() else { return meta }
        meta.favors = old.meta.favors
        meta.premium = old.meta.premium
        meta.noAds = old.meta.noAds
        meta.starterBought = old.meta.starterBought
        meta.dailyLastDay = old.meta.dailyLastDay
        meta.dailyClaims = old.meta.dailyClaims
        return meta
    }

    func enterForeground() {
        guard phase == .ready else { return }
        creditTimeAway()
        startTicking()
    }

    func enterBackground() {
        tickTask?.cancel()
        tickTask = nil
        guard phase == .ready else { return }
        state.lastWallClockMs = wallClockMs()
        save()
    }

    private func creditTimeAway() {
        let (next, report) = Tycoon.applyOffline(state, nowMs: wallClockMs())
        state = next
        if let report, report.earned > 0 || report.clockMovedBack { offline = report }
    }

    private func startTicking() {
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            let clock = ContinuousClock()
            var last = clock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(TycoonStore.tickInterval))
                guard let self, !Task.isCancelled else { return }
                let now = clock.now
                let elapsed = last.duration(to: now)
                last = now
                let dt = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                self.tick(seconds: dt)
            }
        }
    }

    /// Advances the online city by `seconds` of real time.
    func tick(seconds: Double) {
        guard phase == .ready else { return }
        let before = state
        let scaled = timeScale > 1 ? seconds * timeScale : min(Self.maxOnlineTick, max(0, seconds))
        Tycoon.advance(&state, seconds: scaled, offline: false)
        state.lastWallClockMs = wallClockMs()
        observe(from: before)
        secondsSinceSave += seconds
        if secondsSinceSave >= Self.autosaveInterval { save() }
    }

    /// Reports what the simulation did: cycles paid out, police arriving, raids, suitcases.
    private func observe(from before: TycoonState) {
        for f in FloorId.allCases {
            let gained = before.floor(f).running && (!state.floor(f).running || state.floor(f).progress < before.floor(f).progress)
            if gained && Tycoon.cycleTime(state, f) >= 0.5 {
                payoutCounter += 1
                payouts[f] = (Tycoon.revenuePerCycle(state, f), payoutCounter)
            }
        }
        if state.lastRaidLoss != nil && before.lastRaidLoss == nil {
            onFeedback?(.raid)
        } else if state.police != nil && before.police == nil {
            onFeedback?(.alarm)
        } else if state.suitcase != nil && before.suitcase == nil {
            onFeedback?(.decision)
        }
    }

    // MARK: Actions

    /// Applies a player action. Returns the cash it paid out directly (nil when rejected).
    @discardableResult
    func dispatch(_ action: TycoonAction) -> Double? {
        guard phase == .ready else { return nil }
        let before = state
        let r = Tycoon.apply(state, action)
        guard r.isOK else {
            if case .tapFloor = action { return nil }
            rejectedCount += 1
            onFeedback?(.reject)
            if let e = r.error { show(Labels.error(e)) }
            return nil
        }
        state = r.state
        if case .tapFloor = action {
            tapCount += 1
            onFeedback?(.tap)
            return r.gained
        }
        acceptedCount += 1
        report(action, from: before)
        save()
        return r.gained
    }

    private func report(_ action: TycoonAction, from before: TycoonState) {
        switch action {
        case .buy(let f, _):
            let was = Tycoon.milestonesReached(before.floor(f).count)
            let now = Tycoon.milestonesReached(state.floor(f).count)
            if now > was, let reached = TycoonContent.milestones.last(where: { $0 <= state.floor(f).count }) {
                celebrate(.milestone(f, reached))
                onFeedback?(.milestone)
            } else {
                onFeedback?(.buy)
            }
        case .open(let f):
            celebrate(.opened(f))
            onFeedback?(.milestone)
        case .hireManager(let f):
            celebrate(.manager(f))
            onFeedback?(.chapter)
        case .changeCity:
            celebrate(.newCity(state.meta.reputation - before.meta.reputation))
            onFeedback?(.prestige)
        case .buyDeal, .bribe:
            onFeedback?(.buy)
        case .grabSuitcase, .claimMission, .claimDaily, .collectOffline, .adReward:
            onFeedback?(.claim)
        case .grant:
            onFeedback?(.purchase)
        case .buyFavorItem:
            onFeedback?(.boost)
        case .tapFloor, .ackRaid:
            break
        }
    }

    private func celebrate(_ kind: Celebration.Kind) {
        celebrationCounter += 1
        celebration = Celebration(id: celebrationCounter, kind: kind)
    }

    func clearCelebration(_ id: Int) {
        if celebration?.id == id { celebration = nil }
    }

    func show(_ key: String, danger: Bool = false) {
        noticeCounter += 1
        notice = NoticeMessage(id: noticeCounter, key: key, danger: danger)
    }

    func clearNotice(_ id: Int) {
        if notice?.id == id { notice = nil }
    }

    // MARK: Rewards and purchases

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

    func rewardOffered(ads: AdService) -> Bool { state.meta.noAds || ads.ready }

    @discardableResult
    func deliver(_ grant: Grant) -> Bool {
        guard phase == .ready else { return false }
        return dispatch(.grant(grant)) != nil
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

    /// Starts over in a new city with no reputation. What the player paid for stays.
    func resetEverything() {
        var wallet = MetaState()
        if phase == .ready {
            wallet.favors = state.meta.favors
            wallet.premium = state.meta.premium
            wallet.noAds = state.meta.noAds
            wallet.starterBought = state.meta.starterBought
        }
        saveStore.erase()
        offline = nil
        restoredFromBackup = false
        celebration = nil
        state = Tycoon.newCity(seed: makeSeed(), nowMs: wallClockMs(), meta: wallet)
        phase = .ready
        save()
    }

    #if NOIR_QA
    /// Replaces the whole state. Debug/QA builds only.
    func replaceState(_ s: TycoonState) {
        state = s
        save()
    }
    #endif
}

extension FloorId {
    /// The 2.x product whose art, names and colours this floor uses.
    var product: ProductId {
        switch self {
        case .weed: .glimmer
        case .pills: .velvet
        case .crystal: .cinder
        case .coke: .halo
        }
    }
}
