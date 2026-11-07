import NoirCore
import SwiftUI

/// The night city: the pinned map and the five districts.
struct CityView: View {
    @Environment(GameStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        TabScreen("nav_city", identifier: "screen.city") {
            CityMap(state: s) { d in router.cityPath.append(.district(d)) }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(verbatim: t("city_map")))
            ForEach(DistrictId.allCases, id: \.self) { d in
                DistrictRow(district: d, state: s)
            }
        }
    }
}

private struct DistrictRow: View {
    let district: DistrictId
    let state: GameState
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    var body: some View {
        let ds = state.district(district)
        let def = Content.district(district)
        Button {
            router.cityPath.append(.district(district))
        } label: {
            VStack(alignment: .leading, spacing: 0) {
            DistrictArt(district: district, height: 72)
                .overlay(alignment: .topTrailing) {
                    if !ds.unlocked {
                        Image(systemName: "lock.fill").padding(Noir.s2).foregroundStyle(Noir.inkSoft)
                    }
                }
            HStack(alignment: .top, spacing: Noir.s3) {
                VStack(alignment: .leading, spacing: Noir.s1) {
                    Text(verbatim: t(Labels.district(district))).font(.headline).foregroundStyle(Noir.ink)
                    Text(verbatim: t(Labels.districtDesc(district))).font(.subheadline).foregroundStyle(Noir.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if ds.unlocked {
                        HStack(spacing: Noir.s2) {
                            Meter(fraction: ds.control / 100, tint: Noir.amber, height: 4).frame(maxWidth: 120)
                            Text(verbatim: "\(t("district_control")) \(t.points(ds.control))")
                                .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(Noir.inkSoft)
                        }
                        if state.investigation?.district == district {
                            StatusChip(text: t("heat_status_investigation"), symbol: "exclamationmark.triangle.fill", danger: true)
                        } else if ds.suspendedUntil > state.time {
                            StatusChip(text: t("district_suspended", t.duration(ds.suspendedUntil - state.time)), symbol: "xmark.octagon", danger: true)
                        }
                    } else {
                        StatusChip(text: lockText(def), symbol: "lock")
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Noir.inkMuted).accessibilityHidden(true)
            }
            .padding(Noir.s4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Noir.night, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.nightEdge, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableRowStyle())
        .accessibilityIdentifier("district.\(district.rawValue)")
    }

    private func lockText(_ def: DistrictDef) -> String {
        if state.campaign.chapter < def.unlockChapter { return t("locked_chapter", def.unlockChapter) }
        return t("district_locked")
    }
}

/// Press feedback for whole-row buttons: a quick dim (rows never scale, so the list never jitters).
struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// One district: its character, control, the move-in decision, routes per product and pushing the rivals.
struct DistrictView: View {
    let district: DistrictId
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        let ds = s.district(district)
        let m = Economy.mods(s)
        DetailScreen(t(Labels.district(district)), identifier: "screen.district.\(district.rawValue)") {
            DistrictArt(district: district, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.nightEdge, lineWidth: 1))
                .accessibilityIdentifier("district.art")
            Panel(.night) {
                Text(verbatim: t(Labels.district(district))).font(.display(.title3))
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: t(Labels.districtDesc(district))).font(.subheadline).foregroundStyle(Noir.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Label { Text(verbatim: t(Labels.districtSpecial(district))) } icon: { Image(systemName: "star") }
                    .font(.subheadline)
                    .foregroundStyle(Noir.ink)
                PanelDivider()
                ValueRow(label: t("district_control"), value: t.points(ds.control), symbol: "flag")
                ValueRow(label: t("district_rivals"), value: t.points(ds.rival), symbol: "person.2.slash")
                ValueRow(label: t("district_police"), value: t("police_value", t.decimal(Content.district(district).police, digits: 1)), mark: Glyph.investigation)
                if ds.unlocked {
                    ValueRow(label: t("district_influence_label"),
                             value: t.perMinute(Content.district(district).influenceRate * ds.control / 100 * m.influence),
                             symbol: "person.2")
                }
                ValueRow(label: t("city_front_label"), value: t(Labels.front(Content.district(district).front)), mark: Glyph.front(Content.district(district).front))
                if ds.suspendedUntil > s.time {
                    StatusChip(text: t("district_suspended", t.duration(ds.suspendedUntil - s.time)), symbol: "xmark.octagon", danger: true)
                }
            }
            if ds.unlocked {
                SectionHeading(title: t("routes_title"))
                ForEach(ProductId.allCases, id: \.self) { p in
                    RouteRow(district: district, product: p, state: s, mods: m)
                }
                TurfPanel(district: district, state: s, mods: m)
            } else {
                UnlockPanel(district: district, state: s, mods: m)
            }
        }
    }
}

private struct UnlockPanel: View {
    let district: DistrictId
    let state: GameState
    let mods: Mods
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let def = Content.district(district)
        let cost = Economy.districtUnlockCost(state, district, mods)
        let chapterOK = state.campaign.chapter >= def.unlockChapter
        let influenceOK = state.influence >= def.unlockInfluence
        Panel(.anthracite) {
            Text(verbatim: t("district_unlock")).font(.headline)
            Text(verbatim: t("district_needs", def.unlockChapter, t.money(def.unlockInfluence)))
                .font(.subheadline).foregroundStyle(Noir.inkSoft)
            RequirementLine(text: t("chapter_label", def.unlockChapter), met: chapterOK)
            if def.unlockInfluence > 0 {
                RequirementLine(text: t("req_influence", t.money(def.unlockInfluence)), met: influenceOK)
            }
            UpgradeButton(title: t("district_unlock"), cost: cost, affordable: chapterOK && influenceOK && cost.affordable(state), primary: true,
                          identifier: "district.\(district.rawValue).unlock") {
                store.dispatch(.unlockDistrict(district))
            }
        }
    }
}

struct RequirementLine: View {
    let text: String
    let met: Bool
    @Environment(\.noirSurface) private var surface
    @Environment(\.l10n) private var t

