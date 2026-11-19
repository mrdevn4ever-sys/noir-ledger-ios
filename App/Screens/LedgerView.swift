import NoirCore
import SwiftUI

/// The sheets the ledger screen opens.
enum LedgerSheet: Identifiable, Equatable {
    case station(Station)
    case orders, crew, city, book, chapter, challenges, shop, rewards, settings

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
        }
    }
}

/// The whole operation on one portrait screen, top to bottom the way the goods move: the chapter and the next step,
/// where it stops, each workshop with its bench and shelf, the shared fleet, the contacts in their quarters.
struct LedgerView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t
    @State private var sheet: LedgerSheet?

    var body: some View {
        let s = store.state
        let f = store.forecast
        ScrollView {
            VStack(spacing: Noir.s3) {
                ChapterStrip(state: s, sheet: $sheet)
                if let hint = Flow.hint(s) { HintBubble(hint: hint) }
                ForEach(s.openGoods, id: \.self) { g in
                    if let gf = f.good(g), let w = s.workshop(g) {
                        BottleneckBanner(good: g, forecast: gf, workshop: w, state: s, sheet: $sheet)
                    }
                }
                ForEach(s.openGoods, id: \.self) { g in
                    WorkshopCard(good: g, state: s, forecast: f.good(g), sheet: $sheet)
                }
                if let next = Good.allCases.first(where: { !s.isOpen($0) }), FlowContent.good(next).chapter <= s.chapter {
                    LockedWorkshopCard(good: next, state: s)
                }
                FleetCard(state: s, forecast: f, sheet: $sheet)
                ContactsCard(state: s, sheet: $sheet)
                OrdersStrip(state: s, sheet: $sheet)
                NavRow(state: s, sheet: $sheet)
            }
            .padding(.horizontal, Noir.s4)
            .padding(.top, Noir.s3)
            .padding(.bottom, Noir.s6)
            .background(alignment: .topLeading) { ScreenMarker(identifier: "screen.ledger", title: t("app_name")) }
        }
        .background(Noir.ground)
        .safeAreaInset(edge: .top, spacing: 0) {
            LedgerTopBar(state: s, sheet: $sheet).dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let notice = store.notice { NoticeBanner(notice: notice).padding(Noir.s3) }
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
        }
    }
}

// MARK: - Top bar

struct LedgerTopBar: View {
    let state: FlowState
    @Binding var sheet: LedgerSheet?
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let waiting = state.meta.dailyLastDay < store.today ? 1 : 0
        VStack(spacing: Noir.s2) {
            HStack(spacing: Noir.s2) {
                pill(symbol: "seal.fill", text: t.decimal(Double(state.meta.favors), digits: 0), filled: false, plus: true) { sheet = .shop }
                    .accessibilityLabel(Text(verbatim: t("cd_favors", state.meta.favors)))
                    .accessibilityIdentifier("top.favors")
                Spacer(minLength: 0)
                Button { sheet = .book } label: {
                    Image(systemName: "book.closed.fill")
                        .frame(width: Noir.minTarget, height: Noir.minTarget)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Noir.brass)
                .accessibilityLabel(Text(verbatim: t("l4_book")))
                .accessibilityIdentifier("top.book")
                pill(symbol: waiting > 0 ? "gift.fill" : "gift", text: waiting > 0 ? "1" : nil, filled: waiting > 0, plus: false) { sheet = .rewards }
                    .accessibilityLabel(Text(verbatim: t("cd_rewards", waiting)))
                    .accessibilityIdentifier("top.rewards")
                Button { sheet = .settings } label: {
                    Image(systemName: "gearshape.fill")
                        .frame(width: Noir.minTarget, height: Noir.minTarget)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Noir.inkSoft)
                .accessibilityLabel(Text(verbatim: t("cd_settings")))
                .accessibilityIdentifier("top.settings")
            }
            HStack(alignment: .lastTextBaseline, spacing: Noir.s2) {
                RollingText(text: t.money(state.cash), value: state.cash)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(Noir.amber)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel(Text(verbatim: t("l4_cd_cash", t.money(state.cash))))
                    .accessibilityIdentifier("top.cash")
                Spacer(minLength: Noir.s2)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: t("l4_per_min", t.money(store.measuredIncome)))
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(Noir.ink)
                        .accessibilityIdentifier("top.income")
                    Text(verbatim: t("l4_income_now")).font(.caption2).foregroundStyle(Noir.inkSoft)
                    if state.meta.boostSeconds > 0 {
                        Label { Text(verbatim: "×2 · " + t.duration(state.meta.boostSeconds)).monospacedDigit() } icon: { Image(systemName: "bolt.fill") }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Noir.amber)
                    }
                }
            }
        }
        .padding(.horizontal, Noir.s4)
        .padding(.top, Noir.s2)
        .padding(.bottom, Noir.s2)
        .background(Noir.ground.opacity(0.97))
        .overlay(alignment: .bottom) { Rectangle().fill(Noir.hairline).frame(height: 1) }
    }

    private func pill(symbol: String, text: String?, filled: Bool, plus: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Noir.s1) {
                Image(systemName: symbol)
                if let text { Text(verbatim: text).monospacedDigit() }
                if plus { Image(systemName: "plus.circle.fill").foregroundStyle(Noir.amber) }
            }
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, Noir.s3)
            .frame(minHeight: Noir.minTarget)
            .foregroundStyle(filled ? Noir.onAmber : Noir.ink)
            .background(filled ? Noir.amberFill : Noir.raised, in: Capsule())
            .overlay(Capsule().strokeBorder(Noir.hairline, lineWidth: filled ? 0 : 1))
        }
        .buttonStyle(.plain)
    }
}

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

