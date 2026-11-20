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
        for g in Good.allCases { keys += [GoodText.name(g), GoodText.role(g), Labels.product(g.product)] }
        for q in Quarter.allCases { keys += [QuarterText.name(q), QuarterText.desc(q)] }
        for c in FlowContent.contacts { keys += [ContactText.name(c.id), ContactText.desc(c.id)] }
        for ch in FlowContent.chapters { keys += [ChapterText.title(ch.number), ChapterText.intro(ch.number), ChapterText.outro(ch.number)] }
        for h in FlowHint.allCases { keys.append(HintText.key(h)) }
        for b in [Bottleneck.bench, .fleet, .demand, .shelf, .balanced] { keys.append(NeckText.key(b)) }
        for c in StartChoice.allCases { keys += [StartText.title(c), StartText.desc(c), StartText.effect(c)] }
        for k in OrderKind.allCases { keys.append(OrderText.kind(k)) }
        for sp in Specialist.allCases { keys += [SpecialistText.role(sp), SpecialistText.effect(sp)] }
        for a in Ability.allCases { keys += [AbilityText.name(a), AbilityText.desc(a)] }
        for c in ChallengeId.allCases {
            keys += [ChallengeText.name(c), ChallengeText.desc(c)] + (0..<3).map { ChallengeText.goal(c, $0) }
        }
        for i in 0...3 { keys += ["l4_tier_\(i)", "l4_tier_effect_\(i)"] }
        for st in [Station.fleet, .bench(.weed), .shelf(.weed), .contact("muehlgasse")] { keys.append(StationSheet.explainKey(st)) }
        for item in StoreItem.allCases { keys.append(item.titleKey) }
        for e in ActionError.allCases { keys.append(Labels.error(e)) }
        keys += ["ad_unavailable", "ad_dismissed", "shop_pending", "shop_failed", "shop_not_booked", "save_failed", "order_failed",
                 "hint_shelf_empty", "hint_shelf_full"]
        return keys
    }

    @Test("Every return advice and the estate booking read as sentences in both languages")
    func adviceTexts() {
        var advice: [ReturnAdvice] = [.hireDispatcher, .sendVan, .upgrade(.fleet), .upgrade(.bench(.weed))]
        for g in Good.allCases { advice += [ReturnAdvice.hireLead(g), ReturnAdvice.startBench(g)] }
        for table in [en, de] {
            for a in advice {
                for text in [AdviceText.button(a, table), AdviceText.reason(a, table)] {
                    #expect(!text.isEmpty && !text.contains("l4_"), "untranslated advice \(a)")
                }
            }
            let picked = Flow.apply(Flow.newGame(seed: 1, nowMs: 1), .collectEstate).state
            if let entry = picked.ledger.last {
                #expect(entry.kind == .estate && !BookSheet.line(entry, table).contains("l4_"))
            } else {
                Issue.record("the pickup books a line")
            }
            #expect(table("shop_premium_d", table.duration(FlowContent.offlineCap * 2)).contains(table.duration(24 * 3_600)),
                    "the silent partner promises the 24 hours the ledger credits")
        }
    }

    @Test("Every label derived from game content exists in both languages")
    func derivedLabelsExist() {
        let missing = Self.derivedKeys.filter { !en.has($0) || !de.has($0) }
        #expect(missing.isEmpty, "missing keys: \(missing)")
        #expect(Self.derivedKeys.count > 100)
    }

    @Test("Every chapter goal reads as a sentence in both languages, never as a raw key")
    func goalTexts() {
        for ch in FlowContent.chapters {
            for goal in ch.goals {
                for table in [en, de] {
                    let text = ChapterText.goal(goal, table)
                    #expect(!text.isEmpty && !text.contains("l4_g_"), "untranslated goal \(goal.id)")
                }
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
@Suite("Ledger store: saving, relaunch, time away, wallet and recovery", .serialized)
struct LedgerStoreTests {
    final class Clock: @unchecked Sendable {
        var ms: Int64 = 1_700_000_000_000
    }

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("noir-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeStore(_ dir: URL, clock: Clock) -> LedgerStore {
        LedgerStore(saveStore: FlowSaveStore(directory: dir), tycoonStore: TycoonSaveStore(directory: dir),
                    legacyStore: SaveStore(directory: dir), wallClockMs: { clock.ms }, makeSeed: { 42 })
    }

    @Test("A first launch shows the prologue and carries favors and purchases over from a 3.x save")
    func walletCarriesOver() throws {
        let dir = tempDir()
        var old = Tycoon.newCity(seed: 1, nowMs: 1)
        old.meta.favors = 77
        old.meta.premium = true
        try TycoonSaveStore(directory: dir).write(old, savedAtMs: 1)
        let store = makeStore(dir, clock: Clock())
        store.load()
        #expect(store.phase == .ready)
        #expect(store.state.start == nil, "Leopold's things are still to be chosen")
        #expect(store.state.meta.favors == 77)
        #expect(store.state.meta.premium)
        #expect(store.dispatch(.choose(.tools)) != nil)
        #expect(store.state.workshop(.weed)?.bench == FlowContent.toolsBench)
    }

    @Test("Taps, purchases and crew survive a relaunch")
    func relaunch() {
        let dir = tempDir()
        let clock = Clock()
        let store = makeStore(dir, clock: clock)
        store.load()
        store.dispatch(.choose(.cashbox))
        #expect(store.dispatch(.tapBench(.weed)) != nil)
        store.tick(seconds: 5.5)
        #expect(store.state.workshop(.weed)!.stock >= 1)
        var rich = store.state
        rich.cash = 5_000
        store.replaceState(rich)
        #expect(store.dispatch(.hireLead(.weed)) != nil)
        #expect(store.dispatch(.upgrade(.fleet, 5)) != nil)
        store.save()
        let again = makeStore(dir, clock: clock)
        again.load()
        #expect(again.state.workshop(.weed)?.lead == true)
        #expect(again.state.fleet == 6)
    }

    @Test("Time away is booked once by the automated chain, with a summary shown until dismissed")
    func timeAway() {
        let dir = tempDir()
        let clock = Clock()
        let store = makeStore(dir, clock: clock)
        store.load()
        store.dispatch(.choose(.cashbox))
        var s = store.state
        s.cash = 1_000
        store.replaceState(s)
        store.dispatch(.hireLead(.weed))
        store.dispatch(.hireDispatcher)
        let rate = Flow.forecast(store.state).income
        store.enterBackground()
        clock.ms += 2 * 3_600_000
        let again = makeStore(dir, clock: clock)
        again.load()
        let report = try! #require(again.state.welcome)
        #expect(abs(report.earned - rate * 120) <= rate * 120 * 0.03)
        let cash = again.state.cash
        let third = makeStore(dir, clock: clock)
        third.load()
        #expect(third.state.welcome != nil && abs(third.state.cash - cash) < 1e-6, "showing it again does not pay again")
        third.dispatch(.collectOffline(doubled: false))
        #expect(third.state.welcome == nil)
    }

    @Test("Reset keeps what was paid for and the booked transactions, and starts over at the cellar door")
    func resetKeepsWallet() {
        let store = makeStore(tempDir(), clock: Clock())
        store.load()
        store.dispatch(.choose(.cashbox))
        #expect(store.book(.premium, transaction: "9001") == .booked)
        #expect(store.book(.favors(80), transaction: "9002") == .booked)
        store.resetEverything()
        #expect(store.state.meta.premium)
        #expect(store.state.meta.favors == 80)
        #expect(store.state.meta.deliveredTransactions == ["9001", "9002"])
        #expect(store.state.start == nil && store.state.estate == .waiting)
        #expect(store.book(.favors(80), transaction: "9002") == .alreadyBooked, "a redelivery after a reset pays nothing")
        #expect(store.state.meta.favors == 80)
    }

    @Test("A damaged save is restored from the backup and flagged")
    func backup() throws {
        let dir = tempDir()
        let clock = Clock()
        let store = makeStore(dir, clock: clock)
        store.load()
        store.dispatch(.choose(.cashbox))
        store.save()
        store.save()
        try Data("damaged".utf8).write(to: store.saveStore.primaryURL)
        let again = makeStore(dir, clock: clock)
        again.load()
        #expect(again.restoredFromBackup)
        #expect(again.phase == .ready)
        #expect(again.state.start == .cashbox)
    }

    @Test("A save from a newer version is never overwritten")
    func futureSave() throws {
        let dir = tempDir()
        let saveStore = FlowSaveStore(directory: dir)
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

    @Test("Rejected actions are reported for sound, taps are counted, the real income is measured")
    func feedback() {
        let store = makeStore(tempDir(), clock: Clock())
        store.load()
        store.dispatch(.choose(.addressBook))
        var heard: [Feedback] = []
        store.onFeedback = { heard.append($0) }
        store.dispatch(.tapBench(.weed))
        #expect(store.tapCount == 1)
        #expect(heard.contains(.benchWeed))
        #expect(store.dispatch(.hireDispatcher) == nil)
        #expect(heard.contains(.reject))
        store.tick(seconds: 5.25)
        store.dispatch(.tapFleet)
        store.tick(seconds: 5)
        store.tick(seconds: 5.25)
        #expect(store.state.counters.deliveries == 1)
        let booked = store.state.ledger.filter { $0.kind == .delivery }.map(\.amount).reduce(0, +)
        #expect(booked > 0)
        #expect(abs(store.measuredIncome - booked) < 1e-9, "the last minute shows what was booked, not an extrapolation")
        for _ in 0..<13 { store.tick(seconds: 5) }
        #expect(store.measuredIncome == 0, "a minute without bookings shows nothing")
    }

    // MARK: Opening and old saves

    @Test("The pickup at the door is booked once and survives a relaunch before the choice")
    func estateOnceAcrossRelaunch() {
        let dir = tempDir()
        let clock = Clock()
        let store = makeStore(dir, clock: clock)
        store.load()
        #expect(store.state.estate == .waiting && store.state.start == nil)
        #expect(store.dispatch(.collectEstate) == FlowContent.estatePickupCash)
        let again = makeStore(dir, clock: clock)
        again.load()
        #expect(again.state.estate == .booked && again.state.cash == 20 && again.state.start == nil)
        #expect(again.dispatch(.collectEstate) == nil, "relaunching halfway never pays twice")
        #expect(again.dispatch(.choose(.tools)) != nil)
        #expect(again.state.cash == 20)
        #expect(Flow.firstVanUpgradeReady(again.state))
        #expect(again.dispatch(.upgrade(.fleet, 1)) != nil)
        #expect(Flow.fleetCapacity(again.state) == 2)
    }

    @Test("A build-56 business loads with crew, orders, favors, purchases and time away, and never gets the pickup")
    func oldBusinessSave() throws {
        let dir = tempDir()
        try Data(OldSaves.business.utf8).write(to: FlowSaveStore(directory: dir).primaryURL)
        let clock = Clock()
        clock.ms = 1_700_000_000_000 + 2 * 3_600_000
        let store = makeStore(dir, clock: clock)
        store.load()
        let s = store.state
        #expect(store.phase == .ready && s.start == .tools && s.chapter == 2)
        #expect(s.estate == .notOffered && !s.ledger.contains { $0.kind == .estate })
        #expect(s.dispatcher && s.workshop(.weed)?.lead == true && s.specialists == [.okafor])
        #expect(s.meta.favors == 77 && s.meta.premium && s.meta.noAds && s.meta.starterBought)
        let report = try #require(s.welcome, "two hours away are credited")
        #expect(report.earned > 0)
        #expect(store.dispatch(.collectEstate) == nil)
        let cash = s.cash
        let again = makeStore(dir, clock: clock)
        again.load()
        #expect(abs(again.state.cash - cash) < 1e-6, "loading the same save again does not pay again")
        #expect(again.state.welcome != nil)
    }

    // MARK: Paid delivery

    /// Makes the next save fail the way a full or broken disk does: the temporary file's path is taken by a folder.
    private func blockWrites(_ store: LedgerStore) throws {
        let blocker = store.saveStore.directory.appendingPathComponent("noir_flow.save.tmp")
        try FileManager.default.createDirectory(at: blocker, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: blocker.appendingPathComponent("keep"))
    }

    private func unblockWrites(_ store: LedgerStore) throws {
        try FileManager.default.removeItem(at: store.saveStore.directory.appendingPathComponent("noir_flow.save.tmp"))
    }

    @Test("A paid grant is booked only together with its transaction id on disk; a failed write books nothing")
    func paidDeliveryWriteFailure() throws {
        let dir = tempDir()
        let clock = Clock()
        let store = makeStore(dir, clock: clock)
        store.load()
        store.dispatch(.collectEstate)
        store.dispatch(.choose(.cashbox))
        let favors = store.state.meta.favors
        try blockWrites(store)
        #expect(store.book(.favors(500), transaction: "77001") == .notBooked)
        #expect(store.state.meta.favors == favors && store.state.meta.deliveredTransactions.isEmpty, "nothing shown that is not saved")
        let reloaded = makeStore(dir, clock: clock)
        reloaded.load()
        #expect(reloaded.state.meta.favors == favors)
        try unblockWrites(store)
        // The store delivers the unfinished transaction again: now it is booked, exactly once.
        #expect(reloaded.book(.favors(500), transaction: "77001") == .booked)
        #expect(reloaded.state.meta.favors == favors + 500)
        // A crash after the write and before the store hears about it: on relaunch the same id comes again.
        let relaunched = makeStore(dir, clock: clock)
        relaunched.load()
        #expect(relaunched.state.meta.favors == favors + 500)
        #expect(relaunched.book(.favors(500), transaction: "77001") == .alreadyBooked)
        #expect(relaunched.state.meta.favors == favors + 500)
    }

    @Test("Restoring an owned starter records a missing receipt without paying the starter pack again")
    func ownedStarterWithoutReceipt() throws {
        let dir = tempDir(), clock = Clock()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data(OldSaves.business.utf8).write(to: FlowSaveStore(directory: dir).primaryURL)
        let store = makeStore(dir, clock: clock)
        store.load()
        let wallet = store.state.meta
        try #require(wallet.starterBought && wallet.deliveredTransactions.isEmpty)
        try blockWrites(store)
        #expect(store.book(.starter, transaction: "restore") == .notBooked)
        #expect(store.state.meta == wallet)
        try unblockWrites(store)
        #expect(store.book(.starter, transaction: "restore") == .alreadyBooked)
        let reopened = makeStore(dir, clock: clock)
        reopened.load()
        #expect(reopened.state.meta.favors == wallet.favors)
        #expect(reopened.state.meta.boostSeconds == wallet.boostSeconds)
        #expect(reopened.state.meta.deliveredTransactions == ["restore"])
    }

    @Test("Redelivery of the oldest unfinished purchase can finish after a thousand newer bookings and a relaunch")
    func oldReceiptAfterRelaunch() throws {
        let dir = tempDir(), clock = Clock()
        defer { try? FileManager.default.removeItem(at: dir) }
        let game = makeStore(dir, clock: clock)
        game.load()
        #expect(game.book(.favors(80), transaction: "first") == .booked)
        var s = game.state
        for i in 0..<1_005 {
            let r = Flow.apply(s, .deliverPurchase(.favors(1), transaction: "later-\(i)"))
            try #require(r.isOK)
            s = r.state
        }
        try game.saveStore.write(s, savedAtMs: clock.ms)
        let relaunched = makeStore(dir, clock: clock)
        relaunched.load()
        #expect(relaunched.adoptDeliveredTransactions(["legacy", "legacy"]))
        let suite = "noir.tests.redelivery.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let shop = StoreService(defaults: defaults)
        shop.deliver = { item, id in relaunched.book(item.grant, transaction: id) }
        let settlement = shop.settle(productID: StoreItem.favorsSmall.rawValue, transactionID: "first", revoked: false)
        #expect(settlement.finish && settlement.booked)
        #expect(relaunched.state.meta.favors == 1_085)
        #expect(relaunched.state.meta.deliveredTransactions.count == 1_007)
    }

    @Test("Purchases are not booked while the save is from a newer version")
    func noBookingOnFutureSave() throws {
        let dir = tempDir()
        try Data("{\"schema\": 99, \"savedAt\": 1, \"state\": {}}".utf8).write(to: FlowSaveStore(directory: dir).primaryURL)
        let store = makeStore(dir, clock: Clock())
        store.load()
        #expect(store.book(.favors(80), transaction: "5") == .notBooked)
    }

    @Test("The store finishes a transaction only after the booking; old markers and redeliveries never pay twice")
    func storeSettlement() throws {
        let suite = "noir.tests.store.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["31337"], forKey: StoreService.legacyDeliveredKey)
        let store = makeStore(tempDir(), clock: Clock())
        store.load()
        let shop = StoreService(defaults: defaults)
        shop.deliver = { item, id in store.book(item.grant, transaction: id) }
        shop.adoptDelivered = { ids in store.adoptDeliveredTransactions(ids) }

        shop.adoptLegacyMarkers()
        #expect(store.state.meta.deliveredTransactions == ["31337"], "the old marker moves into the save")
        let legacy = shop.settle(productID: StoreItem.favorsSmall.rawValue, transactionID: "31337", revoked: false)
        #expect(legacy == StoreService.Settlement(finish: true, booked: true))
        #expect(store.state.meta.favors == 0, "booked by the earlier version, not again")

        let fresh = shop.settle(productID: StoreItem.favorsSmall.rawValue, transactionID: "40001", revoked: false)
        #expect(fresh == StoreService.Settlement(finish: true, booked: true))
        #expect(store.state.meta.favors == 80)
        let redelivered = shop.settle(productID: StoreItem.favorsSmall.rawValue, transactionID: "40001", revoked: false)
        #expect(redelivered == StoreService.Settlement(finish: true, booked: true))
        #expect(store.state.meta.favors == 80)

        try blockWrites(store)
        let failed = shop.settle(productID: StoreItem.favorsMedium.rawValue, transactionID: "40002", revoked: false)
        #expect(failed == StoreService.Settlement(finish: false, booked: false), "left open for the next attempt")
        #expect(store.state.meta.favors == 80)
        try unblockWrites(store)
        #expect(shop.settle(productID: StoreItem.favorsMedium.rawValue, transactionID: "40002", revoked: false).booked)
        #expect(store.state.meta.favors == 580)

        #expect(shop.settle(productID: StoreItem.premium.rawValue, transactionID: "40003", revoked: true)
                == StoreService.Settlement(finish: true, booked: false))
        #expect(!store.state.meta.premium)
        #expect(shop.settle(productID: "io.example.unknown", transactionID: "40004", revoked: false).finish)
        #expect(shop.settle(productID: StoreItem.premium.rawValue, transactionID: "40005", revoked: false).booked)
        #expect(store.state.meta.premium)
        #expect(shop.settle(productID: StoreItem.premium.rawValue, transactionID: "40005", revoked: false).finish,
                "a restored permanent purchase is acknowledged without a second grant")
    }
}

/// Saves written by earlier builds, kept verbatim.
enum OldSaves {
    /// Schema 1, chapter two, crew, a trip, an active order, favors and all three permanent purchases.
    static let business = """
    {"savedAt":1700000000000,"schema":1,"state":{"abilities":{},"autoQuiet":false,"cash":4321.5,"challengesDone":[],"chapter":2,\
    "contacts":{"altmarkt":{"level":1,"open":0,"trust":0},"baeckerei":{"level":3,"open":2.5,"trust":0},"muehlgasse":{"level":8,"open":4,"trust":0}},\
    "counters":{"big":0,"city":0,"clubBest":0,"clubNow":0,"crates":900,"deliveries":420,"failed":1,"finale":false,"loud":2,"orders":3,\
    "purchases":41,"quiet":2,"taps":300},"dispatcher":true,"earned":70000,"fleet":10,"lastWallClockMs":1700000000000,\
    "ledger":[{"amount":75,"crates":15,"good":"WEED","id":7,"kind":"DELIVERY","subject":"muehlgasse","time":1200}],\
    "meta":{"favors":77,"noAds":true,"premium":true,"starterBought":true},"nextLedgerId":8,"nextOfferAt":1300,"nextOrderId":6,\
    "offers":[],"orders":[{"deadline":1500,"delivered":{"WEED":4},"inTransit":{"WEED":3},"offer":{"attention":-5,"expiresAt":1350,"id":4,\
    "items":{"WEED":20},"kind":"QUIET","pay":150,"quarter":"CELLARS","window":400}}],"ordersFirst":true,\
    "priority":["WEED","CRYSTAL","PILLS","COKE"],"quarters":{"CELLARS":{"attention":12,"paused":false},"OLD_TOWN":{"attention":0,"paused":false}},\
    "rng":"2a","specialists":["OKAFOR"],"start":"TOOLS","time":1280,\
    "trip":{"duration":10,"left":4,"orders":{"4":{"WEED":3}},"standing":{"WEED":2}},"version":1,\
    "workshops":{"WEED":{"bench":12,"cycle":0.5,"fullFor":0,"lead":true,"shelf":6,"stock":8}}}}
    """
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
        var s = Flow.newGame(seed: 1, nowMs: 1)
        QAAccelerator.scenario(&s, "late", quiet: true)
        #expect(Good.allCases.allSatisfy { s.workshop($0)?.lead == true })
        #expect(s.dispatcher && s.offers.isEmpty)
        #else
        Issue.record("Debug test builds are expected to define NOIR_QA")
        #endif
    }
}

// MARK: - Art and sound

@MainActor
@Suite("Delivered art and sound")
struct ArtAndSoundTests {
    @Test("Every image the scene composes from parts is in the asset catalog")
    func sceneArt() {
        let missing = (SceneArt.composedNames + SceneArt.sheetNames).filter { UIImage(named: $0) == nil }
        #expect(missing.isEmpty, "missing images: \(missing)")
    }

    @Test("Both typefaces are registered and give real fonts")
    func fonts() {
        #expect(UIFont(name: ToonFont.display, size: 17) != nil)
        #expect(UIFont(name: ToonFont.text, size: 17) != nil)
        #expect(ToonFont.uiFont(size: 17, weight: .bold, style: .body).fontName.hasPrefix("Fredoka"))
    }

    @Test("Every sound effect, music piece and ambience bed is in the bundle")
    func sounds() {
        let url = { (name: String) in Bundle.main.url(forResource: name, withExtension: "m4a") }
        let missing = Feedback.allCases.map { "sfx_" + $0.rawValue }.filter { url($0) == nil }
        #expect(missing.isEmpty, "missing effects: \(missing)")
        var moods: Set<String> = []
        for chapter in 1...6 {
            var s = Flow.newGame(seed: 1, nowMs: 0)
            s = Flow.apply(s, .choose(.cashbox)).state
            s.chapter = chapter
            for g in Good.allCases where FlowContent.good(g).chapter <= chapter {
                s.cash = 1e15
                s = Flow.apply(s, .openWorkshop(g)).state
            }
            let m = SoundMood.of(s)
            moods.formUnion([m.music, m.ambience])
        }
        moods.formUnion(["music_prologue", "music_challenge", "amb_street"])
        #expect(moods.filter { url($0) == nil }.isEmpty)
        #expect(moods.count >= 10)
    }
}
