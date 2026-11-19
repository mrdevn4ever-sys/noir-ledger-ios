import NoirCore
import SwiftUI

/// Shared frame for the sheets: ground, title, a Done button.
struct SheetFrame<Content: View>: View {
    let titleKey: String
    let identifier: String
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
    @Environment(\.l10n) private var t

    init(_ titleKey: String, identifier: String, @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.identifier = identifier
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s4) {
                if let header = Self.header(identifier) {
                    Image(header).resizable().scaledToFill()
                        .frame(height: 150).frame(maxWidth: .infinity).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Color.black.opacity(0.5), lineWidth: 2))
                        .accessibilityHidden(true)
                }
                content
            }
            .padding(Noir.s4)
            .background(alignment: .topLeading) { ScreenMarker(identifier: identifier, title: t(titleKey)) }
        }
        .background { SheetBackdrop() }
        .toggleStyle(ToonToggleStyle())
        .navigationTitle(Text(verbatim: t(titleKey)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Noir.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { dismiss() } label: { Text(verbatim: t("btn_done")) }
                    .accessibilityIdentifier("sheet.done")
            }
        }
    }
}

extension SheetFrame {
    /// The picture on top of a window, where the window has one.
    static func header(_ identifier: String) -> String? {
        switch identifier {
        case "screen.orders": "HeaderOrders"
        case "screen.contacts": "HeaderCustomers"
        case "screen.crew": "HeaderCrew"
        case "screen.challenges": "HeaderChallenges"
        case "screen.shop": "HeaderShop"
        case "screen.rewards": "HeaderRewards"
        case "screen.settings": "HeaderSettings"
        default: nil
        }
    }
}

/// The night wallpaper behind every window.
struct SheetBackdrop: View {
    var body: some View {
        Image("SheetBackdrop").resizable(resizingMode: .tile).ignoresSafeArea().accessibilityHidden(true)
    }
}

// MARK: - Upgrading a station

/// One station: what it does now, what the next levels change in real sales and income, and the price.
struct StationSheet: View {
    let station: Station
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t
    @State private var mode: BuyMode = .one

