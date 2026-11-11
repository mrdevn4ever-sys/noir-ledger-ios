import NoirCore
import SwiftUI

/// The back room: one-time offers, favor packs, what favors buy, and the free sponsor rewards.
struct ShopView: View {
    @Environment(GameStore.self) private var store
    @Environment(StoreService.self) private var shop
    @Environment(AdService.self) private var ads
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s4) {
                wallet(s)
                SectionHeading(title: t("shop_free"), detail: t(s.meta.noAds ? "shop_free_detail_noads" : "shop_free_detail"))
                RewardRow(reward: .boost, state: s)
                RewardRow(reward: .favors, state: s)
                RewardRow(reward: .coolHeat, state: s)

                SectionHeading(title: t("shop_offers"))
                ForEach(StoreItem.offers) { item in
                    OfferCard(item: item, state: s)
                }

                SectionHeading(title: t("shop_market"), detail: t("shop_market_detail"))
                ForEach(FavorItem.allCases, id: \.self) { item in
                    FavorRow(item: item, state: s)
                }

                SectionHeading(title: t("shop_favors"))
                ForEach(StoreItem.favorPacks) { item in
                    OfferCard(item: item, state: s)
                }

                Button {
                    Task { await shop.restore() }
                } label: {
                    Text(verbatim: t(shop.restoring ? "shop_restoring" : "shop_restore"))
                }
                .noirButton(.quiet)
                .disabled(shop.restoring)
                .accessibilityIdentifier("shop.restore")
                Text(verbatim: t("shop_legal")).font(.footnote).foregroundStyle(Noir.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Noir.s4)
            .background(alignment: .topLeading) { ScreenMarker(identifier: "screen.shop", title: t("shop_title")) }
        }
        .background(Noir.ground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let notice = store.notice { NoticeBanner(notice: notice).padding(Noir.s3) }
        }
        .navigationTitle(Text(verbatim: t("shop_title")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Noir.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { router.showShop = false } label: { Text(verbatim: t("btn_done")) }
                    .accessibilityIdentifier("shop.done")
            }
        }
    }

    private func wallet(_ s: GameState) -> some View {
        Panel(.leather) {
            HStack(spacing: Noir.s3) {
                Image(systemName: "seal.fill").font(.title).foregroundStyle(Noir.brass).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: t("shop_wallet")).font(.caption).foregroundStyle(Noir.inkSoft)
                    RollingText(text: t.decimal(Double(s.meta.favors), digits: 0), value: Double(s.meta.favors))
                        .font(.title.weight(.bold))
                        .accessibilityIdentifier("shop.favors")
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(verbatim: t("shop_payout")).font(.caption).foregroundStyle(Noir.inkSoft)
                    Text(verbatim: t("empire_payout", t.decimal(Idle.globalMultiplier(s), digits: 2)))
                        .font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(Noir.amber)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// A free reward paid by a sponsor video (or directly with the ad-free upgrade).
private struct RewardRow: View {
    let reward: AdReward
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(AdService.self) private var ads
    @Environment(\.l10n) private var t

    var body: some View {
        let block = blocked
        Panel(.anthracite) {
            HStack(spacing: Noir.s3) {
                Image(systemName: symbol).font(.title3).foregroundStyle(Noir.amber).frame(width: 30).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title).font(.subheadline.weight(.semibold))
                    Text(verbatim: block ?? detail).font(.caption).foregroundStyle(Noir.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    store.claimReward(reward, ads: ads)
                } label: {
                    Label {
                        Text(verbatim: t(state.meta.noAds ? "shop_take" : "shop_watch"))
                    } icon: {
                        Image(systemName: state.meta.noAds ? "bolt.fill" : "play.rectangle.fill")
                    }
                }
                .noirButton(.primary, fullWidth: false)
                .disabled(block != nil || !store.rewardOffered(ads: ads))
                .accessibilityIdentifier("shop.reward.\(reward.rawValue)")
            }
        }
    }

    private var symbol: String {
        switch reward {
        case .boost: "bolt.fill"
        case .favors: "seal.fill"
        case .coolHeat: "snowflake"
        case .offlineDouble: "moon.zzz.fill"
        }
    }

    private var title: String {
        switch reward {
        case .boost: t("reward_boost_t", t.duration(Idle.adBoostSeconds))
        case .favors: t("reward_favors_t", Idle.adFavors)
        case .coolHeat: t("reward_heat_t", t.decimal(Idle.adHeatRelief, digits: 0))
        case .offlineDouble: t("offline_title")
        }
    }

    private var detail: String {
        switch reward {
        case .boost: t("reward_boost_d", t.duration(Idle.boostCapSeconds))
        case .favors: t("reward_favors_d", Idle.adFavorsLeft(state, day: store.today), Idle.adFavorsPerDay)
        case .coolHeat: t("reward_heat_d")
        case .offlineDouble: ""
        }
    }

    /// Why the reward cannot be taken right now, if so.
    private var blocked: String? {
        switch reward {
        case .boost:
            return state.meta.boostSeconds >= Idle.boostCapSeconds - 1 ? t("reward_boost_full") : nil
        case .favors:
            return Idle.adFavorsLeft(state, day: store.today) <= 0 ? t("reward_favors_out") : nil
        case .coolHeat:
            if state.meta.heatAidCooldown > 0 { return t("reward_heat_wait", t.duration(state.meta.heatAidCooldown)) }
            return state.heat <= 0.5 && state.investigation == nil ? t("reward_heat_cold") : nil
        case .offlineDouble:
            return nil
        }
    }
}

/// A store product with its App Store price.
private struct OfferCard: View {
    let item: StoreItem
    let state: GameState
    @Environment(StoreService.self) private var shop
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let owned = item.owned(state.meta)
        Panel(item.isConsumable ? .anthracite : .paper) {
            HStack(alignment: .top, spacing: Noir.s3) {
                Image(systemName: item.symbol).font(.title2).frame(width: 34).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: t(item.titleKey)).font(.headline)
                    Text(verbatim: detail).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if owned {
                StatusChip(text: t("shop_owned"), symbol: "checkmark.seal.fill")
                    .accessibilityIdentifier("shop.owned.\(item.rawValue)")
            } else {
                Button {
                    Task {
                        switch await shop.purchase(item) {
                        case .purchased: break
                        case .pending: store.show("shop_pending")
                        case .cancelled: break
                        case .failed: store.show("shop_failed", danger: true)
                        }
                    }
                } label: {
                    Text(verbatim: shop.prices[item] ?? t(shop.status == .loading ? "shop_loading" : "shop_unavailable"))
                        .monospacedDigit()
                }
                .noirButton(.primary)
                .disabled(!shop.available(item) || shop.purchasing != nil)
                .accessibilityIdentifier("shop.buy.\(item.rawValue)")
            }
        }
    }

    private var detail: String {
        switch item {
        case .starter: t("shop_starter_d", Idle.starterFavors, t.duration(Idle.starterBoostSeconds))
        case .premium: t("shop_premium_d", t.duration(Double(2 * Content.offlineCapSeconds)))
        case .noAds: t("shop_noads_d")
        default: t("shop_favors_d", item.favors)
        }
    }
}

