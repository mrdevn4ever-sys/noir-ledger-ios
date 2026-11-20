import Foundation
@testable import NoirCore
import Testing

/// The rebuilt first minute (estate pickup, inheritance, first van level), the purchase receipts, the schema-2
/// migration of older saves, and the advice after time away.
@Suite("Ledger 4.x opening, receipts, migration and return advice")
struct FlowOpeningTests {

    static func ok(_ s: FlowState, _ a: FlowAction, sourceLocation: SourceLocation = #_sourceLocation) -> FlowState {
        FlowTests.ok(s, a, sourceLocation: sourceLocation)
    }

    static func error(_ s: FlowState, _ a: FlowAction) -> ActionError? { Flow.apply(s, a).error }

    /// The player's path: the pickup at the door, then one of Leopold's things.
    static func opened(_ choice: StartChoice, seed: UInt64 = 1) -> FlowState {
        let door = Flow.newGame(seed: seed, nowMs: 1_000)
        return ok(ok(door, .collectEstate), .choose(choice))
    }

    // MARK: Estate pickup

    @Test("A new game waits with one signed crate at the door; handing it over books 20 once, as no ordinary delivery")
    func estatePickup() {
        let door = Flow.newGame(seed: 1, nowMs: 1_000)
        #expect(door.estate == .waiting && door.start == nil && door.cash == 0)
        #expect(Self.error(door, .tapBench(.weed)) == .tutorial, "nothing else happens before the choice")
        let r = Flow.apply(door, .collectEstate)
        #expect(r.error == nil && r.gained == FlowContent.estatePickupCash)
        let s = r.state
        #expect(s.estate == .booked)
        #expect(s.cash == 20 && s.earned == 20)
        let entry = try! #require(s.ledger.last)
        #expect(entry.kind == .estate && entry.amount == 20 && entry.crates == 1 && entry.good == .weed)
        #expect(s.counters.deliveries == 0 && s.counters.crates == 0, "the pickup is not an ordinary delivery")
        #expect(s.time == 0, "no clock runs before the choice")
        #expect(Self.error(s, .collectEstate) == .invalid, "the slip pays once")
        var later = s
        Flow.advance(&later, seconds: 600, offline: false)
        #expect(later.cash == 20 && later.ledger.count == 1, "nothing recurs while the door screen waits")
        // A game that started without the pickup can never book it later than in the waiting state.
        let skipped = Self.ok(door, .choose(.cashbox))
        #expect(skipped.estate == .waiting)
        var notOffered = skipped
        notOffered.estate = .notOffered
        #expect(Self.error(notOffered, .collectEstate) == .invalid)
    }

    @Test("Every start can buy the first ordinary van level right after the pickup, and the street price stays 5",
          arguments: StartChoice.allCases)
    func firstVanUpgrade(start: StartChoice) {
        var s = Self.opened(start)
        let expectedCash = 20 + (start == .cashbox ? FlowContent.cashboxCash : 0)
        #expect(s.cash == expectedCash)
        #expect(Flow.fleetCost(s, 1) == FlowContent.fleetCost && FlowContent.fleetCost == 20, "no price was changed")
        #expect(Flow.firstVanUpgradeReady(s))
        #expect(Flow.hint(s) == .firstUpgrade, "the first hint points at the van the pickup paid for")
        #expect(Flow.fleetCapacity(s) == 1)
        let before = Flow.preview(s, .fleet, 1)
        s = Self.ok(s, .upgrade(.fleet, 1))
        #expect(s.fleet == 2 && Flow.fleetCapacity(s) == 2, "one crate slot more per trip")
        #expect(abs(s.cash - (expectedCash - 20)) < 1e-9, "the model's wallet after the confirmed upgrade: 60 / 0 / 0")
        #expect(before.after.income >= before.before.income)
        #expect(!Flow.firstVanUpgradeReady(s))
        #expect(Flow.hint(s) == .tapBench, "after the upgrade the cellar teaches production")

        // The first ordinary delivery is paid at the contact's standing price, crate by crate.
        s = Self.ok(s, .tapBench(.weed))
        Flow.advance(&s, seconds: 5, offline: false)
        #expect(Flow.hint(s) == .tapFleet)
        let cash = s.cash
        let stock = s.workshop(.weed)?.stock ?? 0
        s = Self.ok(s, .tapFleet)
        let carried = try! #require(s.trip).crates
        #expect(carried > 0 && carried <= min(stock, Flow.fleetCapacity(s)) + 1e-9, "the van loads what is wanted, up to its slots")
        Flow.advance(&s, seconds: 10, offline: false)
        #expect(s.counters.deliveries == 1)
        let deliveries = s.ledger.filter { $0.kind == .delivery }
        #expect(!deliveries.isEmpty)
        for e in deliveries {
            let price = FlowContent.good(.weed).price * (FlowContent.contact(e.subject)?.price ?? 0)
            #expect(abs(e.amount - e.crates * price) < 1e-9, "\(e.subject) pays its standing price per crate")
        }
        #expect(abs(s.cash - cash - deliveries.map(\.amount).reduce(0, +)) < 1e-9)
        #expect(s.ledger.filter { $0.kind == .estate }.count == 1, "the pickup stays a single line")
        #expect(FlowContent.contact("muehlgasse")!.price * FlowContent.good(.weed).price == 5, "the standing ticket stays 5")
    }

