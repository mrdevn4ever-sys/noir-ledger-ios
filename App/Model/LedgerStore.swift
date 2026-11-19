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
        case milestone(Station, Int)
        case opened(Good)
        case hired(String)
        case orderDone(Double)
        case chapterReady(Int)
    }

    let id: Int
    let kind: Kind
}

/// Owns the live ledger: loading, time away, the online tick, actions, autosave and reset. All rules live in
/// `NoirCore.Flow`; this type only schedules them, measures the real income stream and persists the result.
@MainActor
@Observable
final class LedgerStore {
    enum Phase: Equatable {
        case loading
        case futureSave(Int)
        case ready
    }

    private(set) var phase: Phase = .loading
    private(set) var state: FlowState
    var restoredFromBackup = false
    private(set) var lastSavedAtMs: Int64?
    private(set) var notice: NoticeMessage?
    private(set) var celebration: Celebration?
    private(set) var acceptedCount = 0
    private(set) var rejectedCount = 0
    private(set) var tapCount = 0
    /// Cash booked in the last minute of play, per minute: the real income stream (not the forecast).
    private(set) var measuredIncome = 0.0
    /// Increments with every booking, for the ledger's ink animation.
    private(set) var bookings = 0

    @ObservationIgnored var onFeedback: (@MainActor (Feedback) -> Void)?
    @ObservationIgnored let saveStore: FlowSaveStore
    /// Earlier saves (3.x city, 2.x campaign), read once to carry favors and purchases over.
    @ObservationIgnored let tycoonStore: TycoonSaveStore?
    @ObservationIgnored let legacyStore: SaveStore?
    @ObservationIgnored private let wallClockMs: @Sendable () -> Int64
    @ObservationIgnored private let makeSeed: @Sendable () -> UInt64
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var secondsSinceSave = 0.0
    @ObservationIgnored private var noticeCounter = 0
    @ObservationIgnored private var celebrationCounter = 0
    @ObservationIgnored private var recent: [(time: Double, amount: Double)] = []
    /// Game seconds per real second. Always 1 in Release; the Debug-only QA accelerator may raise it.
    @ObservationIgnored var timeScale = 1.0

    static let autosaveInterval = 5.0
    static let tickInterval = 0.25
    static let maxOnlineTick = 5.0