/// Something favors buy.
private struct FavorRow: View {
    let item: FavorItem
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        Panel(.leather) {
            HStack(spacing: Noir.s3) {
                Image(systemName: symbol).font(.title3).foregroundStyle(Noir.brass).frame(width: 30).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title).font(.subheadline.weight(.semibold))
                    Text(verbatim: detail).font(.caption).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    store.dispatch(.buyFavorItem(item))
                } label: {
                    Label { Text(verbatim: t.decimal(Double(item.price), digits: 0)).monospacedDigit() } icon: {
                        Image(systemName: "seal.fill")
                    }
                }
                .noirButton(.primary, fullWidth: false)
                .disabled(state.meta.favors < item.price)
                .accessibilityHint(Text(verbatim: state.meta.favors < item.price ? t("shop_need_favors") : ""))
                .accessibilityIdentifier("shop.item.\(item.rawValue)")
            }
        }
    }

    private var symbol: String {
        switch item {
        case .boost4h: "bolt.fill"
        case .warp2h, .warp8h, .warp24h: "forward.fill"
        case .coolHeat: "snowflake"
        case .loyalty: "heart.fill"
        }
    }

    private var title: String {
        switch item {
        case .boost4h: t("item_boost_t", t.duration(4 * 3600))
        case .warp2h, .warp8h, .warp24h: t("item_warp_t", t.duration(item.warpSeconds))
        case .coolHeat: t("item_heat_t", t.decimal(Idle.favorHeatRelief, digits: 0))
        case .loyalty: t("item_loyalty_t")
        }
    }

    private var detail: String {
        switch item {
        case .boost4h: t("item_boost_d")
        case .warp2h, .warp8h, .warp24h: t("item_warp_d")
        case .coolHeat: t("item_heat_d")
        case .loyalty: t("item_loyalty_d")
        }
    }
}