    @Test("Without the pickup (older paths) the first hints still teach production, never an unaffordable upgrade")
    func hintsCheckAffordability() {
        var s = FlowTests.started(.addressBook)
        #expect(Flow.hint(s) == .tapBench)
        s = Self.ok(s, .tapBench(.weed))
        Flow.advance(&s, seconds: 5, offline: false)
        s = Self.ok(s, .tapFleet)
        Flow.advance(&s, seconds: 10, offline: false)
        #expect(s.cash == 7.5)
        #expect(Flow.hint(s) == .tapBench, "7.5 buys nothing: keep the chain going by hand")
        s.cash = 20
        #expect(Flow.hint(s) == .firstUpgrade)
    }

    @Test("The opening path keeps chapter one inside the same bounds as before, for every start",
          arguments: StartChoice.allCases)
    func openingPacing(start: StartChoice) {
        var p = FlowTests.Player(s: Self.opened(start, seed: 3))
        p.s = Self.ok(p.s, .upgrade(.fleet, 1))
        p.play(minutes: 30)
        let f = p.firsts.mapValues { ($0 / 60 * 10).rounded() / 10 }
        print("opening pacing \(start.rawValue):", f.sorted { $0.value < $1.value }.map { "\($0.key)=\($0.value)min" }.joined(separator: " "),
              "earned=\(Int(p.s.earned))")
        #expect((p.firsts["delivery"] ?? .infinity) <= 30)
        #expect((p.firsts["lead"] ?? .infinity) <= 5 * 60)
        #expect((p.firsts["dispatcher"] ?? .infinity) <= 12 * 60)
        #expect((p.firsts["chapter1"] ?? .infinity) <= 25 * 60)
        #expect((p.firsts["chapter1"] ?? 0) >= 10 * 60)
        #expect(p.s.ledger.filter { $0.kind == .estate }.count <= 1)
    }

    // MARK: Receipts

    @Test("A purchase is booked with its transaction id, once; the same id again changes nothing")
    func receipts() {
        let door = Flow.newGame(seed: 1, nowMs: 1)
        let early = Self.ok(door, .deliverPurchase(.favors(80), transaction: "2000001"))
        #expect(early.meta.favors == 80 && early.meta.deliveredTransactions == ["2000001"], "booked even before the choice")
        #expect(Self.error(early, .deliverPurchase(.favors(80), transaction: "2000001")) == .invalid)
        #expect(Self.error(early, .deliverPurchase(.favors(80), transaction: " ")) == .invalid)
        var s = Self.ok(Self.ok(early, .collectEstate), .choose(.cashbox))
        s = Self.ok(s, .deliverPurchase(.premium, transaction: "2000002"))
        #expect(s.meta.premium && s.meta.deliveredTransactions == ["2000001", "2000002"])
        let again = Flow.apply(s, .deliverPurchase(.favors(500), transaction: "2000002"))
        #expect(again.error == .invalid && again.state.meta.favors == 80)
        var many = s
        for i in 0..<(FlowContent.receiptMemory + 5) { many = Self.ok(many, .deliverPurchase(.favors(1), transaction: "t\(i)")) }
        #expect(many.meta.deliveredTransactions.count == FlowContent.receiptMemory)
        #expect(many.meta.deliveredTransactions.last == "t\(FlowContent.receiptMemory + 4)")
    }

    // MARK: Migration

