import NoirCore
import SwiftUI

// MARK: - Decision

/// One authored decision: the situation, and every choice with its cost, requirement, probabilities and effects.
struct EventSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    var body: some View {
        NavigationStack {
            ScrollView {
                if let p = store.state.pendingEvent {
                    VStack(alignment: .leading, spacing: Noir.s4) {
                        Text(verbatim: t(Labels.eventTitle(p.event))).font(.display(.title2)).foregroundStyle(Noir.ink)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("event.title")
                        Text(verbatim: situation(p)).font(.body).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
                        ForEach(Events.choices(p)) { choice in
                            ChoiceCard(event: p.event, district: p.district, choice: choice)
                        }
                    }
                    .padding(Noir.s4)
                }
            }
            .background(Noir.ground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { router.eventOpen = false } label: { Text(verbatim: t("event_later")) }
                        .accessibilityIdentifier("event.later")
                }
            }
            .toolbarBackground(Noir.ground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDragIndicator(.visible)
    }

    private func situation(_ p: PendingEvent) -> String {
        let key = Labels.eventBody(p.event)
        if let d = p.district, p.event == .rivalTruce || p.event == .sweepRumor {
            return t(key, t(Labels.district(d)))
        }
        return t(key)
    }
}

private struct ChoiceCard: View {
    let event: EventId
    let district: DistrictId?
    let choice: EventChoice
    @Environment(GameStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        let available = choice.available(s)
        Panel(.paper) {
            Text(verbatim: t(Labels.eventChoice(event, choice.key))).font(.headline)
            if let role = choice.requiresRole {
                RequirementLine(text: t("event_requires", t(Labels.role(role))), met: s.crewIn(role) != nil)
            }
            if !choice.cost.isFree {
                CostLine(cost: choice.cost, affordable: choice.cost.affordable(s))
            }
            ForEach(choice.outcomes, id: \.self) { outcome in
                OutcomeLine(outcome: outcome, showChance: choice.outcomes.count > 1)
            }
            Button {
                if store.dispatch(.resolveEvent(choice.key)) { router.eventOpen = false }
            } label: {
                Text(verbatim: t("event_choose"))
            }
            .noirButton(.primary)
            .disabled(!available)
            .accessibilityIdentifier("event.choice.\(choice.key)")
        }
    }
}

