import Foundation

/// The rules of the 4.0 ledger: a pure, deterministic function of the state and elapsed game time.
public enum Flow {

    // MARK: Start

    /// Leopold's cellar before the player has chosen what to take: one bench, one shelf, the corner of Mühlgasse.
    public static func newGame(seed: UInt64, nowMs: Int64, meta: MetaState = MetaState()) -> FlowState {
        var s = FlowState()
        s.rng = UInt64Box(seed == 0 ? 1 : seed)
        s.lastWallClockMs = nowMs
        s.meta = meta
        s.meta.offlineBonus = 0
        s.workshops[.weed] = WorkshopState()
        s.contacts["muehlgasse"] = ContactState()
        s.quarters[.cellars] = QuarterState()
        s.nextOfferAt = -1
        return s
    }

    static func applyStart(_ s: inout FlowState, _ choice: StartChoice) {
        s.start = choice
        switch choice {
        case .cashbox:
            s.cash += FlowContent.cashboxCash
        case .addressBook:
            s.contacts["baeckerei"] = ContactState()
        case .tools:
            s.updateWorkshop(.weed) {
                $0.bench = FlowContent.toolsBench
                $0.shelf = FlowContent.toolsShelf
            }
        }
    }

    // MARK: Randomness

    static func nextRandom(_ s: inout FlowState) -> Double {
        s.rng.raw &+= 0x9E37_79B9_7F4A_7C15
        var z = s.rng.raw
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / 9_007_199_254_740_992.0
    }

    // MARK: Simulation

    /// Advances the game by `seconds`. While away (`offline`) only automated stations work, no new offers come in,
    /// accepted orders keep their deadlines and attention keeps fading.
    public static func advance(_ s: inout FlowState, seconds: Double, offline: Bool, step: Double = 0.25) {
        guard s.start != nil else { return }
        var remaining = max(0, seconds)
        while remaining > 1e-9 {
            let dt = min(step, remaining)
            self.step(&s, dt: dt, offline: offline)
            remaining -= dt
        }
    }

    static func step(_ s: inout FlowState, dt: Double, offline: Bool) {
        let wasNight = clubNight(s).on
        s.time += dt
        timers(&s, dt)
        demand(&s, dt)
        benches(&s, dt, offline: offline)
        fleet(&s, dt, offline: offline)
        ordersDue(&s)
        attention(&s, dt)
        if !offline { offersTick(&s) }
        clubBook(&s, wasNight: wasNight)
        challengeTick(&s)
    }

    static func timers(_ s: inout FlowState, _ dt: Double) {
        if s.meta.boostSeconds > 0 { s.meta.boostSeconds = max(0, s.meta.boostSeconds - dt) }
        if s.meta.heatAidCooldown > 0 { s.meta.heatAidCooldown = max(0, s.meta.heatAidCooldown - dt) }
        for (a, var st) in s.abilities {
            st.active = max(0, st.active - dt)
            st.cooldown = max(0, st.cooldown - dt)
            s.abilities[a] = st
        }
    }

    /// Contacts want more as time passes, up to two minutes of demand.
    static func demand(_ s: inout FlowState, _ dt: Double) {
        for id in s.contacts.keys {
            let rate = contactRate(s, id)
            let cap = max(contactBaseRate(s, id), rate) * FlowContent.demandMemory
            s.updateContact(id) { $0.open = min(cap, $0.open + rate * dt) }
        }
    }

    static func benches(_ s: inout FlowState, _ dt: Double, offline: Bool) {
        for g in s.openGoods {
            guard var w = s.workshops[g] else { continue }
            let capacity = shelfCapacity(s, g)
            let full = w.stock >= capacity - 1e-9
            w.fullFor = full ? w.fullFor + dt : 0
            if w.cycle == nil && w.lead && !full { w.cycle = 0 }
            if var c = w.cycle, !(offline && !w.lead) {
                c += dt / cycleSeconds(s, g)
                if c >= 1 - 1e-9 {
                    w.stock = min(capacity, w.stock + batch(s, g))
                    c = 0
                    w.cycle = w.lead && w.stock < capacity - 1e-9 ? c : nil
                } else {
                    w.cycle = c
                }
            }
            s.workshops[g] = w
        }
    }

    static func fleet(_ s: inout FlowState, _ dt: Double, offline: Bool) {
        if var trip = s.trip {
            trip.left -= dt
            if trip.left <= 1e-9 {
                s.trip = nil
                arrive(&s, trip)
            } else {
                s.trip = trip
            }
        }
        if s.trip == nil && s.dispatcher { _ = departTrip(&s, manual: false) }
    }

