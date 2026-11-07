import NoirCore
import SwiftUI

/// The frame every tab root shares: the accounts header pinned on top, the briefing coach and notices at the bottom,
/// and the settings button in the navigation bar.
struct TabScreen<Content: View>: View {
    let titleKey: String
    let identifier: String
    @ViewBuilder var content: Content
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    init(_ titleKey: String, identifier: String, @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.identifier = identifier
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s4) {
                content
            }
            .padding(.horizontal, Noir.s4)
            .padding(.top, Noir.s3)
            .padding(.bottom, Noir.s6)
            .background(alignment: .topLeading) { ScreenMarker(identifier: identifier, title: t(titleKey)) }
        }
        .scrollDismissesKeyboard(.never)
        .background(Noir.ground)
        .safeAreaInset(edge: .top, spacing: 0) { HUDView().dynamicTypeSize(...DynamicTypeSize.xxLarge) }
        .safeAreaInset(edge: .bottom, spacing: 0) { BottomChrome() }
        .navigationTitle(Text(verbatim: t(titleKey)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Noir.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .frame(width: Noir.minTarget, height: Noir.minTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(verbatim: t("cd_settings")))
                .accessibilityIdentifier("toolbar.settings")
            }
        }
    }
}

/// An invisible, one-point element that names the screen for UI automation. Identifiers on containers would
/// propagate to (and override) the identifiers of every control inside them, so screens use this marker instead.
struct ScreenMarker: View {
    let identifier: String
    let title: String

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: title))
            .accessibilityIdentifier(identifier)
    }
}

/// Pushed detail screens use the same ground and header but keep the system back button.
struct DetailScreen<Content: View>: View {
    let title: String
    let identifier: String
    @ViewBuilder var content: Content

    init(_ title: String, identifier: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.identifier = identifier
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s4) { content }
                .padding(.horizontal, Noir.s4)
                .padding(.top, Noir.s3)
                .padding(.bottom, Noir.s6)
                .background(alignment: .topLeading) { ScreenMarker(identifier: identifier, title: title) }
        }
        .background(Noir.ground)
        .safeAreaInset(edge: .top, spacing: 0) { HUDView().dynamicTypeSize(...DynamicTypeSize.xxLarge) }
        .safeAreaInset(edge: .bottom, spacing: 0) { BottomChrome() }
        .navigationTitle(Text(verbatim: title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Noir.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

// MARK: - Accounts header

/// The pinned header scales with Dynamic Type only up to xxLarge (like system bars; applied at its call sites), so at
/// accessibility sizes the screen content, which scales fully, keeps most of the height.

struct HUDView: View {
    @Environment(GameStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let s = store.state
        VStack(spacing: Noir.s2) {
            accounts(s)
            HeatGauge(heat: s.heat, trend: s.heatTarget, status: HeatStatus.of(s), compact: typeSize.isAccessibilitySize)
            if let inv = s.investigation {
                AlertStrip(symbol: "exclamationmark.triangle.fill",
                           text: t("investigation_body", t(Labels.district(inv.district)), t.duration(inv.endsAt - s.time),
                                   t.decimal(Economy.mods(s).clearThreshold, digits: 0)),
                           action: t("heat_title"), danger: true, identifier: "hud.investigation") {
                    router.tab = .money
                }
            } else if s.pendingEvent != nil && !router.eventOpen {
                AlertStrip(symbol: "envelope.badge", text: t("event_pending"), action: t("event_decide"), danger: false,
                           identifier: "hud.event") {
                    router.eventOpen = true
                }
            }
        }
        .padding(.horizontal, Noir.s4)
        .padding(.vertical, Noir.s2)
        .background(Noir.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(Noir.hairline).frame(height: 1) }
    }

    @ViewBuilder
    private func accounts(_ s: GameState) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Noir.s1) { accountCells(s) }
        } else {
            HStack(alignment: .top, spacing: Noir.s3) { accountCells(s) }
        }
    }

    private func accountCells(_ s: GameState) -> some View {
        ForEach(Account.allCases, id: \.self) { account in
            switch account {
            case .dirty: AccountCell(account: account, value: s.dirty, rate: s.incomeRate)
            case .clean: AccountCell(account: account, value: s.clean, rate: s.cleanRate)
            case .influence: AccountCell(account: account, value: s.influence, rate: s.influenceRateEma)
            }
        }
    }
}

struct AccountCell: View {
    let account: Account
    let value: Double
    let rate: Double
    @Environment(\.l10n) private var t
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Noir.s1) {
                Mark(account.mark, size: 14)
                Text(verbatim: t(account.key)).font(.caption)
            }
            .foregroundStyle(Noir.inkSoft)
            Text(verbatim: t.money(value))
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(account.ink)
                .accessibilityIdentifier("hud.\(account.key)")
            if !typeSize.isAccessibilitySize {
                Text(verbatim: t("per_min", t.money(rate * 60)))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Noir.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "\(t(account.key)) \(t.money(value)), \(t("per_min", t.money(rate * 60)))"))
    }
}

