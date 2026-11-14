import Foundation

/// Accumulates what happened during an advance (used for the offline summary and tests).
public struct TickReport: Sendable, Equatable {
    public var seconds = 0.0
    public var produced = 0.0
    public var sold = 0.0
    public var dirtyEarned = 0.0
    public var dirtyLaundered = 0.0
    public var cleanGained = 0.0
    public var wagesPaid = 0.0
    public var productionSpent = 0.0
    public var influenceGained = 0.0
    public var raids = 0
    public var crewLeft = 0

    public init() {}
}

public enum Simulation {

    public static let maxStep = 1.0

    /// Advances the simulation by `seconds` in steps of at most `step`. Deterministic for a given state.
    @discardableResult
    public static func advance(_ s: inout GameState, seconds: Double, offline: Bool, step: Double = maxStep) -> TickReport {
        var report = TickReport()
        var remaining = seconds
        while remaining > 1e-9 {
            let dt = min(step, remaining)
            self.step(&s, dt: dt, offline: offline, report: &report)
            remaining -= dt
        }
        return report
    }

    public static func step(_ s: inout GameState, dt: Double, offline: Bool, report r: inout TickReport) {
        let m = Economy.mods(s)
        s.time += dt
        r.seconds += dt
        if offline { s.stats.offlineSeconds += dt } else { s.stats.onlineSeconds += dt }
        let now = s.time
        s.modifiers.removeAll { $0.until <= now }
        // Payout multipliers are fixed for the step, before the boost clock runs down.
        let globalMult = Idle.globalMultiplier(s)
        if s.meta.boostSeconds > 0 { s.meta.boostSeconds = max(0, s.meta.boostSeconds - dt) }
        if s.meta.heatAidCooldown > 0 { s.meta.heatAidCooldown = max(0, s.meta.heatAidCooldown - dt) }

        // ---- Production ----
        let cap = Economy.stashCapacity(s, m)
        for p in ProductId.allCases {
            guard var line = s.lines[p], line.owned else { continue }
            defer { s.lines[p] = line }
            if !line.running { line.status = .idle; continue }
            if s.totalStock >= cap - 1e-6 { line.status = .storageFull; continue }
            let cyc = Economy.cycleTime(s, p, m)
            if cyc.isInfinite { line.status = .running; continue }
            line.progress += dt
            if line.status != .emergency && line.status != .noCash { line.status = .running }
            var guardCount = 0
            while line.progress >= cyc && guardCount < 50 {
                guardCount += 1
                let space = cap - s.totalStock
                if space <= 1e-6 { line.status = .storageFull; line.progress = cyc; break }
                let units = min(Economy.batchSize(s, p), space)
                let cost = units * Economy.unitCost(s, p, m)
                if s.dirty >= cost {
                    s.dirty -= cost
                    r.productionSpent += cost
                    line.progress -= cyc
                    line.status = .running
                } else if p == .glimmer {
                    // Scrap mode: the starter line keeps running at half speed for free, so a save can never dead-lock.
                    line.progress -= 2 * cyc
                    line.status = .emergency
                } else {
                    line.status = .noCash
                    line.progress = cyc
                    break
                }
                s.inventory[p] = s.stock(p) + units
                s.stats.unitsProduced += units
                r.produced += units
            }
        }

        // ---- Sales ----
        var exposure = 0.0
        var revenueTotal = 0.0
        var baseRevenueTotal = 0.0
        var desired: [(DistrictId, ProductId, Double)] = []
        var desiredByProduct: [ProductId: Double] = [:]
        for d in DistrictId.allCases {
            guard let ds = s.districts[d], Economy.salesActive(s, d) else { continue }
            for p in ProductId.allCases {
                guard ds.route(p) > 0 else { continue }
                let u = Economy.desiredSales(s, d, p, m) * dt
                if u <= 0 { continue }
                desired.append((d, p, u))
                desiredByProduct[p, default: 0] += u
            }
        }
        var soldInDistrict: [DistrictId: Double] = [:]
        for (d, p, u) in desired {
            let want = desiredByProduct[p] ?? 0
            let ratio = want <= 0 ? 0 : min(1, s.stock(p) / want)
            let sold = u * ratio
            if sold <= 0 { continue }
            // `revenue` is the base street economy and drives exposure; the payout multipliers only raise the cash.
            let revenue = sold * Economy.price(s, d, p, m)
            baseRevenueTotal += revenue
            revenueTotal += revenue * Idle.lineMultiplier(s, p) * globalMult
            soldInDistrict[d, default: 0] += sold
            exposure += revenue / dt * Content.product(p).risk * Content.district(d).police
                * m.salesExposure * Economy.timed(s, .exposure, district: d, product: p)
            r.sold += sold
            s.stats.unitsSold += sold
        }
        // Deduct stock after computing ratios so allocation is fair across districts.
        for p in ProductId.allCases {
            guard let want = desiredByProduct[p] else { continue }
            let taken = min(want, s.stock(p))
            s.inventory[p] = max(0, s.stock(p) - taken)
        }
        s.dirty += revenueTotal
        s.stats.dirtyEarned += revenueTotal
        s.meta.lifetimeDirty += revenueTotal
        if baseRevenueTotal > 0 { s.meta.payoutRatio = max(1, revenueTotal / baseRevenueTotal) }
        let payoutRatio = Idle.payoutRatio(s)
        r.dirtyEarned += revenueTotal
        if s.campaign.tutorial == .earn { s.stats.tutorialEarned += revenueTotal }

        // Passive presence: selling in a district slowly pushes rivals back, up to a presence cap.
        for d in DistrictId.allCases {
            guard let sold = soldInDistrict[d], sold > 0 else { continue }
            let capCtl = Economy.presenceCap(s, d)
            s.updateDistrict(d) { ds in
                if ds.control < capCtl { ds.rival = max(100 - capCtl, ds.rival - 0.02 * dt) }
            }
        }

        // ---- Laundering ----
        let cleanBefore = r.cleanGained
        // No working reserve during the briefing, so the first wash happens right away.
        // The reserve covers minutes of material costs, so the lines never run dry, and everything above is washed.
        let reserve = s.campaign.tutorial != .done ? 0 : Economy.materialCostRate(s, m) * 60 * Double(s.reserveMinutes)
        for f in FrontId.allCases {
            guard let fs = s.fronts[f], fs.owned, fs.active else { continue }
            let avail = max(0, s.dirty - reserve)
            let amount = min(Economy.frontCapacity(s, f, m) * dt, avail)
            if amount <= 0 { continue }
            s.dirty -= amount
            let gained = amount * (1 - Economy.frontFee(s, f, m))
            s.clean += gained
            s.stats.cleanLaundered += gained
            s.meta.lifetimeClean += gained
            r.dirtyLaundered += amount
            r.cleanGained += gained
            exposure += amount / payoutRatio / dt * Content.front(f).risk * m.launderRisk
        }
        exposure *= m.allExposure
        let cleanThisStep = r.cleanGained - cleanBefore

        // ---- Wages & loyalty ----
        let wage = Economy.wagePerSec(s) * m.wage * dt
        if wage > 0 {
            if s.dirty >= wage {
                s.dirty -= wage
                r.wagesPaid += wage
                if s.wagesUnpaid { s.wagesUnpaid = false }
            } else {
                r.wagesPaid += s.dirty
                s.dirty = 0
                if !s.wagesUnpaid {
                    s.wagesUnpaid = true
                    s.log(.wagesUnpaid)
                }
            }
        }
        var leaving: [String] = []
        for i in s.crew.indices {
            let trait = s.crew[i].def?.trait
            if s.wagesUnpaid {
                s.crew[i].loyalty -= 3.0 / 60 * dt * (trait == .loyal ? 0.5 : 1)
            } else if s.crew[i].loyalty < 80 {
                s.crew[i].loyalty = min(80, s.crew[i].loyalty + 0.5 / 60 * dt * (trait == .loyal ? 1.5 : 1))
            }
            if offline { s.crew[i].loyalty = max(s.crew[i].loyalty, 10) }
            if s.crew[i].loyalty <= 0 { leaving.append(s.crew[i].defId) }
        }
        for id in leaving {
            s.crew.removeAll { $0.defId == id }
            if !s.departed.contains(id) { s.departed.append(id) }
            s.log(.crewLeft, ref: id)
            r.crewLeft += 1
        }

        // ---- Influence ----
        let inf = Economy.influencePerSec(s, m) * dt
        s.influence += inf
        r.influenceGained += inf

        // ---- Heat ----
        let cover = Economy.cover(s, m)
        let target = Economy.heatTarget(exposure: exposure, cover: cover)
        s.heatTarget = target
        let prevHeat = s.heat
        if target > s.heat {
            s.heat += (target - s.heat) * min(1, dt / 120 * m.heatRise)
        } else {
            let fall = m.heatFall * (s.layLow ? 2 : 1)
            s.heat += (target - s.heat) * min(1, dt / 200 * fall)
        }
        if offline { s.heat = min(s.heat, max(Content.offlineHeatCeiling, prevHeat)) }
        s.heat = min(100, max(0, s.heat))
        s.stats.peakHeat = max(s.stats.peakHeat, s.heat)
        if !s.warned && s.heat >= Content.heatWarning {
            s.warned = true
            s.log(.heatWarning, amount: s.heat)
        }
        if s.warned && s.heat < Content.heatWarning - 5 { s.warned = false }

        // ---- Investigation & raid ----
        if offline {
            // The case file does not move while the player is away.
            if s.investigation != nil { s.investigation?.endsAt += dt }
        } else if let inv = s.investigation {
            if s.heat < m.clearThreshold {
                s.investigation = nil
                s.stats.investigationsSurvived += 1
                s.log(.investigationCleared, ref: inv.district.rawValue)
            } else if s.time >= inv.endsAt {
                raid(&s, district: inv.district, mods: m)
                r.raids += 1
            }
        } else if s.heat >= Content.heatInvestigation && s.campaign.chapter >= 1 {
            let d = mostExposedDistrict(s)
            s.investigation = Investigation(startedAt: s.time, endsAt: s.time + Content.investigationSeconds + m.countdownBonus, district: d)
            s.stats.investigations += 1
            s.log(.investigationStarted, ref: d.rawValue)
        }

        // ---- Rolling rates ----
        let a = min(1, dt / 120)
        s.incomeRate += (revenueTotal / dt - s.incomeRate) * a
        s.cleanRate += (cleanThisStep / dt - s.cleanRate) * a
        s.influenceRateEma += (inf / dt - s.influenceRateEma) * a

        // ---- Events ----
        if !offline && s.campaign.tutorial == .done && s.pendingEvent == nil && s.time >= s.nextEventAt {
            if let e = Events.pickNext(&s) {
                let created = Events.create(&s, e)
                s.pendingEvent = created
                let gap = Events.nextGap(&s)
                s.nextEventAt = s.time + gap
            } else {
                s.nextEventAt = s.time + 60
            }
        }

        Campaign.update(&s)
        Idle.refreshAchievements(&s)
    }

