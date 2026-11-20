import Foundation

public enum FlowAction: Sendable, Equatable {
    /// Hands the waiting crate to the buyer with the signed slip at the cellar door: one booking, once per game.
    case collectEstate
    /// Picks what to take from Leopold's things; starts the game.
    case choose(StartChoice)
    /// Starts one bench cycle by hand (until the workshop has a lead).
    case tapBench(Good)
    /// Sends the fleet out by hand (until there is a dispatcher).
    case tapFleet
    /// Buys `amount` levels of a station; 0 buys as many as the cash allows.
    case upgrade(Station, Int)
    case unlockContact(String)
    case openWorkshop(Good)
    case hireLead(Good)
    case hireDispatcher
    case accept(Int)
    case decline(Int)
    /// The order goods share the fleet in after their base share.
    case setPriority([Good])
    case setOrdersFirst(Bool)
    /// Keeps deliveries out of a quarter so it calms down three times as fast.
    case pause(Quarter, Bool)
    case setAutoQuiet(Bool)
    case use(Ability, Good?)
    case closeChapter
    case seenChapter
    case startChallenge(ChallengeId)
    case dismissWelcome
    case claimDaily(day: Int)
    case buyFavorItem(FavorItem)
    case adReward(AdReward, day: Int)
    case grant(Grant)
    /// A verified store purchase: the grant and its transaction id are booked together, and an id that was already
    /// booked is rejected (`.invalid`) so a redelivered transaction never pays twice.
    case deliverPurchase(Grant, transaction: String)
    case collectOffline(doubled: Bool)
}


extension MetaState {
    /// Whether this permanent purchase is already in the wallet (a restore then changes nothing).
    public func owns(_ grant: Grant) -> Bool {
        switch grant {
        case .favors: false
        case .premium: premium
        case .noAds: noAds
        case .starter: starterBought
        }
    }
}

public struct FlowResult: Sendable {
    public let state: FlowState
    public let error: ActionError?
    /// Cash the action paid out directly (for floaters).
    public let gained: Double

    public var isOK: Bool { error == nil }
}

