import NoirCore
import SwiftUI

/// The books' other half: Heat and its countermeasures, the laundering fronts, the working reserve,
/// the protection network and civic donations.
struct MoneyView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        let m = Economy.mods(s)
        TabScreen("nav_money", identifier: "screen.money") {
            HeatPanel(state: s, mods: m)
            SectionHeading(title: t("money_launder_title"),
                           detail: t("launder_summary", t.perMinute(Economy.launderCapacity(s, m)), t.perMinute(s.incomeRate)))
            ForEach(FrontId.allCases, id: \.self) { f in
                FrontPanel(front: f, state: s, mods: m)
            }
            ReservePanel(state: s)
            ProtectionPanel(state: s)
            DonationPanel(state: s)
        }
    }
}

private struct HeatPanel: View {
    let state: GameState
    let mods: Mods
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let status = HeatStatus.of(state)
        let bribe = Economy.bribeCost(state, mods)
        Panel(.anthracite) {
            Text(verbatim: t("heat_title")).font(.headline).accessibilityAddTraits(.isHeader)
            HeatGauge(heat: state.heat, trend: state.heatTarget, status: status)
            Text(verbatim: t("heat_explain")).font(.footnote).foregroundStyle(Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            ValueRow(label: t("heat_target"), value: t.decimal(state.heatTarget, digits: 0), symbol: "scope")
            ValueRow(label: t("heat_cover"), value: t.decimal(Economy.cover(state, mods), digits: 0), symbol: "shield")
            if let inv = state.investigation {
                VStack(alignment: .leading, spacing: Noir.s1) {
                    Label { Text(verbatim: t("investigation_title")).font(.subheadline.weight(.bold)) } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    Text(verbatim: t("investigation_body", t(Labels.district(inv.district)), t.duration(inv.endsAt - state.time),
                                     t.decimal(mods.clearThreshold, digits: 0)))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Noir.onDanger)
                .padding(Noir.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Noir.dangerFill, in: RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("money.investigation")
            } else if status == .watched {
                StatusChip(text: t("warning_watched"), symbol: "eye", danger: true)
            }
            if state.campaign.chapter >= 1 {
                if state.bribeReadyAt > state.time {
                    StatusChip(text: t("turf_ready_in", t.duration(state.bribeReadyAt - state.time)), symbol: "hourglass")
                }
                UpgradeButton(title: t("bribe_btn", t.decimal(Economy.bribeHeat, digits: 0)), cost: bribe,
                              affordable: bribe.affordable(state) && state.bribeReadyAt <= state.time && state.heat > 0.5,
                              primary: state.investigation != nil, identifier: "money.bribe") {
                    store.dispatch(.bribe)
                }
                Button {
                    store.dispatch(.setLayLow(!state.layLow))
                } label: {
                    Label { Text(verbatim: t(state.layLow ? "laylow_off" : "laylow_on")) } icon: {
                        Image(systemName: state.layLow ? "play.fill" : "moon.fill")
                    }
                }
                .noirButton(.secondary)
                .accessibilityIdentifier("money.layLow")
                Text(verbatim: t("laylow_desc")).font(.footnote).foregroundStyle(Noir.inkSoft)
            }
        }
    }
}

private struct FrontPanel: View {
    let front: FrontId
    let state: GameState
    let mods: Mods
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let def = Content.front(front)
        let fs = state.front(front)
        let districtOpen = state.district(def.district).unlocked
        Panel(fs.owned ? .paper : .anthracite) {
            HStack(alignment: .firstTextBaseline) {
                Label { Text(verbatim: t(Labels.front(front))).font(.headline) } icon: { Mark(Glyph.front(front), size: 24) }
                    .accessibilityAddTraits(.isHeader)
                            Spacer()
                if fs.owned {
                    Text(verbatim: t("level", fs.level, Content.maxFrontLevel)).font(.caption.weight(.semibold)).monospacedDigit()
                } else {
                    Text(verbatim: t("account_no", Labels.accountNumber(front.rawValue))).font(.caption).foregroundStyle(Noir.inkSoft)
                }
            }
            Text(verbatim: t(Labels.frontDesc(front))).font(.subheadline)
                .foregroundStyle(fs.owned ? Noir.paperInkSoft : Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            let capacity = fs.owned ? Economy.frontCapacity(state, front, mods) : def.capacity * mods.launderCap
            ValueRow(label: t("front_capacity", t.money(capacity * 60)),
                     value: t("front_fee", t.percent(Economy.frontFee(state, front, mods))))
            ValueRow(label: t("front_cover", t.decimal(def.cover * (1 + 0.3 * Double(fs.level - 1)), digits: 1)),
                     value: t(Labels.district(def.district)))
            if fs.owned {
                Toggle(isOn: Binding(get: { fs.active }, set: { store.dispatch(.setFrontActive(front, $0)) })) {
                    Text(verbatim: t(fs.active ? "front_active" : "front_paused")).font(.subheadline.weight(.semibold))
                }
                .tint(Noir.paperGold)
                .frame(minHeight: Noir.minTarget)
                .accessibilityIdentifier("front.\(front.rawValue).active")
                if fs.level < Content.maxFrontLevel {
                    let cost = Cost(clean: Content.frontUpgradeCost(front, currentLevel: fs.level) * mods.frontUpgradeCost)
                    UpgradeButton(title: t("btn_upgrade"), cost: cost, affordable: cost.affordable(state),
                                  identifier: "front.\(front.rawValue).upgrade") {
                        store.dispatch(.upgradeFront(front))
                    }
                }
            } else if districtOpen {
                UpgradeButton(title: t("front_buy"), cost: def.buy, affordable: def.buy.affordable(state), primary: true,
                              identifier: "front.\(front.rawValue).buy") {
                    store.dispatch(.buyFront(front))
                }
            } else {
                StatusChip(text: t("front_needs_district", t(Labels.district(def.district))), symbol: "lock")
            }
        }
        .accessibilityIdentifier("front.\(front.rawValue)")
    }
}

private struct ReservePanel: View {
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        Panel(.anthracite) {
            Text(verbatim: t("reserve_title")).font(.headline)
            Text(verbatim: t("reserve_desc")).font(.footnote).foregroundStyle(Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Picker(selection: Binding(get: { state.reserveMinutes }, set: { store.dispatch(.setReserve($0)) })) {
                ForEach(Engine.reserveOptions, id: \.self) { minutes in
                    Text(verbatim: minutes == 0 ? t("reserve_none") : t("reserve_min", minutes)).tag(minutes)
                }
            } label: {
                Text(verbatim: t("reserve_title"))
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("money.reserve")
        }
    }
}

private struct ProtectionPanel: View {
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        Panel(.anthracite) {
            Text(verbatim: t("protection_title")).font(.headline)
            Text(verbatim: t("protection_desc")).font(.footnote).foregroundStyle(Noir.inkSoft)
            Text(verbatim: t("protection_level", state.protectionLevel, t.decimal(Content.protectionCover(level: state.protectionLevel), digits: 0)))
                .font(.subheadline.weight(.semibold)).monospacedDigit()
            if state.campaign.chapter < 2 {
                StatusChip(text: t("unlocks_ch2"), symbol: "lock")
            } else if state.protectionLevel < Content.maxProtectionLevel {
                let cost = Cost(clean: Content.protectionCost(currentLevel: state.protectionLevel))
                UpgradeButton(title: t("protection_btn"), cost: cost, affordable: cost.affordable(state), identifier: "money.protection") {
                    store.dispatch(.upgradeProtection)
                }
            } else {
                StatusChip(text: t("max"), symbol: "checkmark.seal")
            }
        }
    }
}

private struct DonationPanel: View {
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        Panel(.anthracite) {
            Text(verbatim: t("donate_title")).font(.headline)
            Text(verbatim: t("donate_desc")).font(.footnote).foregroundStyle(Noir.inkSoft)
            if state.campaign.chapter < 2 {
                StatusChip(text: t("unlocks_ch2"), symbol: "lock")
            } else {
                let price = Economy.donationCost(state)
                let gained = Economy.donationInfluence(state, clean: price)
                UpgradeButton(title: t("donate_btn", t.decimal(gained, digits: 1)), cost: Cost(clean: price),
                              affordable: state.clean >= price, identifier: "money.donate") {
                    store.dispatch(.donate)
                }
            }
        }
    }
}
