import NoirCore
import SwiftUI

// MARK: - Final operation

/// Operation Ledger: the requirements, the war chest, then three phases with certain and risky choices.
struct FinalOpView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        DetailScreen(t("final_title"), identifier: "screen.finalOp") {
            Panel(.paper) {
                Text(verbatim: t("final_title")).font(.display(.title2)).accessibilityAddTraits(.isHeader)
                Text(verbatim: t("final_intro")).font(.subheadline).foregroundStyle(Noir.paperInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if s.campaign.won {
                StatusChip(text: t("won_title"), symbol: "checkmark.seal.fill")
            } else if s.campaign.finalOp == nil {
                RequirementsPanel(state: s)
            } else if let phase = Campaign.currentPhase(s) {
                PhasePanel(phase: phase, state: s)
            }
        }
    }
}

private struct RequirementsPanel: View {
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let reqs = Campaign.finalRequirements(state)
        let warChest = Campaign.finalWarChest(state)
        Panel(.anthracite) {
            Text(verbatim: t("final_requirements")).font(.headline).accessibilityAddTraits(.isHeader)
            ForEach(reqs) { r in
                RequirementLine(text: text(r), met: r.met)
            }
            Text(verbatim: t("final_war_chest", t.cost(warChest))).font(.subheadline).foregroundStyle(Noir.inkSoft)
            Button { store.dispatch(.startFinalOp) } label: { Text(verbatim: t("final_start")) }
                .noirButton(.primary)
                .disabled(!Campaign.finalReady(state))
                .accessibilityIdentifier("final.start")
        }
    }

    private func text(_ r: FinalRequirement) -> String {
        let current: String
        let line: String
        switch r.kind {
        case .control(let d):
            line = t("req_control", t(Labels.district(d)), t.points(r.target))
            current = t.points(r.current)
        case .clean:
            line = t("req_clean", t.money(r.target))
            current = t.money(r.current)
        case .influence:
            line = t("req_influence", t.money(r.target))
            current = t.money(r.current)
        case .heat:
            line = t("req_heat", t.decimal(r.target, digits: 0))
            current = t.decimal(r.current, digits: 0)
        }
        return "\(line) (\(current))"
    }
}

private struct PhasePanel: View {
    let phase: FinalPhase
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let op = state.campaign.finalOp
        let cooling = (op?.readyAt ?? 0) > state.time
        Panel(.anthracite) {
            Text(verbatim: t("final_phase_n", phase.rawValue + 1)).font(.caption.weight(.semibold)).foregroundStyle(Noir.inkSoft)
                .accessibilityIdentifier("final.phaseNumber")
            Text(verbatim: t(Labels.phaseTitle(phase))).font(.display(.title3)).accessibilityAddTraits(.isHeader)
            Text(verbatim: t(Labels.phaseBody(phase))).font(.subheadline).foregroundStyle(Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if let last = store.lastFinalAttempt {
                let ok = last.success
                StatusChip(text: t(ok ? "final_success" : "final_failure"), symbol: ok ? "checkmark.circle.fill" : "xmark.octagon.fill", danger: !ok)
                    .accessibilityIdentifier("final.result")
            }
            if cooling {
                StatusChip(text: t("final_retry_in", t.duration((op?.readyAt ?? 0) - state.time)), symbol: "hourglass")
                    .accessibilityIdentifier("final.cooldown")
            }
            ForEach(Campaign.finalChoices(state, phase)) { choice in
                ChoiceBlock(choice: choice, state: state, disabled: cooling)
            }
        }
    }
}

private struct ChoiceBlock: View {
    let choice: FinalChoice
    let state: GameState
    let disabled: Bool
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let roleOK = choice.requiresRole.map { state.crewIn($0) != nil } ?? true
        VStack(alignment: .leading, spacing: Noir.s1) {
            PanelDivider()
            Text(verbatim: t(Labels.finalChoice(choice.key))).font(.headline)
            HStack(spacing: Noir.s3) {
                StatusChip(text: t("final_chance", t.percent(choice.chance)), symbol: "dice")
                if choice.heat > 0 {
                    StatusChip(text: t("final_heat_add", t.decimal(choice.heat, digits: 0)), symbol: "flame", danger: true)
                }
            }
            if let role = choice.requiresRole {
                RequirementLine(text: t("final_needs_role", t(Labels.role(role))), met: roleOK)
            }
            UpgradeButton(title: t("final_commit"), cost: choice.cost, affordable: !disabled && roleOK && choice.cost.affordable(state),
                          primary: choice.chance >= 1, identifier: "final.choice.\(choice.key)") {
                store.dispatch(.finalOpChoice(choice.key))
            }
        }
    }
}

// MARK: - Epilogue, books and credits

