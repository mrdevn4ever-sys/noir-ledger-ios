import NoirCore
import SwiftUI

/// Chooses between the save-version guard, the prologue and the five-section game, and hosts the overlays
/// (decision, raid, return summary, epilogue, save recovery) so they appear wherever the player is.
struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(StoreService.self) private var shop
    @Environment(AdService.self) private var ads

    var body: some View {
        content
            .environment(\.l10n, settings.l10n)
            .environment(\.locale, settings.l10n.locale)
            .environment(\.noirReduceMotion, settings.reduceMotion(system: systemReduceMotion))
            .tint(Noir.amber)
            .sensoryFeedback(.selection, trigger: store.acceptedCount) { _, _ in settings.haptics }
            .sensoryFeedback(.warning, trigger: store.rejectedCount) { _, _ in settings.haptics }
            .sensoryFeedback(.impact(weight: .light), trigger: store.tapCount) { _, _ in settings.haptics }
            .sensoryFeedback(.success, trigger: store.celebration?.id) { _, new in settings.haptics && new != nil }
            .overlay(alignment: .top) {
                CelebrationBanner()
                    .environment(\.l10n, settings.l10n)
                    .environment(\.noirReduceMotion, settings.reduceMotion(system: systemReduceMotion))
            }
            .task {
                shop.start()
                ads.start()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            LoadingView()
        case .futureSave(let version):
            FutureSaveView(version: version)
        case .ready:
            if store.state.campaign.prologueDone {
                GameTabs()
            } else {
                PrologueView()
            }
        }
    }
}

private struct LoadingView: View {
    @Environment(\.l10n) private var t

    var body: some View {
        VStack(spacing: Noir.s4) {
            Wordmark()
            ProgressView().tint(Noir.amber)
            Text(verbatim: t("loading")).foregroundStyle(Noir.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Noir.ground)
    }
}

/// The sheet the root currently shows. One at a time, in priority order.
private enum RootSheet: String, Identifiable {
    case offline, raid, event
    var id: String { rawValue }
}

private struct GameTabs: View {
    @Environment(GameStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    private var activeSheet: Binding<RootSheet?> {
        Binding(
            get: {
                if store.offlineReport != nil { return .offline }
                if store.state.raidUnseen && store.state.lastRaid != nil { return .raid }
                if router.eventOpen && store.state.pendingEvent != nil { return .event }
                return nil
            },
            set: { newValue in
                guard newValue == nil else { return }
                if store.offlineReport != nil {
                    store.offlineReport = nil
                } else if store.state.raidUnseen {
                    store.dispatch(.ackRaid)
                } else {
                    router.eventOpen = false
                }
            }
        )
    }

    private var epilogueOpen: Binding<Bool> {
        Binding(
            get: { store.state.campaign.won && !store.state.campaign.epilogueSeen },
            set: { open in if !open && store.state.campaign.won { store.dispatch(.markEpilogueSeen) } }
        )
    }

    private var restoredAlert: Binding<Bool> {
        Binding(get: { store.restoredFromBackup }, set: { store.restoredFromBackup = $0 })
    }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            NavigationStack(path: $router.opsPath) {
                EmpireView().navigationDestination(for: Route.self, destination: destination)
            }
            .tabItem { tabLabel(.ops) }
            .tag(AppTab.ops)

            NavigationStack(path: $router.ledgerPath) {
                LedgerView().navigationDestination(for: Route.self, destination: destination)
            }
            .tabItem { tabLabel(.ledger) }
            .tag(AppTab.ledger)
            .badge(store.state.pendingEvent != nil ? 1 : 0)

            NavigationStack(path: $router.cityPath) {
                CityView().navigationDestination(for: Route.self, destination: destination)
            }
            .tabItem { tabLabel(.city) }
            .tag(AppTab.city)

            NavigationStack {
                MoneyView()
            }
            .tabItem { tabLabel(.money) }
            .tag(AppTab.money)

            NavigationStack(path: $router.networkPath) {
                NetworkView().navigationDestination(for: Route.self, destination: destination)
            }
            .tabItem { tabLabel(.network) }
            .tag(AppTab.network)
        }
        .toolbarBackground(Noir.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .sheet(item: activeSheet) { sheet in
            Group {
                switch sheet {
                case .offline:
                    if let report = store.offlineReport { OfflineSheet(report: report) }
                case .raid:
                    if let raid = store.state.lastRaid { RaidSheet(report: raid) }
                case .event:
                    EventSheet()
                }
            }
            .environment(\.l10n, t)
        }
        .fullScreenCover(isPresented: epilogueOpen) {
            NavigationStack {
                EpilogueView(isCover: true)
            }
            .environment(\.l10n, t)
        }
        .sheet(isPresented: $router.showSettings) {
            NavigationStack { SettingsView() }
                .environment(\.l10n, t)
        }
        .sheet(isPresented: $router.showShop) {
            NavigationStack { ShopView() }
                .environment(\.l10n, t)
        }
        .sheet(isPresented: $router.showRewards) {
            NavigationStack { RewardsView() }
                .environment(\.l10n, t)
        }
        .alert(Text(verbatim: t("save_restored_title")), isPresented: restoredAlert) {
            Button(role: .cancel) {} label: { Text(verbatim: t("btn_continue")) }
        } message: {
            Text(verbatim: t("save_restored"))
        }
    }

    private func tabLabel(_ tab: AppTab) -> some View {
        Label { Text(verbatim: t(tab.titleKey)) } icon: { Image(systemName: tab.symbol) }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .district(let d): DistrictView(district: d)
        case .finalOp: FinalOpView()
        case .legacy: LegacyView()
        case .epilogue: EpilogueView(isCover: false)
        case .workshop: OperationsView()
        }
    }
}

/// Shown when the save on disk was written by a newer version: it is left untouched unless the player starts over.
struct FutureSaveView: View {
    let version: Int
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t
    @State private var confirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: Noir.s5) {
                Wordmark().padding(.top, Noir.s6)
                Panel(.paper) {
                    Text(verbatim: t("save_future_title")).font(.title3.weight(.semibold))
                    Text(verbatim: t("save_future_body")).font(.body)
                }
                Button(role: .destructive) { confirm = true } label: { Text(verbatim: t("save_future_restart")) }
                    .noirButton(.danger)
                    .accessibilityIdentifier("future.restart")
            }
            .padding(Noir.s4)
        }
        .background(Noir.ground)
        .alert(Text(verbatim: t("reset_confirm_title")), isPresented: $confirm) {
            Button(role: .destructive) { store.resetEverything() } label: { Text(verbatim: t("reset_confirm_btn")) }
            Button(role: .cancel) {} label: { Text(verbatim: t("btn_cancel")) }
        } message: {
            Text(verbatim: t("reset_confirm_body"))
        }
    }
}