    /// Loads the fleet from the shelves: accepted orders first (unless the player says otherwise), then the
    /// contacts' open demand, each good with its base share and the rest in priority order.
    @discardableResult
    static func departTrip(_ s: inout FlowState, manual: Bool) -> Bool {
        let capacity = fleetCapacity(s)
        var stock: [Good: Double] = [:]
        for g in s.openGoods { stock[g] = s.workshops[g]?.stock ?? 0 }

        func orderLoad(_ cap: Double) -> ([Good: Double], [Int: [Good: Double]]) {
            var need: [Good: Double] = [:]
            for o in s.orders {
                for g in o.offer.items.keys { need[g, default: 0] += o.remaining(g) }
            }
            for g in need.keys { need[g] = min(need[g] ?? 0, stock[g] ?? 0) }
            let load = allocate(need: need, capacity: cap, priority: s.priority)
            var left = load
            var per: [Int: [Good: Double]] = [:]
            for o in s.orders {
                for g in o.offer.items.keys {
                    let x = min(left[g] ?? 0, o.remaining(g))
                    if x > 1e-12 {
                        per[o.id, default: [:]][g] = x
                        left[g, default: 0] -= x
                    }
                }
            }
            return (load, per)
        }

        func standingLoad(_ cap: Double) -> [Good: Double] {
            var need: [Good: Double] = [:]
            for g in s.openGoods {
                let open = contacts(s, of: g).reduce(0) { $0 + (s.contacts[$1]?.open ?? 0) }
                need[g] = max(0, min(stock[g] ?? 0, open))
            }
            return allocate(need: need, capacity: cap, priority: s.priority)
        }

        func weight(_ load: [Good: Double]) -> Double {
            load.reduce(0) { $0 + $1.value * FlowContent.good($1.key).weight }
        }

        var standing: [Good: Double] = [:]
        var perOrder: [Int: [Good: Double]] = [:]
        if s.ordersFirst {
            let (load, per) = orderLoad(capacity)
            perOrder = per
            for (g, x) in load { stock[g, default: 0] -= x }
            standing = standingLoad(max(0, capacity - weight(load)))
        } else {
            standing = standingLoad(capacity)
            for (g, x) in standing { stock[g, default: 0] -= x }
            let (_, per) = orderLoad(max(0, capacity - weight(standing)))
            perOrder = per
        }
        let trip = Trip(left: tripSeconds(s), duration: tripSeconds(s), standing: standing.filter { $0.value > 1e-12 },
                        orders: perOrder)
        guard trip.crates > 1e-9 else { return false }
        for (g, x) in trip.standing { s.updateWorkshop(g) { $0.stock = max(0, $0.stock - x) } }
        for (id, items) in trip.orders {
            for (g, x) in items { s.updateWorkshop(g) { $0.stock = max(0, $0.stock - x) } }
            if let i = s.orders.firstIndex(where: { $0.id == id }) {
                for (g, x) in items { s.orders[i].inTransit[g, default: 0] += x }
            }
        }
        s.trip = trip
        return true
    }

    /// A trip arrives: standing contacts pay (best price first) and orders count what they received.
    static func arrive(_ s: inout FlowState, _ trip: Trip) {
        var any = false
        for (g, crates) in trip.standing where crates > 1e-12 {
            var left = crates
            for id in contacts(s, of: g) where left > 1e-12 {
                let open = s.contacts[id]?.open ?? 0
                let x = min(left, open)
                guard x > 1e-12 else { continue }
                let pay = x * contactPrice(s, id)
                s.updateContact(id) { $0.open = max(0, $0.open - x) }
                credit(&s, pay)
                book(&s, .delivery, subject: id, good: g, crates: x, amount: pay)
                if FlowContent.contact(id)?.club == true && clubNight(s).on { s.counters.clubNow += x }
                left -= x
            }
            // Whatever nobody wanted any more goes back on the shelf.
            if left > 1e-12 {
                let cap = shelfCapacity(s, g)
                s.updateWorkshop(g) { $0.stock = min(cap, $0.stock + left) }
            }
            s.counters.crates += crates - left
            any = any || crates - left > 1e-12
        }
        for (id, items) in trip.orders {
            guard let i = s.orders.firstIndex(where: { $0.id == id }) else { continue }
            for (g, x) in items {
                s.orders[i].inTransit[g] = max(0, (s.orders[i].inTransit[g] ?? 0) - x)
                s.orders[i].delivered[g, default: 0] += x
            }
            any = true
            if s.orders[i].done { complete(&s, i) }
        }
        if any { s.counters.deliveries += 1 }
    }

    static func complete(_ s: inout FlowState, _ index: Int) {
        let o = s.orders.remove(at: index)
        let pay = o.offer.pay * (s.has(.morgen) ? FlowContent.morganBonus : 1)
        credit(&s, pay)
        book(&s, .order, subject: o.offer.kind.rawValue, good: o.offer.items.count == 1 ? o.offer.items.keys.first : nil,
             crates: o.offer.crates, amount: pay)
        s.counters.orders += 1
        switch o.offer.kind {
        case .big: s.counters.big += 1
        case .city: s.counters.city += 1
        case .finale: s.counters.finale = true
        case .trust:
            if let c = o.offer.contact { s.updateContact(c) { $0.trust = min(FlowContent.maxTrust, $0.trust + 1) } }
        case .quiet, .loud: break
        }
    }

