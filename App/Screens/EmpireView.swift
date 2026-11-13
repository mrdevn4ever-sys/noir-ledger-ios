import NoirCore
import SwiftUI

/// The empire at a glance: the street above, the stash and one lit room per production line. Every room is tapped
/// to speed it up and grown with one button; the workshop details behind it keep the fine controls.
struct EmpireView: View {
    @Environment(GameStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        let m = Economy.mods(s)
        @Bindable var router = router
        TabScreen("nav_ops", identifier: "screen.ops") {
            MissionStrip(state: s)
            if s.campaign.tutorial == .done {
                Picker(selection: $router.buyMode) {
                    ForEach(BuyMode.allCases) { mode in
                        Text(verbatim: mode == .max ? t("buy_max") : t("buy_times", mode.rawValue)).tag(mode)
                    }
                } label: {
                    Text(verbatim: t("buy_mode"))
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("empire.buyMode")
            }
            VStack(spacing: 0) {
                StreetFloor(state: s)
                StashFloor(state: s, mods: m)
                ForEach(ProductId.allCases, id: \.self) { p in
                    if s.line(p).owned {
                        LineFloor(product: p, state: s, mods: m)
                    } else {
                        LockedFloor(product: p, state: s)
                    }
                }
            }
            .background(Noir.leather)
            // The floors are a picture with captions: past this size the captions would cover the scenes.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .clipShape(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.leatherEdge, lineWidth: 1))
            Button {
                router.opsPath.append(.workshop)
            } label: {
                Label { Text(verbatim: t("empire_workshop")) } icon: { Image(systemName: "slider.horizontal.3") }
            }
            .noirButton(.secondary)
            .accessibilityIdentifier("empire.workshop")
        }
    }
}

// MARK: - Mission

/// What the campaign wants next, in one line; the books hold the details.
private struct MissionStrip: View {
    let state: GameState
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    var body: some View {
        if state.campaign.tutorial == .done {
            let objectives = Campaign.objectives(state)
            let done = objectives.filter(\.done).count
            Button {
                router.tab = .ledger
            } label: {
                HStack(spacing: Noir.s3) {
                    LedgerEmblem().frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: t(Labels.chapterTitle(state.campaign.chapter))).font(.subheadline.weight(.semibold))
                            .foregroundStyle(Noir.paperInk)
                        if objectives.isEmpty {
                            Text(verbatim: t(state.campaign.won ? "mission_won" : "mission_final")).font(.caption)
                                .foregroundStyle(Noir.paperInkSoft)
                        } else {
                            Meter(fraction: Double(done) / Double(objectives.count), tint: Noir.paperGold, height: 5)
                            Text(verbatim: t("mission_progress", done, objectives.count)).font(.caption).monospacedDigit()
                                .foregroundStyle(Noir.paperInkSoft)
                        }
                    }
                    Image(systemName: "chevron.right").imageScale(.small).foregroundStyle(Noir.paperInkSoft).accessibilityHidden(true)
                }
                .padding(Noir.s3)
                .frame(maxWidth: .infinity, minHeight: Noir.minTarget, alignment: .leading)
                .background(Noir.paper, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.paperEdge, lineWidth: 1))
                .environment(\.noirSurface, .paper)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("empire.mission")
        }
    }
}

// MARK: - Street

private struct StreetFloor: View {
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(AdService.self) private var ads
    @Environment(\.l10n) private var t