    /// A schema-1 business in chapter two, as build 56 wrote it: crew, a trip on the road, an active order, an
    /// offer, favors, all three permanent purchases and an offline clock.
    static let schema1Business = """
    {"savedAt":1700000000000,"schema":1,"state":{"abilities":{},"autoQuiet":false,"cash":4321.5,"challengesDone":[],"chapter":2,\
    "contacts":{"altmarkt":{"level":1,"open":0,"trust":0},"baeckerei":{"level":3,"open":2.5,"trust":0},"muehlgasse":{"level":8,"open":4,"trust":0}},\
    "counters":{"big":0,"city":0,"clubBest":0,"clubNow":0,"crates":900,"deliveries":420,"failed":1,"finale":false,"loud":2,"orders":3,\
    "purchases":41,"quiet":2,"taps":300},"dispatcher":true,"earned":70000,"fleet":10,"lastWallClockMs":1700000000000,\
    "ledger":[{"amount":75,"crates":15,"good":"WEED","id":7,"kind":"DELIVERY","subject":"muehlgasse","time":1200},\
    {"amount":100,"crates":20,"good":"WEED","id":8,"kind":"ORDER","subject":"QUIET","time":1250}],\
    "meta":{"adFavorsDay":-1,"adFavorsToday":0,"adsWatched":2,"bestStage":0,"boostSeconds":0,"claimed":[],"dailyClaims":3,\
    "dailyLastDay":19675,"favors":77,"heatAidCooldown":0,"lifetimeClean":0,"lifetimeDirty":70000,"noAds":true,"offlineBonus":0,\
    "payoutRatio":1,"premium":true,"prestiges":0,"reputation":0,"starterBought":true,"taps":300,"unlocked":[]},\
    "nextLedgerId":9,"nextOfferAt":1300,"nextOrderId":6,\
    "offers":[{"attention":20,"expiresAt":1400,"id":5,"items":{"WEED":30},"kind":"LOUD","pay":290,"quarter":"CELLARS","window":300}],\
    "orders":[{"deadline":1500,"delivered":{"WEED":4},"inTransit":{"WEED":3},"offer":{"attention":-5,"expiresAt":1350,"id":4,\
    "items":{"WEED":20},"kind":"QUIET","pay":150,"quarter":"CELLARS","window":400}}],"ordersFirst":true,\
    "priority":["WEED","CRYSTAL","PILLS","COKE"],"quarters":{"CELLARS":{"attention":12,"paused":false},"OLD_TOWN":{"attention":0,"paused":false}},\
    "rng":"2a","specialists":["OKAFOR"],"start":"TOOLS","time":1280,\
    "trip":{"duration":10,"left":4,"orders":{"4":{"WEED":3}},"standing":{"WEED":2}},"version":1,\
    "workshops":{"WEED":{"bench":12,"cycle":0.5,"fullFor":0,"lead":true,"shelf":6,"stock":8}}}}
    """

    /// A schema-1 save of a player who closed the app at the old prologue: nothing chosen, nothing earned.
    static let schema1Prologue = """
    {"savedAt":1700000000000,"schema":1,"state":{"cash":0,"chapter":1,"contacts":{"muehlgasse":{"level":1,"open":0,"trust":0}},\
    "earned":0,"fleet":1,"lastWallClockMs":1700000000000,"ledger":[],"meta":{"favors":12,"premium":false},\
    "quarters":{"CELLARS":{"attention":0,"paused":false}},"rng":"7","time":0,"version":1,\
    "workshops":{"WEED":{"bench":1,"fullFor":0,"lead":false,"shelf":1,"stock":0}}}}
    """

    static func directory() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("flow-open-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func load(_ store: FlowSaveStore) -> (FlowState, Bool)? {
        guard case .loaded(let s, let restored) = store.load() else { return nil }
        return (s, restored)
    }

