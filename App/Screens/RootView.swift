import NoirCore
import SwiftUI

/// Chooses between the save-version guard and the game, and hosts what can interrupt play: the return summary, the
/// raid, the save-recovery note and the celebration banner.
struct RootView: View {
    @Environment(TycoonStore.self) private var store
    @Environment(AppSettings.self) private var settings
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
            GameRoot()
        }
    }
}

/// The interruptions, one at a time: the return summary first, then a raid.
private enum Interruption: String, Identifiable {
    case offline, raid
    var id: String { rawValue }
}

private struct GameRoot: View {
    @Environment(TycoonStore.self) private var store
    @Environment(\.l10n) private var t

    private var interruption: Binding<Interruption?> {
        Binding(
            get: {
                if store.offline != nil { return .offline }
                if store.state.lastRaidLoss != nil { return .raid }
                return nil
            },
            set: { newValue in
                guard newValue == nil else { return }
                if store.offline != nil {
                    store.dispatch(.collectOffline(doubled: false))
                    store.offline = nil
                } else if store.state.lastRaidLoss != nil {
                    store.dispatch(.ackRaid)
                }
            }
        )
    }

    private var restoredAlert: Binding<Bool> {
        Binding(get: { store.restoredFromBackup }, set: { store.restoredFromBackup = $0 })
    }

    var body: some View {
        TycoonView()
            .sheet(item: interruption) { kind in
                Group {
                    switch kind {
                    case .offline:
                        if let report = store.offline { OfflineSheet(report: report) }
                    case .raid:
                        RaidSheet(loss: store.state.lastRaidLoss ?? 0)
                    }
                }
                .environment(\.l10n, t)
            }
            .alert(Text(verbatim: t("save_restored_title")), isPresented: restoredAlert) {
                Button(role: .cancel) {} label: { Text(verbatim: t("btn_continue")) }
            } message: {
                Text(verbatim: t("save_restored"))
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

/// Shown when the save on disk was written by a newer version: it is left untouched unless the player starts over.
struct FutureSaveView: View {
    let version: Int
    @Environment(TycoonStore.self) private var store
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
