import Foundation

/// The next small step the cellar teaches, in order.
public enum FlowHint: String, Sendable, CaseIterable {
    case tapBench, tapFleet, firstUpgrade, bottleneck, hireLead, chooseOrder, hireDispatcher
}

extension Flow {

    // MARK: Order board

    public static func boardOpen(_ s: FlowState) -> Bool { s.chapter > 1 || s.workshop(.weed)?.lead == true }
    public static func boardSize(_ s: FlowState) -> Int { s.chapter == 1 ? 2 : 3 + (s.has(.okafor) ? 1 : 0) }
    public static func orderSlots(_ s: FlowState) -> Int { (s.chapter == 1 ? 1 : 2) + (s.has(.okafor) ? 1 : 0) }

    static func offersTick(_ s: inout FlowState) {
        s.offers.removeAll { $0.expiresAt <= s.time }
        guard boardOpen(s) else { return }
        if s.nextOfferAt < 0 {
            s.offers = firstPair(&s)
            s.nextOfferAt = s.time + 2 * FlowContent.offerGap
        } else if s.chapter == 1 {
            if s.offers.isEmpty && s.time >= s.nextOfferAt {
                s.offers = pair(&s)
                s.nextOfferAt = s.time + 2 * FlowContent.offerGap
            }
        } else if s.offers.count < boardSize(s) && s.time >= s.nextOfferAt {
            if let o = makeOffer(&s) { s.offers.append(o) }
            s.nextOfferAt = s.time + FlowContent.offerGap
        }
        if finaleReady(s) && !s.offers.contains(where: { $0.kind == .finale }) && !s.orders.contains(where: { $0.offer.kind == .finale }) {
            s.offers.append(finaleOffer(&s))
        }
        if s.autoQuiet && s.has(.okafor) {
            while s.orders.count < orderSlots(s), let quiet = s.offers.first(where: { $0.kind == .quiet }) {
                accept(&s, quiet)
            }
        }
    }

    static func newOfferId(_ s: inout FlowState) -> Int {
        defer { s.nextOrderId += 1 }
        return s.nextOrderId
    }

    /// Crates per second the good reliably sells (never less than a token amount, so early offers make sense).
    static func pace(_ s: FlowState, _ g: Good) -> Double {
        let f = forecast(s).good(g)
        return max(0.1, (f?.sold ?? 0) / 60, s.workshop(g)?.lead == true ? 0 : benchRate(s, g) * 0.5)
    }

    static func quarter(of g: Good, _ s: FlowState) -> Quarter {
        if let c = FlowContent.contacts.first(where: { $0.good == g && s.contacts[$0.id] != nil }) { return c.quarter }
        return FlowContent.contacts.first(where: { $0.good == g })?.quarter ?? .cellars
    }

    static func value(_ s: FlowState, _ items: [Good: Double]) -> Double {
        items.reduce(0) { $0 + $1.value * FlowContent.good($1.key).price } * payMultiplier(s)
    }

    /// The cellar's first choice: the same twenty crates of weed, quietly for 100 or loudly for 145.
    static func firstPair(_ s: inout FlowState) -> [OrderOffer] {
        let items: [Good: Double] = [.weed: 20]
        let window = 120 + 3 * 20 / pace(s, .weed)
        let base = value(s, items)
        return [
            OrderOffer(id: newOfferId(&s), kind: .quiet, quarter: .cellars, items: items, pay: (base * FlowContent.quietPay).rounded(),
                       attention: FlowContent.quietAttention, window: window, expiresAt: s.time + 4 * FlowContent.offerSeconds),
            OrderOffer(id: newOfferId(&s), kind: .loud, quarter: .cellars, items: items, pay: (base * FlowContent.loudPay).rounded(),
                       attention: FlowContent.loudAttention, window: window, expiresAt: s.time + 4 * FlowContent.offerSeconds),
        ]
    }