    var body: some View {
        let s = store.state
        let level = Flow.level(s, station)
        let amount = mode == .max ? max(1, Flow.affordable(s, station)) : mode.rawValue
        let cost = Flow.cost(s, station, amount)
        let preview = Flow.preview(s, station, amount)
        let after = Flow.upgraded(s, station, amount)
        let good = Self.good(station)
        SheetFrame(StationText.id(station).hasPrefix("contact") ? "l4_contact_sheet" : "l4_station_sheet", identifier: "screen.station") {
            StationArt(station: station, state: s, after: after)
            Text(verbatim: StationText.title(station, t)).font(.display(.title2))
            Text(verbatim: t(Self.explainKey(station))).font(.toon(.subheadline)).foregroundStyle(Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            ToonSegments(options: BuyMode.allCases.map { ($0, $0 == .max ? t("buy_max") : t("buy_times", $0.rawValue)) }, selection: $mode)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(verbatim: t("buy_mode")))
                .accessibilityIdentifier("station.mode")
            Panel(.leather) {
                ValueRow(label: t("l4_level_label"), value: "\(level) → \(Flow.level(after, station))")
                ValueRow(label: t("l4_capacity"), value: StationText.capacity(station, s, t) + " → " + StationText.capacity(station, after, t),
                         valueColor: Noir.amber)
                ForEach(good.map { [$0] } ?? s.openGoods, id: \.self) { g in
                    if let before = preview.before.good(g), let next = preview.after.good(g) {
                        ValueRow(label: t("l4_sold") + (good == nil ? " · " + t(GoodText.name(g)) : ""),
                                 value: t.money(before.sold) + " → " + t("l4_per_min_crates", t.money(next.sold)))
                        if good != nil {
                            ValueRow(label: t("l4_shelf_trend"), value: t.money(before.piling) + " → " + t.money(next.piling))
                        }
                    }
                }
                let gain = preview.after.income - preview.before.income
                ValueRow(label: t("l4_income"), value: t("l4_per_min", t.money(preview.before.income)) + " → " + t("l4_per_min", t.money(preview.after.income)),
                         valueColor: gain > 0.0001 ? Noir.amber : Noir.inkSoft)
                    .accessibilityIdentifier("station.income")
            }
            Text(verbatim: Self.verdict(station, preview, good: good, state: s, t))
                .font(.toon(.subheadline, .semibold))
                .foregroundStyle(preview.after.income > preview.before.income + 0.0001 ? Noir.amber : Noir.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("station.verdict")
            if let next = Flow.nextMilestone(level) {
                Label { Text(verbatim: t("l4_milestone_next", next)) } icon: { Image("IconUpgrade").resizable().frame(width: 20, height: 20) }
                    .font(.toon(.footnote)).foregroundStyle(Noir.brass)
            }
            Button {
                store.dispatch(.upgrade(station, mode == .max ? 0 : amount))
            } label: {
                VStack(spacing: 2) {
                    Text(verbatim: t("l4_buy_levels", amount))
                    Text(verbatim: t.money(cost)).font(.toon(.caption, .semibold)).monospacedDigit().opacity(0.85)
                }
            }
            .noirButton(s.cash >= cost ? .go : .secondary)
            .disabled(s.cash < cost || level >= FlowContent.maxLevel)
            .accessibilityIdentifier("station.buy")
        }
    }

    static func good(_ st: Station) -> Good? {
        switch st {
        case .bench(let g), .shelf(let g): g
        case .contact(let id): FlowContent.contact(id)?.good
        case .fleet: nil
        }
    }

    static func explainKey(_ st: Station) -> String {
        switch st {
        case .bench: "l4_explain_bench"
        case .shelf: "l4_explain_shelf"
        case .fleet: "l4_explain_fleet"
        case .contact: "l4_explain_contact"
        }
    }

    /// What buying actually does, in one sentence: more income, or only more stock, or nothing until another station grows.
    static func verdict(_ st: Station, _ p: (before: Forecast, after: Forecast), good: Good?, state: FlowState, _ t: L10n) -> String {
        let gain = p.after.income - p.before.income
        if gain > 0.0001 { return t("l4_verdict_gain", t.money(gain)) }
        if case .shelf = st { return t("l4_verdict_shelf") }
        if let g = good ?? state.openGoods.first, let f = p.after.good(g) {
            switch f.bottleneck {
            case .bench: return t("l4_verdict_needs_bench")
            case .fleet: return t("l4_verdict_needs_fleet")
            case .shelf: return t("l4_verdict_needs_shelf")
            case .demand: return t("l4_verdict_needs_demand")
            case .balanced: return t("l4_verdict_stock")
            }
        }
        return t("l4_verdict_stock")
    }
}

// MARK: - Orders

struct OrdersSheet: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        SheetFrame("l4_orders", identifier: "screen.orders") {
            Text(verbatim: t("l4_orders_b")).font(.toon(.subheadline)).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
            StatusChip(text: t("l4_orders_slots", s.orders.count, Flow.orderSlots(s)), symbol: "tray.full.fill")
            ForEach(Array(s.orders.enumerated()), id: \.element.id) { i, o in
                ActiveOrderCard(order: o, state: s).accessibilityIdentifier("order.active.\(i)")
            }
            if s.offers.isEmpty {
                Text(verbatim: t("l4_offers_none", t.duration(max(0, s.nextOfferAt - s.time)))).font(.toon(.subheadline)).foregroundStyle(Noir.inkSoft)
            }
            ForEach(Array(s.offers.enumerated()), id: \.element.id) { i, offer in
                OrderOfferCard(offer: offer, index: i, state: s)
            }
            Panel(.anthracite) {
                Toggle(isOn: Binding(get: { store.state.ordersFirst }, set: { store.dispatch(.setOrdersFirst($0)) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: t("l4_orders_first")).font(.toon(.subheadline, .semibold))
                        Text(verbatim: t("l4_orders_first_b")).font(.toon(.caption)).foregroundStyle(Noir.inkSoft)
                    }
                }
                .tint(Noir.amber)
                .accessibilityIdentifier("orders.first")
                if s.has(.okafor) {
                    Toggle(isOn: Binding(get: { store.state.autoQuiet }, set: { store.dispatch(.setAutoQuiet($0)) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: t("l4_auto_quiet")).font(.toon(.subheadline, .semibold))
                            Text(verbatim: t("l4_auto_quiet_b")).font(.toon(.caption)).foregroundStyle(Noir.inkSoft)
                        }
                    }
                    .tint(Noir.amber)
                    .accessibilityIdentifier("orders.autoQuiet")
                }
            }
        }
    }
}

