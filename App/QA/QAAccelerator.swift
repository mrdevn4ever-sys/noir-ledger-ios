#if NOIR_QA
import Foundation
import NoirCore

/// Debug/UI-test-only campaign accelerator. Compiled only when the `NOIR_QA` flag is set (Debug configuration);
/// Release builds contain none of this code and no player-visible control can reach it. Driven exclusively by
/// launch arguments from XCUITest:
///
/// - `-qa-reset`              erase the save and the settings before loading
/// - `-qa-corrupt-save`       overwrite the primary save with garbage before loading (backup recovery)
/// - `-qa-future-save`        write a save from a newer schema before loading
/// - `-qa-seed N`             seed for a fresh campaign
/// - `-qa-scenario NAME`      chapter2…chapter5, final_ready, won, ngplus, investigation, raid, event, rich
/// - `-qa-away SECONDS`       pretend the app was closed this long (offline return summary)
/// - `-qa-timescale X`        game seconds per real second
/// - `-qa-quiet`              no new decisions during the session (stable screenshots)
enum QAAccelerator {
    private static var args: [String] { ProcessInfo.processInfo.arguments }

    private static func value(_ flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    private static func has(_ flag: String) -> Bool { args.contains(flag) }

    /// Runs before the save is loaded.
    @MainActor
    static func prepare(store: GameStore, settings: AppSettings) {
        let saveStore = store.saveStore
        if has("-qa-reset") {
            saveStore.erase()
            settings.resetToDefaults()
        }
        if let seed = value("-qa-seed").flatMap(UInt64.init) {
            seedOverride = seed
        }
        if has("-qa-corrupt-save") {
            try? Data("damaged".utf8).write(to: saveStore.primaryURL)
        }
        if has("-qa-future-save") {
            if let data = try? SaveCodec(currentVersion: saveSchemaVersion + 1).encode(GameState(), savedAtMs: 1) {
                try? data.write(to: saveStore.primaryURL)
            }
        }
    }

    nonisolated(unsafe) static var seedOverride: UInt64?

    /// Runs after the save is loaded.
    @MainActor
    static func apply(store: GameStore) {
        guard store.phase == .ready else { return }
        if let seed = seedOverride, !store.state.campaign.prologueDone, store.state.time == 0 {
            store.replaceState(Engine.newGame(seed: seed, nowMs: store.nowMs))
        }
        if let name = value("-qa-scenario") {
            var s = store.state
            scenario(&s, name)
            s.lastWallClockMs = store.nowMs
            store.replaceState(s)
        }
        if has("-qa-quiet") {
            var s = store.state
            s.nextEventAt = s.time + 1e9
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

    // MARK: Scenarios (state shortcuts that skip play time, never rules)

    static func finishBriefing(_ s: inout GameState) {
        s.campaign.prologueDone = true
        if s.campaign.prologueChoice == nil { s.campaign.prologueChoice = .cashBox }
        if s.campaign.tutorial != .done {
            s.campaign.tutorial = .done
            s.updateLine(.glimmer) { $0.running = true }
            s.updateDistrict(.cellars) { ds in
                let level = max(1, ds.route(.glimmer))
                ds.routes[.glimmer] = level
            }
            s.updateFront(.laundromat) { $0.owned = true }
        }
        s.campaign.chapter = max(1, s.campaign.chapter)
    }

    static func chapterSetup(_ s: inout GameState, _ chapter: Int) {
        finishBriefing(&s)
        s.campaign.chapter = max(s.campaign.chapter, chapter)
        let opened = DistrictId.allCases.filter { Content.district($0).unlockChapter < chapter }
        for d in opened {
            s.updateDistrict(d) { ds in
                ds.unlocked = true
                ds.rival = min(ds.rival, 35)
            }
            s.updateFront(Content.district(d).front) { $0.owned = true }
        }
        for p in ProductId.allCases where Content.product(p).unlockChapter < chapter {
            s.updateLine(p) { l in
                l.owned = true
                l.running = true
            }
            for d in opened where (Content.district(d).demandMod[p] ?? 0) >= 1.0 {
                s.updateDistrict(d) { ds in
                    let level = max(3, ds.route(p))
                    ds.routes[p] = level
                }
            }
        }
        s.storageLevel = max(s.storageLevel, min(Content.maxStorageLevel, 2 + chapter))
        let scale = pow(8.0, Double(chapter))
        s.dirty += 400 * scale
        s.clean += 300 * scale
        s.influence += 40 * Double(chapter * chapter)
        for c in Content.crew where c.unlockChapter < chapter && c.tier == 1 && s.crewIn(c.role) == nil {
            s.crew.append(CrewMember(defId: c.id, loyalty: 70, hiredAt: s.time))
        }
        s.heat = min(s.heat, 30)
    }

    static func finalReady(_ s: inout GameState) {
        chapterSetup(&s, Content.finalChapter)
        for d in DistrictId.allCases {
            s.updateDistrict(d) { ds in
                ds.unlocked = true
                ds.rival = 12
            }
            s.updateFront(Content.district(d).front) { $0.owned = true }
        }
        let ng = s.legacy.ngLevel
        s.clean = Content.finalCleanRequired(ng: ng) * 2.2
        s.influence = Content.finalInfluenceRequired(ng: ng) * 2.0
        s.dirty = 2_500_000 * (1 + 0.25 * Double(ng))
        s.heat = 12
        s.investigation = nil
        s.pendingEvent = nil
        s.crew = Content.crew.filter { $0.tier == 2 }.map { CrewMember(defId: $0.id, loyalty: 85, hiredAt: s.time) }
    }

    /// Plays the final operation through the engine's own actions (certain choices first, regrouping after failures).
    static func playFinalOperation(_ s: inout GameState) {
        if s.campaign.finalOp == nil { s = Engine.apply(s, .startFinalOp).state }
        var guardCount = 0
        while !s.campaign.won && guardCount < 40 {
            guardCount += 1
            guard let phase = Campaign.currentPhase(s) else { break }
            if let op = s.campaign.finalOp, op.readyAt > s.time {
                Simulation.advance(&s, seconds: op.readyAt - s.time + 1, offline: false)
                continue
            }
            let choices = Campaign.finalChoices(s, phase).filter { $0.available(s) }.sorted { $0.chance > $1.chance }
            guard let pick = choices.first else { break }
            s = Engine.apply(s, .finalOpChoice(pick.key)).state
        }
    }

    static func scenario(_ s: inout GameState, _ name: String) {
        switch name {
        case "chapter2", "chapter3", "chapter4", "chapter5":
            chapterSetup(&s, Int(name.dropFirst("chapter".count)) ?? 2)
        case "final_ready":
            finalReady(&s)
        case "won":
            finalReady(&s)
            playFinalOperation(&s)
        case "ngplus":
            finalReady(&s)
            playFinalOperation(&s)
            s = Engine.apply(s, .markEpilogueSeen).state
            s = Engine.apply(s, .startNewGamePlus).state
        case "investigation":
            chapterSetup(&s, 2)
            s.heat = 82
            s.investigation = Investigation(startedAt: s.time, endsAt: s.time + 45, district: Simulation.mostExposedDistrict(s))
            s.stats.investigations += 1
        case "raid":
            chapterSetup(&s, 2)
            s.inventory[.glimmer] = 60
            Simulation.raid(&s, district: .cellars)
        case "event":
            chapterSetup(&s, 2)
            let created = Events.create(&s, .rivalTruce)
            s.pendingEvent = created
        case "rich":
            s.dirty += 10_000_000
            s.clean += 10_000_000
            s.influence += 5000
        default:
            break
        }
        if name != "event" { s.nextEventAt = max(s.nextEventAt, s.time + 600) }
    }
}
#endif
