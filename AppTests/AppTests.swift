import Foundation
import NoirCore
import Testing
import UIKit
@testable import NoirLedger

// MARK: - Localization

@Suite("Localization integrity")
struct LocalizationTests {
    let en = L10n(language: "en")
    let de = L10n(language: "de")

    @Test("English and German tables are loaded and share exactly the same keys")
    func sameKeys() {
        #expect(en.keys.count > 500)
        #expect(en.keys == de.keys)
    }

    /// Every key the UI derives from engine identifiers.
    static var derivedKeys: [String] {
        var keys: [String] = []
        for p in ProductId.allCases { keys += [Labels.product(p), Labels.productDesc(p)] }
        for d in DistrictId.allCases { keys += [Labels.district(d), Labels.districtDesc(d), Labels.districtSpecial(d)] }
        for f in FrontId.allCases { keys += [Labels.front(f), Labels.frontDesc(f)] }
        for r in CrewRole.allCases { keys += [Labels.role(r), Labels.roleEffect(r)] }
        for t in Trait.allCases { keys += [Labels.trait(t), Labels.traitDesc(t)] }
        for b in UpgradeBranch.allCases { keys.append(Labels.branch(b)) }
        for u in UpgradeId.allCases { keys += [Labels.upgrade(u), Labels.upgradeDesc(u)] }
        for p in PerkId.allCases { keys += [Labels.perk(p), Labels.perkDesc(p)] }
        for s in LineStatus.allCases { keys.append(Labels.lineStatus(s)) }
        for t in LineTrack.allCases { keys.append(Labels.track(t)) }
        for c in 0...6 { keys += [Labels.chapterTitle(c), Labels.chapterIntro(c)] }
        for e in ActionError.allCases { keys.append(Labels.error(e)) }
        for p in FinalPhase.allCases {
            keys += [Labels.phaseTitle(p), Labels.phaseBody(p)]
        }
        var state = GameState()
        state.legacy.ngLevel = 0
        for p in FinalPhase.allCases {
            for c in Campaign.finalChoices(state, p) { keys.append(Labels.finalChoice(c.key)) }
        }
        for e in EventId.allCases {
            keys += [Labels.eventTitle(e), Labels.eventBody(e)]
            let pending = PendingEvent(event: e, district: .cellars, unit: 100, cleanUnit: 50, influenceUnit: 10, createdAt: 0)
            for c in Events.choices(pending) { keys.append(Labels.eventChoice(e, c.key)) }
        }
        for s in TutorialStep.allCases where s != .done { keys += [Labels.tutorialTitle(s), Labels.tutorialBody(s)] }
        for c in PrologueChoice.allCases { keys += [Labels.prologueChoice(c).title, Labels.prologueChoice(c).detail] }
        for k in [FinalRequirement.Kind.control(.cellars), .clean, .influence, .heat] { keys.append(Labels.requirement(k)) }
        for tab in AppTab.allCases { keys.append(tab.titleKey) }
        for section in NetworkSection.allCases { keys.append(section.titleKey) }
        for a in Account.allCases { keys.append(a.key) }
        for h in [HeatStatus.calm, .watched, .investigation, .layLow] { keys.append(h.key) }
        return keys
    }

    @Test("Every label derived from game content exists in both languages")
    func derivedLabelsExist() {
        let missing = Self.derivedKeys.filter { !en.has($0) || !de.has($0) }
        #expect(missing.isEmpty, "missing keys: \(missing)")
        #expect(Self.derivedKeys.count > 200)
    }

    @Test("Every journal entry kind renders a localized line")
    func journalLines() {
        for kind in JournalKind.allCases {
            let entry = JournalEntry(seq: 1, time: 60, kind: kind, ref: "CELLARS", amount: 12, amount2: 3)
            let line = JournalText.line(entry, de)
            #expect(!line.text.isEmpty)
            #expect(!line.text.contains("j_"), "untranslated journal key for \(kind)")
        }
    }

