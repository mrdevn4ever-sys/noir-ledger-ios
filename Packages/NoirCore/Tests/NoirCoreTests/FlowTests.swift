import Foundation
@testable import NoirCore
import Testing

@Suite("Ledger 4.0: visible flow, bottlenecks, orders and attention, chapters, time away")
struct FlowTests {

    static func ok(_ s: FlowState, _ a: FlowAction, sourceLocation: SourceLocation = #_sourceLocation) -> FlowState {
        let r = Flow.apply(s, a)
        #expect(r.error == nil, "action \(a) failed with \(String(describing: r.error))", sourceLocation: sourceLocation)
        return r.state
    }

    static func error(_ s: FlowState, _ a: FlowAction) -> ActionError? { Flow.apply(s, a).error }

    static func started(_ choice: StartChoice = .cashbox, seed: UInt64 = 1) -> FlowState {
        ok(Flow.newGame(seed: seed, nowMs: 1_000), .choose(choice))
    }

    /// A cellar with every station automated (no orders on the board).
    static func automated(bench: Int = 1, shelf: Int = 1, fleet: Int = 1, contact: Int = 1) -> FlowState {
        var s = started()
        s.updateWorkshop(.weed) { $0.bench = bench; $0.shelf = shelf; $0.lead = true }
        s.fleet = fleet
        s.dispatcher = true
        s.updateContact("muehlgasse") { $0.level = contact }
        s.nextOfferAt = 1e12
        s.offers = []
        return s
    }

    @Test("A new game waits for the choice, then each choice is felt at once")
    func startChoices() {
        let fresh = Flow.newGame(seed: 1, nowMs: 1)
        #expect(fresh.start == nil)
        #expect(Self.error(fresh, .tapBench(.weed)) == .tutorial)
        var before = fresh
        Flow.advance(&before, seconds: 60, offline: false)
        #expect(before.time == 0, "nothing runs before the choice")
        let cash = Self.ok(fresh, .choose(.cashbox))
        #expect(cash.cash == FlowContent.cashboxCash)
        let book = Self.ok(fresh, .choose(.addressBook))
        #expect(book.contacts["baeckerei"] != nil)
        let tools = Self.ok(fresh, .choose(.tools))
        #expect(tools.workshop(.weed)?.bench == FlowContent.toolsBench)
        #expect(Self.error(tools, .choose(.cashbox)) == .invalid)
    }

    @Test("By hand: start the bench, see the crate, send it, the delivery is booked")
    func firstDelivery() {
        var s = Self.started(.addressBook)
        #expect(Flow.hint(s) == .tapBench)
        s = Self.ok(s, .tapBench(.weed))
        Flow.advance(&s, seconds: 5, offline: false)
        #expect(s.workshop(.weed)?.stock == 1)
        #expect(Flow.hint(s) == .tapFleet)
        s = Self.ok(s, .tapFleet)
        #expect(s.workshop(.weed)?.stock == 0)
        #expect(s.cash == 0, "nothing is paid before the goods arrive")
        Flow.advance(&s, seconds: 10, offline: false)
        #expect(s.counters.deliveries == 1)
        #expect(abs(s.cash - 5 * 1.5) < 1e-9, "the baker pays half again")
        #expect(s.ledger.last?.kind == .delivery && s.ledger.last?.subject == "baeckerei")
        #expect(Flow.hint(s) == .firstUpgrade)
        #expect(Self.error(s, .tapFleet) == .requirements, "an empty shelf sends nobody out")
    }

    @Test("The slowest station sets the sales: the guide's example of 12 made, 6 carried, 10 wanted")
    func bottleneck() {
        let s = Self.automated()
        let f = Flow.forecast(s).good(.weed)!
        #expect(abs(f.production - 12) < 1e-9 && abs(f.carried - 6) < 1e-9 && abs(f.demand - 10) < 1e-9)
        #expect(abs(f.sold - 6) < 1e-9)
        #expect(f.bottleneck == .fleet)
        #expect(abs(f.piling - 6) < 1e-9, "the shelf fills by six crates a minute")
        let fleet = Flow.preview(s, .fleet, 1)
        #expect(abs(fleet.after.good(.weed)!.sold - 10) < 1e-9, "a better fleet sells right away, up to the demand")
        #expect(fleet.after.good(.weed)!.bottleneck == .demand)
        #expect(fleet.after.income > fleet.before.income)
        let bench = Flow.preview(s, .bench(.weed), 1)
        #expect(bench.after.income == bench.before.income, "a bench alone only fills the shelf")
        #expect(bench.after.good(.weed)!.piling > bench.before.good(.weed)!.piling)
    }