/// Where a good's flow stops right now, in numbers, with the station that would fix it.
struct BottleneckBanner: View {
    let good: Good
    let forecast: GoodForecast
    let workshop: WorkshopState
    let state: FlowState
    @Binding var sheet: LedgerSheet?
    @Environment(\.l10n) private var t

    var body: some View {
        let fix = StationText.fix(forecast.bottleneck, good: good, state: state)
        HStack(alignment: .top, spacing: Noir.s3) {
            Mark(Glyph.product(good.product), size: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: t(NeckText.key(forecast.bottleneck), t(GoodText.name(good))))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(forecast.bottleneck == .fleet || forecast.bottleneck == .shelf ? Noir.danger : Noir.ink)
                Text(verbatim: t("l4_neck_numbers", t.money(forecast.production), t.money(forecast.carried), t.money(forecast.demand)))
                    .font(.caption).monospacedDigit().foregroundStyle(Noir.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if !workshop.lead || !state.dispatcher {
                    Text(verbatim: t("l4_neck_manual")).font(.caption2).foregroundStyle(Noir.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let fix {
                Button { sheet = .station(fix) } label: { Text(verbatim: t("l4_neck_fix")) }
                    .noirButton(.primary, fullWidth: false)
                    .accessibilityIdentifier("neck.\(good.rawValue).fix")
            }
        }
        .padding(Noir.s3)
        .background(Noir.raised, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.hairline, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("neck.\(good.rawValue)")
    }
}

// MARK: - Workshop

/// One workshop: the room with its bench, the shelf that fills with crates, the lead.
struct WorkshopCard: View {
    let good: Good
    let state: FlowState
    let forecast: GoodForecast?
    @Binding var sheet: LedgerSheet?
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let w = state.workshop(good) ?? WorkshopState()
        let capacity = Flow.shelfCapacity(state, good)
        let full = w.stock >= capacity - 1e-9
        let running = w.cycle != nil
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoomScene(product: good.product, tier: min(3, Flow.milestonesReached(w.bench)), workers: w.lead ? 3 : 1,
                          running: running, pile: min(1, w.stock / max(1, capacity)))
                    .frame(height: 128)
                LinearGradient(colors: [Noir.ground.opacity(0.85), Noir.ground.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 56)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                HStack(alignment: .top, spacing: Noir.s2) {
                    Mark(Glyph.product(good.product), size: 26)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: t("l4_workshop", t(GoodText.name(good)))).font(.headline)
                        Text(verbatim: t(GoodText.role(good))).font(.caption2).foregroundStyle(Noir.inkSoft)
                    }
                    Spacer(minLength: 0)
                    if w.lead {
                        Portrait(crewId: FlowContent.good(good).lead, size: 30).clipShape(Circle())
                            .accessibilityHidden(true)
                    }
                }
                .padding(Noir.s2)
                .shadow(color: Noir.ground, radius: 3)
                if !w.lead && !running && !full {
                    Text(verbatim: t("l4_tap_bench"))
                        .font(.headline.weight(.heavy))
                        .padding(.horizontal, Noir.s4).padding(.vertical, Noir.s2)
                        .foregroundStyle(Noir.onAmber)
                        .background(Noir.amberFill, in: Capsule())
                        .shadow(color: Noir.amber.opacity(0.5), radius: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 128)
            .contentShape(Rectangle())
            .onTapGesture { store.dispatch(.tapBench(good)) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(verbatim: t("l4_cd_bench", t(GoodText.name(good)))))
            .accessibilityAction { store.dispatch(.tapBench(good)) }
            .accessibilityIdentifier("bench.\(good.rawValue)")
            Meter(fraction: w.cycle ?? 0, tint: SceneTint.product(good.product), height: 5)
            HStack(spacing: Noir.s2) {
                stationButton(title: t("l4_bench"), value: t("l4_per_min_crates", t.money((forecast?.production ?? 0))),
                              level: w.bench, id: "bench.\(good.rawValue).open", station: .bench(good))
                Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundStyle(Noir.inkSoft).accessibilityHidden(true)
                ShelfView(stock: w.stock, capacity: capacity, piling: forecast?.piling ?? 0)
                    .onTapGesture { sheet = .station(.shelf(good)) }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("shelf.\(good.rawValue)")
            }
            .padding(.horizontal, Noir.s3)
            .padding(.top, Noir.s3)
            if !w.lead { LeadRow(good: good, state: state) }
            Spacer(minLength: Noir.s3)
        }
        .foregroundStyle(Noir.ink)
        .background(Noir.leather)
        .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous)
            .strokeBorder(full ? Noir.danger.opacity(0.8) : Noir.leatherEdge, lineWidth: full ? 2 : 1))
        .environment(\.noirSurface, .leather)
    }

