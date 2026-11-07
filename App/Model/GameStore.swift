import Foundation
import NoirCore
import Observation

/// A transient, localised message shown after a rejected action or a save problem.
struct NoticeMessage: Equatable, Sendable, Identifiable {
    let id: Int
    let key: String
    let danger: Bool
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

    @ObservationIgnored let saveStore: SaveStore
    @ObservationIgnored private let wallClockMs: @Sendable () -> Int64
    @ObservationIgnored private let makeSeed: @Sendable () -> UInt64
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var secondsSinceSave = 0.0
    @ObservationIgnored private var noticeCounter = 0
    /// Game seconds per real second. Always 1 in Release; the Debug-only QA accelerator may raise it.
    @ObservationIgnored var timeScale = 1.0

    static let autosaveInterval = 5.0

    init(saveStore: SaveStore,
         wallClockMs: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) },
         makeSeed: @escaping @Sendable () -> UInt64 = { UInt64.random(in: 1...UInt64.max) }) {
        self.saveStore = saveStore
        self.wallClockMs = wallClockMs
        self.makeSeed = makeSeed
        self.state = Engine.newGame(seed: 1, nowMs: 0)
    }

    var nowMs: Int64 { wallClockMs() }

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
                try? await Task.sleep(for: .seconds(1))
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
        let scaled = seconds * timeScale
        if timeScale > 1 {
            var s = state
            if s.campaign.prologueDone { Simulation.advance(&s, seconds: scaled, offline: false) }
            s.lastWallClockMs = wallClockMs()
            state = s
        } else {
            state = Engine.tick(state, dtSec: scaled, nowMs: wallClockMs())
        }
        secondsSinceSave += seconds
        if secondsSinceSave >= Self.autosaveInterval { save() }
    }

    // MARK: Actions

    /// Applies a player action. Returns whether the engine accepted it.
    @discardableResult
    func dispatch(_ action: Action) -> Bool {
        guard phase == .ready else { return false }
        let r = Engine.apply(state, action)
        guard r.isOK else {
            rejectedCount += 1
            if let e = r.error { show(Labels.error(e)) }
            return false
        }
        if case .finalOpChoice = action, let phase = state.campaign.finalOp?.phase {
            lastFinalAttempt = (phase, r.success)
        }
        if case .resolveEvent(let key) = action, let event = state.pendingEvent?.event {
            lastEventOutcome = (event, key, r.outcome)
        }
        if case .startNewGamePlus = action { lastFinalAttempt = nil }
        state = r.state
        acceptedCount += 1
        save()
        return true
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

    /// Erases the save (including New Game+ progress and legacy) and starts a fresh campaign.
    func resetEverything() {
        saveStore.erase()
        offlineReport = nil
        restoredFromBackup = false
        lastFinalAttempt = nil
        lastEventOutcome = nil
        state = Engine.newGame(seed: makeSeed(), nowMs: wallClockMs())
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