    /// The same crates offered quietly and loudly.
    static func pair(_ s: inout FlowState) -> [OrderOffer] {
        let g = s.openGoods[min(s.openGoods.count - 1, Int(nextRandom(&s) * Double(s.openGoods.count)))]
        let rate = pace(s, g)
        let qty = max(10, (rate * 60 * (1 + nextRandom(&s))).rounded())
        let items: [Good: Double] = [g: qty]
        let window = (120 + 3 * qty / rate).rounded()
        let q = quarter(of: g, s)
        let base = value(s, items)
        let expires = s.time + FlowContent.offerSeconds
        return [
            OrderOffer(id: newOfferId(&s), kind: .quiet, quarter: q, items: items, pay: (base * FlowContent.quietPay).rounded(),
                       attention: FlowContent.quietAttention, window: window, expiresAt: expires),
            OrderOffer(id: newOfferId(&s), kind: .loud, quarter: q, items: items, pay: (base * FlowContent.loudPay).rounded(),
                       attention: FlowContent.loudAttention, window: window, expiresAt: expires),
        ]
    }

    /// One new offer for the board, its kind depending on the chapter.
    static func makeOffer(_ s: inout FlowState, bonus: Double = 1) -> OrderOffer? {
        guard !s.openGoods.isEmpty else { return nil }
        var kinds: [(OrderKind, Double)] = [(.quiet, 30), (.loud, 30)]
        if s.chapter >= 3 { kinds.append((.big, 20)) }
        let luxury = FlowContent.contacts.filter { $0.luxury && s.contacts[$0.id] != nil }
        if s.chapter >= 5 && !luxury.isEmpty { kinds.append((.trust, 25)) }
        if s.chapter >= 6 && s.openGoods.count >= 2 { kinds.append((.city, 25)) }
        let total = kinds.reduce(0) { $0 + $1.1 }
        var roll = nextRandom(&s) * total
        var kind = OrderKind.quiet
        for (k, w) in kinds {
            if roll < w { kind = k; break }
            roll -= w
        }
        let expires = s.time + FlowContent.offerSeconds
        switch kind {
        case .quiet, .loud:
            let g = s.openGoods[min(s.openGoods.count - 1, Int(nextRandom(&s) * Double(s.openGoods.count)))]
            let rate = pace(s, g)
            let qty = max(10, (rate * 60 * (1 + nextRandom(&s))).rounded())
            let factor = kind == .quiet ? FlowContent.quietPay : FlowContent.loudPay
            return OrderOffer(id: newOfferId(&s), kind: kind, quarter: quarter(of: g, s), items: [g: qty],
                              pay: (value(s, [g: qty]) * factor * bonus).rounded(),
                              attention: kind == .quiet ? FlowContent.quietAttention : FlowContent.loudAttention,
                              window: (120 + 3 * qty / rate).rounded(), expiresAt: expires)
        case .big:
            let g: Good = s.isOpen(.crystal) ? .crystal : s.openGoods.last!
            let rate = pace(s, g)
            let qty = max(50, (rate * 300).rounded())
            return OrderOffer(id: newOfferId(&s), kind: .big, quarter: quarter(of: g, s), items: [g: qty],
                              pay: (value(s, [g: qty]) * FlowContent.bigPay * bonus).rounded(), attention: FlowContent.bigAttention,
                              window: (120 + 2.5 * qty / rate).rounded(), expiresAt: expires)
        case .trust:
            let c = luxury[min(luxury.count - 1, Int(nextRandom(&s) * Double(luxury.count)))]
            let rate = pace(s, c.good)
            let qty = max(5, (rate * 90).rounded())
            return OrderOffer(id: newOfferId(&s), kind: .trust, quarter: c.quarter, contact: c.id, items: [c.good: qty],
                              pay: (value(s, [c.good: qty]) * FlowContent.trustPay * bonus).rounded(),
                              attention: FlowContent.trustAttention, window: (120 + 3 * qty / rate).rounded(), expiresAt: expires)
        case .city:
            var items: [Good: Double] = [:]
            var longest = 0.0
            for g in s.openGoods {
                let rate = pace(s, g)
                let qty = max(10, (rate * 90).rounded())
                items[g] = qty
                longest = max(longest, qty / rate)
            }
            return OrderOffer(id: newOfferId(&s), kind: .city, quarter: .oldTown, items: items,
                              pay: (value(s, items) * FlowContent.cityPay * bonus).rounded(), attention: FlowContent.cityAttention,
                              window: (180 + 3 * longest).rounded(), expiresAt: expires)
        case .finale:
            return nil
        }
    }

    /// The last contract appears once the other goals of the final chapter are met.
    static func finaleReady(_ s: FlowState) -> Bool {
        guard s.chapter == 6, !s.counters.finale, let ch = FlowContent.chapter(6) else { return false }
        return ch.goals.filter { $0.kind != .finale }.allSatisfy { goalDone(s, $0) }
    }