    private func stationButton(title: String, value: String, level: Int, id: String, station: Station) -> some View {
        Button { sheet = .station(station) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(.caption.weight(.bold)).foregroundStyle(Noir.inkSoft)
                Text(verbatim: value).font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(Noir.amber)
                Text(verbatim: t("l4_level", level)).font(.caption2).monospacedDigit().foregroundStyle(Noir.inkSoft)
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .padding(.horizontal, Noir.s2)
            .background(Noir.ground.opacity(0.45), in: RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

/// The shelf as crates: ten slots fill with the stock; a full shelf says so in words and colour.
struct ShelfView: View {
    let stock: Double
    let capacity: Double
    let piling: Double
    @Environment(\.l10n) private var t

    var body: some View {
        let fraction = capacity > 0 ? min(1, stock / capacity) : 0
        let full = fraction >= 0.999
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: t("l4_shelf")).font(.caption.weight(.bold)).foregroundStyle(Noir.inkSoft)
            HStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Double(i) < fraction * 10 - 0.001 ? (full ? Noir.danger : Noir.brass) : Noir.hairline.opacity(0.6))
                        .frame(height: 12)
                }
            }
            .accessibilityHidden(true)
            Text(verbatim: t("l4_shelf_count", t.decimal(stock.rounded(.down), digits: 0), t.money(capacity)))
                .font(.caption2.weight(.semibold)).monospacedDigit()
                .foregroundStyle(full ? Noir.danger : Noir.inkSoft)
            if full {
                Label { Text(verbatim: t("l4_shelf_full")) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                    .font(.caption2.weight(.bold)).foregroundStyle(Noir.danger)
            } else if piling > 0.01 {
                Text(verbatim: t("l4_shelf_filling", t.money(piling))).font(.caption2).foregroundStyle(Noir.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(.horizontal, Noir.s2)
        .padding(.vertical, 4)
        .background(Noir.ground.opacity(0.45), in: RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous))
        .contentShape(Rectangle())
    }
}

/// Hiring the workshop lead, until hired.
struct LeadRow: View {
    let good: Good
    let state: FlowState
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let def = FlowContent.good(good)
        let affordable = state.cash >= def.leadCost
        HStack(spacing: Noir.s3) {
            Portrait(crewId: def.lead, size: 42).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: t("l4_lead_t", Content.crewDef(def.lead)?.name ?? "")).font(.subheadline.weight(.semibold))
                Text(verbatim: t("l4_lead_b")).font(.caption).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { store.dispatch(.hireLead(good)) } label: {
                VStack(spacing: 2) {
                    Text(verbatim: t("l4_hire"))
                    Text(verbatim: t.money(def.leadCost)).font(.caption.weight(.semibold)).monospacedDigit().opacity(0.85)
                }
            }
            .noirButton(affordable ? .primary : .secondary, fullWidth: false)
            .disabled(!affordable)
            .accessibilityIdentifier("lead.\(good.rawValue)")
        }
        .padding(.horizontal, Noir.s3)
        .padding(.top, Noir.s3)
    }
}

