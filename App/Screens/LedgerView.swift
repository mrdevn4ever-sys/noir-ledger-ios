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
            HStack(spacing: Noir.s2) {
                if let ch = FlowContent.chapter(state.chapter) {
                    Portrait(crewId: ch.person, size: 32).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(verbatim: t("l4_chapter_n", ch.number) + " · " + t(ChapterText.title(ch.number)))
                                .font(.toon(13, .heavy))
                                .lineLimit(1).minimumScaleFactor(0.8)
                            Spacer(minLength: 0)
                            Text(verbatim: "\(ch.goals.filter { Flow.goalDone(state, $0) }.count)/\(ch.goals.count)")
                                .font(.toon(12, .heavy)).monospacedDigit()
                        }
                        if let goal = ch.goals.first(where: { !Flow.goalDone(state, $0) }) {
                            let p = Flow.goalProgress(state, goal)
                            HStack(spacing: Noir.s2) {
                                Text(verbatim: ChapterText.goal(goal, t)).font(.toon(12, .semibold))
                                    .foregroundStyle(Noir.paperInk.opacity(0.75))
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                Meter(fraction: p.target > 0 ? min(1, p.current / p.target) : 1, tint: Noir.paperGold, height: 4)
                                    .frame(width: 56)
                            }
                        } else {
                            Text(verbatim: t("l4_chapter_ready")).font(.toon(12, .heavy))
                                .foregroundStyle(Noir.paperRed).lineLimit(1).minimumScaleFactor(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Image(systemName: "flag.checkered").font(.toon(.headline))
                    Text(verbatim: t("l4_challenges_strip")).font(.toon(13, .heavy))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right").font(.toon(.caption, .bold))
            }
            .padding(.horizontal, Noir.s3).padding(.vertical, 7)
            .foregroundStyle(Noir.paperInk)
            .background(Noir.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if Flow.chapterComplete(state) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Noir.amber, lineWidth: 2)
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
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "hand.point.down.fill")
            Text(verbatim: t(HintText.key(hint))).fixedSize(horizontal: false, vertical: true)
        }
        .font(.toon(13, .bold))
        .foregroundStyle(Noir.onAmber)
        .padding(.horizontal, Noir.s3).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Noir.amberFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hint")
    }
}

/// The one place where the flow loses the most right now, in a single line with the fix; the scene itself marks
/// every other station that holds back with a red "!".
struct BottleneckPanel: View {
    let state: FlowState
    let forecast: Forecast
    @Binding var sheet: LedgerSheet?

    var body: some View {
        if let g = Self.worst(state, forecast), let gf = forecast.good(g), let w = state.workshop(g) {
            BottleneckBanner(good: g, forecast: gf, workshop: w, state: state, sheet: $sheet)
        }
    }

    /// The good whose stuck station costs the most cash per minute; a good piling up on a full shelf comes first.
    static func worst(_ s: FlowState, _ f: Forecast) -> Good? {
        let stuck = s.openGoods.compactMap { g -> (Good, Double)? in
            guard let gf = f.good(g), gf.bottleneck != .balanced, StationText.fix(gf.bottleneck, good: g, state: s) != nil else { return nil }
            let price = gf.sold > 0 ? gf.income / gf.sold : 1
            let lost = max(0, max(gf.production, gf.demand) - gf.sold) * price
            let full = (s.workshop(g)?.stock ?? 0) >= Flow.shelfCapacity(s, g) - 1e-9
            return (g, lost + (full ? 1e30 : 0))
        }
        return stuck.max { $0.1 < $1.1 }?.0
    }
}

/// The worst good's line: where it stops, the three rates, the station that would fix it.
struct BottleneckBanner: View {
    let good: Good
    let forecast: GoodForecast
    let workshop: WorkshopState
    let state: FlowState
    @Binding var sheet: LedgerSheet?
    @Environment(\.l10n) private var t