    @Test("Numbers, money and durations follow the language")
    func formatting() {
        #expect(en.money(1234) == "1,234")
        #expect(de.money(1234) == "1.234")
        #expect(en.money(25_500) == "25.5k")
        #expect(de.money(25_500) == "25,5 Tsd.")
        #expect(en.money(2_500_000) == "2.5M")
        #expect(en.duration(75) == "1m 15s")
        #expect(de.duration(3_900) == "1 h 05 min")
        #expect(en.percent(0.3) == "30%")
        #expect(de.percent(0.3) == "30 %")
        #expect(de("upd_bought_press").contains("30 %"))
        #expect(en.plural("obj_crew", count: 1, 1) == "Have 1 specialist in the crew")
        #expect(en.plural("obj_crew", count: 2, 2) == "Have 2 specialists in the crew")
    }

    @Test("Effect lines are written in the active language, never as raw keys")
    func effectLines() {
        let effects = Effects(influence: 3, heat: 5, loyalty: -2, control: 4, suspendSeconds: 300, stockLoss: 0.3,
                              mods: [ModTemplate(.price, 0.8, seconds: 900), ModTemplate(.productionSpeed, 0, seconds: 120)])
        let lines = EffectText.lines(effects, de)
        #expect(lines.count == 8)
        #expect(lines.allSatisfy { !$0.text.contains("eff_") })
    }
}

// MARK: - Store lifecycle

@MainActor
@Suite("Game store: saving, relaunch, offline return and recovery", .serialized)
struct GameStoreTests {
    final class Clock: @unchecked Sendable {
        var ms: Int64 = 1_700_000_000_000
    }

    private func makeStore(_ dir: URL, clock: Clock) -> GameStore {
        GameStore(saveStore: SaveStore(directory: dir), wallClockMs: { clock.ms }, makeSeed: { 4242 })
    }

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("noir-store-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("A fresh install starts at the prologue and writes a save")
    func freshInstall() {
        let dir = tempDir()
        let clock = Clock()
        let store = makeStore(dir, clock: clock)
        store.load()
        #expect(store.phase == .ready)
        #expect(!store.state.campaign.prologueDone)
        #expect(store.state.seed.raw == 4242)
        #expect(FileManager.default.fileExists(atPath: store.saveStore.primaryURL.path))
    }

    @Test("Actions persist across a relaunch, and time away is credited with a summary")
    func relaunchAndOffline() throws {
        let dir = tempDir()
        let clock = Clock()
        let store = makeStore(dir, clock: clock)
        store.load()
        #expect(store.dispatch(.choosePrologue(.cashBox)))
        #expect(store.dispatch(.setLineRunning(.glimmer, true)))
        store.tick(seconds: 1)
        store.enterBackground()
        let saved = store.state

        clock.ms += 2 * 3600 * 1000
        let relaunched = makeStore(dir, clock: clock)
        relaunched.load()
        #expect(relaunched.state.campaign.prologueChoice == .cashBox)
        #expect(relaunched.state.line(.glimmer).running)
        let report = try #require(relaunched.offlineReport)
        #expect(report.creditedSeconds == 2 * 3600)
        #expect(relaunched.state.time > saved.time + 7000)
    }

    @Test("A rejected action leaves the state untouched and shows a notice")
    func rejected() {
        let store = makeStore(tempDir(), clock: Clock())
        store.load()
        store.dispatch(.choosePrologue(.contacts))
        let before = store.state
        #expect(!store.dispatch(.upgradeStorage))
        #expect(store.state == before)
        #expect(store.notice?.key == "err_tutorial")
        #expect(store.rejectedCount == 1)
    }

    @Test("A damaged save is recovered from the backup and the player is told")
    func backupRecovery() throws {
        let dir = tempDir()
        let clock = Clock()
        let store = makeStore(dir, clock: clock)
        store.load()
        store.dispatch(.choosePrologue(.tools))
        store.save()
        try Data("damaged".utf8).write(to: store.saveStore.primaryURL)
        let relaunched = makeStore(dir, clock: clock)
        relaunched.load()
        #expect(relaunched.restoredFromBackup)
        #expect(relaunched.state.campaign.prologueDone)
    }

    @Test("A save from a newer version is never touched until the player starts over")
    func futureSave() throws {
        let dir = tempDir()
        let saveStore = SaveStore(directory: dir)
        let data = try SaveCodec(currentVersion: saveSchemaVersion + 1).encode(GameState(), savedAtMs: 1)
        try data.write(to: saveStore.primaryURL)
        let store = makeStore(dir, clock: Clock())
        store.load()
        #expect(store.phase == .futureSave(saveSchemaVersion + 1))
        store.save()
        #expect(try Data(contentsOf: saveStore.primaryURL) == data)
        store.resetEverything()
        #expect(store.phase == .ready)
        #expect(!store.state.campaign.prologueDone)
    }

    @Test("Reset erases legacy and campaign")
    func reset() {
        let store = makeStore(tempDir(), clock: Clock())
        store.load()
        store.dispatch(.choosePrologue(.cashBox))
        store.resetEverything()
        #expect(!store.state.campaign.prologueDone)
        #expect(store.state.legacy.points == 0)
    }

    @Test("Online ticks run the simulation in real time")
    func ticking() {
        let store = makeStore(tempDir(), clock: Clock())
        store.load()
        store.dispatch(.choosePrologue(.cashBox))
        store.dispatch(.setLineRunning(.glimmer, true))
        let t0 = store.state.time
        store.tick(seconds: 1)
        #expect(abs(store.state.time - t0 - 1) < 1e-9)
        store.tick(seconds: 60)
        #expect(abs(store.state.time - t0 - 1 - Engine.maxOnlineTick) < 1e-9, "long pauses are credited by applyOffline, not ticks")
    }
}

// MARK: - Settings

@MainActor
@Suite("Settings")
struct SettingsTests {
    @Test("Language choice switches the text table and persists")
    func language() {
        let suite = "noir.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let settings = AppSettings(defaults: defaults)
        settings.language = .de
        #expect(settings.l10n.language == "de")
        #expect(settings.l10n("nav_ledger") == "Buch")
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.language == .de)
        reloaded.language = .en
        #expect(reloaded.l10n("nav_ledger") == "Ledger")
        #expect(reloaded.reduceMotion(system: false) == false)
        reloaded.motion = .reduced
        #expect(reloaded.reduceMotion(system: false))
        defaults.removePersistentDomain(forName: suite)
    }
}