    var body: some View {
        Label { Text(verbatim: text) } icon: { Image(systemName: met ? "checkmark.circle.fill" : "circle") }
            .font(.subheadline)
            .foregroundStyle(met ? surface.ink : surface.inkSoft)
            .accessibilityValue(Text(verbatim: met ? t("a11y_done") : t("a11y_open")))
    }
}

private struct RouteRow: View {
    let district: DistrictId
    let product: ProductId
    let state: GameState
    let mods: Mods
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let ds = state.district(district)
        let level = ds.route(product)
        let owned = state.line(product).owned
        Panel(.night) {
            HStack {
                Label { Text(verbatim: t(Labels.product(product))).font(.headline) } icon: { Mark(Glyph.product(product), size: 28) }
                Spacer()
                Text(verbatim: t("level", level, Content.maxRouteLevel)).font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(Noir.inkSoft)
            }
            if !owned {
                StatusChip(text: t("route_needs_line", t(Labels.product(product))), symbol: "lock")
            } else {
                let sales = Economy.desiredSales(state, district, product, mods)
                let demand = Economy.demand(state, district, product)
                if level > 0 {
                    Text(verbatim: t("route_flow", t.decimal(sales * 60, digits: 1), t.decimal(demand * 60, digits: 1)))
                        .font(.subheadline).monospacedDigit().foregroundStyle(Noir.inkSoft)
                }
                Text(verbatim: t("route_price", t.money(Economy.price(state, district, product, mods))))
                    .font(.subheadline).monospacedDigit().foregroundStyle(Noir.inkSoft)
                if level < Content.maxRouteLevel {
                    let free = state.campaign.tutorial != .done && level == 0
                    let cost = free ? Cost() : Cost(dirty: Content.routeCost(district, product, currentLevel: level))
                    if free {
                        Text(verbatim: t("route_free")).font(.footnote.weight(.semibold)).foregroundStyle(Noir.amber)
                    }
                    UpgradeButton(title: t(level == 0 ? "route_open" : "route_expand"), cost: cost, affordable: cost.affordable(state),
                                  primary: level == 0, identifier: "route.\(district.rawValue).\(product.rawValue)") {
                        store.dispatch(.upgradeRoute(district, product))
                    }
                } else {
                    StatusChip(text: t("max"), symbol: "checkmark.seal")
                }
            }
        }
    }
}

private struct TurfPanel: View {
    let district: DistrictId
    let state: GameState
    let mods: Mods
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let ds = state.district(district)
        let cost = Economy.turfCost(state, district)
        Panel(.anthracite) {
            Text(verbatim: t("turf_title")).font(.headline)
            Text(verbatim: t("turf_body", t.decimal(Economy.turfGain(state, district, mods), digits: 1),
                             t.decimal(Economy.turfHeat(district) * mods.allExposure, digits: 1)))
                .font(.subheadline).foregroundStyle(Noir.inkSoft)
            if ds.rival <= 0 {
                StatusChip(text: t("turf_done"), symbol: "checkmark.seal")
            } else if ds.turfReadyAt > state.time {
                StatusChip(text: t("turf_ready_in", t.duration(ds.turfReadyAt - state.time)), symbol: "hourglass")
            }
            UpgradeButton(title: t("turf_btn"), cost: cost,
                          affordable: ds.rival > 0 && ds.turfReadyAt <= state.time && cost.affordable(state) && state.campaign.tutorial == .done,
                          identifier: "turf.\(district.rawValue)") {
                store.dispatch(.turf(district))
            }
        }
    }
}
