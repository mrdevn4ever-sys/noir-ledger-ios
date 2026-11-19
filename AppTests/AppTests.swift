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
        for f in FloorId.allCases { keys += [Labels.product(f.product), Labels.productDesc(f.product)] }
        for item in StoreItem.allCases { keys.append(item.titleKey) }
        for e in ActionError.allCases { keys.append(Labels.error(e)) }
        for h in TycoonHint.allCases { keys.append(TycoonText.hint(h)) }
        keys += ["ty_suitcase_got", "ad_unavailable", "ad_dismissed", "shop_pending", "shop_failed", "save_failed"]
        keys += ["call_won", "call_lost", "call_done"]
        for c in Cut.allCases { keys += [CutText.name(c), CutText.desc(c)] }
        for call in TycoonContent.calls {
            keys.append("call_\(call.id)_b")
            for i in call.options.indices { keys.append("call_\(call.id)_o\(i)") }
        }
        return keys
    }

    @Test("Every answer to every call says in words what it does, in both languages")
    func callTexts() {
        for call in TycoonContent.calls {
            for effects in call.options {
                for table in [en, de] {
                    let text = CallText.effects(effects, unit: 1_000, table)
                    #expect(!text.isEmpty && !text.contains("ty_fx"), "untranslated effect in \(call.id)")
                }
            }
        }
    }

    @Test("Every label derived from game content exists in both languages")
    func derivedLabelsExist() {
        let missing = Self.derivedKeys.filter { !en.has($0) || !de.has($0) }
        #expect(missing.isEmpty, "missing keys: \(missing)")
        #expect(Self.derivedKeys.count > 20)
    }

    @Test("Every mission reads as a sentence in both languages, never as a raw key")
    func missionTexts() {
        for m in TycoonContent.missions {
            for table in [en, de] {
                let text = TycoonText.mission(m, table)
                #expect(!text.isEmpty && !text.contains("ty_m_"), "untranslated mission \(m.id)")
            }
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
        #expect(de.duration(1_800) == "30 min")
        #expect(de.duration(4 * 3_600) == "4 h")
        #expect(en.duration(7_200) == "2h")
        #expect(en.percent(0.3) == "30%")
        // German sets a no-break space before % so a value never wraps away from its sign.
        #expect(de.percent(0.3) == "30\u{00A0}%")
        #expect(de("upd_bought_press").contains("30\u{00A0}%"))
        #expect(en.plural("obj_crew", count: 1, 1) == "Have 1 specialist in the crew")
        #expect(en.plural("obj_crew", count: 2, 2) == "Have 2 specialists in the crew")
    }

}

// MARK: - Store lifecycle

@MainActor
@Suite("Tycoon store: saving, relaunch, time away, wallet and recovery", .serialized)
struct TycoonStoreTests {
    final class Clock: @unchecked Sendable {
        var ms: Int64 = 1_700_000_000_000
    }

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("noir-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeStore(_ dir: URL, clock: Clock) -> TycoonStore {
        TycoonStore(saveStore: TycoonSaveStore(directory: dir), legacyStore: SaveStore(directory: dir),
                    wallClockMs: { clock.ms }, makeSeed: { 42 })
    }

    @Test("A first launch starts a city and carries favors and purchases over from a 2.x save")
    func walletCarriesOver() throws {
        let dir = tempDir()
        var old = Engine.newGame(seed: 1, nowMs: 1)
        old.meta.favors = 77
        old.meta.premium = true
        try SaveStore(directory: dir).write(old, savedAtMs: 1)
        let store = makeStore(dir, clock: Clock())
        store.load()
        #expect(store.phase == .ready)
        #expect(store.state.floor(.weed).count == 1)
        #expect(store.state.meta.favors == 77)
        #expect(store.state.meta.premium)
    }

    @Test("Taps, purchases and managers survive a relaunch")
    func relaunch() {
        let dir = tempDir()
        let clock = Clock()
        let store = makeStore(dir, clock: clock)
        store.load()
        #expect(store.dispatch(.tapFloor(.weed)) != nil)
        store.tick(seconds: 1.1)
        #expect(store.state.cash >= 1)
        var rich = store.state
        rich.cash = 5_000
        store.replaceState(rich)
        #expect(store.dispatch(.hireManager(.weed)) != nil)
        #expect(store.dispatch(.buy(.weed, 10)) != nil)
        store.save()
        let again = makeStore(dir, clock: clock)
        again.load()
        #expect(again.state.floor(.weed).manager)
        #expect(again.state.floor(.weed).count == 11)
    }

    @Test("Time away is credited to managed floors with a summary")
    func timeAway() {
        let dir = tempDir()
        let clock = Clock()
        let store = makeStore(dir, clock: clock)
        store.load()
        var s = store.state
        s.cash = 1_000
        store.replaceState(s)
        store.dispatch(.hireManager(.weed))
        store.enterBackground()
        clock.ms += 2 * 3_600_000
        let again = makeStore(dir, clock: clock)
        again.load()
        let report = try! #require(again.offline)
        #expect(abs(report.earned - 7_200 * TycoonContent.hustlerRevenue) < 1, "two hours of a hustler on one plant")
        #expect(again.state.meta.offlineBonus > 0)
    }

    @Test("Reset keeps what was paid for and clears reputation")
    func resetKeepsWallet() {
        let store = makeStore(tempDir(), clock: Clock())
        store.load()
        #expect(store.deliver(.premium))
        #expect(store.deliver(.favors(80)))
        var s = store.state
        s.meta.reputation = 30
        store.replaceState(s)
        store.resetEverything()
        #expect(store.state.meta.premium)
        #expect(store.state.meta.favors == 80)
        #expect(store.state.meta.reputation == 0)
        #expect(store.state.floor(.weed).count == 1)
    }

    @Test("A damaged save is restored from the backup and flagged")
    func backup() throws {
        let dir = tempDir()
        let clock = Clock()
        let store = makeStore(dir, clock: clock)
        store.load()
        store.dispatch(.tapFloor(.weed))
        store.save()
        store.save()
        try Data("damaged".utf8).write(to: store.saveStore.primaryURL)
        let again = makeStore(dir, clock: clock)
        again.load()
        #expect(again.restoredFromBackup)
        #expect(again.phase == .ready)
    }

    @Test("A save from a newer version is never overwritten")
    func futureSave() throws {
        let dir = tempDir()
        let saveStore = TycoonSaveStore(directory: dir)
        let data = Data("{\"schema\": 99, \"savedAt\": 1, \"state\": {}}".utf8)
        try data.write(to: saveStore.primaryURL)
        let store = makeStore(dir, clock: Clock())
        store.load()
        #expect(store.phase == .futureSave(99))
        store.save()
        #expect(try Data(contentsOf: saveStore.primaryURL) == data)
        store.resetEverything()
        #expect(store.phase == .ready)
    }

    @Test("Rejected actions are reported for sound, taps are counted")
    func feedback() {
        let store = makeStore(tempDir(), clock: Clock())
        store.load()
        var heard: [Feedback] = []
        store.onFeedback = { heard.append($0) }
        store.dispatch(.tapFloor(.weed))
        #expect(store.tapCount == 1)
        #expect(heard.contains(.tap))
        #expect(store.dispatch(.hireManager(.weed)) == nil)
        #expect(heard.contains(.reject))
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
        var s = Tycoon.newCity(seed: 1, nowMs: 1)
        QAAccelerator.scenario(&s, "rich")
        #expect(FloorId.allCases.allSatisfy { s.floor($0).manager })
        #else
        Issue.record("Debug test builds are expected to define NOIR_QA")
        #endif
    }
}
