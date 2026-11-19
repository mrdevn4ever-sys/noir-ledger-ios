#if NOIR_QA
import Foundation
import NoirCore

/// Debug/UI-test-only accelerator. Compiled only when the `NOIR_QA` flag is set (Debug configuration); Release builds
/// contain none of this code and no player-visible control can reach it. Driven exclusively by launch arguments:
///
/// - `-qa-reset`              erase the save and the settings before loading
/// - `-qa-corrupt-save`       overwrite the primary save with garbage before loading (backup recovery)
/// - `-qa-future-save`        write a save from a newer schema before loading
/// - `-qa-seed N`             seed for a fresh city
/// - `-qa-scenario NAME`      starter, rich, police, suitcase, change, raid, call
/// - `-qa-away SECONDS`       pretend the app was closed this long (return summary)
/// - `-qa-timescale X`        game seconds per real second
/// - `-qa-quiet`              no Heat, no police, no suitcases and no calls during the session (applied before the scenario)
/// - `-qa-ads`                sponsor videos finish instantly (read by `AdService`)
enum QAAccelerator {
    private static var args: [String] { ProcessInfo.processInfo.arguments }

    private static func value(_ flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    private static func has(_ flag: String) -> Bool { args.contains(flag) }

    nonisolated(unsafe) static var seedOverride: UInt64?

    /// Runs before the save is loaded.
    @MainActor
    static func prepare(store: TycoonStore, settings: AppSettings) {
        if has("-qa-reset") {
            store.saveStore.erase()
            store.legacyStore?.erase()
            settings.resetToDefaults()
        }
        if let seed = value("-qa-seed").flatMap(UInt64.init) { seedOverride = seed }
        if has("-qa-corrupt-save") {
            try? Data("damaged".utf8).write(to: store.saveStore.primaryURL)
        }
        if has("-qa-future-save") {
            let future = "{\"schema\": \(tycoonSchemaVersion + 1), \"savedAt\": 1, \"state\": {}}"
            try? FileManager.default.createDirectory(at: store.saveStore.directory, withIntermediateDirectories: true)
            try? Data(future.utf8).write(to: store.saveStore.primaryURL)
        }
    }

    /// Runs after the save is loaded.
    @MainActor
    static func apply(store: TycoonStore) {
        guard store.phase == .ready else { return }
        if let seed = seedOverride, store.state.totalEarned == 0 {
            store.replaceState(Tycoon.newCity(seed: seed, nowMs: store.nowMs, meta: store.state.meta))
        }
        if has("-qa-quiet") {
            var s = store.state
            s.heat = 0
            s.police = nil
            s.suitcase = nil
            s.nextSuitcaseAt = s.time + 1e9
            s.call = nil
            s.nextCallAt = s.time + 1e9
            store.replaceState(s)
        }
        if let name = value("-qa-scenario") {
            var s = store.state
            scenario(&s, name)
            s.lastWallClockMs = store.nowMs
            store.replaceState(s)
        }
        if let away = value("-qa-away").flatMap(Double.init) {
            var s = store.state
            s.lastWallClockMs = store.nowMs - Int64(away * 1000)
            store.replaceState(s)
            store.enterForeground()
        }
        if let scale = value("-qa-timescale").flatMap(Double.init), scale > 0 {
            store.timeScale = scale
        }
    }

    /// Prepares a named situation for screenshots and UI tests.
    static func scenario(_ s: inout TycoonState, _ name: String) {
        switch name {
        case "starter":
            s.cash = 2_000
        case "rich", "police", "suitcase", "change", "raid", "call":
            for f in FloorId.allCases {
                s.updateFloor(f) { fl in
                    fl.count = max(fl.count, f == .weed ? 120 : 40)
                    fl.manager = true
                    fl.running = true
                    fl.trait = f == .pills || f == .coke ? .ghost : .hustler
                }
            }
            s.updateFloor(.weed) { $0.cut = .cut }
            s.cash = 5e8
            s.runEarned = 2e8
            s.totalEarned = max(s.totalEarned, 2e8)
            s.deals = ["weed_1", "pills_1"]
            s.hintsDone = true
            s.meta.favors = max(s.meta.favors, 120)
            switch name {
            case "police":
                s.heat = 100
                s.police = Police(arrivedAt: s.time, deadline: s.time + 600)
            case "suitcase":
                s.suitcase = Suitcase(amount: 12_345, expiresAt: s.time + 600, position: 0.5)
            case "change":
                s.runEarned = 4e8
            case "raid":
                s.lastRaidLoss = 1.25e8
                s.cash = 3.75e8
            case "call":
                s.call = ActiveCall(id: "villa", expiresAt: s.time + 600)
                s.lastCallId = "villa"
            default:
                break
            }
        default:
            break
        }
    }
}
#endif