extension Flow {
    public static func apply(_ state: FlowState, _ action: FlowAction) -> FlowResult {
        var s = state
        func fail(_ e: ActionError) -> FlowResult { FlowResult(state: state, error: e, gained: 0) }
        func done(_ gained: Double = 0) -> FlowResult { FlowResult(state: s, error: nil, gained: gained) }
        func pay(_ cost: Double) -> Bool {
            guard cost.isFinite, s.cash >= cost - 1e-9 else { return false }
            s.cash = max(0, s.cash - cost)
            s.counters.purchases += 1
            return true
        }

        // Before Leopold's things are chosen only the pickup at the door, the choice and purchases can happen.
        if s.start == nil {
            switch action {
            case .choose(let choice):
                applyStart(&s, choice)
                return done()
            case .collectEstate, .grant, .deliverPurchase:
                break
            default:
                return fail(.tutorial)
            }
        }

        switch action {
        case .choose:
            return fail(.invalid)

        case .collectEstate:
            guard s.estate == .waiting else { return fail(.invalid) }
            s.estate = .booked
            let paid = FlowContent.estatePickupCash
            credit(&s, paid)
            book(&s, .estate, subject: "estate", good: .weed, crates: FlowContent.estatePickupCrates, amount: paid)
            return done(paid)

        case .tapBench(let g):
            guard let w = s.workshop(g) else { return fail(.locked) }
            s.meta.taps += 1
            s.counters.taps += 1
            if w.lead || w.cycle != nil { return done() }
            guard w.stock < shelfCapacity(s, g) - 1e-9 else { return fail(.maxLevel) }
            s.updateWorkshop(g) { $0.cycle = 0 }
            return done()

        case .tapFleet:
            s.meta.taps += 1
            s.counters.taps += 1
            if s.dispatcher || s.trip != nil { return done() }
            guard departTrip(&s, manual: true) else { return fail(.requirements) }
            return done()

        case .upgrade(let station, let amount):
            switch station {
            case .bench(let g), .shelf(let g): guard s.isOpen(g) else { return fail(.locked) }
            case .contact(let id): guard s.contacts[id] != nil else { return fail(.locked) }
            case .fleet: break
            }
            let current = level(s, station)
            guard current < FlowContent.maxLevel else { return fail(.maxLevel) }
            let n = amount <= 0 ? affordable(s, station) : min(amount, FlowContent.maxLevel - current)
            guard n > 0, pay(cost(s, station, n)) else { return fail(.notAffordable) }
            let cash = s.cash
            s = upgraded(s, station, n)
            s.cash = cash
            return done()

        case .unlockContact(let id):
            guard let def = FlowContent.contact(id), s.contacts[id] == nil else { return fail(.invalid) }
            guard s.chapter >= def.chapter, s.isOpen(def.good) else { return fail(.locked) }
            guard pay(def.unlockCost) else { return fail(.notAffordable) }
            s.contacts[id] = ContactState()
            if s.quarters[def.quarter] == nil { s.quarters[def.quarter] = QuarterState() }
            return done()

        case .openWorkshop(let g):
            let def = FlowContent.good(g)
            guard !s.isOpen(g) else { return fail(.invalid) }
            guard s.chapter >= def.chapter else { return fail(.locked) }
            guard pay(def.openCost) else { return fail(.notAffordable) }
            s.workshops[g] = WorkshopState()
            for c in FlowContent.contacts where c.good == g && c.unlockCost == 0 && s.contacts[c.id] == nil {
                s.contacts[c.id] = ContactState()
                if s.quarters[c.quarter] == nil { s.quarters[c.quarter] = QuarterState() }
            }
            return done()

        case .hireLead(let g):
            guard let w = s.workshop(g) else { return fail(.locked) }
            guard !w.lead else { return fail(.invalid) }
            guard pay(FlowContent.good(g).leadCost) else { return fail(.notAffordable) }
            s.updateWorkshop(g) { $0.lead = true }
            return done()

        case .hireDispatcher:
            guard !s.dispatcher else { return fail(.invalid) }
            guard pay(FlowContent.dispatcherCost) else { return fail(.notAffordable) }
            s.dispatcher = true
            return done()

        case .accept(let id):
            guard let offer = s.offers.first(where: { $0.id == id }), offer.expiresAt > s.time else { return fail(.invalid) }
            guard s.orders.count < orderSlots(s) || offer.kind == .finale else { return fail(.requirements) }
            accept(&s, offer)
            return done()

        case .decline(let id):
            guard s.offers.contains(where: { $0.id == id }) else { return fail(.invalid) }
            s.offers.removeAll { $0.id == id }
            return done()

        case .setPriority(let order):
            guard Set(order) == Set(Good.allCases), order.count == Good.allCases.count else { return fail(.invalid) }
            s.priority = order
            return done()

        case .setOrdersFirst(let on):
            s.ordersFirst = on
            return done()

        case .pause(let q, let on):
            guard s.quarters[q] != nil else { return fail(.locked) }
            s.updateQuarter(q) { $0.paused = on }
            return done()

        case .setAutoQuiet(let on):
            guard s.has(.okafor) else { return fail(.locked) }
            s.autoQuiet = on
            return done()

        case .use(let ability, let good):
            var st = s.ability(ability)
            guard st.cooldown <= 0 else { return fail(.cooldown) }
            switch ability {
            case .doubleShift:
                guard s.chapter >= FlowContent.abilityChapter, let g = good, s.workshop(g)?.lead == true else { return fail(.locked) }
                st.good = g
                st.active = FlowContent.abilitySeconds
            case .rushRun:
                guard s.chapter >= FlowContent.abilityChapter, s.dispatcher else { return fail(.locked) }
                st.active = FlowContent.abilitySeconds
            case .newWindow:
                guard s.has(.okafor), boardOpen(s) else { return fail(.locked) }
                s.offers.removeAll { $0.kind != .finale }
                var made = 0
                while made < boardSize(s) {
                    if let o = makeOffer(&s, bonus: made == 0 ? 1.2 : 1) { s.offers.append(o) }
                    made += 1
                }
                s.nextOfferAt = s.time + FlowContent.offerGap
            case .quietWord:
                guard s.has(.kraus) else { return fail(.locked) }
                guard let hottest = s.quarters.max(by: { $0.value.attention < $1.value.attention }), hottest.value.attention > 0.5 else {
                    return fail(.invalid)
                }
                s.updateQuarter(hottest.key) { $0.attention = max(0, $0.attention - FlowContent.quietWord) }
            }
            st.cooldown = FlowContent.abilityCooldown[ability] ?? 600
            s.abilities[ability] = st
            return done()

        case .closeChapter:
            guard chapterComplete(s) else { return fail(.requirements) }
            closeChapter(&s)
            return done()

        case .seenChapter:
            s.chapterNews = nil
            return done()

        case .startChallenge(let id):
            guard challengesOpen(s) else { return fail(.locked) }
            guard s.challenge == nil else { return fail(.invalid) }
            guard s.dispatcher else { return fail(.requirements) }
            startChallenge(&s, id)
            return done()

        case .dismissWelcome:
            s.welcome = nil
            return done()

        case .claimDaily(let day):
            guard day > s.meta.dailyLastDay else { return fail(.cooldown) }
            let reward = Idle.dailyReward(claims: s.meta.dailyClaims)
            s.meta.dailyLastDay = day
            s.meta.dailyClaims += 1
            switch reward {
            case .favors(let n): s.meta.favors += n
            case .boost(let seconds): s.meta.boostSeconds = min(Idle.boostCapSeconds, s.meta.boostSeconds + seconds)
            case .warp(let seconds):
                if s.dispatcher { passTime(&s, seconds: seconds) } else { s.meta.favors += 10 }
            }
            return done()

        case .buyFavorItem(let item):
            guard s.meta.favors >= item.price else { return fail(.notAffordable) }
            switch item {
            case .boost4h:
                guard s.meta.boostSeconds < Idle.boostCapSeconds - 1 else { return fail(.maxLevel) }
                s.meta.boostSeconds = min(Idle.boostCapSeconds, s.meta.boostSeconds + 4 * 3600)
            case .warp2h, .warp8h, .warp24h:
                guard s.dispatcher else { return fail(.requirements) }
                let before = s.earned
                passTime(&s, seconds: item.warpSeconds)
                s.meta.favors -= item.price
                return done(s.earned - before)
            case .coolHeat:
                guard s.quarters.values.contains(where: { $0.attention > 0.5 }) else { return fail(.invalid) }
                for q in Array(s.quarters.keys) { s.updateQuarter(q) { $0.attention = max(0, $0.attention - 50) } }
            case .loyalty:
                return fail(.invalid)
            }
            s.meta.favors -= item.price
            return done()

        case .adReward(let reward, let day):
            switch reward {
            case .boost:
                guard s.meta.boostSeconds < Idle.boostCapSeconds - 1 else { return fail(.maxLevel) }
                s.meta.boostSeconds = min(Idle.boostCapSeconds, s.meta.boostSeconds + Idle.adBoostSeconds)
            case .coolHeat:
                guard s.meta.heatAidCooldown <= 0 else { return fail(.cooldown) }
                guard let hottest = s.quarters.max(by: { $0.value.attention < $1.value.attention }), hottest.value.attention > 0.5 else {
                    return fail(.invalid)
                }
                s.updateQuarter(hottest.key) { $0.attention = max(0, $0.attention - 50) }
                s.meta.heatAidCooldown = Idle.adHeatCooldown
            case .favors:
                if s.meta.adFavorsDay != day {
                    s.meta.adFavorsDay = day
                    s.meta.adFavorsToday = 0
                }
                guard s.meta.adFavorsToday < Idle.adFavorsPerDay else { return fail(.cooldown) }
                s.meta.adFavorsToday += 1
                s.meta.favors += Idle.adFavors
            case .offlineDouble:
                guard s.meta.offlineBonus > 0 else { return fail(.invalid) }
                let bonus = s.meta.offlineBonus
                credit(&s, bonus)
                s.meta.offlineBonus = 0
                s.meta.adsWatched += 1
                return done(bonus)
            }
            s.meta.adsWatched += 1
            return done()

        case .grant:
            return applyGrant(&s, action) ? done() : fail(.invalid)

        case .deliverPurchase(let grant, let transaction):
            let id = transaction.trimmingCharacters(in: .whitespaces)
            guard !id.isEmpty, !s.meta.deliveredTransactions.contains(id) else { return fail(.invalid) }
            guard applyGrant(&s, .grant(grant)) else { return fail(.invalid) }
            // Kept for the whole life of the save: an unfinished transaction can come back after any number of
            // newer ones, and it must still be recognised.
            s.meta.deliveredTransactions.append(id)
            return done()

        case .collectOffline(let doubled):
            var gained = 0.0
            if doubled && s.meta.offlineBonus > 0 {
                gained = s.meta.offlineBonus
                credit(&s, gained)
            }
            s.meta.offlineBonus = 0
            s.welcome = nil
            return done(gained)
        }
    }

    /// Whether a verified transaction id is already booked in this save.
    public static func hasBooked(_ s: FlowState, transaction id: String) -> Bool {
        s.meta.deliveredTransactions.contains(id.trimmingCharacters(in: .whitespaces))
    }

    static func applyGrant(_ s: inout FlowState, _ action: FlowAction) -> Bool {
        guard case .grant(let grant) = action else { return false }
        switch grant {
        case .favors(let n):
            guard n > 0 else { return false }
            s.meta.favors += n
        case .premium:
            s.meta.premium = true
        case .noAds:
            s.meta.noAds = true
        case .starter:
            if !s.meta.starterBought {
                s.meta.starterBought = true
                s.meta.favors += Idle.starterFavors
                s.meta.boostSeconds = min(Idle.boostCapSeconds, s.meta.boostSeconds + Idle.starterBoostSeconds)
            }
        }
        return true
    }
}
