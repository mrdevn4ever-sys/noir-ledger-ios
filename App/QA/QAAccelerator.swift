#if NOIR_QA
import Foundation
import NoirCore

/// Debug/UI-test-only accelerator. Compiled only when the `NOIR_QA` flag is set (Debug configuration); Release builds
/// contain none of this code and no player-visible control can reach it. Driven exclusively by launch arguments:
///
/// - `-qa-reset`              erase the save and the settings before loading
/// - `-qa-corrupt-save`       overwrite the primary save with garbage before loading (backup recovery)
/// - `-qa-future-save`        write a save from a newer schema before loading
/// - `-qa-seed N`             seed for a fresh game
/// - `-qa-scenario NAME`      cellar, neck, board, chain, harbour, night, crown, late, contract, finale, hot
/// - `-qa-away SECONDS`       pretend the app was closed this long (return summary)
/// - `-qa-timescale X`        game seconds per real second
/// - `-qa-quiet`              no new orders on the board during the session (applied before the scenario)
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
    static func prepare(store: LedgerStore, settings: AppSettings) {
        if has("-qa-reset") {
            store.saveStore.erase()
            store.tycoonStore?.erase()
            store.legacyStore?.erase()
            settings.resetToDefaults()
        }
        if let seed = value("-qa-seed").flatMap(UInt64.init) { seedOverride = seed }
        if has("-qa-corrupt-save") {
            try? Data("damaged".utf8).write(to: store.saveStore.primaryURL)
        }
        if has("-qa-future-save") {
            let future = "{\"schema\": \(flowSchemaVersion + 1), \"savedAt\": 1, \"state\": {}}"
            try? FileManager.default.createDirectory(at: store.saveStore.directory, withIntermediateDirectories: true)
            try? Data(future.utf8).write(to: store.saveStore.primaryURL)
        }
    }

    /// Runs after the save is loaded.
    @MainActor
    static func apply(store: LedgerStore) {
        guard store.phase == .ready else { return }
        if let seed = seedOverride, store.state.earned == 0, store.state.start == nil {
            store.replaceState(Flow.newGame(seed: seed, nowMs: store.nowMs, meta: store.state.meta))
        }
        if has("-qa-quiet") {
            var s = store.state
            s.offers = []
            if s.nextOfferAt >= 0 || s.start != nil { s.nextOfferAt = 1e12 }
            store.replaceState(s)
        }
        if let name = value("-qa-scenario") {
            var s = store.state
            scenario(&s, name, quiet: has("-qa-quiet"))
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

    private static func choose(_ s: inout FlowState) {
        if s.start == nil { s = Flow.apply(s, .choose(.cashbox)).state }
    }

    private static func automate(_ s: inout FlowState, bench: Int, fleet: Int, contact: Int) {
        for g in s.openGoods {
            s.updateWorkshop(g) {
                $0.lead = true
                $0.bench = max($0.bench, bench)
                $0.shelf = max($0.shelf, max(1, bench / 2))
            }
        }
        s.dispatcher = true
        s.fleet = max(s.fleet, fleet)
        for id in s.contacts.keys { s.updateContact(id) { $0.level = max($0.level, contact) } }
    }

    private static func open(_ s: inout FlowState, _ goods: [Good], contacts: [String], quarters: [Quarter]) {
        for g in goods where !s.isOpen(g) { s.workshops[g] = WorkshopState() }
        for c in contacts where s.contacts[c] == nil { s.contacts[c] = ContactState() }
        for q in quarters where s.quarters[q] == nil { s.quarters[q] = QuarterState() }
    }

    /// Prepares a named situation for screenshots and UI tests.
    static func scenario(_ s: inout FlowState, _ name: String, quiet: Bool) {
        switch name {
        case "cellar":
            choose(&s)
        case "neck":
            // The guide's example: the bench makes more than the van carries; the shelf is full.
            choose(&s)
            s.updateWorkshop(.weed) { $0.lead = true; $0.bench = 2; $0.stock = 20 }
            s.cash = 40
            s.counters.deliveries = 3
            s.counters.purchases = 2
        case "board":
            choose(&s)
            s.updateWorkshop(.weed) { $0.lead = true }
            s.cash = 120
            s.counters.deliveries = 5
            s.counters.purchases = 3
            s.nextOfferAt = -1
            Flow.advance(&s, seconds: 0.25, offline: false)
        case "chain":
            choose(&s)
            open(&s, [], contacts: ["baeckerei"], quarters: [])
            automate(&s, bench: 12, fleet: 10, contact: 8)
            s.cash = 2_500
            s.earned = 6_200
            s.counters.deliveries = 220
            s.counters.orders = 2
            s.counters.purchases = 40
        case "harbour":
            choose(&s)
            s.chapter = 3
            s.specialists = [.okafor, .morgen]
            open(&s, [.crystal], contacts: ["baeckerei", "altmarkt", "uni", "kai7"], quarters: [.oldTown, .docks])
            automate(&s, bench: 40, fleet: 45, contact: 30)
            s.updateWorkshop(.crystal) { $0.bench = 12; $0.shelf = 4 }
            s.updateContact("kai7") { $0.level = 10 }
            s.updateQuarter(.docks) { $0.attention = 45 }
            s.cash = 3e6
            s.earned = 2e7
            s.counters.deliveries = 4_000
            s.counters.orders = 9
        case "night":
            choose(&s)
            s.chapter = 4
            s.specialists = [.okafor, .morgen, .sand]
            open(&s, [.crystal, .pills], contacts: ["baeckerei", "altmarkt", "uni", "kai7", "werk", "club"],
                 quarters: [.oldTown, .docks, .night])
            automate(&s, bench: 60, fleet: 80, contact: 40)
            s.updateWorkshop(.pills) { $0.bench = 10; $0.shelf = 6 }
            s.updateContact("club") { $0.level = 8 }
            s.cash = 5e8
            s.earned = 5e9
            s.counters.deliveries = 20_000
            s.counters.orders = 30
        case "crown":
            // Start at the chapter-five purchase decision, not after the new floor has appeared.
            scenario(&s, "night", quiet: quiet)
            s.chapter = 5
            s.specialists.append(.lind)
            s.quarters[.crown] = QuarterState()
            s.cash = FlowContent.good(.coke).openCost + FlowContent.good(.coke).leadCost
            s.earned = 3e10
        case "contract":
            scenario(&s, "late", quiet: quiet)
            s.counters.city = 3
            // Let the normal board generate the final contract; do not manufacture a win or an offer.
            Flow.advance(&s, seconds: 0.25, offline: false)
        case "late", "finale":
            choose(&s)
            s.chapter = name == "late" ? 6 : FlowContent.chapters.count + 1
            s.specialists = Specialist.allCases
            open(&s, Good.allCases, contacts: FlowContent.contacts.map(\.id), quarters: Quarter.allCases)
            automate(&s, bench: 100, fleet: 160, contact: 80)
            s.updateContact("villa") { $0.trust = 3 }
            s.updateQuarter(.crown) { $0.attention = 62 }
            s.updateQuarter(.night) { $0.attention = 33 }
            s.cash = 4e12
            s.earned = 2e13
            s.counters.deliveries = 90_000
            s.counters.orders = 120
            s.counters.city = name == "late" ? 1 : 3
            s.counters.finale = name == "finale"
        case "hot":
            choose(&s)
            automate(&s, bench: 8, fleet: 8, contact: 8)
            s.updateQuarter(.cellars) { $0.attention = 66 }
            s.counters.deliveries = 100
            s.counters.purchases = 20
        default:
            break
        }
        if quiet {
            s.offers.removeAll { $0.kind != .finale }
            s.nextOfferAt = 1e12
        }
    }
}
#endif