/// An offer with everything that matters before saying yes: pay, the deadline, the fleet time it needs, what is on
/// the shelf, and what the attention does to its quarter.
struct OrderOfferCard: View {
    let offer: OrderOffer
    let index: Int
    let state: FlowState
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let att = Flow.attentionPreview(state, offer)
        let tierBefore = Flow.tier(att.before)
        let tierAfter = Flow.tier(att.after)
        let loud = offer.attention > 0
        let slotsFull = state.orders.count >= Flow.orderSlots(state) && offer.kind != .finale
        Panel(loud ? .leather : .paper) {
            HStack(spacing: Noir.s2) {
                Image(SceneArt.order(offer.kind)).resizable().frame(width: 44, height: 44).accessibilityHidden(true)
                StatusChip(text: t(OrderText.kind(offer.kind)), symbol: loud ? "exclamationmark.bubble.fill" : "hand.thumbsup.fill",
                           danger: tierAfter >= 2)
                Spacer()
                Text(verbatim: "+" + t.money(offer.pay)).font(.toon(.title3, .bold)).monospacedDigit()
                    .foregroundStyle(loud ? Noir.amber : Noir.paperInk)
                    .accessibilityIdentifier("offer.\(index).pay")
            }
            Text(verbatim: OrderText.items(offer, t)).font(.toon(.headline))
            if let c = offer.contact { Text(verbatim: t(ContactText.name(c))).font(.toon(.subheadline)) }
            ValueRow(label: t("l4_offer_window"), value: t.duration(offer.window))
            ValueRow(label: t("l4_offer_fleet"), value: t.duration(Flow.deliverySeconds(state, offer)))
            ValueRow(label: t("l4_offer_stock"), value: Good.allCases.compactMap { g in
                offer.items[g] != nil ? t.money(state.workshop(g)?.stock ?? 0) : nil
            }.joined(separator: " · "))
            HStack(spacing: Noir.s2) {
                Image(SceneArt.attention(tier: tierAfter, paused: false)).resizable().frame(width: 26, height: 26).accessibilityHidden(true)
                Text(verbatim: t("l4_offer_attention", t(QuarterText.name(att.quarter)), t.decimal(att.before, digits: 0), t.decimal(att.after, digits: 0)))
                    .font(.toon(.subheadline, .semibold)).monospacedDigit()
                    .foregroundStyle(tierAfter >= 2 ? Noir.danger : (loud ? Noir.amber : Noir.paperInk))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("offer.\(index).attention")
            }
            if tierAfter > tierBefore {
                Label { Text(verbatim: t("l4_offer_tier_up", t("l4_tier_\(tierAfter)")) + " " + t("l4_tier_effect_\(tierAfter)")) } icon: {
                    Image("IconWarning").resizable().frame(width: 18, height: 18)
                }
                .font(.toon(.caption, .semibold)).foregroundStyle(Noir.danger)
                .fixedSize(horizontal: false, vertical: true)
            }
            Text(verbatim: t(offer.kind == .trust ? "l4_offer_fail_trust" : "l4_offer_fail")).font(.toon(.caption))
                .foregroundStyle(loud ? Noir.inkSoft : Noir.paperInk.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Noir.s2) {
                Button { store.dispatch(.decline(offer.id)) } label: { Text(verbatim: t("l4_decline")) }
                    .noirButton(.secondary)
                    .accessibilityIdentifier("offer.\(index).decline")
                Button { store.dispatch(.accept(offer.id)) } label: { Text(verbatim: t("l4_accept")) }
                    .noirButton(.primary)
                    .disabled(slotsFull)
                    .accessibilityIdentifier("offer.\(index).accept")
            }
            if slotsFull {
                Text(verbatim: t("l4_slots_full")).font(.toon(.caption)).foregroundStyle(loud ? Noir.inkSoft : Noir.paperInk.opacity(0.7))
            }
        }
    }
}

