import NoirCore
import SwiftUI

/// The books: the current chapter's objectives, the final operation, the three accounts and the bookings journal.
struct LedgerView: View {
    @Environment(GameStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        TabScreen("nav_ledger", identifier: "screen.ledger") {
            if s.campaign.won {
                WonPanel()
            }
            if s.legacy.ngLevel > 0 {
                StatusChip(text: t("ng_level", s.legacy.ngLevel), symbol: "arrow.triangle.2.circlepath")
                    .accessibilityIdentifier("ledger.ngLevel")
            }
            ChapterPanel(state: s)
            if s.campaign.chapter >= Content.finalChapter && !s.campaign.won {
                FinalOpEntry(state: s)
            }
            if let p = s.pendingEvent {
                Panel(.anthracite) {
                    Label { Text(verbatim: t(Labels.eventTitle(p.event))).font(.headline) } icon: { Image(systemName: "envelope.badge") }
                    Text(verbatim: t("event_pending")).font(.subheadline).foregroundStyle(Noir.inkSoft)
                    Button { router.eventOpen = true } label: { Text(verbatim: t("event_decide")) }
                        .noirButton(.primary)
                        .accessibilityIdentifier("ledger.event")
                }
            }
            AccountsPanel(state: s)
            JournalPanel(journal: s.journal)
        }
    }
}

private struct WonPanel: View {
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    var body: some View {
        Panel(.paper) {
            HStack(alignment: .top, spacing: Noir.s3) {
                LedgerEmblem().frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: Noir.s1) {
                    Text(verbatim: t("won_title")).font(.display(.title3))
                    Text(verbatim: t("won_body")).font(.subheadline).foregroundStyle(Noir.paperInkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button { router.ledgerPath.append(.epilogue) } label: { Text(verbatim: t("btn_epilogue")) }
                .noirButton(.secondary)
                .accessibilityIdentifier("ledger.epilogue")
            Button { router.ledgerPath.append(.legacy) } label: { Text(verbatim: t("btn_new_game_plus")) }
                .noirButton(.primary)
                .accessibilityIdentifier("ledger.newGamePlus")
        }
    }
}

/// The chapter page: title, intro, objectives with progress and the reward.
struct ChapterPanel: View {
    let state: GameState
    @Environment(\.l10n) private var t

    var body: some View {
        let chapter = state.campaign.chapter
        Panel(.paper) {
            VStack(alignment: .leading, spacing: 2) {
                if chapter > 0 {
                    Text(verbatim: t("chapter_label", chapter)).font(.caption.weight(.semibold)).foregroundStyle(Noir.paperInkSoft)
                }
                Text(verbatim: t(Labels.chapterTitle(chapter)))
                    .font(.display(.title2))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("ledger.chapterTitle")
            }
            Text(verbatim: t(Labels.chapterIntro(chapter))).font(.subheadline).foregroundStyle(Noir.paperInkSoft)
                .fixedSize(horizontal: false, vertical: true)
            let objectives = Campaign.objectives(state)
            if !objectives.isEmpty {
                PanelDivider()
                ForEach(objectives, id: \.objective) { o in
                    ObjectiveRow(progress: o)
                }
                let reward = Content.chapterReward(chapter)
                if !reward.isFree {
                    Text(verbatim: t("chapter_reward", t.cost(reward)))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Noir.paperInk)
                }
            }
        }
    }
}

struct ObjectiveRow: View {
    let progress: ObjectiveProgress
    @Environment(\.l10n) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: Noir.s1) {
            HStack(alignment: .firstTextBaseline, spacing: Noir.s2) {
                Image(systemName: progress.done ? "checkmark.square.fill" : "square")
                    .foregroundStyle(progress.done ? Noir.paperGold : Noir.paperInkSoft)
                    .accessibilityHidden(true)
                Text(verbatim: ObjectiveText.title(progress.objective, t))
                    .font(.subheadline)
                    .strikethrough(progress.done, color: Noir.paperInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Noir.s2)
                let value = ObjectiveText.progress(progress, t)
                if !value.isEmpty {
                    Text(verbatim: value)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Noir.paperInkSoft)
                }
            }
            if !progress.done && progress.target > 1 {
                Meter(fraction: progress.fraction, tint: Noir.paperGold, height: 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(verbatim: progress.done ? t("a11y_done") : t("a11y_open")))
    }
}