private struct OutcomeLine: View {
    let outcome: Outcome
    let showChance: Bool
    @Environment(\.l10n) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if showChance {
                Text(verbatim: t("event_chance", t.percent(outcome.chance))).font(.caption.weight(.semibold)).foregroundStyle(Noir.paperInkSoft)
            }
            ForEach(EffectText.lines(outcome.effects, t), id: \.self) { line in
                Label { Text(verbatim: line.text) } icon: { Image(systemName: line.symbol) }
                    .font(.subheadline)
                    .foregroundStyle(line.bad ? Noir.paperRed : Noir.paperInk)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct EffectLine: Hashable {
    let text: String
    let symbol: String
    let bad: Bool
}

enum EffectText {
    static func signed(_ v: Double, _ t: L10n, digits: Int = 0) -> String {
        (v >= 0 ? "+" : "−") + t.decimal(abs(v), digits: digits)
    }

    static func lines(_ e: Effects, _ t: L10n) -> [EffectLine] {
        if e.isEmpty { return [EffectLine(text: t("eff_nothing"), symbol: "minus", bad: false)] }
        var out: [EffectLine] = []
        if e.dirty != 0 { out.append(EffectLine(text: t("eff_dirty", signed(e.dirty, t)), symbol: "banknote", bad: e.dirty < 0)) }
        if e.clean != 0 { out.append(EffectLine(text: t("eff_clean", signed(e.clean, t)), symbol: "building.columns", bad: e.clean < 0)) }
        if e.influence != 0 { out.append(EffectLine(text: t("eff_influence", signed(e.influence, t)), symbol: "person.2", bad: e.influence < 0)) }
        if e.heat != 0 { out.append(EffectLine(text: t("eff_heat", signed(e.heat, t)), symbol: "flame", bad: e.heat > 0)) }
        if e.loyalty != 0 { out.append(EffectLine(text: t("eff_loyalty", signed(e.loyalty, t)), symbol: "heart", bad: e.loyalty < 0)) }
        if e.control != 0 { out.append(EffectLine(text: t("eff_control", signed(e.control, t)), symbol: "flag", bad: e.control < 0)) }
        if e.suspendSeconds > 0 { out.append(EffectLine(text: t("eff_suspend", t.duration(e.suspendSeconds)), symbol: "xmark.octagon", bad: true)) }
        if e.stockLoss > 0 { out.append(EffectLine(text: t("eff_stock", t.percent(e.stockLoss)), symbol: "archivebox", bad: true)) }
        for m in e.mods {
            let pct = t("percent", signed((m.value - 1) * 100, t))
            let time = t.duration(m.seconds)
            switch m.kind {
            case .price: out.append(EffectLine(text: t("eff_mod_price", pct, time), symbol: "tag", bad: m.value < 1))
            case .demand: out.append(EffectLine(text: t("eff_mod_demand", pct, time), symbol: "person.3", bad: m.value < 1))
            case .unitCost: out.append(EffectLine(text: t("eff_mod_cost", pct, time), symbol: "cart", bad: m.value > 1))
            case .productionSpeed:
                if m.value <= 0 {
                    out.append(EffectLine(text: t("eff_mod_halt", time), symbol: "pause.circle", bad: true))
                } else {
                    out.append(EffectLine(text: t("eff_mod_speed", pct, time), symbol: "gearshape.2", bad: m.value < 1))
                }
            case .routeCapacity: out.append(EffectLine(text: t("eff_mod_route", pct, time), symbol: "point.topleft.down.to.point.bottomright.curvepath", bad: m.value < 1))
            case .exposure: out.append(EffectLine(text: t("eff_mod_exposure", pct, time), symbol: "eye", bad: m.value > 1))
            }
        }
        return out
    }
}

// MARK: - Raid

struct RaidSheet: View {
    let report: RaidReport
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s4) {
                Label { Text(verbatim: t("raid_title", t(Labels.district(report.district)))).font(.display(.title2)) } icon: {
                    Mark(Glyph.raid, size: 28)
                }
                .foregroundStyle(Noir.danger)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("raid.title")
                Text(verbatim: t("raid_body")).font(.body).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
                Panel(.paper) {
                    ValueRow(label: t("raid_lost_dirty"), value: "−" + t.money(report.dirtyLost), symbol: "banknote", valueColor: Noir.paperRed)
                    ValueRow(label: t("raid_lost_stock"), value: "−" + t("units_val", t.money(report.inventoryLost)), symbol: "archivebox", valueColor: Noir.paperRed)
                    ValueRow(label: t("raid_control"), value: "−" + t.points(report.controlLost), symbol: "flag", valueColor: Noir.paperRed)
                }
                Text(verbatim: t("raid_suspended", t(Labels.district(report.district)), t.duration(Content.raidSuspendSeconds)))
                    .font(.subheadline).foregroundStyle(Noir.ink)
                Label { Text(verbatim: t("raid_recover")) } icon: { Image(systemName: "arrow.uturn.up") }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Noir.amber)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("raid.recover")
                Button { store.dispatch(.ackRaid) } label: { Text(verbatim: t("raid_ack")) }
                    .noirButton(.primary)
                    .accessibilityIdentifier("raid.ack")
            }
            .padding(Noir.s4)
        }
        .background(Noir.ground)
        .interactiveDismissDisabled()
    }
}

// MARK: - Return summary

struct OfflineSheet: View {
    let report: OfflineReport
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s4) {
                Text(verbatim: t("offline_title")).font(.display(.title2)).foregroundStyle(Noir.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("offline.title")
                if report.clockMovedBack {
                    Label { Text(verbatim: t("offline_clock")) } icon: { Mark(Glyph.offlineReturn) }
                        .font(.body).foregroundStyle(Noir.ink)
                } else {
                    Text(verbatim: t("offline_away", t.duration(Double(report.awaySeconds)), t.duration(Double(report.creditedSeconds))))
                        .font(.subheadline).foregroundStyle(Noir.inkSoft)
                    if report.capped {
                        Label { Text(verbatim: t("offline_capped")) } icon: { Image(systemName: "hourglass.bottomhalf.filled") }
                            .font(.subheadline).foregroundStyle(Noir.amber)
                    }
                    Panel(.paper) {
                        ValueRow(label: t("offline_produced"), value: t("units_val", t.money(report.produced)), symbol: "gearshape.2")
                        ValueRow(label: t("offline_sold"), value: t("units_val", t.money(report.sold)), symbol: "cart")
                        ValueRow(label: t("offline_earned"), value: "+" + t.money(report.dirtyEarned), symbol: "banknote")
                        ValueRow(label: t("offline_laundered"), value: "+" + t.money(report.cleanGained), symbol: "building.columns")
                        ValueRow(label: t("offline_costs"), value: "−" + t.money(report.wagesPaid + report.productionSpent), symbol: "person.2")
                        ValueRow(label: t("offline_influence"), value: "+" + t.decimal(report.influenceGained, digits: 1), symbol: "person.3")
                        ValueRow(label: t("offline_heat"), value: t("offline_heat_val", t.decimal(report.heatBefore, digits: 0), t.decimal(report.heatAfter, digits: 0)), symbol: "flame")
                    }
                    Text(verbatim: t("offline_rules")).font(.footnote).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                Button { store.offlineReport = nil } label: { Text(verbatim: t("offline_ok")) }
                    .noirButton(.primary)
                    .accessibilityIdentifier("offline.ok")
            }
            .padding(Noir.s4)
        }
        .background(Noir.ground)
    }
}