    static func finaleOffer(_ s: inout FlowState) -> OrderOffer {
        var items: [Good: Double] = [:]
        var longest = 0.0
        for g in s.openGoods {
            let rate = pace(s, g)
            let qty = max(20, (rate * 600).rounded())
            items[g] = qty
            longest = max(longest, qty / rate)
        }
        return OrderOffer(id: newOfferId(&s), kind: .finale, quarter: .oldTown, items: items,
                          pay: (value(s, items) * FlowContent.finalePay).rounded(), attention: 0,
                          window: (600 + 2 * longest).rounded(), expiresAt: s.time + 3.0e8)
    }

    /// Takes an offer from the board: its attention lands now, the deadline starts now.
    static func accept(_ s: inout FlowState, _ offer: OrderOffer) {
        s.offers.removeAll { $0.id == offer.id }
        var attention = offer.attention
        if attention > 0 && s.challenge?.id == .pressWeek { attention *= 2 }
        let quarters: [Quarter] = offer.kind == .city
            ? Array(Set(offer.items.keys.map { quarter(of: $0, s) })).sorted { $0.rawValue < $1.rawValue }
            : [offer.quarter]
        for q in quarters {
            s.updateQuarter(q) { $0.attention = min(100, max(0, $0.attention + attention)) }
        }
        s.orders.append(ActiveOrder(offer: offer, deadline: s.time + offer.window))
        if offer.kind == .quiet { s.counters.quiet += 1 } else if offer.kind != .finale { s.counters.loud += 1 }
    }

    /// What accepting an offer does to its quarter: attention before and after, and the tiers.
    public static func attentionPreview(_ s: FlowState, _ offer: OrderOffer) -> (quarter: Quarter, before: Double, after: Double) {
        var a = offer.attention
        if a > 0 && s.challenge?.id == .pressWeek { a *= 2 }
        let before = s.quarter(offer.quarter).attention
        return (offer.quarter, before, min(100, max(0, before + a)))
    }

    /// Seconds the fleet needs for an order at its current capacity, with nothing else on the way.
    public static func deliverySeconds(_ s: FlowState, _ offer: OrderOffer) -> Double {
        let weight = offer.items.reduce(0) { $0 + $1.value * FlowContent.good($1.key).weight }
        let trips = (weight / max(1e-9, fleetCapacity(s))).rounded(.up)
        return trips * tripSeconds(s)
    }

    // MARK: Chapters

    public static func goalProgress(_ s: FlowState, _ goal: GoalDef) -> (current: Double, target: Double) {
        switch goal.kind {
        case .deliveries(let n): return (Double(s.counters.deliveries), Double(n))
        case .hireLead(let g): return (s.workshop(g)?.lead == true ? 1 : 0, 1)
        case .hireDispatcher: return (s.dispatcher ? 1 : 0, 1)
        case .orders(let n): return (Double(s.counters.orders), Double(n))
        case .earn(let x): return (s.earned, x)
        case .unlockContact(let id): return (s.contacts[id] != nil ? 1 : 0, 1)
        case .throughput(let g, let n):
            let automated = s.dispatcher && s.workshop(g)?.lead == true
            return (automated ? (forecast(s).good(g)?.sold ?? 0) : 0, n)
        case .openGood(let g): return (s.isOpen(g) ? 1 : 0, 1)
        case .bigOrders(let n): return (Double(s.counters.big), Double(n))
        case .clubNight(let n): return (s.counters.clubBest, n)
        case .trust(let contacts, let level):
            return (Double(s.contacts.values.filter { $0.trust >= level }.count), Double(contacts))
        case .cityOrders(let n): return (Double(s.counters.city), Double(n))
        case .finale: return (s.counters.finale ? 1 : 0, 1)
        }
    }

    public static func goalDone(_ s: FlowState, _ goal: GoalDef) -> Bool {
        let p = goalProgress(s, goal)
        return p.current >= p.target - 1e-9
    }

    /// True when every goal of the current chapter is met and it can be closed.
    public static func chapterComplete(_ s: FlowState) -> Bool {
        guard let ch = FlowContent.chapter(s.chapter) else { return false }
        return ch.goals.allSatisfy { goalDone(s, $0) }
    }