    var body: some View {
        let fix = StationText.fix(forecast.bottleneck, good: good, state: state)
        HStack(alignment: .center, spacing: Noir.s2) {
            BottleneckDot()
            Mark(Glyph.product(good.product), size: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: t(NeckText.key(forecast.bottleneck), t(GoodText.name(good))))
                    .font(.toon(13, .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: t("l4_neck_numbers", t.money(forecast.production), t.money(forecast.carried), t.money(forecast.demand)))
                    .font(.toon(11, .semibold)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2).minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let fix {
                Button { sheet = .station(fix) } label: {
                    Text(verbatim: t("l4_neck_fix"))
                        .font(.toon(14, .heavy))
                        .foregroundStyle(Color(hex: 0x1B1B28))
                        .padding(.horizontal, 14).frame(minHeight: 36)
                        .background(Toon.window, in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(minHeight: Noir.minTarget)
                .accessibilityIdentifier("neck.\(good.rawValue).fix")
            }
        }
        .padding(.leading, Noir.s2).padding(.trailing, Noir.s2).padding(.vertical, 4)
        .background(Color(hex: 0x6A2026).opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(hex: 0xE5484D).opacity(0.6), lineWidth: 1))
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
                Text(verbatim: t(QuarterText.name(quarter))).font(.toon(.subheadline, .bold))
                Spacer(minLength: 0)
                AttentionChip(attention: qs.attention, paused: qs.paused)
            }
            Meter(fraction: qs.attention / 100, tint: tier >= 2 ? Noir.danger : (tier == 1 ? Noir.amber : Noir.brass), height: 4)
            if tier > 0 || qs.paused {
                Text(verbatim: t(qs.paused ? "l4_paused_b" : "l4_tier_effect_\(tier)")).font(.toon(.caption2))
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
            Image(SceneArt.attention(tier: tier, paused: paused)).resizable().frame(width: 20, height: 20)
        }
        .font(.toon(.caption, .bold)).monospacedDigit()
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
            Image(SceneArt.contact(contact.id)).resizable().scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Mark(Glyph.product(contact.good.product), size: 18).padding(2)
                        .background(Color.black.opacity(0.55), in: Circle()).offset(x: 4, y: 4)
                }
                .saturation(owned == nil ? 0.2 : 1).opacity(owned == nil ? 0.7 : 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: t(ContactText.name(contact.id))).font(.toon(.subheadline, .semibold))
                if owned != nil {
                    Text(verbatim: t("l4_contact_line", t.money(Flow.contactAverageRate(state, contact.id) * 60),
                                     t.money(Flow.contactPrice(state, contact.id, average: true))))
                        .font(.toon(.caption)).monospacedDigit().foregroundStyle(Noir.inkSoft)
                    if contact.club {
                        let night = Flow.clubNight(state)
                        Label { Text(verbatim: t(night.on ? "l4_club_on" : "l4_club_off", t.duration(night.left))) } icon: {
                            Image(night.on ? "IconClubOn" : "IconClubOff").resizable().frame(width: 18, height: 18)
                        }
                        .font(.toon(.caption2, .bold)).monospacedDigit().foregroundStyle(night.on ? Noir.amber : Noir.inkSoft)
                    }
                    if contact.luxury, let trust = owned?.trust {
                        HStack(spacing: 2) {
                            ForEach(0..<FlowContent.maxTrust, id: \.self) { i in
                                Image(i < trust ? "IconTrustStar" : "IconTrustStarEmpty").resizable().frame(width: 16, height: 16)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: t("l4_trust", trust, FlowContent.maxTrust)))
                    }
                } else {
                    Text(verbatim: t(ContactText.desc(contact.id))).font(.toon(.caption)).foregroundStyle(Noir.inkSoft)
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
                        Text(verbatim: t.money(contact.unlockCost)).font(.toon(.caption, .semibold)).monospacedDigit().opacity(0.85)
                    }
                }
                .noirButton(state.cash >= contact.unlockCost ? .go : .secondary, fullWidth: false)
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
            Image(notice.danger ? "IconWarning" : "IconInfo").resizable().frame(width: 22, height: 22)
        }
        .font(.toon(.subheadline, .semibold))
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