struct LockedWorkshopCard: View {
    let good: Good
    let state: FlowState
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let def = FlowContent.good(good)
        let affordable = state.cash >= def.openCost
        HStack(spacing: Noir.s3) {
            Mark(Glyph.product(good.product), size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: t("l4_workshop", t(GoodText.name(good)))).font(.headline)
                Text(verbatim: t(GoodText.role(good))).font(.caption).foregroundStyle(Noir.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { store.dispatch(.openWorkshop(good)) } label: {
                VStack(spacing: 2) {
                    Text(verbatim: t("l4_open"))
                    Text(verbatim: t.money(def.openCost)).font(.caption.weight(.semibold)).monospacedDigit().opacity(0.85)
                }
            }
            .noirButton(affordable ? .primary : .secondary, fullWidth: false)
            .disabled(!affordable)
            .accessibilityIdentifier("workshop.\(good.rawValue).open")
        }
        .padding(Noir.s3)
        .foregroundStyle(Noir.ink)
        .background(SceneTint.wallDeep, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.amber.opacity(0.6), lineWidth: 1))
    }
}

// MARK: - Fleet

/// The shared fleet: the van on the street, the trip under way, what it carries per minute.
struct FleetCard: View {
    let state: FlowState
    let forecast: Forecast
    @Binding var sheet: LedgerSheet?
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let trip = state.trip
        let hottest = state.quarters.values.map(\.attention).max() ?? 0
        VStack(spacing: 0) {
            StreetScene(fronts: 0, selling: trip != nil, danger: Flow.tier(hottest) >= 2, police: Flow.tier(hottest) >= 2 ? 1 : 0)
                .frame(height: 110)
                .overlay(alignment: .topLeading) {
                    Text(verbatim: t("l4_fleet")).font(.headline).padding(Noir.s2).shadow(color: Noir.ground, radius: 3)
                }
                .accessibilityHidden(true)
            Meter(fraction: trip.map { 1 - $0.left / max(0.1, $0.duration) } ?? 0, tint: Noir.amber, height: 5)
            HStack(spacing: Noir.s2) {
                Button { sheet = .station(.fleet) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: t("l4_fleet_capacity")).font(.caption.weight(.bold)).foregroundStyle(Noir.inkSoft)
                        Text(verbatim: t("l4_fleet_rate", t.money(forecast.fleetCapacity))).font(.subheadline.weight(.bold))
                            .monospacedDigit().foregroundStyle(Noir.amber)
                        Text(verbatim: t("l4_fleet_used", t.percent(forecast.fleetCapacity > 0 ? min(1, forecast.fleetUsed / forecast.fleetCapacity) : 0)))
                            .font(.caption2).monospacedDigit().foregroundStyle(Noir.inkSoft)
                    }
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                    .padding(.horizontal, Noir.s2)
                    .background(Noir.ground.opacity(0.45), in: RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fleet.open")
                if !state.dispatcher {
                    Button { store.dispatch(.tapFleet) } label: {
                        Label { Text(verbatim: t(trip == nil ? "l4_fleet_go" : "l4_fleet_on_way")) } icon: { Image(systemName: "shippingbox.fill") }
                    }
                    .noirButton(trip == nil ? .primary : .secondary, fullWidth: false)
                    .disabled(trip != nil)
                    .accessibilityIdentifier("fleet.go")
                } else if let trip {
                    Text(verbatim: t("l4_fleet_trip", t.decimal(trip.crates, digits: 0), t.duration(trip.left)))
                        .font(.caption).monospacedDigit().foregroundStyle(Noir.inkSoft)
                        .frame(maxWidth: 140, alignment: .trailing)
                }
            }
            .padding(Noir.s3)
            if !state.dispatcher { DispatcherRow(state: state) }
        }
        .foregroundStyle(Noir.ink)
        .background(Noir.leather)
        .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.leatherEdge, lineWidth: 1))
        .environment(\.noirSurface, .leather)
    }
}