    @Test("Previews match what the running simulation sells",
          arguments: [[1, 1, 1, 1], [3, 2, 1, 1], [5, 4, 6, 3], [12, 9, 10, 5], [30, 26, 25, 3], [30, 26, 25, 12]])
    func previewMatchesSimulation(levels: [Int]) {
        var s = Self.automated(bench: levels[0], shelf: levels[3], fleet: levels[1], contact: levels[2])
        s.contacts["baeckerei"] = ContactState()
        let expected = Flow.forecast(s)
        Flow.advance(&s, seconds: 300, offline: false)
        let crates = s.counters.crates
        let cash = s.earned
        Flow.advance(&s, seconds: 1_200, offline: false)
        let sold = (s.counters.crates - crates) / 20
        let income = (s.earned - cash) / 20
        let f = expected.good(.weed)!
        #expect(abs(sold - f.sold) <= max(0.5, f.sold * 0.03), "sold \(sold)/min, forecast \(f.sold)/min")
        #expect(abs(income - expected.income) <= max(3, expected.income * 0.03), "earned \(income)/min, forecast \(expected.income)/min")
        #expect(s.workshop(.weed)!.stock >= 0)
    }

    @Test("Two goods share the fleet: the priority decides, the base share keeps the second line moving")
    func sharedFleet() {
        var s = Self.automated(bench: 40, shelf: 10, fleet: 10, contact: 30)
        s.chapter = 3
        s.cash = 1e9
        s = Self.ok(s, .openWorkshop(.crystal))
        s = Self.ok(s, .hireLead(.crystal))
        s.updateWorkshop(.crystal) { $0.bench = 30 }
        s.updateContact("kai7") { $0.level = 30 }
        let weedFirst = Flow.forecast(s)
        #expect(weedFirst.good(.crystal)!.bottleneck == .fleet)
        let crystalShare = weedFirst.good(.crystal)!.carried * 2 / weedFirst.fleetCapacity
        #expect(crystalShare >= FlowContent.baseShare - 1e-9, "crystal keeps its base share")
        let swapped = Self.ok(s, .setPriority([.crystal, .weed, .pills, .coke]))
        let crystalFirst = Flow.forecast(swapped)
        #expect(crystalFirst.good(.crystal)!.carried > weedFirst.good(.crystal)!.carried)
        #expect(crystalFirst.good(.weed)!.carried < weedFirst.good(.weed)!.carried)
        #expect(Self.error(s, .setPriority([.weed])) == .invalid)
    }

    @Test("The first order choice: 100 quietly or 145 with +20 attention, and what that does to the corner")
    func firstOrderChoice() {
        var s = Self.started()
        s.cash = 100
        s = Self.ok(s, .hireLead(.weed))
        Flow.advance(&s, seconds: 1, offline: false)
        #expect(s.offers.count == 2)
        let quiet = s.offers.first { $0.kind == .quiet }!
        let loud = s.offers.first { $0.kind == .loud }!
        #expect(quiet.items == [.weed: 20] && loud.items == [.weed: 20])
        #expect(quiet.pay == 100 && loud.pay == 145)
        #expect(quiet.attention <= 0 && loud.attention == 20)
        let preview = Flow.attentionPreview(s, loud)
        #expect(preview.after == preview.before + 20)
        var hot = s
        hot.updateQuarter(.cellars) { $0.attention = 15 }
        let before = Flow.contactRate(hot, "muehlgasse")
        hot = Self.ok(hot, .accept(loud.id))
        #expect(Flow.tier(hot, .cellars) == 1, "the second loud job makes the corner watched")
        #expect(Flow.contactRate(hot, "muehlgasse") < before)
        #expect(hot.orders.count == 1)
        #expect(Self.error(hot, .accept(quiet.id)) == .requirements, "one order at a time in the cellar")
    }