struct ActiveOrderCard: View {
    let order: ActiveOrder
    let state: FlowState
    @Environment(\.l10n) private var t

    var body: some View {
        let left = max(0, order.deadline - state.time)
        Panel(.anthracite) {
            HStack(spacing: Noir.s2) {
                Image(SceneArt.order(order.offer.kind)).resizable().frame(width: 34, height: 34).accessibilityHidden(true)
                StatusChip(text: t(OrderText.kind(order.offer.kind)), symbol: "shippingbox.fill")
                Spacer()
                Text(verbatim: "+" + t.money(order.offer.pay)).font(.toon(.headline)).monospacedDigit().foregroundStyle(Noir.amber)
            }
            Text(verbatim: OrderText.items(order.offer, t)).font(.toon(.subheadline, .semibold))
            Meter(fraction: order.progress, tint: Noir.amber, height: 6)
            Text(verbatim: t("l4_order_progress", t.percent(order.progress), t.duration(left))).font(.toon(.caption)).monospacedDigit()
                .foregroundStyle(left < 60 ? Noir.danger : Noir.inkSoft)
        }
    }
}

/// The picture on top of an upgrade: the floor as it looks now (and the next look when this upgrade reaches it), the
/// vehicle, the shelf or the customer.
struct StationArt: View {
    let station: Station
    let state: FlowState
    let after: FlowState

