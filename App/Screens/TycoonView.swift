import NoirCore
import SwiftUI

/// The sheets the main screen opens.
enum TycoonSheet: String, Identifiable {
    case shop, rewards, settings, deals, city
    var id: String { rawValue }
}

/// The whole game on one screen: the street on top, one floor per drug below, the board of missions in between.
struct TycoonView: View {
    @Environment(TycoonStore.self) private var store
    @Environment(\.l10n) private var t
    @State private var sheet: TycoonSheet?
    @State private var buyMode: BuyMode = .one

    var body: some View {
        let s = store.state
        ScrollView {
            VStack(spacing: Noir.s3) {
                if let hint = Tycoon.hint(s) { HintBubble(hint: hint) }
                StreetPanel(state: s)
                MissionBoard(state: s)
                Picker(selection: $buyMode) {
                    ForEach(BuyMode.allCases) { mode in
                        Text(verbatim: mode == .max ? t("buy_max") : t("buy_times", mode.rawValue)).tag(mode)
                    }
                } label: {
                    Text(verbatim: t("buy_mode"))
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("tycoon.buyMode")
                ForEach(FloorId.allCases, id: \.self) { f in
                    if Tycoon.isOpen(s, f) {
                        FloorCard(floor: f, state: s, buyMode: buyMode)
                    } else {
                        LockedFloorCard(floor: f, state: s)
                    }
                }
                HStack(spacing: Noir.s3) {
                    Button { sheet = .deals } label: {
                        Label { Text(verbatim: t("ty_deals")) } icon: { Image(systemName: "doc.text.fill") }
                    }
                    .noirButton(.secondary)
                    .accessibilityIdentifier("tycoon.deals")
                    Button { sheet = .city } label: {
                        Label { Text(verbatim: t("ty_city")) } icon: { Image(systemName: "train.side.front.car") }
                    }
                    .noirButton(Tycoon.reputationGain(s) >= 1 ? .primary : .secondary)
                    .accessibilityIdentifier("tycoon.city")
                }
            }
            .padding(.horizontal, Noir.s4)
            .padding(.top, Noir.s3)
            .padding(.bottom, Noir.s6)
            .background(alignment: .topLeading) { ScreenMarker(identifier: "screen.tycoon", title: t("app_name")) }
        }
        .background(Noir.ground)
        .safeAreaInset(edge: .top, spacing: 0) { TopBar(state: s, sheet: $sheet).dynamicTypeSize(...DynamicTypeSize.xxLarge) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let notice = store.notice { NoticeBanner(notice: notice).padding(Noir.s3) }
        }
        .sheet(item: $sheet) { kind in
            NavigationStack { sheetContent(kind) }
                .environment(\.l10n, t)
        }
    }

    @ViewBuilder
    private func sheetContent(_ kind: TycoonSheet) -> some View {
        switch kind {
        case .shop: ShopView()
        case .rewards: RewardsView()
        case .settings: SettingsView()
        case .deals: DealsSheet()
        case .city: CitySheet()
        }
    }
}

// MARK: - Top bar

struct TopBar: View {
    let state: TycoonState
    @Binding var sheet: TycoonSheet?
    @Environment(TycoonStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let waiting = Tycoon.claimableMissions(state) + (state.meta.dailyLastDay < store.today ? 1 : 0)
        VStack(spacing: Noir.s2) {
            HStack(spacing: Noir.s2) {
                pill(symbol: "seal.fill", text: t.decimal(Double(state.meta.favors), digits: 0), filled: false, plus: true) { sheet = .shop }
                    .accessibilityLabel(Text(verbatim: t("cd_favors", state.meta.favors)))
                    .accessibilityIdentifier("top.favors")
                if state.meta.reputation > 0 {
                    Label { Text(verbatim: t("ty_rep_chip", state.meta.reputation)).monospacedDigit() } icon: { Image(systemName: "star.fill") }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Noir.brass)
                }
                Spacer(minLength: 0)
                pill(symbol: waiting > 0 ? "gift.fill" : "gift", text: waiting > 0 ? t.decimal(Double(waiting), digits: 0) : nil,
                     filled: waiting > 0, plus: false) { sheet = .rewards }
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
                    .accessibilityLabel(Text(verbatim: t("ty_cd_cash", t.money(state.cash))))
                    .accessibilityIdentifier("top.cash")
                Spacer(minLength: Noir.s2)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: t("ty_per_sec", t.money(max(Tycoon.managedRate(state), state.incomeRate))))
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(Noir.inkSoft)
                    if state.meta.boostSeconds > 0 {
                        Label { Text(verbatim: "×2 · " + t.duration(state.meta.boostSeconds)).monospacedDigit() } icon: { Image(systemName: "bolt.fill") }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Noir.amber)
                    }
                }
            }
            HeatBar(state: state)
        }
        .padding(.horizontal, Noir.s4)
        .padding(.vertical, Noir.s2)
        .background(Noir.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(Noir.hairline).frame(height: 1) }
    }

    private func pill(symbol: String, text: String?, filled: Bool, plus: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Noir.s1) {
                Image(systemName: symbol).foregroundStyle(filled ? Noir.onAmber : Noir.brass)
                if let text { Text(verbatim: text).font(.subheadline.weight(.bold)).monospacedDigit() }
                if plus { Image(systemName: "plus.circle.fill").foregroundStyle(Noir.amber) }
            }
            .padding(.horizontal, Noir.s3)
            .frame(minHeight: 36)
            .foregroundStyle(filled ? Noir.onAmber : Noir.ink)
            .background(filled ? Noir.amberFill : Noir.raised, in: Capsule())
            .overlay(Capsule().strokeBorder(Noir.hairline, lineWidth: 1))
            .frame(minHeight: Noir.minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Heat as a thin bar that turns into a countdown when the police are at the door.
struct HeatBar: View {
    let state: TycoonState
    @Environment(\.l10n) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: Noir.s1) {
                Image(systemName: state.police != nil ? "light.beacon.max.fill" : "flame.fill").imageScale(.small)
                if let p = state.police {
                    Text(verbatim: t("ty_police_banner", t.duration(max(0, p.deadline - state.time)))).font(.caption.weight(.bold))
                } else {
                    Text(verbatim: t("ty_heat")).font(.caption.weight(.semibold))
                }
                Spacer(minLength: 0)
                Text(verbatim: t.decimal(state.heat, digits: 0)).font(.caption.weight(.bold)).monospacedDigit()
            }
            .foregroundStyle(state.police != nil || state.heat >= 75 ? Noir.danger : Noir.inkSoft)
            Meter(fraction: state.heat / 100, tint: state.heat >= 75 ? Noir.danger : Noir.amber, height: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("top.heat")
    }
}