/// A full-width alert line with a symbol, text and an explicit action.
struct AlertStrip: View {
    let symbol: String
    let text: String
    let action: String
    let danger: Bool
    let identifier: String
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            HStack(alignment: .firstTextBaseline, spacing: Noir.s2) {
                Image(systemName: symbol).accessibilityHidden(true)
                Text(verbatim: text).font(.footnote.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.right").imageScale(.small).accessibilityHidden(true)
            }
            .padding(.horizontal, Noir.s3)
            .padding(.vertical, Noir.s2)
            .frame(minHeight: Noir.minTarget)
            .foregroundStyle(danger ? Noir.onDanger : Noir.onAmber)
            .background(danger ? Noir.dangerFill : Noir.amberFill, in: RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(verbatim: action))
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Bottom chrome

struct BottomChrome: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        VStack(spacing: Noir.s2) {
            if let notice = store.notice { NoticeBanner(notice: notice) }
            if store.state.campaign.tutorial != .done { TutorialCoach() }
        }
        .padding(.horizontal, Noir.s3)
        .padding(.bottom, Noir.s2)
    }
}

struct NoticeBanner: View {
    let notice: NoticeMessage
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        Label { Text(verbatim: t(notice.key)) } icon: {
            Image(systemName: notice.danger ? "exclamationmark.octagon" : "info.circle")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(notice.danger ? Noir.onDanger : Noir.ink)
        .padding(Noir.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(notice.danger ? Noir.dangerFill : Noir.raised, in: RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous).strokeBorder(Noir.hairline, lineWidth: 1))
        .accessibilityIdentifier("notice")
        .task(id: notice.id) {
            AccessibilityNotification.Announcement(t(notice.key)).post()
            try? await Task.sleep(for: .seconds(3))
            store.clearNotice(notice.id)
        }
    }
}

// MARK: - Briefing coach

struct TutorialCoach: View {
    @Environment(GameStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t
    @State private var collapsed = false

    var body: some View {
        let s = store.state
        let step = s.campaign.tutorial
        let progress = Campaign.tutorialProgress(s)
        VStack(alignment: .leading, spacing: Noir.s2) {
            Button {
                collapsed.toggle()
            } label: {
                HStack {
                    Text(verbatim: t("tut_label", step.ordinal + 1)).font(.caption.weight(.semibold)).foregroundStyle(Noir.paperInkSoft)
                    Spacer()
                    Image(systemName: collapsed ? "chevron.up" : "chevron.down").foregroundStyle(Noir.paperInkSoft)
                }
                .frame(minHeight: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: t("tut_label", step.ordinal + 1)))
            .accessibilityIdentifier("coach.toggle")
            Text(verbatim: t(Labels.tutorialTitle(step)))
                .font(.headline)
                .foregroundStyle(Noir.paperInk)
                .accessibilityIdentifier("coach.title")
            if !collapsed {
                Text(verbatim: bodyText(step))
                    .font(.subheadline)
                    .foregroundStyle(Noir.paperInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let progress {
                    Meter(fraction: progress.current / progress.target, tint: Noir.paperGold)
                    Text(verbatim: t("obj_progress", t.money(min(progress.current, progress.target)), t.money(progress.target)))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Noir.paperInkSoft)
                }
            }
            actions(step)
        }
        .padding(Noir.s3)
        .background(Noir.paper, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.paperEdge, lineWidth: 1))
        .environment(\.noirSurface, .paper)
        .accessibilityElement(children: .contain)
    }

    private func bodyText(_ step: TutorialStep) -> String {
        switch step {
        case .stockUp: t(Labels.tutorialBody(step), t.decimal(tutorialStockTarget, digits: 0))
        case .earn: t(Labels.tutorialBody(step), t.money(tutorialEarnTarget))
        case .launder: t(Labels.tutorialBody(step), t.money(tutorialLaunderTarget))
        default: t(Labels.tutorialBody(step))
        }
    }

    @ViewBuilder
    private func actions(_ step: TutorialStep) -> some View {
        if step == .heatBriefing {
            Button {
                store.dispatch(.ackTutorial)
            } label: {
                Text(verbatim: t("tut_understood"))
            }
            .noirButton(.primary)
            .accessibilityIdentifier("coach.ack")
        } else if let target = AppTab.forTutorial(step), needsJump(step, target) {
            Button {
                router.showTutorialTarget(step)
            } label: {
                Text(verbatim: t("tut_go"))
            }
            .noirButton(.primary)
            .accessibilityIdentifier("coach.go")
        }
    }

    private func needsJump(_ step: TutorialStep, _ target: AppTab) -> Bool {
        if router.tab != target { return true }
        if step == .openRoute { return router.cityPath.last != .district(.cellars) }
        return false
    }
}