    public static func mostExposedDistrict(_ s: GameState) -> DistrictId {
        let m = Economy.mods(s)
        var best = DistrictId.cellars
        var bestV = -1.0
        for d in DistrictId.allCases {
            guard let ds = s.districts[d], ds.unlocked else { continue }
            var v = 0.0
            for p in ProductId.allCases where ds.route(p) > 0 {
                v += Economy.routeCapacity(s, d, p, m) * Economy.price(s, d, p, m) * Content.product(p).risk * Content.district(d).police
            }
            if v > bestV {
                bestV = v
                best = d
            }
        }
        return best
    }

    /// The police hit the stash and the street crews. Lines, fronts, routes, crew and clean money are untouched,
    /// so a raid is always recoverable.
    public static func raid(_ s: inout GameState, district d: DistrictId, mods m: Mods) {
        let invLoss = 0.5 * m.raidInventoryLoss
        var lostUnits = 0.0
        for p in ProductId.allCases {
            let st = s.stock(p)
            lostUnits += st * invLoss
            s.inventory[p] = st * (1 - invLoss)
        }
        let cashFrac = 0.2 * m.raidCashLoss
        let dirtyLost = s.dirty * cashFrac
        s.dirty -= dirtyLost
        let ctlLoss = 15 * m.raidControlLoss
        let suspendUntil = s.time + Content.raidSuspendSeconds
        s.updateDistrict(d) { ds in
            ds.rival = min(100, ds.rival + ctlLoss)
            ds.suspendedUntil = suspendUntil
        }
        for i in s.crew.indices { s.crew[i].loyalty = max(5, s.crew[i].loyalty - 8) }
        s.heat = 40
        s.investigation = nil
        s.stats.raids += 1
        s.lastRaid = RaidReport(district: d, inventoryLost: lostUnits, dirtyLost: dirtyLost, controlLost: ctlLoss, time: s.time)
        s.raidUnseen = true
        s.log(.raid, ref: d.rawValue, amount: dirtyLost, amount2: lostUnits)
    }

    public static func raid(_ s: inout GameState, district d: DistrictId) {
        raid(&s, district: d, mods: Economy.mods(s))
    }
}
