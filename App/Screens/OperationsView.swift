import NoirCore
import SwiftUI

/// The workshop: the shared stash and the four production lines.
struct OperationsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        let m = Economy.mods(s)
        TabScreen("nav_ops", identifier: "screen.ops") {
            StashPanel(state: s, mods: m)
            SectionHeading(title: t("ops_lines"))
            ForEach(ProductId.allCases, id: \.self) { p in
                if s.line(p).owned {
                    LinePanel(product: p, state: s, mods: m)
                } else {
                    LockedLinePanel(product: p, state: s)
                }
            }
        }
    }
}

private struct StashPanel: View {
    let state: GameState
    let mods: Mods
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let cap = Economy.stashCapacity(state, mods)
        let full = state.totalStock >= cap - 1e-6
        Panel(.leather) {
            HStack {
                Label { Text(verbatim: t("stash_title")).font(.headline) } icon: { Image(systemName: "archivebox") }
                Spacer()
                Text(verbatim: t("level", state.storageLevel, Content.maxStorageLevel)).font(.caption.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(Noir.inkSoft)
            }
            Meter(fraction: state.totalStock / max(1, cap), tint: full ? Noir.danger : Noir.amber)
            Text(verbatim: t("stash_fill", t.money(state.totalStock), t.money(cap)))
                .font(.subheadline).monospacedDigit()
                .foregroundStyle(full ? Noir.danger : Noir.inkSoft)
                .accessibilityIdentifier("ops.stashFill")
            HStack(spacing: Noir.s3) {
                ForEach(ProductId.allCases.filter { state.stock($0) > 0.05 }, id: \.self) { p in
                    Label { Text(verbatim: t.money(state.stock(p))).monospacedDigit() } icon: { Mark(Glyph.product(p), size: 18) }
                        .font(.caption)
                        .foregroundStyle(Noir.inkSoft)
                        .accessibilityLabel(Text(verbatim: "\(t(Labels.product(p))) \(t.money(state.stock(p)))"))
                }
            }
            if state.storageLevel < Content.maxStorageLevel {
                let cost = Cost(dirty: Content.storageCost(currentLevel: state.storageLevel))
                UpgradeButton(title: t("stash_upgrade"), cost: cost, affordable: cost.affordable(state), identifier: "ops.stash.upgrade") {
                    store.dispatch(.upgradeStorage)
                }
            } else {
                StatusChip(text: t("max"), symbol: "checkmark.seal")
            }
        }
    }
}

private struct LinePanel: View {
    let product: ProductId
    let state: GameState
    let mods: Mods
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let line = state.line(product)
        let rate = Economy.productionRate(state, product, mods)
        Panel(.leather) {
            HeaderRow {
                Label { Text(verbatim: t(Labels.product(product))).font(.headline) } icon: { Mark(Glyph.product(product), size: 28) }
                    .accessibilityAddTraits(.isHeader)
            } trailing: {
                StatusChip(text: t(Labels.lineStatus(line.status)), symbol: statusSymbol(line.status),
                           danger: line.status == .noCash || line.status == .storageFull)
                    .accessibilityIdentifier("line.\(product.rawValue).status")
            }
            ValueRow(label: t("line_rate", t.decimal(rate.isFinite ? rate * 60 : 0, digits: 1)), value: t("line_stock", t.money(state.stock(product))))
            ValueRow(label: t("line_unit_cost", t.money(Economy.unitCost(state, product, mods))),
                     value: t("route_price", t.money(Content.product(product).basePrice * Economy.qualityMult(state, product) * mods.price)))
            Button {
                store.dispatch(.setLineRunning(product, !line.running))
            } label: {
                Label { Text(verbatim: t(line.running ? "line_stop" : "line_start")) } icon: {
                    Image(systemName: line.running ? "pause.fill" : "play.fill")
                }
            }
            .noirButton(line.running ? .secondary : .primary)
            .accessibilityIdentifier("line.\(product.rawValue).toggle")
            PanelDivider()
            ForEach(LineTrack.allCases, id: \.self) { track in
                TrackRow(product: product, track: track, state: state)
            }
        }
    }

    private func statusSymbol(_ s: LineStatus) -> String {
        switch s {
        case .idle: "pause.circle"
        case .running: "gearshape.2"
        case .storageFull: "archivebox.fill"
        case .noCash: "xmark.circle"
        case .emergency: "wrench.adjustable"
        }
    }
}