    var body: some View {
        let selling = state.incomeRate > 0.01 && !state.layLow
        let owned = FrontId.allCases.filter { state.front($0).owned }.count
        let multiplier = Idle.globalMultiplier(state)
        ZStack(alignment: .bottomLeading) {
            StreetScene(fronts: owned, selling: selling, danger: state.investigation != nil)
                .frame(height: 132)
            VStack(alignment: .leading, spacing: Noir.s1) {
                Text(verbatim: t("empire_income")).font(.caption).foregroundStyle(Noir.inkSoft)
                Text(verbatim: t("per_min", t.money(state.incomeRate * 60)))
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Noir.amber)
                    .accessibilityIdentifier("empire.income")
                HStack(spacing: Noir.s2) {
                    if multiplier > 1.001 {
                        chip(t("empire_payout", t.decimal(multiplier, digits: 2)), symbol: "arrow.up.right.circle.fill")
                    }
                    if Idle.boostActive(state) {
                        chip(t.duration(state.meta.boostSeconds), symbol: "bolt.fill")
                    }
                }
            }
            .padding(.horizontal, Noir.s3)
            .padding(.vertical, Noir.s2)
            // A solid plate: the number must read over lit windows, signs and rain.
            .background(Noir.ground.opacity(0.78), in: RoundedRectangle(cornerRadius: Noir.controlCorner, style: .continuous))
            .padding(Noir.s2)
        }
        .overlay(alignment: .topTrailing) {
            if state.campaign.tutorial == .done, !Idle.boostActive(state), store.rewardOffered(ads: ads) {
                Button {
                    store.claimReward(.boost, ads: ads)
                } label: {
                    Label {
                        Text(verbatim: t(state.meta.noAds ? "empire_boost_free" : "empire_boost_video"))
                    } icon: {
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
                .accessibilityIdentifier("empire.boost")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func chip(_ text: String, symbol: String) -> some View {
        Label { Text(verbatim: text).monospacedDigit() } icon: { Image(systemName: symbol) }
            .font(.caption.weight(.bold))
            .padding(.horizontal, Noir.s2)
            .padding(.vertical, 3)
            .foregroundStyle(Noir.onAmber)
            .background(Noir.amberFill, in: Capsule())
    }
}

// MARK: - Stash

private struct StashFloor: View {
    let state: GameState
    let mods: Mods
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let cap = Economy.stashCapacity(state, mods)
        let full = state.totalStock >= cap - 1e-6
        VStack(spacing: 0) {
            FloorEdge()
            StashScene(fraction: state.totalStock / max(1, cap), full: full)
                .frame(height: 58)
            HStack(spacing: Noir.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Label { Text(verbatim: t("stash_title")).font(.subheadline.weight(.semibold)) } icon: { Image(systemName: "archivebox") }
                    Text(verbatim: t("stash_fill", t.money(state.totalStock), t.money(cap)))
                        .font(.caption).monospacedDigit()
                        .foregroundStyle(full ? Noir.danger : Noir.inkSoft)
                        .accessibilityIdentifier("ops.stashFill")
                }
                Spacer(minLength: Noir.s2)
                if state.campaign.tutorial != .done {
                    EmptyView()
                } else if state.storageLevel < Content.maxStorageLevel {
                    let cost = Cost(dirty: Content.storageCost(currentLevel: state.storageLevel))
                    UpgradeButton(title: t("stash_upgrade"), cost: cost, affordable: cost.affordable(state), identifier: "ops.stash.upgrade") {
                        store.dispatch(.upgradeStorage)
                    }
                    .frame(maxWidth: 170)
                } else {
                    StatusChip(text: t("max"), symbol: "checkmark.seal")
                }
            }
            .padding(Noir.s3)
        }
        .foregroundStyle(Noir.ink)
        .environment(\.noirSurface, .leather)
    }
}

private struct FloorEdge: View {
    var body: some View {
        Rectangle().fill(Noir.brassDark.opacity(0.7)).frame(height: 2).accessibilityHidden(true)
    }
}

// MARK: - A running line

private struct LineFloor: View {
    let product: ProductId
    let state: GameState
    let mods: Mods
    @Environment(GameStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t
    @State private var floaters: [Floater] = []
    @State private var floaterSeq = 0

    var body: some View {
        let line = state.line(product)
        let stage = Idle.stage(line)
        let reached = Idle.milestonesReached(stage: stage)
        let cycle = Economy.cycleTime(state, product, mods)
        let fraction = cycle.isFinite && cycle > 0 ? min(1, max(0, line.progress / cycle)) : 0
        let working = line.running && line.status != .storageFull && line.status != .noCash
        VStack(spacing: 0) {
            FloorEdge()
            ZStack(alignment: .topLeading) {
                RoomScene(product: product, tier: min(3, reached), workers: 1 + min(3, reached), running: working)
                    .frame(height: 118)
                // A shade under the title, so it stays legible on any delivered room plate.
                LinearGradient(colors: [Noir.ground.opacity(0.8), Noir.ground.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 58)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                header(line: line, stage: stage)
                FloaterLayer(floaters: floaters)
            }
            .frame(height: 118)
            .contentShape(Rectangle())
            .onTapGesture { location in tap(at: location) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text(verbatim: t("empire_tap_hint")))
            .accessibilityAction { tap(at: CGPoint(x: 60, y: 60)) }
            .accessibilityIdentifier("line.\(product.rawValue).room")
            Meter(fraction: fraction, tint: SceneTint.product(product), height: 4)
            controls(line: line, stage: stage)
            if state.campaign.tutorial == .done, line.running, Idle.salesBound(state, product, mods) {
                BottleneckHint(product: product, state: state)
            }
        }
        .foregroundStyle(Noir.ink)
        .environment(\.noirSurface, .leather)
        .onChange(of: line.progress) { old, new in
            // Progress falls back when a batch is finished.
            if new < old - 0.001, working {
                float("+" + t.decimal(Economy.batchSize(state, product), digits: 0), at: CGPoint(x: 70, y: 84))
            }
        }
    }

    private func header(line: LineState, stage: Int) -> some View {
        HStack(alignment: .top, spacing: Noir.s2) {
            Mark(Glyph.product(product), size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: t(Labels.product(product))).font(.headline)
                Text(verbatim: t("empire_stage", stage)).font(.caption.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(Noir.inkSoft)
                    .accessibilityIdentifier("line.\(product.rawValue).stage")
            }
            Spacer(minLength: Noir.s2)
            VStack(alignment: .trailing, spacing: 2) {
                let multiplier = Idle.lineMultiplier(line)
                if multiplier > 1.001 {
                    Text(verbatim: t("empire_payout", t.decimal(multiplier, digits: 2)))
                        .font(.caption.weight(.heavy)).monospacedDigit()
                        .padding(.horizontal, Noir.s2).padding(.vertical, 2)
                        .foregroundStyle(Noir.onAmber)
                        .background(Noir.amberFill, in: Capsule())
                }
                if line.status != .running {
                    StatusChip(text: t(Labels.lineStatus(line.status)), symbol: "exclamationmark.circle",
                               danger: line.status == .noCash || line.status == .storageFull)
                        .accessibilityIdentifier("line.\(product.rawValue).status")
                }
            }
        }
        .padding(Noir.s2)
        .shadow(color: Noir.ground, radius: 3)
    }

    @ViewBuilder
    private func controls(line: LineState, stage: Int) -> some View {
        HStack(alignment: .center, spacing: Noir.s3) {
            VStack(alignment: .leading, spacing: 3) {
                RollingText(text: t("empire_line_income", t.money(income * 60)), value: income)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Noir.amber)
                if let next = Idle.nextMilestone(stage: stage) {
                    let previous = stage >= Idle.milestones[0] ? Idle.previousMilestone(stage: stage) : 1
                    Meter(fraction: Double(stage - previous) / Double(max(1, next - previous)), tint: Noir.brass, height: 5)
                    Text(verbatim: t("empire_next_milestone", next)).font(.caption).monospacedDigit().foregroundStyle(Noir.inkSoft)
                } else {
                    Text(verbatim: t("empire_all_milestones")).font(.caption).foregroundStyle(Noir.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !line.running {
                Button {
                    store.dispatch(.setLineRunning(product, true))
                } label: {
                    Label { Text(verbatim: t("line_start")) } icon: { Image(systemName: "play.fill") }
                }
                .noirButton(.primary)
                .frame(maxWidth: 170)
                .accessibilityIdentifier("line.\(product.rawValue).toggle")
            } else if state.campaign.tutorial != .done {
                // The briefing teaches the street first; upgrades open with chapter 1.
                Text(verbatim: t("empire_tap_hint")).font(.caption).foregroundStyle(Noir.inkSoft)
                    .frame(maxWidth: 170, alignment: .trailing)
            } else if let next = Idle.nextLineStep(state, product) {
                let plan = Idle.lineUpgradePlan(state, product, limit: router.buyMode.limit)
                let count = max(1, plan.count)
                let cost = plan.count > 0 ? plan.cost : next.cost
                Button {
                    store.dispatch(.upgradeLineAuto(product, router.buyMode.limit))
                } label: {
                    VStack(spacing: 2) {
                        Text(verbatim: t("empire_upgrade", count))
                        Text(verbatim: t("cost_dirty", t.money(cost))).font(.caption.weight(.medium)).monospacedDigit().opacity(0.85)
                    }
                }
                .noirButton(plan.count > 0 ? .primary : .secondary)
                .disabled(plan.count == 0)
                .frame(maxWidth: 170)
                .accessibilityHint(Text(verbatim: plan.count > 0 ? "" : t("err_not_affordable")))
                .accessibilityIdentifier("line.\(product.rawValue).auto")
            } else {
                StatusChip(text: t("max"), symbol: "checkmark.seal")
            }
        }
        .padding(Noir.s3)
    }

    /// What this line brings in per second at the current routes, stock aside.
    private var income: Double { Idle.lineIncome(state, product, mods) }

    private func tap(at location: CGPoint) {
        let before = store.state.dirty
        if store.dispatch(.hustle(product)) {
            let gained = store.state.dirty - before
            float(gained > 0.005 ? "+" + t.money(gained) : t("empire_hustle"), at: location)
        } else {
            float(t(state.line(product).status == .storageFull ? "empire_tap_full" : "empire_tap_idle"), at: location)
        }
    }

    private func float(_ text: String, at point: CGPoint) {
        floaterSeq += 1
        let id = floaterSeq
        floaters.append(Floater(id: id, text: text, at: point))
        if floaters.count > 12 { floaters.removeFirst(floaters.count - 12) }
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            floaters.removeAll { $0.id == id }
        }
    }
}

// MARK: - Bottleneck

/// Shown when a line makes more than the streets take: the honest answer is more routes, so say so and go there.
private struct BottleneckHint: View {
    let product: ProductId
    let state: GameState
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    var body: some View {
        Button {
            router.tab = .city
            router.cityPath = []
        } label: {
            HStack(spacing: Noir.s2) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath").accessibilityHidden(true)
                Text(verbatim: t("empire_bottleneck", t(Labels.product(product))))
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.right").imageScale(.small).accessibilityHidden(true)
            }
            .padding(.horizontal, Noir.s3)
            .padding(.vertical, Noir.s2)
            .frame(minHeight: Noir.minTarget)
            .foregroundStyle(Noir.amber)
            .background(Noir.amberContainer.opacity(0.35))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("line.\(product.rawValue).bottleneck")
    }
}

// MARK: - A line that is not open yet

private struct LockedFloor: View {
    let product: ProductId
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let def = Content.product(product)
        let unlocked = state.campaign.chapter >= def.unlockChapter
        VStack(spacing: 0) {
            FloorEdge()
            HStack(alignment: .center, spacing: Noir.s3) {
                Mark(Glyph.product(product), size: 30).opacity(0.55)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: t(Labels.product(product))).font(.headline)
                    Text(verbatim: t(Labels.productDesc(product))).font(.caption).foregroundStyle(Noir.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if unlocked {
                    let cost = Cost(dirty: def.lineCost)
                    UpgradeButton(title: t("line_open"), cost: cost, affordable: cost.affordable(state), primary: true,
                                  identifier: "line.\(product.rawValue).buy") {
                        store.dispatch(.buyLine(product))
                    }
                    .frame(maxWidth: 150)
                } else {
                    StatusChip(text: t("locked_chapter", def.unlockChapter), symbol: "lock.fill")
                }
            }
            .padding(Noir.s3)
            .frame(minHeight: 84)
            .background(SceneTint.wallDeep)
        }
        .foregroundStyle(Noir.ink)
        .environment(\.noirSurface, .anthracite)
    }
}
