import NoirCore
import SwiftUI

/// People and structure: the crew, the improvement branches and the legacy carried between runs.
struct NetworkView: View {
    @Environment(GameStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    var body: some View {
        @Bindable var router = router
        let s = store.state
        TabScreen("nav_network", identifier: "screen.network") {
            Picker(selection: $router.networkSection) {
                ForEach(NetworkSection.allCases) { section in
                    Text(verbatim: t(section.titleKey)).tag(section)
                }
            } label: {
                Text(verbatim: t("nav_network"))
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("network.section")
            switch router.networkSection {
            case .crew: CrewSection(state: s)
            case .improvements: ImprovementsSection(state: s)
            case .legacy: LegacySummary(state: s)
            }
        }
    }
}

// MARK: - Crew

private struct CrewSection: View {
    let state: GameState
    @Environment(\.l10n) private var t

    var body: some View {
        if state.wagesUnpaid {
            StatusChip(text: t("crew_unpaid"), symbol: "exclamationmark.triangle.fill", danger: true)
                .accessibilityIdentifier("crew.unpaid")
        }
        ValueRow(label: t("ledger_wages"), value: t.perMinute(Economy.wagePerSec(state)), symbol: "person.2")
        ForEach(CrewRole.allCases, id: \.self) { role in
            RolePanel(role: role, state: state)
        }
    }
}

private struct RolePanel: View {
    let role: CrewRole
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t
    @State private var confirmDismiss = false

    var body: some View {
        let member = state.crewIn(role)
        Panel(.leather) {
            HStack {
                Label { Text(verbatim: t(Labels.role(role))).font(.headline) } icon: { Mark(Glyph.role(role), size: 24) }
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if member == nil { StatusChip(text: t("crew_vacant"), symbol: "person.crop.circle.badge.questionmark") }
            }
            if let member, let def = member.def {
                memberBlock(member, def)
            } else {
                Text(verbatim: t("crew_candidates")).font(.subheadline.weight(.semibold)).foregroundStyle(Noir.inkSoft)
                ForEach(Content.crew.filter { $0.role == role }) { def in
                    CandidateRow(def: def, state: state)
                }
            }
        }
        .accessibilityIdentifier("crew.\(role.rawValue)")
    }

    @ViewBuilder
    private func memberBlock(_ member: CrewMember, _ def: CrewDef) -> some View {
        let power = Economy.crewPower(member)
        HStack(alignment: .center, spacing: Noir.s3) {
            Portrait(crewId: def.id, size: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: def.name).font(.title3.weight(.semibold)).accessibilityIdentifier("crew.\(role.rawValue).name")
                Text(verbatim: "\(t(def.tier == 1 ? "crew_tier1" : "crew_tier2")) · \(t(Labels.trait(def.trait)))")
                    .font(.subheadline).foregroundStyle(Noir.inkSoft)
            }
        }
        Text(verbatim: t(Labels.traitDesc(def.trait))).font(.footnote).foregroundStyle(Noir.inkSoft)
        Text(verbatim: RoleEffectText.text(role, power: power, t)).font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: Noir.s2) {
            Meter(fraction: member.loyalty / 100, tint: member.loyalty < 25 ? Noir.danger : Noir.amber)
            Text(verbatim: t("crew_loyalty", t.decimal(member.loyalty, digits: 0))).font(.caption.weight(.semibold)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        if member.loyalty < 50 {
            StatusChip(text: t("crew_low_loyalty"), symbol: "arrow.down.heart", danger: member.loyalty < 25)
        }
        Text(verbatim: t("crew_wage", t.money(def.wagePerMin * def.trait.wageMult))).font(.footnote).monospacedDigit().foregroundStyle(Noir.inkSoft)
        let bonus = Cost(dirty: Engine.bonusCost(member))
        UpgradeButton(title: t("crew_bonus"), cost: bonus, affordable: bonus.affordable(state) && member.loyalty < 100,
                      identifier: "crew.\(role.rawValue).bonus") {
            store.dispatch(.crewBonus(member.defId))
        }
        Button(role: .destructive) { confirmDismiss = true } label: { Text(verbatim: t("crew_dismiss")) }
            .noirButton(.quiet)
            .accessibilityIdentifier("crew.\(role.rawValue).dismiss")
            .confirmationDialog(Text(verbatim: t("crew_dismiss_title", def.name)), isPresented: $confirmDismiss, titleVisibility: .visible) {
                Button(role: .destructive) { store.dispatch(.dismiss(member.defId)) } label: { Text(verbatim: t("crew_dismiss")) }
                Button(role: .cancel) {} label: { Text(verbatim: t("btn_cancel")) }
            } message: {
                Text(verbatim: t("crew_dismiss_body"))
            }
    }
}

private struct CandidateRow: View {
    let def: CrewDef
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let unlocked = state.campaign.chapter >= def.unlockChapter
        let cost = Cost(dirty: Engine.hireCost(state, def))
        VStack(alignment: .leading, spacing: Noir.s1) {
            PanelDivider()
            HStack(spacing: Noir.s3) {
                Portrait(crewId: def.id, size: 44)
                Text(verbatim: def.name).font(.headline)
            }
            Text(verbatim: "\(t(def.tier == 1 ? "crew_tier1" : "crew_tier2")) · \(t(Labels.trait(def.trait))) · \(t("crew_wage", t.money(def.wagePerMin * def.trait.wageMult)))")
                .font(.footnote).foregroundStyle(Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: t(Labels.traitDesc(def.trait))).font(.footnote).foregroundStyle(Noir.inkSoft)
            if state.departed.contains(def.id) {
                StatusChip(text: t("crew_rehire"), symbol: "arrow.uturn.backward")
            }
            if unlocked {
                UpgradeButton(title: t("crew_hire"), cost: cost, affordable: cost.affordable(state) && state.campaign.tutorial == .done,
                              identifier: "crew.hire.\(def.id)") {
                    store.dispatch(.hire(def.id))
                }
            } else {
                StatusChip(text: t("locked_chapter", def.unlockChapter), symbol: "lock")
            }
        }
    }
}

enum RoleEffectText {
    static func text(_ role: CrewRole, power p: Double, _ t: L10n) -> String {
        switch role {
        case .foreman: t(Labels.roleEffect(role), t.percent(0.15 * p), t.percent(0.05 * p))
        case .courier: t(Labels.roleEffect(role), t.percent(0.2 * p))
        case .enforcer: t(Labels.roleEffect(role), t.percent(0.5 * p))
        case .accountant: t(Labels.roleEffect(role), t.percent(0.25 * p), t.decimal(3 * p, digits: 1))
        case .lawyer: t(Labels.roleEffect(role), t.percent(0.12 * p), t.percent(0.3 * p), t.percent(min(0.7, 0.4 * p)))
        case .fixer: t(Labels.roleEffect(role), t.percent(0.3 * p), t.percent(min(0.5, 0.2 * p)))
        }
    }
}

// MARK: - Improvements

private struct ImprovementsSection: View {
    let state: GameState
    @Environment(\.l10n) private var t