    /// Orders past their deadline fail: what arrived is paid at the standing price; trust suffers.
    static func ordersDue(_ s: inout FlowState) {
        var i = 0
        while i < s.orders.count {
            let o = s.orders[i]
            if s.time >= o.deadline && o.inTransit.values.allSatisfy({ $0 <= 1e-12 }) {
                s.orders.remove(at: i)
                var pay = 0.0
                for (g, x) in o.delivered { pay += x * FlowContent.good(g).price * payMultiplier(s) }
                credit(&s, pay)
                book(&s, .orderFailed, subject: o.offer.kind.rawValue, good: o.offer.items.count == 1 ? o.offer.items.keys.first : nil,
                     crates: o.delivered.values.reduce(0, +), amount: pay)
                s.counters.failed += 1
                if o.offer.kind == .trust, let c = o.offer.contact {
                    s.updateContact(c) { $0.trust = max(0, $0.trust - 1) }
                }
            } else {
                i += 1
            }
        }
    }

    static func attention(_ s: inout FlowState, _ dt: Double) {
        for q in Quarter.allCases where s.quarters[q] != nil {
            let fade = fadeRate(s, q) * dt
            s.updateQuarter(q) { $0.attention = max(0, $0.attention - fade) }
        }
        if var c = s.challenge {
            c.peakAttention = max(c.peakAttention, s.quarters.values.map(\.attention).max() ?? 0)
            s.challenge = c
        }
    }

    /// Books pills sold in a club night when it ends.
    static func clubBook(_ s: inout FlowState, wasNight: Bool) {
        let now = clubNight(s).on
        if wasNight && !now {
            s.counters.clubBest = max(s.counters.clubBest, s.counters.clubNow)
            s.counters.clubNow = 0
        } else if now {
            s.counters.clubBest = max(s.counters.clubBest, s.counters.clubNow)
        }
    }

    static func credit(_ s: inout FlowState, _ amount: Double) {
        guard amount.isFinite, amount > 0 else { return }
        s.cash += amount
        s.earned += amount
        s.meta.lifetimeDirty += amount
    }

    /// Writes a booking into the ledger; deliveries to the same contact within ten seconds share one line.
    static func book(_ s: inout FlowState, _ kind: LedgerKind, subject: String, good: Good?, crates: Double, amount: Double) {
        if kind == .delivery, var last = s.ledger.last, last.kind == .delivery, last.subject == subject, s.time - last.time < 10 {
            last.crates += crates
            last.amount += amount
            last.time = s.time
            s.ledger[s.ledger.count - 1] = last
            return
        }
        s.ledger.append(LedgerEntry(id: s.nextLedgerId, time: s.time, kind: kind, subject: subject, good: good, crates: crates, amount: amount))
        s.nextLedgerId += 1
        if s.ledger.count > FlowContent.ledgerSize { s.ledger.removeFirst(s.ledger.count - FlowContent.ledgerSize) }
    }

    // MARK: Time away

    /// Credits time spent away: up to the cap, simulated second by second with only the automated stations. The
    /// summary is stored in the state, so showing it again never pays a second time.
    public static func applyOffline(_ state: FlowState, nowMs: Int64) -> FlowState {
        var s = state
        let last = s.lastWallClockMs
        s.lastWallClockMs = nowMs
        guard last > 0, s.start != nil else { return s }
        let elapsed = Double(nowMs - last) / 1000
        if elapsed < 0 {
            s.welcome = FlowReturn(away: 0, credited: 0, capped: false, earned: 0, deliveries: 0, ordersDone: 0,
                                   ordersFailed: 0, fullShelves: [], clockMovedBack: true)
            return s
        }
        guard elapsed >= 5 else { return s }
        let cap = FlowContent.offlineCap * (s.meta.premium ? 2 : 1)
        let credited = min(elapsed, cap)
        let before = (earned: s.earned, deliveries: s.counters.deliveries, orders: s.counters.orders, failed: s.counters.failed)
        passTime(&s, seconds: credited)
        let earned = s.earned - before.earned
        guard elapsed >= 60 else { return s }
        if earned > 0 {
            s.meta.offlineBonus = earned
            book(&s, .away, subject: "", good: nil, crates: 0, amount: earned)
        }
        let full = s.openGoods.filter { (s.workshops[$0]?.stock ?? 0) >= shelfCapacity(s, $0) - 1e-9 }
        s.welcome = FlowReturn(away: elapsed, credited: credited, capped: elapsed > cap, earned: earned,
                               deliveries: s.counters.deliveries - before.deliveries,
                               ordersDone: s.counters.orders - before.orders, ordersFailed: s.counters.failed - before.failed,
                               fullShelves: full, clockMovedBack: false)
        return s
    }

    /// Lets `seconds` pass as time away (also used by time jumps): second by second, only automated work.
    static func passTime(_ s: inout FlowState, seconds: Double) {
        // Offers on the board leave; a fresh board waits for the player.
        s.offers.removeAll()
        advance(&s, seconds: seconds, offline: true, step: seconds > 600 ? 1 : 0.25)
        if s.nextOfferAt >= 0 { s.nextOfferAt = min(s.nextOfferAt, s.time + 10) }
    }
}
