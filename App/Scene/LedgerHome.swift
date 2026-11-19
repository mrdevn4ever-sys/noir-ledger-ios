import NoirCore
import SwiftUI

/// The game screen: the money on top, the chapter and the next step, the living building, and a bar of short ways
/// to orders, customers, crew, city and the ledger book.
struct LedgerView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t
    @State private var sheet: LedgerSheet?

    var body: some View {
        let s = store.state
        let f = store.forecast
        VStack(spacing: 0) {
            GameHUD(state: s, sheet: $sheet)
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: Noir.s2) {
                        ChapterStrip(state: s, sheet: $sheet)
                        if let hint = Flow.hint(s) { HintBubble(hint: hint) }
                        if s.counters.deliveries > 0 { BottleneckPanel(state: s, forecast: f, sheet: $sheet) }
                    }
                    .padding(.horizontal, Noir.s3)
                    .padding(.vertical, Noir.s2)
                    BuildingScene(state: s, forecast: f, sheet: $sheet)
                }
                .background(alignment: .topLeading) { ScreenMarker(identifier: "screen.ledger", title: t("app_name")) }
            }
            .background(Toon.skyTop)
            BottomBar(state: s, sheet: $sheet)
        }
        .background(Noir.ground)
        .overlay(alignment: .bottom) {
            if let notice = store.notice { NoticeBanner(notice: notice).padding(.horizontal, Noir.s3).padding(.bottom, 76) }
        }
        .sheet(item: $sheet) { kind in
            NavigationStack { sheetContent(kind) }
                .environment(\.l10n, t)
        }
    }

    @ViewBuilder
    private func sheetContent(_ kind: LedgerSheet) -> some View {
        switch kind {
        case .station(let st): StationSheet(station: st)
        case .orders: OrdersSheet()
        case .crew: CrewSheet()
        case .city: CitySheet()
        case .book: BookSheet()
        case .chapter: ChapterSheet()
        case .challenges: ChallengesSheet()
        case .shop: ShopView()
        case .rewards: RewardsView()
        case .settings: SettingsView()
        case .contacts: ContactsSheet()
        }
    }
}

// MARK: - Head-up display

/// Cash in a big coin pill, the real income of the last minute, favors, the daily gift, the book and settings.
struct GameHUD: View {
    let state: FlowState
    @Binding var sheet: LedgerSheet?
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let waiting = state.meta.dailyLastDay < store.today
        VStack(spacing: 6) {
            HStack(spacing: Noir.s2) {
                Button { sheet = .shop } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "seal.fill").foregroundStyle(Toon.pill)
                        Text(verbatim: t.decimal(Double(state.meta.favors), digits: 0)).monospacedDigit()
                        Image(systemName: "plus.circle.fill").foregroundStyle(Toon.up)
                    }
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 36)
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.35), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: t("cd_favors", state.meta.favors)))
                .accessibilityIdentifier("top.favors")
                Spacer(minLength: 0)
                hudButton("book.closed.fill", label: t("l4_book"), id: "top.book") { sheet = .book }
                hudButton(waiting ? "gift.fill" : "gift", label: t("cd_rewards", waiting ? 1 : 0), id: "top.rewards", dot: waiting) { sheet = .rewards }
                hudButton("gearshape.fill", label: t("cd_settings"), id: "top.settings") { sheet = .settings }
            }
            HStack(spacing: Noir.s2) {
                HStack(spacing: 8) {
                    Circle().fill(Toon.window).frame(width: 30, height: 30)
                        .overlay(Text(verbatim: "€").font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(Color(hex: 0x8A6410)))
                        .overlay(Circle().stroke(Color(hex: 0xC89520), lineWidth: 2))
                    RollingText(text: t.money(state.cash), value: state.cash)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .padding(.leading, 6).padding(.trailing, 14).padding(.vertical, 4)
                .background(Color.black.opacity(0.35), in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: t("l4_cd_cash", t.money(state.cash))))
                .accessibilityIdentifier("top.cash")
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(verbatim: t("l4_per_min", t.money(store.measuredIncome)))
                        .font(.system(size: 17, weight: .heavy, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Toon.up)
                        .accessibilityIdentifier("top.income")
                    if state.meta.boostSeconds > 0 {
                        Label { Text(verbatim: "×2 · " + t.duration(state.meta.boostSeconds)).monospacedDigit() } icon: { Image(systemName: "bolt.fill") }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Toon.window)
                    } else {
                        Text(verbatim: t("l4_income_now")).font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(.horizontal, Noir.s3)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(Toon.skyTop)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    private func hudButton(_ symbol: String, label: String, id: String, dot: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.35), in: Circle())
                .overlay(alignment: .topTrailing) {
                    if dot { Circle().fill(Color(hex: 0xE5484D)).frame(width: 11, height: 11).offset(x: 1, y: -1) }
                }
        }
        .buttonStyle(.plain)
        .frame(minWidth: Noir.minTarget, minHeight: Noir.minTarget)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityIdentifier(id)
    }
}

// MARK: - Bottom bar

struct BottomBar: View {
    let state: FlowState
    @Binding var sheet: LedgerSheet?
    @Environment(\.l10n) private var t

    var body: some View {
        HStack(spacing: 0) {
            item("envelope.fill", "l4_orders", .orders, "nav.orders", badge: Flow.boardOpen(state) ? state.offers.count : 0)
            item("person.2.fill", "l4_customers", .contacts, "nav.contacts")
            item("person.3.fill", "l4_crew", .crew, "nav.crew")
            item("map.fill", "l4_city", .city, "nav.city")
            item("book.closed.fill", "l4_book", .book, "nav.book")
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(Toon.skyTop.overlay(Rectangle().fill(Color.black.opacity(0.25))))
        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1) }
    }

    private func item(_ symbol: String, _ key: String, _ target: LedgerSheet, _ id: String, badge: Int = 0) -> some View {
        Button { sheet = target } label: {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 20, weight: .bold))
                    .frame(width: 44, height: 30)
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 {
                            Text(verbatim: "\(badge)").font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white).frame(minWidth: 18, minHeight: 18)
                                .background(Color(hex: 0xE5484D), in: Capsule())
                                .offset(x: 6, y: -4)
                        }
                    }
                Text(verbatim: t(key)).font(.system(size: 11, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

// MARK: - Customers

/// The contacts in their quarters: what they take, what they pay, the attention of the quarter.
struct ContactsSheet: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t
    @State private var station: LedgerSheet?

    var body: some View {
        let s = store.state
        SheetFrame("l4_customers", identifier: "screen.contacts") {
            Text(verbatim: t("l4_explain_contact")).font(.subheadline).foregroundStyle(Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Quarter.allCases.filter { s.quarters[$0] != nil }, id: \.self) { q in
                Panel(.anthracite) {
                    QuarterBlock(quarter: q, state: s, sheet: $station)
                }
            }
        }
        .sheet(item: $station) { kind in
            if case .station(let st) = kind {
                NavigationStack { StationSheet(station: st) }.environment(\.l10n, t)
            }
        }
    }
}