// MARK: - Shared assets

@Suite("Shared asset inventory")
struct AssetTests {
    static var names: [String] {
        var n = ProductId.allCases.map(Glyph.product) + DistrictId.allCases.map(Glyph.district)
        n += FrontId.allCases.map(Glyph.front) + CrewRole.allCases.map(Glyph.role) + UpgradeBranch.allCases.map(Glyph.branch)
        n += Content.crew.map { Glyph.portrait($0.id) }
        n += [Glyph.dirtyCash, Glyph.cleanCash, Glyph.influence, Glyph.heat, Glyph.investigation, Glyph.raid, Glyph.offlineReturn]
        n += ["BrandLedgerEmblem", "BrandWordmark", "MaterialLeather", "MaterialPaper", "MaterialRainGrain"]
        return n
    }

    @Test("Every canonical asset referenced by the UI is in the compiled asset catalog", arguments: AssetTests.names)
    func resolves(_ name: String) {
        #expect(UIImage(named: name) != nil, "missing asset \(name)")
    }

    @Test("Twelve crew portraits, five districts, four product seals")
    func counts() {
        #expect(Set(Content.crew.map { Glyph.portrait($0.id) }).count == 12)
        #expect(Set(DistrictId.allCases.map(Glyph.district)).count == 5)
        #expect(Set(ProductId.allCases.map(Glyph.product)).count == 4)
    }
}

// MARK: - Build flavour

@Suite("QA accelerator boundary")
struct BuildFlavorTests {
    @Test("The QA accelerator is compiled into Debug test builds only (Release is verified by the CI binary scan)")
    func debugHasAccelerator() {
        #if NOIR_QA
        var s = Engine.newGame(seed: 1, nowMs: 1)
        QAAccelerator.scenario(&s, "final_ready")
        #expect(Campaign.finalReady(s))
        QAAccelerator.playFinalOperation(&s)
        #expect(s.campaign.won)
        #else
        Issue.record("Debug test builds are expected to define NOIR_QA")
        #endif
    }
}