    @Test("A schema-1 business loads whole: chapter, cash, crew, trip, orders, favors and purchases; no pickup afterwards")
    func migratesBusiness() throws {
        let store = FlowSaveStore(directory: Self.directory())
        try Data(Self.schema1Business.utf8).write(to: store.primaryURL)
        let (s, restored) = try #require(Self.load(store))
        #expect(!restored)
        #expect(s.version == flowSchemaVersion && flowSchemaVersion == 2)
        #expect(s.estate == .notOffered, "a business in play never receives the pickup")
        #expect(s.start == .tools && s.chapter == 2 && s.cash == 4321.5 && s.earned == 70_000 && s.time == 1_280)
        #expect(s.workshop(.weed)?.bench == 12 && s.workshop(.weed)?.shelf == 6 && s.workshop(.weed)?.lead == true)
        #expect(s.workshop(.weed)?.stock == 8 && s.workshop(.weed)?.cycle == 0.5)
        #expect(s.fleet == 10 && s.dispatcher && s.specialists == [.okafor])
        #expect(s.contacts["muehlgasse"]?.level == 8 && s.contacts["baeckerei"]?.level == 3 && s.contacts["altmarkt"] != nil)
        #expect(s.quarter(.cellars).attention == 12 && s.quarters[.oldTown] != nil)
        let trip = try #require(s.trip)
        #expect(trip.left == 4 && trip.standing[.weed] == 2 && trip.orders[4]?[.weed] == 3)
        #expect(s.orders.count == 1 && s.orders[0].delivered[.weed] == 4 && s.orders[0].inTransit[.weed] == 3)
        #expect(s.offers.count == 1 && s.offers[0].pay == 290)
        #expect(s.ledger.count == 2 && s.nextLedgerId == 9 && s.nextOrderId == 6)
        #expect(s.counters.deliveries == 420 && s.counters.orders == 3 && s.counters.purchases == 41)
        #expect(s.meta.favors == 77 && s.meta.premium && s.meta.noAds && s.meta.starterBought)
        #expect(s.meta.dailyLastDay == 19_675 && s.meta.dailyClaims == 3)
        #expect(s.meta.deliveredTransactions.isEmpty)
        #expect(s.lastWallClockMs == 1_700_000_000_000)
        #expect(Self.error(s, .collectEstate) == .invalid)
        #expect(FileManager.default.fileExists(atPath: store.archiveURL.path), "the untouched schema-1 file is kept")
        let original = try Data(contentsOf: store.archiveURL)
        #expect(original == Data(Self.schema1Business.utf8))

        // Time away is credited once on the migrated business; loading the result again does not pay again.
        let back = Flow.applyOffline(s, nowMs: s.lastWallClockMs + 2 * 3_600_000)
        let report = try #require(back.welcome)
        #expect(report.earned > 0 && back.cash > s.cash)
        try store.write(back, savedAtMs: back.lastWallClockMs)
        let (again, _) = try #require(Self.load(store))
        #expect(again == back, "a schema-2 file reads back exactly")
        let twice = Flow.applyOffline(again, nowMs: again.lastWallClockMs)
        #expect(twice.cash == back.cash)
        #expect(try Data(contentsOf: store.archiveURL) == original, "the archive is written once")
    }

    @Test("A schema-1 save at the old prologue gets the pickup once; a relaunch halfway never pays twice")
    func migratesPrologue() throws {
        let store = FlowSaveStore(directory: Self.directory())
        try Data(Self.schema1Prologue.utf8).write(to: store.primaryURL)
        let (s, _) = try #require(Self.load(store))
        #expect(s.start == nil && s.estate == .waiting && s.meta.favors == 12)
        let picked = Self.ok(s, .collectEstate)
        try store.write(picked, savedAtMs: 2)
        let (relaunched, _) = try #require(Self.load(store))
        #expect(relaunched.estate == .booked && relaunched.cash == 20 && relaunched.start == nil)
        #expect(Self.error(relaunched, .collectEstate) == .invalid)
        let started = Self.ok(relaunched, .choose(.addressBook))
        #expect(started.cash == 20 && started.contacts["baeckerei"] != nil)
    }