    var body: some View {
        Group {
            switch station {
            case .bench(let g):
                let now = Flow.level(state, station)
                let next = Flow.level(after, station)
                ZStack(alignment: .bottomTrailing) {
                    Image(SceneArt.floor(g, level: now)).resizable().scaledToFill()
                    if SceneArt.stage(level: next) > SceneArt.stage(level: now) {
                        Image(SceneArt.floor(g, level: next)).resizable().scaledToFill()
                            .frame(width: 120, height: 60).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Toon.window, lineWidth: 2))
                            .overlay(alignment: .topLeading) {
                                Image("ArrowUp").resizable().frame(width: 22, height: 22).offset(x: -8, y: -8)
                            }
                            .padding(Noir.s2)
                    }
                }
            case .fleet:
                ZStack(alignment: .bottom) {
                    Image("SkyNight").resizable().scaledToFill()
                    Image("Street").resizable().frame(height: 40)
                    VehicleSprite(vehicle: SceneArt.vehicle(fleetLevel: Flow.level(after, station)), wheelAngle: 0, scale: 1)
                        .padding(.bottom, 6)
                }
            case .shelf(let g):
                ZStack {
                    Image(SceneArt.floor(g, level: state.workshop(g)?.bench ?? 1)).resizable().scaledToFill().blur(radius: 2)
                    Image("ShelfFrame").resizable().scaledToFit().frame(height: 110)
                    Image(SceneArt.crate(g)).resizable().scaledToFit().frame(height: 34).offset(y: 30)
                }
            case .contact(let id):
                Image(SceneArt.contact(id)).resizable().scaledToFill()
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Crew

struct CrewSheet: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        SheetFrame("l4_crew", identifier: "screen.crew") {
            Text(verbatim: t("l4_crew_b")).font(.toon(.subheadline)).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
            ForEach(s.openGoods, id: \.self) { g in
                let def = FlowContent.good(g)
                CrewCard(crew: def.lead, role: t("l4_role_lead", t(GoodText.name(g))), effect: t("l4_lead_b"),
                         hired: s.workshop(g)?.lead == true, cost: def.leadCost, hire: .hireLead(g),
                         ability: s.chapter >= FlowContent.abilityChapter ? (Ability.doubleShift, Optional(g)) : nil)
            }
            CrewCard(crew: FlowContent.dispatcher, role: t("l4_role_dispatcher"), effect: t("l4_dispatcher_b"),
                     hired: s.dispatcher, cost: FlowContent.dispatcherCost, hire: .hireDispatcher,
                     ability: s.chapter >= FlowContent.abilityChapter ? (Ability.rushRun, Good?.none) : nil)
            if !s.specialists.isEmpty {
                Text(verbatim: t("l4_specialists")).font(.toon(.headline)).padding(.top, Noir.s2)
            }
            ForEach(s.specialists, id: \.self) { sp in
                let ability: (Ability, Good?)? = sp == .okafor ? (Ability.newWindow, Good?.none)
                    : (sp == .kraus ? (Ability.quietWord, Good?.none) : nil)
                CrewCard(crew: SpecialistText.crew(sp), role: t(SpecialistText.role(sp)), effect: t(SpecialistText.effect(sp)),
                         hired: true, cost: 0, hire: nil, ability: ability)
            }
            let upcoming = FlowContent.chapters.filter { $0.number >= s.chapter }.compactMap(\.joins)
            if let next = upcoming.first {
                Text(verbatim: t("l4_crew_next", Content.crewDef(SpecialistText.crew(next))?.name ?? "")).font(.toon(.footnote))
                    .foregroundStyle(Noir.inkSoft)
            }
        }
    }
}

struct CrewCard: View {
    let crew: String
    let role: String
    let effect: String
    let hired: Bool
    let cost: Double
    let hire: FlowAction?
    let ability: (Ability, Good?)?
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        Panel(.leather) {
            HStack(spacing: Noir.s3) {
                Portrait(crewId: crew, size: 56).clipShape(Circle()).opacity(hired ? 1 : 0.6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: Content.crewDef(crew)?.name ?? "").font(.toon(.headline))
                    Text(verbatim: role).font(.toon(.caption, .bold)).foregroundStyle(Noir.amber)
                    Text(verbatim: effect).font(.toon(.caption)).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !hired, let hire {
                    Button { store.dispatch(hire) } label: {
                        VStack(spacing: 2) {
                            Text(verbatim: t("l4_hire"))
                            Text(verbatim: t.money(cost)).font(.toon(.caption, .semibold)).monospacedDigit().opacity(0.85)
                        }
                    }
                    .noirButton(s.cash >= cost ? .go : .secondary, fullWidth: false)
                    .disabled(s.cash < cost)
                    .accessibilityIdentifier("crew.\(crew).hire")
                }
            }
            if hired, let pick = ability {
                let a = pick.0
                let g = pick.1
                let st = s.ability(a)
                Button { store.dispatch(.use(a, g)) } label: {
                    HStack(spacing: Noir.s2) {
                    Image(SceneArt.ability(a)).resizable().frame(width: 36, height: 36).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: t(AbilityText.name(a))).font(.toon(.subheadline, .bold))
                        Text(verbatim: st.active > 0 ? t("l4_ability_running", t.duration(st.active))
                             : (st.cooldown > 0 ? t("l4_ability_wait", t.duration(st.cooldown)) : t(AbilityText.desc(a))))
                            .font(.toon(.caption)).monospacedDigit().opacity(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .noirButton(st.cooldown <= 0 ? .primary : .secondary)
                .disabled(st.cooldown > 0)
                .accessibilityIdentifier("ability.\(a.rawValue)")
            }
        }
    }
}

// MARK: - City

struct CitySheet: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        SheetFrame("l4_city", identifier: "screen.city") {
            Image("CityMap").resizable().scaledToFill()
                .frame(height: 200).frame(maxWidth: .infinity).clipped()
                .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                .accessibilityHidden(true)
            Text(verbatim: t("l4_city_b")).font(.toon(.subheadline)).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
            ForEach(Quarter.allCases, id: \.self) { q in
                QuarterCard(quarter: q, state: s)
            }
            if s.openGoods.count > 1 {
                PriorityPanel(state: s)
            }
        }
    }
}

