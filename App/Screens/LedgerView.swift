import NoirCore
import SwiftUI

/// The sheets the ledger screen opens.
enum LedgerSheet: Identifiable, Equatable {
    case station(Station)
    case orders, crew, city, book, chapter, challenges, shop, rewards, settings, contacts

    var id: String {
        switch self {
        case .station(let st): "station.\(StationText.id(st))"
        case .orders: "orders"
        case .crew: "crew"
        case .city: "city"
        case .book: "book"
        case .chapter: "chapter"
        case .challenges: "challenges"
        case .shop: "shop"
        case .rewards: "rewards"
        case .settings: "settings"
        case .contacts: "contacts"
        }
    }
}

// MARK: - Top bar

// MARK: - Chapter and hints

struct ChapterStrip: View {
    let state: FlowState
    @Binding var sheet: LedgerSheet?
    @Environment(\.l10n) private var t

    var body: some View {
        Button {
            sheet = Flow.challengesOpen(state) ? .challenges : .chapter
        } label: {
            HStack(spacing: Noir.s3) {
                if let ch = FlowContent.chapter(state.chapter) {
                    Portrait(crewId: ch.person, size: 44).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: t("l4_chapter_n", ch.number) + " · " + t(ChapterText.title(ch.number)))
                            .font(.subheadline.weight(.bold))
                        if let goal = ch.goals.first(where: { !Flow.goalDone(state, $0) }) {
                            let p = Flow.goalProgress(state, goal)
                            Text(verbatim: ChapterText.goal(goal, t)).font(.caption).foregroundStyle(Noir.paperInk.opacity(0.75))
                            Meter(fraction: p.target > 0 ? min(1, p.current / p.target) : 1, tint: Noir.paperGold, height: 4)
                        } else {
                            Text(verbatim: t("l4_chapter_ready")).font(.caption.weight(.bold)).foregroundStyle(Noir.paperRed)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(verbatim: "\(ch.goals.filter { Flow.goalDone(state, $0) }.count)/\(ch.goals.count)")
                        .font(.caption.weight(.heavy)).monospacedDigit()
                } else {
                    Image(systemName: "flag.checkered").font(.title2)
                    Text(verbatim: t("l4_challenges_strip")).font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right").font(.caption.weight(.bold))
            }
            .padding(Noir.s3)
            .foregroundStyle(Noir.paperInk)
            .background(Noir.paper, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
            .overlay {
                if Flow.chapterComplete(state) {
                    RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.amber, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chapter.strip")
    }
}

struct HintBubble: View {
    let hint: FlowHint
    @Environment(\.l10n) private var t

    var body: some View {
        Label { Text(verbatim: t(HintText.key(hint))).fixedSize(horizontal: false, vertical: true) } icon: {
            Image(systemName: "hand.point.down.fill")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Noir.onAmber)
        .padding(Noir.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Noir.amberFill, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .accessibilityIdentifier("hint")
    }
}

/// Where each good's flow stops right now, in one compact panel.
struct BottleneckPanel: View {
    let state: FlowState
    let forecast: Forecast
    @Binding var sheet: LedgerSheet?
    @Environment(\.l10n) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: Noir.s2) {
            Text(verbatim: t("l4_neck_title")).font(.caption.weight(.heavy)).foregroundStyle(Noir.inkSoft)
                .accessibilityAddTraits(.isHeader)
            ForEach(state.openGoods, id: \.self) { g in
                if let gf = forecast.good(g), let w = state.workshop(g) {
                    BottleneckBanner(good: g, forecast: gf, workshop: w, state: state, sheet: $sheet)
                }
            }
            if !state.dispatcher || state.openGoods.contains(where: { state.workshop($0)?.lead != true }) {
                Text(verbatim: t("l4_neck_manual")).font(.caption2).foregroundStyle(Noir.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Noir.s3)
        .background(Noir.raised, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.hairline, lineWidth: 1))
    }
}

/// One good's line in the panel: where it stops, the three rates, the station that would fix it.
struct BottleneckBanner: View {
    let good: Good
    let forecast: GoodForecast
    let workshop: WorkshopState
    let state: FlowState
    @Binding var sheet: LedgerSheet?
    @Environment(\.l10n) private var t

    var body: some View {
        let fix = StationText.fix(forecast.bottleneck, good: good, state: state)
        let piling = workshop.stock >= Flow.shelfCapacity(state, good) * 0.8
        HStack(alignment: .center, spacing: Noir.s2) {
            Mark(Glyph.product(good.product), size: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: t(NeckText.key(forecast.bottleneck), t(GoodText.name(good))))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(piling && forecast.bottleneck != .bench ? Noir.danger : Noir.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: t("l4_neck_numbers", t.money(forecast.production), t.money(forecast.carried), t.money(forecast.demand)))
                    .font(.caption).monospacedDigit().foregroundStyle(Noir.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let fix {
                Button { sheet = .station(fix) } label: { Text(verbatim: t("l4_neck_fix")).font(.subheadline.weight(.bold)) }
                    .noirButton(.primary, fullWidth: false)
                    .accessibilityIdentifier("neck.\(good.rawValue).fix")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("neck.\(good.rawValue)")
    }
}

// MARK: - Workshop

// MARK: - Fleet

// MARK: - Contacts

struct QuarterBlock: View {
    let quarter: Quarter
    let state: FlowState
    @Binding var sheet: LedgerSheet?
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let qs = state.quarter(quarter)
        let tier = Flow.tier(qs.attention)
        VStack(alignment: .leading, spacing: Noir.s2) {
            HStack(spacing: Noir.s2) {
                Text(verbatim: t(QuarterText.name(quarter))).font(.subheadline.weight(.bold))
                Spacer(minLength: 0)
                AttentionChip(attention: qs.attention, paused: qs.paused)
            }
            Meter(fraction: qs.attention / 100, tint: tier >= 2 ? Noir.danger : (tier == 1 ? Noir.amber : Noir.brass), height: 4)
            if tier > 0 || qs.paused {
                Text(verbatim: t(qs.paused ? "l4_paused_b" : "l4_tier_effect_\(tier)")).font(.caption2)
                    .foregroundStyle(tier >= 2 ? Noir.danger : Noir.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(FlowContent.contacts.filter { $0.quarter == quarter && state.isOpen($0.good) && $0.chapter <= state.chapter }) { c in
                ContactRow(contact: c, state: state, sheet: $sheet)
            }
        }
        .padding(.vertical, Noir.s1)
    }
}

struct AttentionChip: View {
    let attention: Double
    let paused: Bool
    @Environment(\.l10n) private var t

    var body: some View {
        let tier = Flow.tier(attention)
        Label {
            Text(verbatim: t(paused ? "l4_paused" : "l4_tier_\(tier)") + " · " + t.decimal(attention, digits: 0))
        } icon: {
            Image(systemName: paused ? "pause.circle.fill" : (tier >= 2 ? "exclamationmark.triangle.fill" : "eye.fill"))
        }
        .font(.caption.weight(.bold)).monospacedDigit()
        .foregroundStyle(tier >= 2 ? Noir.danger : (tier == 1 ? Noir.amber : Noir.inkSoft))
    }
}

struct ContactRow: View {
    let contact: ContactDef
    let state: FlowState
    @Binding var sheet: LedgerSheet?
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let owned = state.contacts[contact.id]
        HStack(spacing: Noir.s3) {
            Mark(Glyph.product(contact.good.product), size: 22).opacity(owned == nil ? 0.5 : 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: t(ContactText.name(contact.id))).font(.subheadline.weight(.semibold))
                if owned != nil {
                    Text(verbatim: t("l4_contact_line", t.money(Flow.contactAverageRate(state, contact.id) * 60),
                                     t.money(Flow.contactPrice(state, contact.id, average: true))))
                        .font(.caption).monospacedDigit().foregroundStyle(Noir.inkSoft)
                    if contact.club {
                        let night = Flow.clubNight(state)
                        Text(verbatim: t(night.on ? "l4_club_on" : "l4_club_off", t.duration(night.left)))
                            .font(.caption2.weight(.bold)).monospacedDigit().foregroundStyle(night.on ? Noir.amber : Noir.inkSoft)
                    }
                    if contact.luxury, let trust = owned?.trust {
                        Text(verbatim: t("l4_trust", trust, FlowContent.maxTrust)).font(.caption2.weight(.bold)).foregroundStyle(Noir.brass)
                    }
                } else {
                    Text(verbatim: t(ContactText.desc(contact.id))).font(.caption).foregroundStyle(Noir.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let owned {
                Button { sheet = .station(.contact(contact.id)) } label: {
                    Text(verbatim: t("l4_level", owned.level)).monospacedDigit()
                }
                .noirButton(.secondary, fullWidth: false)
                .accessibilityIdentifier("contact.\(contact.id)")
            } else {
                Button { store.dispatch(.unlockContact(contact.id)) } label: {
                    VStack(spacing: 2) {
                        Text(verbatim: t("l4_unlock"))
                        Text(verbatim: t.money(contact.unlockCost)).font(.caption.weight(.semibold)).monospacedDigit().opacity(0.85)
                    }
                }
                .noirButton(state.cash >= contact.unlockCost ? .primary : .secondary, fullWidth: false)
                .disabled(state.cash < contact.unlockCost)
                .accessibilityIdentifier("contact.\(contact.id).unlock")
            }
        }
    }
}

// MARK: - Orders strip and navigation

// MARK: - Small chrome

/// An invisible, one-point element that names the screen for UI automation.
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

struct NoticeBanner: View {
    let notice: NoticeMessage
    @Environment(LedgerStore.self) private var store
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
            try? await Task.sleep(for: .seconds(2.5))
            store.clearNotice(notice.id)
        }
    }
}