    @Test("An order pays once when everything has arrived; a missed deadline pays what arrived at the standing price")
    func orders() {
        var s = Self.automated(bench: 10, shelf: 5, fleet: 10, contact: 1)
        s.updateWorkshop(.weed) { $0.stock = 100 }
        let offer = OrderOffer(id: 99, kind: .loud, quarter: .cellars, items: [.weed: 30], pay: 500, attention: 20, window: 300, expiresAt: 1e9)
        s.offers = [offer]
        s = Self.ok(s, .accept(99))
        let cash = s.cash
        Flow.advance(&s, seconds: 120, offline: false)
        #expect(s.orders.isEmpty && s.counters.orders == 1)
        let fromOrder = s.ledger.filter { $0.kind == .order }.map(\.amount).reduce(0, +)
        #expect(fromOrder == 500)
        #expect(s.cash - cash >= 500)

        var late = Self.automated(bench: 1, shelf: 5, fleet: 1, contact: 1)
        late.offers = [OrderOffer(id: 7, kind: .quiet, quarter: .cellars, items: [.weed: 50], pay: 400, attention: -5, window: 60, expiresAt: 1e9)]
        late = Self.ok(late, .accept(7))
        Flow.advance(&late, seconds: 90, offline: false)
        #expect(late.orders.isEmpty && late.counters.failed == 1)
        let failed = late.ledger.first { $0.kind == .orderFailed }!
        #expect(failed.amount == failed.crates * FlowContent.good(.weed).price)
    }

    @Test("Attention is graded and reversible: watched, hot, underground; it fades, faster when the quarter rests")
    func attention() {
        var s = Self.automated(contact: 10)
        let calm = Flow.contactRate(s, "muehlgasse")
        s.updateQuarter(.cellars) { $0.attention = 65 }
        #expect(Flow.tier(s, .cellars) == 2)
        #expect(abs(Flow.contactRate(s, "muehlgasse") - calm * 0.5) < 1e-12)
        #expect(Flow.contactPrice(s, "muehlgasse") < FlowContent.good(.weed).price)
        s.updateQuarter(.cellars) { $0.attention = 90 }
        #expect(Flow.contactRate(s, "muehlgasse") == 0, "the corner goes underground")
        var fading = s
        Flow.advance(&fading, seconds: 60, offline: false)
        #expect(abs(fading.quarter(.cellars).attention - 87) < 1e-6)
        var resting = Self.ok(s, .pause(.cellars, true))
        #expect(Flow.contactRate(resting, "muehlgasse") == 0)
        Flow.advance(&resting, seconds: 60, offline: false)
        #expect(abs(resting.quarter(.cellars).attention - 81) < 1e-6)
        let away = Flow.applyOffline(s, nowMs: s.lastWallClockMs + 3_600_000)
        #expect(away.quarter(.cellars).attention == 0, "attention fades while away")
    }

    @Test("Time away: only automation works, booked once, shown again without paying again; the clock cannot be turned back")
    func timeAway() {
        var manual = Self.started()
        manual.updateWorkshop(.weed) { $0.stock = 5 }
        let idle = Flow.applyOffline(manual, nowMs: manual.lastWallClockMs + 3_600_000)
        #expect(idle.earned == 0 && idle.workshop(.weed)?.stock == 5, "no hands, no work")

        let s = Self.automated(bench: 5, shelf: 5, fleet: 4, contact: 4)
        let rate = Flow.forecast(s).income
        let back = Flow.applyOffline(s, nowMs: s.lastWallClockMs + 2 * 3_600_000)
        let w = try! #require(back.welcome)
        #expect(abs(w.earned - rate * 120) <= rate * 120 * 0.03)
        #expect(abs(back.cash - s.cash - w.earned) < 1e-6)
        #expect(back.meta.offlineBonus == w.earned)
        let again = Self.ok(back, .collectOffline(doubled: false))
        #expect(again.cash == back.cash && again.welcome == nil && again.meta.offlineBonus == 0)
        let doubled = Self.ok(back, .collectOffline(doubled: true))
        #expect(abs(doubled.cash - back.cash - w.earned) < 1e-6)

        let week = Flow.applyOffline(s, nowMs: s.lastWallClockMs + 7 * 86_400_000)
        #expect(week.welcome!.capped && week.welcome!.credited == FlowContent.offlineCap)
        let back2 = Flow.applyOffline(s, nowMs: s.lastWallClockMs - 60_000)
        #expect(back2.welcome!.clockMovedBack && back2.cash == s.cash)
    }