enum ObjectiveText {
    static func title(_ o: Objective, _ t: L10n) -> String {
        switch o {
        case .earnDirty(let a): t("obj_earn", t.money(a))
        case .lineLevels(let p, let n): t.plural("obj_line_levels", count: n, t(Labels.product(p)), n)
        case .crewCount(let n): t.plural("obj_crew", count: n, n)
        case .launder(let a): t("obj_launder", t.money(a))
        case .unlockDistrict(let d): t("obj_unlock", t(Labels.district(d)))
        case .ownLine(let p): t("obj_own_line", t(Labels.product(p)))
        case .ownFront(let f): t("obj_front", t(Labels.front(f)))
        case .control(let d, let pct): t("obj_control", t(Labels.district(d)), t.points(pct))
        case .upgrades(let n): t.plural("obj_upgrades", count: n, n)
        case .influenceHeld(let a): t("obj_influence", t.money(a))
        }
    }

    static func progress(_ p: ObjectiveProgress, _ t: L10n) -> String {
        switch p.objective {
        case .unlockDistrict, .ownLine, .ownFront:
            return ""
        case .control:
            return t("obj_progress", t.points(p.current), t.points(p.target))
        default:
            return t("obj_progress", t.money(min(p.current, p.target)), t.money(p.target))
        }
    }
}

private struct FinalOpEntry: View {
    let state: GameState
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    var body: some View {
        let reqs = Campaign.finalRequirements(state)
        let met = reqs.filter(\.met).count
        Panel(.anthracite) {
            Text(verbatim: t("final_title")).font(.display(.title3)).accessibilityAddTraits(.isHeader)
            Text(verbatim: t("final_intro")).font(.subheadline).foregroundStyle(Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            ValueRow(label: t("final_requirements"), value: t("obj_progress", String(met), String(reqs.count)), symbol: "checklist")
            Button { router.ledgerPath.append(.finalOp) } label: {
                Text(verbatim: t(state.campaign.finalOp == nil ? "final_open_plan" : "final_open"))
            }
            .noirButton(.primary)
            .accessibilityIdentifier("ledger.finalOp")
        }
    }
}

private struct AccountsPanel: View {
    let state: GameState
    @Environment(\.l10n) private var t

    var body: some View {
        let m = Economy.mods(state)
        Panel(.paper) {
            Text(verbatim: t("ledger_accounts")).font(.headline).accessibilityAddTraits(.isHeader)
            ForEach(Account.allCases, id: \.key) { account in
                ValueRow(label: "\(t("account_no", Labels.accountNumber(account.key)))  \(t(account.key))",
                         value: t.money(balance(account)), mark: account.mark)
            }
            PanelDivider()
            ValueRow(label: t("ledger_street_income"), value: t.perMinute(state.incomeRate), symbol: "arrow.down.left")
            ValueRow(label: t("ledger_laundering"), value: t.perMinute(state.cleanRate), symbol: "arrow.triangle.2.circlepath")
            ValueRow(label: t("ledger_wages"), value: t.perMinute(Economy.wagePerSec(state)), symbol: "person.2",
                     valueColor: state.wagesUnpaid ? Noir.paperRed : nil)
            ValueRow(label: t("heat_cover"), value: t.decimal(Economy.cover(state, m), digits: 0), symbol: "shield")
        }
    }

    private func balance(_ a: Account) -> Double {
        switch a {
        case .dirty: state.dirty
        case .clean: state.clean
        case .influence: state.influence
        }
    }
}

private struct JournalPanel: View {
    let journal: [JournalEntry]
    @Environment(\.l10n) private var t