    init(saveStore: FlowSaveStore, tycoonStore: TycoonSaveStore? = nil, legacyStore: SaveStore? = nil,
         wallClockMs: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) },
         makeSeed: @escaping @Sendable () -> UInt64 = { UInt64.random(in: 1...UInt64.max) }) {
        self.saveStore = saveStore
        self.tycoonStore = tycoonStore
        self.legacyStore = legacyStore
        self.wallClockMs = wallClockMs
        self.makeSeed = makeSeed
        self.state = Flow.newGame(seed: 1, nowMs: 0)
    }

    var nowMs: Int64 { wallClockMs() }

    /// Calendar day in the player's time zone (days since 1970), for daily rewards and caps.
    var today: Int {
        let seconds = Double(wallClockMs()) / 1000 + Double(TimeZone.current.secondsFromGMT())
        return Int((seconds / 86_400).rounded(.down))
    }

    var forecast: Forecast { Flow.forecast(state) }

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
            state = Flow.newGame(seed: makeSeed(), nowMs: wallClockMs(), meta: carriedWallet())
        }
        phase = .ready
        creditTimeAway()
        save()
    }

    /// Favors, purchases and the daily envelope from an earlier version, so nothing the player paid for is lost.
    private func carriedWallet() -> MetaState {
        var meta = MetaState()
        var old: MetaState?
        if let tycoonStore, case .loaded(let city, _) = tycoonStore.load() { old = city.meta }
        if old == nil, let legacyStore, case .loaded(let campaign, _, _) = legacyStore.load() { old = campaign.meta }
        guard let old else { return meta }
        meta.favors = old.favors
        meta.premium = old.premium
        meta.noAds = old.noAds
        meta.starterBought = old.starterBought
        meta.dailyLastDay = old.dailyLastDay
        meta.dailyClaims = old.dailyClaims
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
        state = Flow.applyOffline(state, nowMs: wallClockMs())
        recent.removeAll()
        measuredIncome = 0
        save()
    }

    private func startTicking() {
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            let clock = ContinuousClock()
            var last = clock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(LedgerStore.tickInterval))
                guard let self, !Task.isCancelled else { return }
                let now = clock.now
                let elapsed = last.duration(to: now)
                last = now
                let dt = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                self.tick(seconds: dt)
            }
        }
    }

    /// Advances the game by `seconds` of real time.
    func tick(seconds: Double) {
        guard phase == .ready, state.start != nil else { return }
        let before = state
        let scaled = timeScale > 1 ? seconds * timeScale : min(Self.maxOnlineTick, max(0, seconds))
        Flow.advance(&state, seconds: scaled, offline: false)
        state.lastWallClockMs = wallClockMs()
        observe(from: before)
        secondsSinceSave += seconds
        if secondsSinceSave >= Self.autosaveInterval { save() }
    }

    /// Reports what the simulation did: bookings, new offers, finished or failed orders, a chapter ready to close.
    private func observe(from before: FlowState) {
        let gained = state.earned - before.earned
        if gained > 0 {
            recent.append((state.time, gained))
            bookings += 1
        }
        recent.removeAll { state.time - $0.time > 60 }
        let window = min(60, max(1, state.time - (recent.first?.time ?? state.time) + 1))
        measuredIncome = recent.reduce(0) { $0 + $1.amount } * 60 / max(window, 10)
        if state.counters.orders > before.counters.orders {
            let paid = state.ledger.last { $0.kind == .order }?.amount ?? 0
            celebrate(.orderDone(paid))
            onFeedback?(.claim)
        } else if state.counters.failed > before.counters.failed {
            show("order_failed", danger: true)
            onFeedback?(.reject)
        } else if state.offers.count > before.offers.count && !state.offers.isEmpty {
            onFeedback?(.decision)
        }
        if Flow.chapterComplete(state) && !Flow.chapterComplete(before) {
            celebrate(.chapterReady(state.chapter))
            onFeedback?(.chapter)
        }
    }

    // MARK: Actions

    /// Applies a player action. Returns the cash it paid out directly (nil when rejected).
    @discardableResult
    func dispatch(_ action: FlowAction) -> Double? {
        guard phase == .ready else { return nil }
        let before = state
        let r = Flow.apply(state, action)
        guard r.isOK else {
            switch action {
            case .tapBench, .tapFleet:
                if r.error == .requirements { show("hint_shelf_empty") } else if r.error == .maxLevel { show("hint_shelf_full") }
                rejectedCount += 1
            default:
                rejectedCount += 1
                onFeedback?(.reject)
                if let e = r.error { show(Labels.error(e)) }
            }
            return nil
        }
        state = r.state
        switch action {
        case .tapBench, .tapFleet:
            tapCount += 1
            onFeedback?(.tap)
            return r.gained
        default:
            break
        }
        acceptedCount += 1
        report(action, from: before)
        save()
        return r.gained
    }

    private func report(_ action: FlowAction, from before: FlowState) {
        switch action {
        case .upgrade(let station, _):
            let was = Flow.milestonesReached(Flow.level(before, station))
            let now = Flow.level(state, station)
            if Flow.milestonesReached(now) > was, let reached = FlowContent.milestones.last(where: { $0 <= now }) {
                celebrate(.milestone(station, reached))
                onFeedback?(.milestone)
            } else {
                onFeedback?(.buy)
            }
        case .openWorkshop(let g):
            celebrate(.opened(g))
            onFeedback?(.milestone)
        case .hireLead(let g):
            celebrate(.hired(FlowContent.good(g).lead))
            onFeedback?(.chapter)
        case .hireDispatcher:
            celebrate(.hired(FlowContent.dispatcher))
            onFeedback?(.chapter)
        case .unlockContact:
            onFeedback?(.milestone)
        case .accept:
            onFeedback?(.decision)
        case .closeChapter:
            onFeedback?(.prestige)
        case .use:
            onFeedback?(.boost)
        case .claimDaily, .collectOffline, .adReward:
            onFeedback?(.claim)
        case .grant:
            onFeedback?(.purchase)
        case .buyFavorItem:
            onFeedback?(.boost)
        case .choose, .startChallenge:
            onFeedback?(.chapter)
        default:
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

    /// Starts over in Leopold's cellar. What the player paid for stays.
    func resetEverything() {
        var wallet = MetaState()
        if phase == .ready {
            wallet.favors = state.meta.favors
            wallet.premium = state.meta.premium
            wallet.noAds = state.meta.noAds
            wallet.starterBought = state.meta.starterBought
        }
        saveStore.erase()
        restoredFromBackup = false
        celebration = nil
        recent.removeAll()
        measuredIncome = 0
        state = Flow.newGame(seed: makeSeed(), nowMs: wallClockMs(), meta: wallet)
        phase = .ready
        save()
    }

    #if NOIR_QA
    /// Replaces the whole state. Debug/QA builds only.
    func replaceState(_ s: FlowState) {
        state = s
        save()
    }
    #endif
}

extension Good {
    /// The product whose art, names and colours this good uses.
    var product: ProductId {
        switch self {
        case .weed: .glimmer
        case .crystal: .cinder
        case .pills: .velvet
        case .coke: .halo
        }
    }
}