struct QuarterCard: View {
    let quarter: Quarter
    let state: FlowState
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let open = state.quarters[quarter] != nil
        let qs = state.quarter(quarter)
        VStack(alignment: .leading, spacing: 0) {
            Image(SceneArt.quarter(quarter, wide: true))
                .resizable()
                .scaledToFill()
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .clipped()
                .saturation(open ? 1 : 0.1)
                .overlay(alignment: .bottomLeading) {
                    Text(verbatim: t(QuarterText.name(quarter))).font(.toon(.headline)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.black.opacity(0.6), in: Capsule())
                        .padding(Noir.s2)
                }
                .overlay(alignment: .topTrailing) {
                    if !open { Image("IconLock").resizable().frame(width: 34, height: 34).padding(Noir.s2) }
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Noir.s2) {
                Text(verbatim: t(QuarterText.desc(quarter))).font(.toon(.caption)).foregroundStyle(Noir.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if open {
                    AttentionChip(attention: qs.attention, paused: qs.paused)
                    Meter(fraction: qs.attention / 100, tint: Flow.tier(qs.attention) >= 2 ? Noir.danger : Noir.amber, height: 5)
                    Text(verbatim: t("l4_tier_effect_\(Flow.tier(qs.attention))")).font(.toon(.caption2)).foregroundStyle(Noir.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Toggle(isOn: Binding(get: { store.state.quarter(quarter).paused }, set: { store.dispatch(.pause(quarter, $0)) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: t("l4_pause")).font(.toon(.subheadline, .semibold))
                            Text(verbatim: t("l4_pause_b")).font(.toon(.caption)).foregroundStyle(Noir.inkSoft)
                        }
                    }
                    .tint(Noir.amber)
                    .accessibilityIdentifier("quarter.\(quarter.rawValue).pause")
                } else {
                    let chapter = FlowContent.chapters.first { $0.quarter == quarter }?.number ?? 1
                    Label { Text(verbatim: t("l4_quarter_locked", chapter)) } icon: { Image("IconLock").resizable().frame(width: 18, height: 18) }
                        .font(.toon(.caption, .semibold)).foregroundStyle(Noir.inkSoft)
                }
            }
            .padding(Noir.s3)
        }
        .foregroundStyle(Noir.ink)
        .background(Noir.raised)
        .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.hairline, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("quarter.\(quarter.rawValue)")
    }
}

/// The order goods share the fleet in, after every good's base share.
struct PriorityPanel: View {
    let state: FlowState
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let order = state.priority.filter { state.isOpen($0) }
        let f = Flow.forecast(state)
        Panel(.leather) {
            Text(verbatim: t("l4_priority")).font(.toon(.headline))
            Text(verbatim: t("l4_priority_b", t.percent(FlowContent.baseShare))).font(.toon(.caption)).foregroundStyle(Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(order.enumerated()), id: \.element) { i, g in
                HStack(spacing: Noir.s2) {
                    Text(verbatim: "\(i + 1).").font(.toon(.headline)).monospacedDigit()
                    Mark(Glyph.product(g.product), size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: t(GoodText.name(g))).font(.toon(.subheadline, .semibold))
                        Text(verbatim: t("l4_priority_line", t.money(f.good(g)?.carried ?? 0), t.money(f.good(g)?.demand ?? 0)))
                            .font(.toon(.caption)).monospacedDigit().foregroundStyle(Noir.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button { move(g, up: true) } label: { Image(systemName: "arrow.up").frame(width: Noir.minTarget, height: Noir.minTarget) }
                        .disabled(i == 0)
                        .accessibilityLabel(Text(verbatim: t("l4_priority_up")))
                        .accessibilityIdentifier("priority.\(g.rawValue).up")
                }
            }
        }
    }