    @Test("Unknown fields and an unreadable ledger line do not cost the rest of a save")
    func unknownFields() throws {
        let store = FlowSaveStore(directory: Self.directory())
        var s = Self.opened(.cashbox)
        s = Self.ok(s, .upgrade(.fleet, 1))
        try store.write(s, savedAtMs: 3)
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: store.primaryURL))
        guard var raw = object as? [String: Any], var state = raw["state"] as? [String: Any],
              var ledger = state["ledger"] as? [[String: Any]] else {
            Issue.record("the written save is a JSON object with a ledger")
            return
        }
        state["somethingNew"] = ["nested": 1]
        ledger.append(["amount": 3, "crates": 1, "id": 99, "kind": "SOMETHING_NEW", "subject": "x", "time": 0])
        state["ledger"] = ledger
        raw["state"] = state
        try JSONSerialization.data(withJSONObject: raw).write(to: store.primaryURL)
        let (loaded, _) = try #require(Self.load(store))
        #expect(loaded.fleet == 2 && loaded.cash == s.cash && loaded.estate == .booked)
        #expect(loaded.ledger == s.ledger, "only the unreadable line is dropped")
    }

    @Test("Newer saves are protected; damaged files are restored from backup or archive, or set aside, never overwritten")
    func recovery() throws {
        let dir = Self.directory()
        let store = FlowSaveStore(directory: dir)
        try Data("{\"schema\": 3, \"savedAt\": 1, \"state\": {}}".utf8).write(to: store.primaryURL)
        guard case .futureVersion(3) = store.load() else {
            Issue.record("a schema-3 save must be reported as newer")
            return
        }
        try FileManager.default.removeItem(at: store.primaryURL)

        try Data(Self.schema1Business.utf8).write(to: store.primaryURL)
        _ = store.load()
        try Data("damaged".utf8).write(to: store.primaryURL)
        let (fromArchive, restored) = try #require(Self.load(store))
        #expect(restored && fromArchive.start == .tools && fromArchive.meta.premium, "the pre-migration copy is the last resort")

        store.erase()
        #expect(!FileManager.default.fileExists(atPath: store.archiveURL.path))
        try Data("damaged".utf8).write(to: store.primaryURL)
        guard case .fresh = store.load() else {
            Issue.record("nothing readable means a fresh game")
            return
        }
        #expect(try Data(contentsOf: store.damagedURL) == Data("damaged".utf8), "the unreadable file is set aside first")
    }

    // MARK: Return advice

    /// Four minutes into chapter one: the bench has its lead, nobody drives.
    static func leadOnly(cash: Double) -> FlowState {
        var s = Self.opened(.cashbox)
        s.updateWorkshop(.weed) { $0.lead = true }
        s.counters.deliveries = 6
        s.counters.purchases = 2
        s.cash = cash
        s.nextOfferAt = 1e12
        return s
    }

    @Test("Four minutes away with a lead and no dispatcher: nothing is sold, and the advice is a step the player can take")
    func fourMinuteReturn() throws {
        for cash in [0.0, 40, FlowContent.dispatcherCost + 40] {
            let s = Self.leadOnly(cash: cash)
            let back = Flow.applyOffline(s, nowMs: s.lastWallClockMs + 240_000)
            let report = try #require(back.welcome)
            #expect(report.earned == 0 && report.deliveries == 0 && back.cash == cash, "a van nobody drives sells nothing")
            #expect((back.workshop(.weed)?.stock ?? 0) >= 20, "the lead filled the shelf")
            let advice = Flow.returnAdvice(back)
            if cash >= FlowContent.dispatcherCost {
                #expect(advice == .hireDispatcher)
            } else {
                #expect(advice == .sendVan, "the hire is out of reach: send the van by hand")
                let hire = try #require(Flow.nextHire(back))
                #expect(hire.advice == .hireDispatcher && hire.cost == FlowContent.dispatcherCost)
            }
            let action = try #require(advice).action
            #expect(Flow.apply(back, action).error == nil, "the advice is always accepted")
        }
    }

    @Test("No futile advice: not the van while it drives, the bench in an empty manual cellar, upgrades only for a running chain")
    func adviceCases() throws {
        var driving = Self.leadOnly(cash: 40)
        driving.updateWorkshop(.weed) { $0.stock = 3 }
        #expect(Self.error(driving, .tapFleet) == .requirements, "stock alone does not make a buyer")
        #expect(Flow.returnAdvice(driving) == nil, "do not suggest an empty trip")
        Flow.advance(&driving, seconds: 10, offline: false)
        #expect(Flow.returnAdvice(driving) == .sendVan, "a buyer now wants the stock")
        driving = Self.ok(driving, .tapFleet)
        let trip = try #require(driving.trip)
        #expect(trip.crates > 0, "a live trip must have cargo")
        #expect(Flow.returnAdvice(driving) == nil, "the van is on the road and the lead keeps the bench busy")

        var manual = Self.opened(.addressBook)
        manual.cash = 0
        #expect(Flow.returnAdvice(manual) == .startBench(.weed))
        manual.cash = FlowContent.good(.weed).leadCost
        #expect(Flow.returnAdvice(manual) == .hireLead(.weed), "an affordable hire comes first")

        var chain = FlowTests.automated()
        chain.cash = 0
        #expect(Flow.returnAdvice(chain) == nil, "nothing affordable, nothing advised")
        chain.cash = 1_000
        let advice = try #require(Flow.returnAdvice(chain))
        guard case .upgrade(let st) = advice else {
            Issue.record("a running chain is advised its bottleneck, got \(advice)")
            return
        }
        #expect(st == .fleet, "the guide's example: the van holds the chain back")
        #expect(Flow.apply(chain, advice.action).error == nil)
        #expect(Flow.returnAdvice(Flow.newGame(seed: 1, nowMs: 1)) == nil)
    }
}