    var body: some View {
        Text(verbatim: t("upgrades_intro")).font(.footnote).foregroundStyle(Noir.inkSoft)
        ForEach(UpgradeBranch.allCases, id: \.self) { branch in
            Panel(.anthracite) {
                Label { Text(verbatim: t(Labels.branch(branch))).font(.headline) } icon: { Mark(Glyph.branch(branch), size: 24) }
                    .accessibilityAddTraits(.isHeader)
                let nodes = UpgradeId.inBranch(branch)
                ForEach(nodes.filter { $0.tier == 1 }, id: \.self) { UpgradeRow(upgrade: $0, state: state) }
                PanelDivider()
                Text(verbatim: t("up_choose_one")).font(.caption.weight(.semibold)).foregroundStyle(Noir.amber)
                ForEach(nodes.filter { $0.tier == 2 }, id: \.self) { UpgradeRow(upgrade: $0, state: state) }
                PanelDivider()
                ForEach(nodes.filter { $0.tier == 3 }, id: \.self) { UpgradeRow(upgrade: $0, state: state) }
            }
            .accessibilityIdentifier("branch.\(branch.rawValue)")
        }
    }
}

private struct UpgradeRow: View {
    let upgrade: UpgradeId
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let status = Engine.upgradeStatus(state, upgrade)
        VStack(alignment: .leading, spacing: Noir.s1) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: t(Labels.upgrade(upgrade))).font(.subheadline.weight(.semibold))
                Spacer()
                Text(verbatim: t("tier_label", upgrade.tier)).font(.caption).foregroundStyle(Noir.inkMuted)
            }
            Text(verbatim: t(Labels.upgradeDesc(upgrade))).font(.footnote).foregroundStyle(Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            switch status {
            case .owned:
                StatusChip(text: t("up_owned"), symbol: "checkmark.seal.fill")
            case .excluded:
                StatusChip(text: t("up_excluded"), symbol: "xmark.circle")
            case .needsPrevious:
                StatusChip(text: t("up_needs_previous"), symbol: "arrow.up")
            case .chapterLocked:
                StatusChip(text: t("locked_chapter", Content.upgradeAvailableChapter(upgrade)), symbol: "lock")
            case .available:
                let cost = Content.upgradeCost(upgrade)
                UpgradeButton(title: t("up_buy"), cost: cost, affordable: cost.affordable(state), identifier: "upgrade.\(upgrade.rawValue)") {
                    store.dispatch(.buyUpgrade(upgrade))
                }
            }
        }
        .padding(.vertical, Noir.s1)
        .accessibilityIdentifier("upgrade.row.\(upgrade.rawValue)")
    }
}

// MARK: - Legacy summary

private struct LegacySummary: View {
    let state: GameState
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    var body: some View {
        Panel(.paper) {
            Text(verbatim: t("legacy_title")).font(.display(.title3)).accessibilityAddTraits(.isHeader)
            Text(verbatim: t.plural("legacy_points", count: state.legacy.points, state.legacy.points))
                .font(.headline).monospacedDigit()
            if state.legacy.ngLevel > 0 {
                Text(verbatim: t("ng_level", state.legacy.ngLevel)).font(.subheadline)
            }
            Text(verbatim: t(state.legacy.wins > 0 || state.legacy.points > 0 ? "legacy_desc" : "legacy_empty"))
                .font(.subheadline).foregroundStyle(Noir.paperInkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button { router.networkPath.append(.legacy) } label: { Text(verbatim: t("legacy_open")) }
                .noirButton(.secondary)
                .accessibilityIdentifier("network.legacy.open")
        }
    }
}