    /// Closes the chapter: the network grows, someone joins, the next quarter opens.
    static func closeChapter(_ s: inout FlowState) {
        guard let ch = FlowContent.chapter(s.chapter) else { return }
        if let who = ch.joins, !s.specialists.contains(who) { s.specialists.append(who) }
        s.chapterNews = ch.number
        s.chapter += 1
        if let next = FlowContent.chapter(s.chapter), let q = next.quarter, s.quarters[q] == nil {
            s.quarters[q] = QuarterState()
        }
        s.nextOfferAt = min(max(0, s.nextOfferAt), s.time + 5)
    }

    // MARK: Challenges

    public static func challengesOpen(_ s: FlowState) -> Bool { s.chapter > FlowContent.chapters.count }

    static func startChallenge(_ s: inout FlowState, _ id: ChallengeId) {
        let def = FlowContent.challenge(id)
        let minutes: Double = switch id {
        case .fog: 6
        case .pressWeek: 12
        case .strike: 7
        }
        s.challenge = ChallengeState(id: id, endsAt: s.time + def.seconds, startEarned: s.earned, startOrders: s.counters.orders,
                                     peakAttention: s.quarters.values.map(\.attention).max() ?? 0,
                                     target: max(1, forecast(s).income * minutes), startDeliveries: s.counters.deliveries)
    }

    public static func challengeGoals(_ s: FlowState) -> [Bool] {
        guard let c = s.challenge else { return [] }
        let earned = s.earned - c.startEarned >= c.target
        let orders = s.counters.orders - c.startOrders
        switch c.id {
        case .fog: return [earned, orders >= 3, c.peakAttention < FlowContent.hot]
        case .pressWeek: return [earned, orders >= 2, c.peakAttention < FlowContent.underground]
        case .strike: return [earned, orders >= 2, s.counters.deliveries - c.startDeliveries >= 60]
        }
    }

    static func challengeTick(_ s: inout FlowState) {
        guard var c = s.challenge else { return }
        let now = challengeGoals(s)
        for i in 0..<min(3, now.count) where now[i] { c.goalsDone[i] = true }
        // The attention goals hold only if they held to the end.
        if c.id == .fog { c.goalsDone[2] = c.peakAttention < FlowContent.hot }
        if c.id == .pressWeek { c.goalsDone[2] = c.peakAttention < FlowContent.underground }
        s.challenge = c
        guard s.time >= c.endsAt else { return }
        let def = FlowContent.challenge(c.id)
        for i in 0..<3 where c.goalsDone[i] { s.meta.favors += def.rewards[i] }
        if c.goalsDone.allSatisfy({ $0 }) && !s.challengesDone.contains(c.id) { s.challengesDone.append(c.id) }
        s.challenge = nil
    }

    // MARK: Hints

    /// True while the first ordinary upgrade (the van, one crate more per trip) is waiting and the cash covers it.
    public static func firstVanUpgradeReady(_ s: FlowState) -> Bool {
        s.start != nil && s.counters.purchases == 0 && s.fleet == 1 && s.cash + 1e-9 >= fleetCost(s, 1)
    }

    /// The first steps in the cellar: the van upgrade the pickup paid for, start the bench, send the crates, fix the
    /// bottleneck, automate, choose. A step is only suggested when it can be done now; while the next hire is out
    /// of reach the hint keeps the chain going by hand.
    public static func hint(_ s: FlowState) -> FlowHint? {
        guard s.start != nil, s.chapter == 1, let w = s.workshop(.weed) else { return nil }
        if firstVanUpgradeReady(s) { return .firstUpgrade }
        let benchIdle = w.stock < 1 && w.cycle == nil && !w.lead
        let vanReady = w.stock >= 1 && s.trip == nil && !s.dispatcher
        if s.counters.deliveries == 0 {
            if benchIdle { return .tapBench }
            if vanReady { return .tapFleet }
            return nil
        }
        if !w.lead {
            if forecast(s).good(.weed)?.bottleneck == .fleet && w.stock >= shelfCapacity(s, .weed) * 0.8 && s.fleet < 3 {
                return .bottleneck
            }
            if s.cash + 1e-9 < FlowContent.good(.weed).leadCost {
                if benchIdle { return .tapBench }
                if vanReady { return .tapFleet }
            }
            return .hireLead
        }
        if s.counters.quiet + s.counters.loud == 0 && !s.offers.isEmpty { return .chooseOrder }
        if !s.dispatcher { return .hireDispatcher }
        return nil
    }
}