    @Test("An accepted order keeps its deadline while away and is never counted as done afterwards")
    func ordersWhileAway() {
        var s = Self.automated(bench: 1, fleet: 1)
        s.offers = [OrderOffer(id: 3, kind: .quiet, quarter: .cellars, items: [.weed: 500], pay: 9_999, attention: 0, window: 600, expiresAt: 1e9)]
        s = Self.ok(s, .accept(3))
        let back = Flow.applyOffline(s, nowMs: s.lastWallClockMs + 3 * 3_600_000)
        #expect(back.orders.isEmpty)
        #expect(back.counters.orders == 0 && back.counters.failed == 1)
        #expect(back.welcome?.ordersFailed == 1)
        #expect(!back.ledger.contains { $0.kind == .order })
    }

    @Test("Chapters close on their goals, bring someone new and raise every payout")
    func chapters() {
        var s = Self.automated(bench: 10, fleet: 10, contact: 10)
        #expect(Self.error(s, .closeChapter) == .requirements)
        s.counters.deliveries = 1
        s.counters.orders = 1
        s.earned = 6_000
        #expect(Flow.chapterComplete(s))
        let income = Flow.forecast(s).income
        s = Self.ok(s, .closeChapter)
        #expect(s.chapter == 2 && s.chapterNews == 1)
        #expect(s.has(.okafor))
        #expect(s.quarters[.oldTown] != nil)
        #expect(abs(Flow.forecast(s).income - income * FlowContent.chapterBonus) < 1e-6)
        #expect(Flow.boardSize(s) == 4 && Flow.orderSlots(s) == 3)
        #expect(Self.error(s, .openWorkshop(.crystal)) == .locked, "the harbour opens in chapter three")
        s = Self.ok(s, .seenChapter)
        #expect(s.chapterNews == nil)
        #expect(FlowContent.chapters.count == 6)
        for ch in FlowContent.chapters {
            #expect(!ch.goals.isEmpty)
            #expect(Content.crewDef(ch.person) != nil, "chapter \(ch.number) has a face")
        }
    }

    @Test("Crew abilities run for a minute and then cool down; nothing stacks without limit")
    func abilities() {
        var s = Self.automated(bench: 10)
        #expect(Self.error(s, .use(.doubleShift, .weed)) == .locked, "abilities come with the harbour")
        s.chapter = 3
        let rate = Flow.benchRate(s, .weed)
        s = Self.ok(s, .use(.doubleShift, .weed))
        #expect(Flow.benchRate(s, .weed) == 2 * rate)
        #expect(Self.error(s, .use(.doubleShift, .weed)) == .cooldown)
        s = Self.ok(s, .use(.rushRun, nil))
        #expect(Flow.tripSeconds(s) == FlowContent.tripSeconds / 2)
        Flow.advance(&s, seconds: 61, offline: false)
        #expect(Flow.benchRate(s, .weed) == rate && Flow.tripSeconds(s) == FlowContent.tripSeconds)
        Flow.advance(&s, seconds: 600, offline: false)
        #expect(Self.error(s, .use(.doubleShift, .weed)) == nil)
    }

    @Test("Stock never goes negative and cash never appears from nowhere under random play")
    func invariants() {
        var s = Self.started(.tools, seed: 5)
        var total = 0.0
        let actions: [FlowAction] = [.tapBench(.weed), .tapFleet, .upgrade(.fleet, 1), .upgrade(.bench(.weed), 1), .upgrade(.contact("muehlgasse"), 1),
                                     .upgrade(.shelf(.weed), 1), .hireLead(.weed), .hireDispatcher, .unlockContact("baeckerei")]
        for i in 0..<4_000 {
            let r = Flow.apply(s, actions[(i * 7) % actions.count])
            s = r.state
            if i % 5 == 0, let offer = s.offers.first { s = Flow.apply(s, .accept(offer.id)).state }
            let before = s.earned
            Flow.advance(&s, seconds: 0.75, offline: false)
            total += s.earned - before
            for g in s.openGoods {
                #expect(s.workshop(g)!.stock >= -1e-9)
                #expect(s.workshop(g)!.stock <= Flow.shelfCapacity(s, g) + 1e-6)
            }
            #expect(s.cash >= 0)
        }
        let booked = s.ledger.map(\.amount).reduce(0, +)
        #expect(booked <= total + 1e-6)
        #expect(s.counters.deliveries > 0)
    }