    var body: some View {
        Panel(.paper) {
            Text(verbatim: t("journal_title")).font(.headline).accessibilityAddTraits(.isHeader)
                    if journal.isEmpty {
                Text(verbatim: t("journal_empty")).font(.subheadline).foregroundStyle(Noir.paperInkSoft)
            } else {
                ForEach(journal.prefix(20)) { entry in
                    VStack(alignment: .leading, spacing: Noir.s2) {
                        if entry.id != journal.first?.id { PanelDivider() }
                        JournalRow(entry: entry)
                    }
                }
            }
        }
        .accessibilityIdentifier("ledger.journal")
    }
}

private struct JournalRow: View {
    let entry: JournalEntry
    @Environment(\.l10n) private var t

    var body: some View {
        let line = JournalText.line(entry, t)
        HStack(alignment: .firstTextBaseline, spacing: Noir.s3) {
            Text(verbatim: t.duration(entry.time))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Noir.paperInkSoft)
                .frame(minWidth: 64, alignment: .leading)
            Text(verbatim: line.text)
                .font(.subheadline)
                .foregroundStyle(line.loss ? Noir.paperRed : Noir.paperInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

enum JournalText {
    static func line(_ e: JournalEntry, _ t: L10n) -> (text: String, loss: Bool) {
        func district() -> String { DistrictId(rawValue: e.ref).map { t(Labels.district($0)) } ?? e.ref }
        func crewName() -> String { Content.crewDef(e.ref)?.name ?? e.ref }
        switch e.kind {
        case .chapterComplete: return (t("j_chapter", e.ref), false)
        case .districtUnlocked: return (t("j_district", district()), false)
        case .lineBought: return (t("j_line", ProductId(rawValue: e.ref).map { t(Labels.product($0)) } ?? e.ref), false)
        case .frontBought: return (t("j_front", FrontId(rawValue: e.ref).map { t(Labels.front($0)) } ?? e.ref), false)
        case .crewHired: return (t("j_hired", crewName()), false)
        case .crewLeft: return (t("j_left", crewName()), true)
        case .crewDismissed: return (t("j_dismissed", crewName()), false)
        case .investigationStarted: return (t("j_inv_start", district()), true)
        case .investigationCleared: return (t("j_inv_clear", district()), false)
        case .raid: return (t("j_raid", district(), t.money(e.amount)), true)
        case .heatWarning: return (t("j_heat_warn", t.decimal(e.amount, digits: 0)), true)
        case .eventResolved:
            let parts = e.ref.split(separator: ":").map(String.init)
            let title = parts.first.flatMap { EventId(rawValue: $0) }.map { t(Labels.eventTitle($0)) } ?? e.ref
            return (t("j_event", title), false)
        case .turf: return (t("j_turf", district()), false)
        case .bribe: return (t("j_bribe", t.decimal(e.amount, digits: 0)), false)
        case .upgrade: return (t("j_upgrade", UpgradeId(rawValue: e.ref).map { t(Labels.upgrade($0)) } ?? e.ref), false)
        case .finalPhaseWon: return (t("j_final_won", phaseTitle(e.ref, t)), false)
        case .finalPhaseLost: return (t("j_final_lost", phaseTitle(e.ref, t)), true)
        case .campaignWon: return (t("j_won", t.decimal(e.amount, digits: 0)), false)
        case .newGamePlus: return (t("j_ng", t.decimal(e.amount, digits: 0)), false)
        case .offlineReturn:
            if e.ref == "clock" { return (t("j_offline_clock"), true) }
            return (t("j_offline", t.duration(e.amount), t.money(e.amount2)), false)
        case .layLowOn: return (t("j_laylow_on"), false)
        case .layLowOff: return (t("j_laylow_off"), false)
        case .protection: return (t("j_protection", t.decimal(e.amount, digits: 0)), false)
        case .wagesUnpaid: return (t("j_wages"), true)
        case .donation: return (t("j_donation", t.money(e.amount), t.decimal(e.amount2, digits: 1)), false)
        }
    }

    private static func phaseTitle(_ ref: String, _ t: L10n) -> String {
        guard let i = Int(ref), let p = FinalPhase(rawValue: i) else { return ref }
        return t(Labels.phaseTitle(p))
    }
}