    private func move(_ g: Good, up: Bool) {
        var all = state.priority
        guard let i = all.firstIndex(of: g) else { return }
        let open = all.enumerated().filter { state.isOpen($0.element) }.map(\.offset)
        guard let pos = open.firstIndex(of: i), pos > 0 else { return }
        all.swapAt(i, open[pos - 1])
        store.dispatch(.setPriority(all))
    }
}

// MARK: - The ledger book

struct BookSheet: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        let f = store.forecast
        SheetFrame("l4_book", identifier: "screen.book") {
            Image("LedgerCover").resizable().scaledToFill().frame(height: 140).frame(maxWidth: .infinity).clipped()
                .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                .accessibilityHidden(true)
            Panel(.paper) {
                ValueRow(label: t("l4_book_earned"), value: t.money(s.earned))
                ValueRow(label: t("l4_book_measured"), value: t("l4_per_min", t.money(store.measuredIncome)))
                ValueRow(label: t("l4_book_forecast"), value: t("l4_per_min", t.money(f.income)))
                ValueRow(label: t("l4_book_deliveries"), value: t.decimal(Double(s.counters.deliveries), digits: 0))
                ValueRow(label: t("l4_book_orders"), value: "\(s.counters.orders) / \(s.counters.failed)")
            }
            Text(verbatim: t("l4_book_entries")).font(.toon(.headline))
            if s.ledger.isEmpty {
                Text(verbatim: t("l4_book_empty")).font(.toon(.subheadline)).foregroundStyle(Noir.inkSoft)
            }
            VStack(spacing: 0) {
                ForEach(s.ledger.reversed()) { e in
                    HStack(alignment: .firstTextBaseline, spacing: Noir.s2) {
                        Text(verbatim: t.duration(max(0, s.time - e.time))).font(.toon(.caption2)).monospacedDigit()
                            .foregroundStyle(Noir.paperInk.opacity(0.6)).frame(width: 64, alignment: .leading)
                        Text(verbatim: Self.line(e, t)).font(.toon(.subheadline))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: (e.kind == .orderFailed ? "" : "+") + t.money(e.amount))
                            .font(.toon(.subheadline, .bold)).monospacedDigit()
                            .foregroundStyle(e.kind == .orderFailed ? Noir.paperRed : Noir.paperInk)
                    }
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) { Rectangle().fill(Noir.paperEdge.opacity(0.4)).frame(height: 1) }
                }
            }
            .padding(Noir.s3)
            .foregroundStyle(Noir.paperInk)
            .background(Noir.paper, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
            .accessibilityIdentifier("book.entries")
        }
    }

    static func line(_ e: LedgerEntry, _ t: L10n) -> String {
        switch e.kind {
        case .delivery:
            t("l4_book_delivery", t(ContactText.name(e.subject)), t.money(e.crates), e.good.map { t(GoodText.name($0)) } ?? "")
        case .order:
            t("l4_book_order", t(OrderText.kind(OrderKind(rawValue: e.subject) ?? .quiet)), t.money(e.crates))
        case .orderFailed:
            t("l4_book_failed", t(OrderText.kind(OrderKind(rawValue: e.subject) ?? .quiet)), t.money(e.crates))
        case .away:
            t("l4_book_away")
        }
    }
}