// MARK: - Street

/// The night street: the police, a suitcase now and then, the van, and the sponsor's boost.
struct StreetPanel: View {
    let state: TycoonState
    @Environment(TycoonStore.self) private var store
    @Environment(AdService.self) private var ads
    @Environment(\.l10n) private var t

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                StreetScene(fronts: 0, selling: state.incomeRate > 0.01, danger: state.police != nil,
                            police: state.police != nil ? 2 : (state.heat >= 75 ? 1 : 0))
                if let c = state.suitcase {
                    Button {
                        if let gained = store.dispatch(.grabSuitcase), gained > 0 { store.show("ty_suitcase_got") }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "suitcase.fill").font(.title2)
                            Text(verbatim: "+" + t.money(c.amount)).font(.caption.weight(.heavy)).monospacedDigit()
                        }
                        .padding(Noir.s2)
                        .foregroundStyle(Noir.onAmber)
                        .background(Noir.amberFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: Noir.amber.opacity(0.6), radius: 10)
                    }
                    .buttonStyle(.plain)
                    .position(x: geo.size.width * c.position, y: geo.size.height * 0.62)
                    .accessibilityLabel(Text(verbatim: t("ty_suitcase", t.money(c.amount))))
                    .accessibilityIdentifier("street.suitcase")
                }
                VStack(alignment: .leading, spacing: Noir.s2) {
                    Spacer(minLength: 0)
                    if state.police != nil { policeControls }
                }
                .padding(Noir.s2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.nightEdge, lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            if state.meta.boostSeconds <= 0, store.rewardOffered(ads: ads) {
                Button {
                    store.claimReward(.boost, ads: ads)
                } label: {
                    Label { Text(verbatim: t("empire_boost_video")) } icon: {
                        Image(systemName: state.meta.noAds ? "bolt.fill" : "play.rectangle.fill")
                    }
                    .font(.footnote.weight(.bold))
                    .padding(.horizontal, Noir.s3)
                    .frame(minHeight: Noir.minTarget)
                    .foregroundStyle(Noir.onAmber)
                    .background(Noir.amberFill, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(Noir.s2)
                .accessibilityIdentifier("street.boost")
            }
        }
    }

    private var policeControls: some View {
        HStack(spacing: Noir.s2) {
            Button {
                store.dispatch(.bribe)
            } label: {
                Label { Text(verbatim: t("ty_bribe", t.money(Tycoon.bribeCost(state)))).monospacedDigit() } icon: {
                    Image(systemName: "banknote.fill")
                }
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, Noir.s3)
                .frame(minHeight: Noir.minTarget)
                .foregroundStyle(Noir.onDanger)
                .background(Noir.dangerFill, in: Capsule())
                .overlay(Capsule().strokeBorder(Noir.danger, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("street.bribe")
            if state.meta.heatAidCooldown <= 0, store.rewardOffered(ads: ads) {
                Button {
                    store.claimReward(.coolHeat, ads: ads)
                } label: {
                    Label { Text(verbatim: t("ty_police_video")) } icon: {
                        Image(systemName: state.meta.noAds ? "hand.wave.fill" : "play.rectangle.fill")
                    }
                    .font(.footnote.weight(.bold))
                    .padding(.horizontal, Noir.s3)
                    .frame(minHeight: Noir.minTarget)
                    .foregroundStyle(Noir.onAmber)
                    .background(Noir.amberFill, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("street.policeVideo")
            }
        }
    }
}

// MARK: - Missions and hints

enum TycoonText {
    static func mission(_ m: MissionDef, _ t: L10n) -> String {
        switch m.kind {
        case .own(let f, let n): t("ty_m_own", n, t(Labels.product(f.product)))
        case .manager(let f): t("ty_m_manager", t(Labels.product(f.product)))
        case .earn(let amount): t("ty_m_earn", t.money(amount))
        case .taps(let n): t("ty_m_taps", n)
        case .suitcases(let n): t("ty_m_suitcases", n)
        case .bribes(let n): t("ty_m_bribes", n)
        case .deals(let n): t("ty_m_deals", n)
        case .prestige(let n): t("ty_m_prestige", n)
        }
    }

    static func hint(_ h: TycoonHint) -> String {
        switch h {
        case .tapWeed: "ty_hint_tap"
        case .buyWeed: "ty_hint_buy"
        case .openPills: "ty_hint_open"
        case .hireManager: "ty_hint_manager"
        }
    }
}

struct HintBubble: View {
    let hint: TycoonHint
    @Environment(\.l10n) private var t

    var body: some View {
        Label { Text(verbatim: t(TycoonText.hint(hint))).fixedSize(horizontal: false, vertical: true) } icon: {
            Image(systemName: "hand.point.down.fill")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Noir.paperInk)
        .padding(Noir.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Noir.paper, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .accessibilityIdentifier("tycoon.hint")
    }
}

/// Three small jobs with an instant reward.
struct MissionBoard: View {
    let state: TycoonState
    @Environment(TycoonStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let missions = Tycoon.activeMissions(state)
        if !missions.isEmpty {
            Panel(.paper) {
                Text(verbatim: t("ty_missions")).font(.headline).accessibilityAddTraits(.isHeader)
                ForEach(missions) { m in
                    let p = Tycoon.missionProgress(state, m)
                    let done = Tycoon.missionDone(state, m)
                    HStack(spacing: Noir.s3) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(verbatim: TycoonText.mission(m, t)).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            Meter(fraction: p.target > 0 ? min(1, p.current / p.target) : 1, tint: Noir.paperGold, height: 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            store.dispatch(.claimMission(m.id))
                        } label: {
                            Label { Text(verbatim: t("ty_claim", m.reward)).monospacedDigit() } icon: { Image(systemName: "seal.fill") }
                        }
                        .noirButton(done ? .primary : .secondary, fullWidth: false)
                        .disabled(!done)
                        .accessibilityIdentifier("mission.\(m.id)")
                    }
                }
            }
        }
    }
}

// MARK: - Floors

/// One floor: its room, the cycle bar, the buy button and, until hired, its manager.
struct FloorCard: View {
    let floor: FloorId
    let state: TycoonState
    let buyMode: BuyMode
    @Environment(TycoonStore.self) private var store
    @Environment(\.l10n) private var t
    @State private var floaters: [Floater] = []
    @State private var floaterSeq = 0

    var body: some View {
        let fl = state.floor(floor)
        let p = floor.product
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoomScene(product: p, tier: min(3, Tycoon.milestonesReached(fl.count)), workers: fl.manager ? 3 : 1,
                          running: fl.running || fl.manager)
                    .frame(height: 124)
                LinearGradient(colors: [Noir.ground.opacity(0.8), Noir.ground.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 58)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                header(fl)
                if !fl.running && !fl.manager {
                    Text(verbatim: t("ty_tap_to_sell"))
                        .font(.headline.weight(.heavy))
                        .padding(.horizontal, Noir.s4).padding(.vertical, Noir.s2)
                        .foregroundStyle(Noir.onAmber)
                        .background(Noir.amberFill, in: Capsule())
                        .shadow(color: Noir.amber.opacity(0.5), radius: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }
                FloaterLayer(floaters: floaters)
            }
            .frame(height: 124)
            .contentShape(Rectangle())
            .onTapGesture { location in
                if store.dispatch(.tapFloor(floor)) != nil, !fl.manager, !fl.running {
                    float(t("ty_tap_go"), at: location)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(verbatim: t("ty_cd_room", t(Labels.product(p)), fl.count)))
            .accessibilityAction { store.dispatch(.tapFloor(floor)) }
            .accessibilityIdentifier("floor.\(floor.rawValue)")
            Meter(fraction: fl.running || fl.manager ? fl.progress : 0, tint: SceneTint.product(p), height: 6)
            controls(fl)
            if !fl.manager { ManagerRow(floor: floor, state: state) }
        }
        .foregroundStyle(Noir.ink)
        .background(Noir.leather)
        .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.leatherEdge, lineWidth: 1))
        .environment(\.noirSurface, .leather)
        .onChange(of: store.payouts[floor]?.seq) { _, _ in
            if let amount = store.payouts[floor]?.amount { float("+" + t.money(amount), at: CGPoint(x: 90, y: 92)) }
        }
    }

    private func header(_ fl: FloorState) -> some View {
        HStack(alignment: .top, spacing: Noir.s2) {
            Mark(Glyph.product(floor.product), size: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: t(Labels.product(floor.product))).font(.headline)
                Text(verbatim: t("ty_count", fl.count)).font(.caption.weight(.bold)).monospacedDigit()
                    .foregroundStyle(Noir.inkSoft)
                    .accessibilityIdentifier("floor.\(floor.rawValue).count")
            }
            Spacer(minLength: 0)
            if fl.manager {
                HStack(spacing: Noir.s1) {
                    Portrait(crewId: TycoonContent.floor(floor).managerId, size: 30)
                        .clipShape(Circle())
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Noir.amber).imageScale(.small)
                }
                .accessibilityHidden(true)
            }
        }
        .padding(Noir.s2)
        .shadow(color: Noir.ground, radius: 3)
    }

    private func controls(_ fl: FloorState) -> some View {
        let units = buyMode == .max ? max(1, Tycoon.affordableUnits(state, floor)) : buyMode.rawValue
        let cost = Tycoon.unitsCost(state, floor, units)
        let affordable = state.cash >= cost - 1e-9
        let cycle = Tycoon.cycleTime(state, floor)
        return HStack(alignment: .center, spacing: Noir.s3) {
            VStack(alignment: .leading, spacing: 3) {
                if cycle >= 0.5 {
                    Text(verbatim: t("ty_per_cycle", t.money(Tycoon.revenuePerCycle(state, floor))))
                        .font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(Noir.amber)
                    Text(verbatim: t("ty_cycle", t.decimal(cycle, digits: cycle < 10 ? 1 : 0)))
                        .font(.caption).monospacedDigit().foregroundStyle(Noir.inkSoft)
                } else {
                    Text(verbatim: t("ty_per_sec", t.money(Tycoon.floorRate(state, floor))))
                        .font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(Noir.amber)
                }
                if let next = Tycoon.nextMilestone(fl.count) {
                    let previous = TycoonContent.milestones.last { $0 <= fl.count } ?? 0
                    Meter(fraction: Double(fl.count - previous) / Double(max(1, next - previous)), tint: Noir.brass, height: 4)
                    Text(verbatim: t("ty_next_ms", next)).font(.caption2).monospacedDigit().foregroundStyle(Noir.inkSoft)
                } else {
                    Text(verbatim: t("ty_all_ms")).font(.caption2).foregroundStyle(Noir.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                store.dispatch(.buy(floor, buyMode == .max ? 0 : units))
            } label: {
                VStack(spacing: 2) {
                    Text(verbatim: t("ty_buy", units))
                    Text(verbatim: t.money(cost)).font(.caption.weight(.semibold)).monospacedDigit().opacity(0.85)
                }
            }
            .noirButton(affordable ? .primary : .secondary)
            .disabled(!affordable)
            .frame(maxWidth: 170)
            .accessibilityIdentifier("floor.\(floor.rawValue).buy")
        }
        .padding(Noir.s3)
    }

    private func float(_ text: String, at point: CGPoint) {
        floaterSeq += 1
        let id = floaterSeq
        floaters.append(Floater(id: id, text: text, at: point))
        if floaters.count > 10 { floaters.removeFirst(floaters.count - 10) }
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            floaters.removeAll { $0.id == id }
        }
    }
}

/// The floor's manager, until hired: a face, a name and what they do.
struct ManagerRow: View {
    let floor: FloorId
    let state: TycoonState
    @Environment(TycoonStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let def = TycoonContent.floor(floor)
        let name = Content.crewDef(def.managerId)?.name ?? ""
        let affordable = state.cash >= def.managerCost
        HStack(spacing: Noir.s3) {
            Portrait(crewId: def.managerId, size: 44).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: t("ty_manager_t", name)).font(.subheadline.weight(.semibold))
                Text(verbatim: t("ty_manager_b")).font(.caption).foregroundStyle(Noir.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                store.dispatch(.hireManager(floor))
            } label: {
                VStack(spacing: 2) {
                    Text(verbatim: t("ty_manager_hire"))
                    Text(verbatim: t.money(def.managerCost)).font(.caption.weight(.semibold)).monospacedDigit().opacity(0.85)
                }
            }
            .noirButton(affordable ? .primary : .secondary, fullWidth: false)
            .disabled(!affordable)
            .accessibilityIdentifier("floor.\(floor.rawValue).manager")
        }
        .padding(.horizontal, Noir.s3)
        .padding(.bottom, Noir.s3)
    }
}

/// A floor that is not open yet.
struct LockedFloorCard: View {
    let floor: FloorId
    let state: TycoonState
    @Environment(TycoonStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let def = TycoonContent.floor(floor)
        let canOpen = Tycoon.canOpen(state, floor)
        let affordable = state.cash >= def.unlockCost
        HStack(alignment: .center, spacing: Noir.s3) {
            Mark(Glyph.product(floor.product), size: 34).opacity(canOpen ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: t(Labels.product(floor.product))).font(.headline)
                Text(verbatim: t(Labels.productDesc(floor.product))).font(.caption).foregroundStyle(Noir.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if canOpen {
                Button {
                    store.dispatch(.open(floor))
                } label: {
                    VStack(spacing: 2) {
                        Text(verbatim: t("ty_open"))
                        Text(verbatim: t.money(def.unlockCost)).font(.caption.weight(.semibold)).monospacedDigit().opacity(0.85)
                    }
                }
                .noirButton(affordable ? .primary : .secondary, fullWidth: false)
                .disabled(!affordable)
                .accessibilityIdentifier("floor.\(floor.rawValue).open")
            } else if let i = FloorId.allCases.firstIndex(of: floor), i > 0 {
                StatusChip(text: t("ty_open_after", t(Labels.product(FloorId.allCases[i - 1].product))), symbol: "lock.fill")
            }
        }
        .padding(Noir.s3)
        .frame(minHeight: 84)
        .foregroundStyle(Noir.ink)
        .background(SceneTint.wallDeep, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.hairline, lineWidth: 1))
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
    @Environment(TycoonStore.self) private var store
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