struct EpilogueView: View {
    let isCover: Bool
    @Environment(GameStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let s = store.state
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s5) {
                HStack { Spacer(); Wordmark(); Spacer() }.padding(.top, Noir.s4)
                Text(verbatim: t("epilogue_title")).font(.display(.largeTitle)).foregroundStyle(Noir.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("epilogue.title")
                ForEach(["epilogue_1", "epilogue_2", "epilogue_3"], id: \.self) { key in
                    Text(verbatim: t(key)).font(.body).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                Panel(.paper) {
                    Text(verbatim: t("epilogue_books")).font(.headline).accessibilityAddTraits(.isHeader)
                    ValueRow(label: t("stat_time"), value: t.duration(s.campaign.won ? s.campaign.wonAtTime : s.time), symbol: "clock")
                    ValueRow(label: t("stat_dirty"), value: t.money(s.stats.dirtyEarned), symbol: "banknote")
                    ValueRow(label: t("stat_clean"), value: t.money(s.stats.cleanLaundered), symbol: "building.columns")
                    ValueRow(label: t("stat_raids"), value: String(s.stats.raids), mark: Glyph.raid)
                    ValueRow(label: t("stat_investigations"), value: String(s.stats.investigationsSurvived), symbol: "eye.slash")
                    ValueRow(label: t("stat_decisions"), value: String(s.stats.eventsResolved), symbol: "envelope")
                    PanelDivider()
                    Text(verbatim: t.plural("epilogue_legacy", count: s.campaign.legacyAwarded, s.campaign.legacyAwarded))
                        .font(.headline)
                        .foregroundStyle(Noir.paperInk)
                        .accessibilityIdentifier("epilogue.legacy")
                }
                Panel(.anthracite) {
                    Text(verbatim: t("credits_title")).font(.headline).accessibilityAddTraits(.isHeader)
                    Text(verbatim: t("credits_body")).font(.footnote).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    finish()
                    router.openLegacy()
                } label: { Text(verbatim: t("btn_new_game_plus")) }
                    .noirButton(.primary)
                    .accessibilityIdentifier("epilogue.newGamePlus")
                Button {
                    finish()
                } label: { Text(verbatim: t("btn_freeplay")) }
                    .noirButton(.secondary)
                    .accessibilityIdentifier("epilogue.freeplay")
            }
            .padding(Noir.s4)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .background(alignment: .topLeading) { ScreenMarker(identifier: "screen.epilogue", title: t("epilogue_title")) }
        }
        .background(Noir.ground)
        .navigationTitle(Text(verbatim: t("epilogue_title")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Noir.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func finish() {
        if !store.state.campaign.epilogueSeen { store.dispatch(.markEpilogueSeen) }
        if isCover { dismiss() } else { router.ledgerPath.removeAll { $0 == .epilogue } }
    }
}

// MARK: - Legacy and New Game+

struct LegacyView: View {
    @Environment(GameStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t
    @State private var confirmNewGame = false

    var body: some View {
        let s = store.state
        DetailScreen(t("legacy_title"), identifier: "screen.legacy") {
            Panel(.paper) {
                Text(verbatim: t("legacy_title")).font(.display(.title2)).accessibilityAddTraits(.isHeader)
                Text(verbatim: t.plural("legacy_points", count: s.legacy.points, s.legacy.points))
                    .font(.headline).monospacedDigit()
                    .accessibilityIdentifier("legacy.points")
                Text(verbatim: t(s.legacy.wins > 0 ? "legacy_desc" : "legacy_empty")).font(.subheadline).foregroundStyle(Noir.paperInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(PerkId.allCases, id: \.self) { perk in
                PerkRow(perk: perk, state: s)
            }
            if s.campaign.won {
                Panel(.anthracite) {
                    Text(verbatim: t("ng_confirm_body")).font(.subheadline).foregroundStyle(Noir.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: t("ng_level", s.legacy.ngLevel + 1)).font(.headline)
                    Button { confirmNewGame = true } label: { Text(verbatim: t("btn_new_game_plus")) }
                        .noirButton(.primary)
                        .accessibilityIdentifier("legacy.startNewGamePlus")
                }
            }
        }
        .alert(Text(verbatim: t("ng_confirm_title")), isPresented: $confirmNewGame) {
            Button {
                if store.dispatch(.startNewGamePlus) { router.resetNavigation() }
            } label: { Text(verbatim: t("btn_new_game_plus")) }
            Button(role: .cancel) {} label: { Text(verbatim: t("btn_cancel")) }
        } message: {
            Text(verbatim: t("ng_confirm_body"))
        }
    }
}

private struct PerkRow: View {
    let perk: PerkId
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let rank = state.legacy.rank(perk)
        let cost = Content.perkCost(currentRank: rank)
        Panel(.anthracite) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: t(Labels.perk(perk))).font(.headline)
                Spacer()
                Text(verbatim: t("perk_rank", rank, perk.maxRank)).font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(Noir.inkSoft)
            }
            Text(verbatim: t(Labels.perkDesc(perk))).font(.subheadline).foregroundStyle(Noir.inkSoft)
            if rank < perk.maxRank {
                Button { store.dispatch(.buyPerk(perk)) } label: { Text(verbatim: t.plural("perk_buy", count: cost, cost)) }
                    .noirButton(.secondary)
                    .disabled(state.legacy.points < cost)
                    .accessibilityIdentifier("perk.\(perk.rawValue)")
            } else {
                StatusChip(text: t("max"), symbol: "checkmark.seal")
            }
        }
    }
}