struct DispatcherRow: View {
    let state: FlowState
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let affordable = state.cash >= FlowContent.dispatcherCost
        HStack(spacing: Noir.s3) {
            Portrait(crewId: FlowContent.dispatcher, size: 42).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: t("l4_dispatcher_t", Content.crewDef(FlowContent.dispatcher)?.name ?? "")).font(.subheadline.weight(.semibold))
                Text(verbatim: t("l4_dispatcher_b")).font(.caption).foregroundStyle(Noir.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { store.dispatch(.hireDispatcher) } label: {
                VStack(spacing: 2) {
                    Text(verbatim: t("l4_hire"))
                    Text(verbatim: t.money(FlowContent.dispatcherCost)).font(.caption.weight(.semibold)).monospacedDigit().opacity(0.85)
                }
            }
            .noirButton(affordable ? .primary : .secondary, fullWidth: false)
            .disabled(!affordable)
            .accessibilityIdentifier("dispatcher.hire")
        }
        .padding(.horizontal, Noir.s3)
        .padding(.bottom, Noir.s3)
    }
}

// MARK: - Contacts

/// The contacts in their quarters: what they take, what they pay, how much attention the quarter has.
struct ContactsCard: View {
    let state: FlowState
    @Binding var sheet: LedgerSheet?
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        Panel(.anthracite) {
            HStack {
                Text(verbatim: t("l4_contacts")).font(.headline).accessibilityAddTraits(.isHeader)
                Spacer()
                Button { sheet = .city } label: { Label { Text(verbatim: t("l4_city")) } icon: { Image(systemName: "map.fill") } }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("contacts.city")
            }
            ForEach(Quarter.allCases.filter { state.quarters[$0] != nil }, id: \.self) { q in
                QuarterBlock(quarter: q, state: state, sheet: $sheet)
            }
        }
    }
}

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

struct OrdersStrip: View {
    let state: FlowState
    @Binding var sheet: LedgerSheet?
    @Environment(\.l10n) private var t

    var body: some View {
        if Flow.boardOpen(state) {
            Button { sheet = .orders } label: {
                VStack(alignment: .leading, spacing: Noir.s2) {
                    HStack {
                        Label { Text(verbatim: t("l4_orders")) } icon: { Image(systemName: "envelope.fill") }
                            .font(.headline)
                        Spacer()
                        if !state.offers.isEmpty {
                            Text(verbatim: t("l4_offers_waiting", state.offers.count))
                                .font(.caption.weight(.heavy))
                                .padding(.horizontal, Noir.s2).padding(.vertical, 3)
                                .foregroundStyle(Noir.onAmber)
                                .background(Noir.amberFill, in: Capsule())
                        }
                    }
                    ForEach(state.orders) { o in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: OrderText.items(o.offer, t)).font(.caption.weight(.semibold))
                            Meter(fraction: o.progress, tint: Noir.amber, height: 4)
                            Text(verbatim: t("l4_order_left", t.duration(max(0, o.deadline - state.time)))).font(.caption2)
                                .monospacedDigit().foregroundStyle(o.deadline - state.time < 60 ? Noir.danger : Noir.inkSoft)
                        }
                    }
                }
                .padding(Noir.s3)
                .foregroundStyle(Noir.ink)
                .background(Noir.raised, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous)
                    .strokeBorder(state.offers.isEmpty ? Noir.hairline : Noir.amber, lineWidth: state.offers.isEmpty ? 1 : 2))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nav.orders")
        }
    }
}

struct NavRow: View {
    let state: FlowState
    @Binding var sheet: LedgerSheet?
    @Environment(\.l10n) private var t

    var body: some View {
        HStack(spacing: Noir.s2) {
            item("l4_crew", "person.3.fill", .crew, "nav.crew")
            item("l4_city", "map.fill", .city, "nav.city")
            item("l4_book", "book.closed.fill", .book, "nav.book")
        }
    }

    private func item(_ key: String, _ symbol: String, _ target: LedgerSheet, _ id: String) -> some View {
        Button { sheet = target } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.title3)
                Text(verbatim: t(key)).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(Noir.ink)
            .background(Noir.raised, in: RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous).strokeBorder(Noir.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

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