private struct TrackRow: View {
    let product: ProductId
    let track: LineTrack
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let level = state.line(product).level(track)
        VStack(alignment: .leading, spacing: Noir.s1) {
            HStack {
                Text(verbatim: t(Labels.track(track))).font(.subheadline.weight(.semibold))
                Spacer()
                Text(verbatim: valueText(level)).font(.subheadline).monospacedDigit().foregroundStyle(Noir.inkSoft)
                Text(verbatim: t("level", level, Content.maxLineLevel)).font(.caption).monospacedDigit().foregroundStyle(Noir.inkSoft)
            }
            if level < Content.maxLineLevel {
                let cost = Cost(dirty: Content.lineUpgradeCost(product, track, currentLevel: level))
                UpgradeButton(title: t("btn_upgrade"), cost: cost, affordable: cost.affordable(state),
                              identifier: "line.\(product.rawValue).\(track.rawValue)") {
                    store.dispatch(.upgradeLine(product, track))
                }
            }
        }
    }

    private func valueText(_ level: Int) -> String {
        let def = Content.product(product)
        switch track {
        case .capacity: return t("track_capacity_val", t.decimal(def.batch * (1 + 0.5 * Double(level - 1)), digits: 1))
        case .speed: return t.duration(def.cycleSec * pow(0.9, Double(level - 1)))
        case .quality: return t("track_quality_val", t.decimal(1 + 0.1 * Double(level - 1), digits: 1))
        }
    }
}

private struct LockedLinePanel: View {
    let product: ProductId
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let def = Content.product(product)
        let unlocked = state.campaign.chapter >= def.unlockChapter
        Panel(.anthracite) {
            HeaderRow {
                Label { Text(verbatim: t(Labels.product(product))).font(.headline) } icon: { Mark(Glyph.product(product), size: 28) }
            } trailing: {
                if !unlocked { StatusChip(text: t("locked_chapter", def.unlockChapter), symbol: "lock.fill") }
            }
            Text(verbatim: t(Labels.productDesc(product))).font(.subheadline).foregroundStyle(Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Noir.s4) {
                profile("profile_price", grade(def.basePrice, [20, 60, 200]))
                profile("profile_risk", grade(def.risk, [0.8, 1.05, 1.3]))
                profile("profile_volume", grade(def.demandPerMin, [6, 15, 32]))
            }
            if unlocked {
                let cost = Cost(dirty: def.lineCost)
                UpgradeButton(title: t("line_open"), cost: cost, affordable: cost.affordable(state), primary: true,
                              identifier: "line.\(product.rawValue).buy") {
                    store.dispatch(.buyLine(product))
                }
            }
        }
    }

    private func profile(_ key: String, _ gradeKey: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: t(key)).font(.caption).foregroundStyle(Noir.inkMuted)
            Text(verbatim: t(gradeKey)).font(.subheadline.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }

    private func grade(_ v: Double, _ limits: [Double]) -> String {
        if v < limits[0] { return "grade_low" }
        if v < limits[1] { return "grade_mid" }
        if v < limits[2] { return "grade_high" }
        return "grade_extreme"
    }
}

/// A purchase button that states its cost and, when unaffordable, says so in words and stays disabled.
struct UpgradeButton: View {
    let title: String
    let cost: Cost
    let affordable: Bool
    var primary = false
    let identifier: String
    let action: () -> Void
    @Environment(\.l10n) private var t

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(verbatim: title)
                Text(verbatim: t.cost(cost)).font(.caption.weight(.medium)).monospacedDigit().opacity(0.85)
            }
        }
        .noirButton(primary ? .primary : .secondary)
        .disabled(!affordable)
        .accessibilityHint(Text(verbatim: affordable ? "" : t("err_not_affordable")))
        .accessibilityIdentifier(identifier)
    }
}
