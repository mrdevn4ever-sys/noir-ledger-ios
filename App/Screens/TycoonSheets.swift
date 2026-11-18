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
            VStack(alignment: .leading, spacing: Noir.s4) { content }
                .padding(Noir.s4)
                .background(alignment: .topLeading) { ScreenMarker(identifier: identifier, title: t(titleKey)) }
        }
        .background(Noir.ground)
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

// MARK: - Deals

struct DealsSheet: View {
    @Environment(TycoonStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        let open = TycoonContent.deals.filter { !s.deals.contains($0.id) }
        SheetFrame("ty_deals", identifier: "screen.deals") {
            Text(verbatim: t("ty_deals_b")).font(.subheadline).foregroundStyle(Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if !s.deals.isEmpty {
                StatusChip(text: t("ty_deals_done", s.deals.count), symbol: "checkmark.seal.fill")
            }
            if open.isEmpty {
                Text(verbatim: t("ty_deals_none")).font(.headline)
            }
            ForEach(open.prefix(6)) { d in
                let locked = d.floor.map { !Tycoon.isOpen(s, $0) } ?? false
                let affordable = s.cash >= d.cost
                Panel(.leather) {
                    HStack(spacing: Noir.s3) {
                        if let f = d.floor {
                            Mark(Glyph.product(f.product), size: 30)
                        } else {
                            Image(systemName: "building.2.fill").font(.title2).foregroundStyle(Noir.brass).frame(width: 30)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: d.floor.map { t(Labels.product($0.product)) } ?? t("ty_deal_all")).font(.headline)
                            Text(verbatim: t("ty_deal_mult", t.decimal(d.multiplier, digits: 0))).font(.subheadline.weight(.semibold))
                                .foregroundStyle(Noir.amber)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            store.dispatch(.buyDeal(d.id))
                        } label: {
                            Text(verbatim: t.money(d.cost)).monospacedDigit()
                        }
                        .noirButton(affordable && !locked ? .primary : .secondary, fullWidth: false)
                        .disabled(!affordable || locked)
                        .accessibilityIdentifier("deal.\(d.id)")
                    }
                }
            }
        }
    }
}

// MARK: - Change city

struct CitySheet: View {
    @Environment(TycoonStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.l10n) private var t
    @State private var confirm = false

    var body: some View {
        let s = store.state
        let gain = Tycoon.reputationGain(s)
        let after = 1 + TycoonContent.reputationBonus * Double(s.meta.reputation + gain)
        SheetFrame("ty_city", identifier: "screen.city") {
            Text(verbatim: t("ty_city_b")).font(.body).foregroundStyle(Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Panel(.leather) {
                ValueRow(label: t("ty_city_rep"), value: t("ty_rep_chip", s.meta.reputation))
                ValueRow(label: t("ty_city_gain"), value: "+" + t.decimal(Double(gain), digits: 0), valueColor: Noir.amber)
                ValueRow(label: t("ty_city_after"), value: t("empire_payout", t.decimal(after, digits: 1)), valueColor: Noir.amber)
            }
            if gain < 1 {
                Text(verbatim: t("ty_city_need", t.money(TycoonContent.reputationScale)))
                    .font(.subheadline).foregroundStyle(Noir.inkSoft)
            }
            Button { confirm = true } label: { Text(verbatim: t("ty_city_button", gain)) }
                .noirButton(.primary)
                .disabled(gain < 1)
                .accessibilityIdentifier("city.change")
        }
        .confirmationDialog(Text(verbatim: t("ty_city_confirm_t")), isPresented: $confirm, titleVisibility: .visible) {
            Button(role: .destructive) {
                if store.dispatch(.changeCity) != nil { dismiss() }
            } label: {
                Text(verbatim: t("ty_city_confirm", gain))
            }
            .accessibilityIdentifier("city.confirm")
            Button(role: .cancel) {} label: { Text(verbatim: t("btn_cancel")) }
        } message: {
            Text(verbatim: t("ty_city_confirm_b"))
        }
    }
}

// MARK: - Time away

struct OfflineSheet: View {
    let report: TycoonOffline
    @Environment(TycoonStore.self) private var store
    @Environment(AdService.self) private var ads
    @Environment(\.l10n) private var t

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s4) {
                Text(verbatim: t("ty_offline_title")).font(.display(.title2)).foregroundStyle(Noir.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("offline.title")
                if report.clockMovedBack {
                    Text(verbatim: t("ty_offline_clock")).font(.body).foregroundStyle(Noir.inkSoft)
                } else {
                    Text(verbatim: t("ty_offline_away", t.duration(report.awaySeconds), t.duration(report.creditedSeconds)))
                        .font(.subheadline).foregroundStyle(Noir.inkSoft)
                    VStack(spacing: 2) {
                        Text(verbatim: t("ty_offline_haul")).font(.caption).foregroundStyle(Noir.inkSoft)
                        Text(verbatim: "+" + t.money(report.earned))
                            .font(.system(.largeTitle, design: .serif, weight: .bold)).monospacedDigit()
                            .foregroundStyle(Noir.amber)
                            .accessibilityIdentifier("offline.haul")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Noir.s2)
                    if report.capped {
                        Label { Text(verbatim: t("ty_offline_capped", t.duration(report.creditedSeconds))) } icon: {
                            Image(systemName: "hourglass.bottomhalf.filled")
                        }
                        .font(.subheadline).foregroundStyle(Noir.amber)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if store.state.meta.offlineBonus > 0, store.rewardOffered(ads: ads) {
                    Button {
                        store.claimReward(.offlineDouble, ads: ads)
                    } label: {
                        Label {
                            Text(verbatim: t(store.state.meta.noAds ? "offline_double_free" : "offline_double_video", t.money(store.state.meta.offlineBonus)))
                        } icon: {
                            Image(systemName: store.state.meta.noAds ? "bolt.fill" : "play.rectangle.fill")
                        }
                    }
                    .noirButton(.primary)
                    .accessibilityIdentifier("offline.double")
                }
                Button {
                    store.dispatch(.collectOffline(doubled: false))
                    store.offline = nil
                } label: {
                    Text(verbatim: t("offline_ok"))
                }
                .noirButton(store.state.meta.offlineBonus > 0 && store.rewardOffered(ads: ads) ? .secondary : .primary)
                .accessibilityIdentifier("offline.ok")
            }
            .padding(Noir.s4)
        }
        .background(Noir.ground)
        .onChange(of: store.state.meta.offlineBonus) { old, new in
            if old > 0 && new <= 0 { store.offline = nil }
        }
    }
}

// MARK: - Raid

struct RaidSheet: View {
    let loss: Double
    @Environment(TycoonStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: Noir.s4) {
            Label { Text(verbatim: t("ty_raid_title")).font(.display(.title2)) } icon: { Mark(Glyph.raid, size: 28) }
                .foregroundStyle(Noir.danger)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("raid.title")
            Text(verbatim: t("ty_raid_b")).font(.body).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
            Panel(.paper) {
                ValueRow(label: t("ty_raid_loss"), value: "−" + t.money(loss), symbol: "banknote", valueColor: Noir.paperRed)
            }
            Spacer(minLength: 0)
            Button { store.dispatch(.ackRaid) } label: { Text(verbatim: t("ty_raid_ack")) }
                .noirButton(.primary)
                .accessibilityIdentifier("raid.ack")
        }
        .padding(Noir.s4)
        .background(Noir.ground)
        .interactiveDismissDisabled()
        .presentationDetents([.medium])
    }
}