    @Test("Challenges after the finale run on their own rules and pay for each goal")
    func challenges() {
        var s = Self.automated(bench: 20, fleet: 20, contact: 20)
        #expect(Self.error(s, .startChallenge(.fog)) == .locked)
        s.chapter = FlowContent.chapters.count + 1
        let full = Flow.fleetCapacity(s)
        s = Self.ok(s, .startChallenge(.fog))
        #expect(abs(Flow.fleetCapacity(s) - full / 3) < 1e-9)
        #expect(Self.error(s, .startChallenge(.strike)) == .invalid)
        let favors = s.meta.favors
        Flow.advance(&s, seconds: FlowContent.challenge(.fog).seconds + 1, offline: false)
        #expect(s.challenge == nil)
        #expect(s.meta.favors >= favors + FlowContent.challenge(.fog).rewards[2], "calm quarters all along")
    }

    @Test("Saves round-trip and damaged values are repaired")
    func save() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("flow-\(UUID().uuidString)")
        let store = FlowSaveStore(directory: dir)
        var s = Self.automated(bench: 4)
        s.offers = [OrderOffer(id: 1, kind: .loud, quarter: .cellars, items: [.weed: 20], pay: 145, attention: 20, window: 300, expiresAt: 500)]
        Flow.advance(&s, seconds: 30, offline: false)
        try store.write(s, savedAtMs: 5)
        guard case .loaded(let loaded, let restored) = store.load() else {
            Issue.record("load failed")
            return
        }
        #expect(!restored)
        #expect(loaded == s)
        var broken = s
        broken.cash = -5
        broken.priority = [.weed]
        broken.updateWorkshop(.weed) { $0.stock = -3 }
        FlowSaveStore.sanitize(&broken)
        #expect(broken.cash == 0 && broken.priority == Good.allCases && broken.workshop(.weed)!.stock == 0)
        try store.write(loaded, savedAtMs: 6)
        try Data("damaged".utf8).write(to: store.primaryURL)
        guard case .loaded(let backup, let fromBackup) = store.load() else {
            Issue.record("backup failed")
            return
        }
        #expect(fromBackup && backup.cash == s.cash)
    }

    // MARK: Pacing

    /// A player who taps idle stations after a short reaction, buys the upgrade that pays back fastest (or the
    /// cheapest station of the bottleneck when nothing pays back alone), hires the crew as soon as it is within reach
    /// and takes loud orders while the quarter is calm.
    struct Player {
        var s: FlowState
        var firsts: [String: Double] = [:]
        var idleSince: [String: Double] = [:]
        let react = 0.6
        var loud = true

        mutating func tapIfIdle() {
            guard let w = s.workshop(.weed) else { return }
            if !w.lead && w.cycle == nil && w.stock < Flow.shelfCapacity(s, .weed) {
                let since = idleSince["bench", default: s.time]
                idleSince["bench"] = since
                if s.time - since >= react { s = Flow.apply(s, .tapBench(.weed)).state; idleSince["bench"] = nil }
            }
            if !s.dispatcher && s.trip == nil && w.stock >= 1 {
                let since = idleSince["fleet", default: s.time]
                idleSince["fleet"] = since
                if s.time - since >= react { s = Flow.apply(s, .tapFleet).state; idleSince["fleet"] = nil }
            }
        }

        func stations() -> [Station] {
            var out: [Station] = [.fleet]
            for g in s.openGoods { out += [.bench(g), .shelf(g)] }
            for id in s.contacts.keys.sorted() { out.append(.contact(id)) }
            return out
        }

        mutating func buy() {
            let income = max(Flow.forecast(s).income, 3)
            for _ in 0..<50 {
                var goal: FlowAction?
                var goalKey = ""
                var goalCost = Double.infinity
                if let w = s.workshop(.weed), !w.lead {
                    goal = .hireLead(.weed); goalKey = "lead"; goalCost = FlowContent.good(.weed).leadCost
                } else if !s.dispatcher {
                    goal = .hireDispatcher; goalKey = "dispatcher"; goalCost = FlowContent.dispatcherCost
                } else if s.contacts["baeckerei"] == nil {
                    goal = .unlockContact("baeckerei"); goalKey = "baker"; goalCost = 400
                }
                if let g = goal, goalCost <= income * 6, s.cash >= goalCost {
                    s = Flow.apply(s, g).state
                    firsts[goalKey] = firsts[goalKey] ?? s.time
                    continue
                }
                let limit = goal != nil && goalCost <= income * 6 ? goalCost * 0.15 : Double.infinity
                let base = Flow.forecast(s).income
                var best: (Double, Station)?
                var cheapestNeck: (Double, Station)?
                for st in stations() {
                    let c = Flow.cost(s, st, 1)
                    guard c <= min(s.cash, limit) else { continue }
                    let gain = Flow.forecast(Flow.upgraded(s, st, 1)).income - base
                    if gain > 1e-9 {
                        if best == nil || c / gain < best!.0 { best = (c / gain, st) }
                    }
                    if cheapestNeck == nil || c < cheapestNeck!.0 {
                        let f = Flow.forecast(s).good(.weed)!
                        let relevant: Bool = switch st {
                        case .fleet: f.bottleneck == .fleet || f.carried <= f.sold + 1e-9
                        case .shelf: f.bottleneck == .shelf
                        case .bench: f.bottleneck == .bench || f.production <= f.sold + 1e-9
                        case .contact: f.bottleneck == .demand || f.demand <= f.sold + 1e-9
                        }
                        if relevant { cheapestNeck = (c, st) }
                    }
                }
                guard let pick = best?.1 ?? cheapestNeck?.1 else { return }
                s = Flow.apply(s, .upgrade(pick, 1)).state
            }
        }

        mutating func orders() {
            guard s.orders.count < Flow.orderSlots(s), !s.offers.isEmpty else { return }
            let calm = s.offers.first { $0.kind == .quiet }
            let noisy = s.offers.first { $0.kind == .loud }
            if loud, let o = noisy, Flow.attentionPreview(s, o).after < FlowContent.watched {
                s = Flow.apply(s, .accept(o.id)).state
            } else if let o = calm {
                s = Flow.apply(s, .accept(o.id)).state
            }
        }

        mutating func play(minutes: Double) {
            let end = s.time + minutes * 60
            var nextBuy = 0.0
            while s.time < end {
                tapIfIdle()
                Flow.advance(&s, seconds: 0.25, offline: false)
                if s.counters.deliveries > 0 { firsts["delivery"] = firsts["delivery"] ?? s.time }
                if s.counters.orders > 0 { firsts["order"] = firsts["order"] ?? s.time }
                if s.time >= nextBuy {
                    nextBuy = s.time + 1
                    buy()
                    orders()
                    if s.chapter == 1 && Flow.chapterComplete(s) {
                        s = Flow.apply(s, .closeChapter).state
                        firsts["chapter1"] = s.time
                    }
                }
            }
        }
    }

    @Test("Chapter one: first delivery in seconds, automation in minutes, the chapter in a quarter of an hour, for every start",
          arguments: StartChoice.allCases)
    func pacing(start: StartChoice) {
        var p = Player(s: Self.started(start, seed: 3))
        p.play(minutes: 30)
        let f = p.firsts.mapValues { ($0 / 60 * 10).rounded() / 10 }
        print("pacing \(start.rawValue):", f.sorted { $0.value < $1.value }.map { "\($0.key)=\($0.value)min" }.joined(separator: " "),
              "earned=\(Int(p.s.earned)) loud=\(p.s.counters.loud) quiet=\(p.s.counters.quiet)")
        #expect((p.firsts["delivery"] ?? .infinity) <= 30, "first delivery within half a minute")
        #expect((p.firsts["lead"] ?? .infinity) <= 5 * 60, "first automation within five minutes")
        #expect((p.firsts["dispatcher"] ?? .infinity) <= 12 * 60, "the whole chain runs within twelve minutes")
        #expect((p.firsts["chapter1"] ?? .infinity) <= 25 * 60, "the cellar chapter closes within 25 minutes")
        #expect((p.firsts["chapter1"] ?? 0) >= 10 * 60, "and not in a rush")
    }

    @Test("A calm player who never takes a loud order reaches the end of chapter one too")
    func calmStyle() {
        var p = Player(s: Self.started(.cashbox, seed: 8))
        p.loud = false
        p.play(minutes: 30)
        #expect(p.s.counters.loud == 0)
        #expect(p.s.chapter >= 2)
    }
}
