import NoirCore
import SwiftUI

/// The daily envelope and the board of missions.
struct RewardsView: View {
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        SheetFrame("rewards_title", identifier: "screen.rewards") {
            DailyPanel(state: s)
            Text(verbatim: t("l4_rewards_more")).font(.toon(.footnote)).foregroundStyle(Noir.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DailyPanel: View {
    let state: FlowState
    @Environment(LedgerStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let available = store.today > state.meta.dailyLastDay
        let position = state.meta.dailyClaims % Idle.dailyCycle.count
        Panel(.paper) {
            Text(verbatim: t("daily_title")).font(.toon(.headline)).accessibilityAddTraits(.isHeader)
            Text(verbatim: t(available ? "daily_ready" : "daily_done")).font(.toon(.subheadline)).foregroundStyle(Noir.paperInkSoft)
            HStack(spacing: Noir.s1) {
                ForEach(0..<Idle.dailyCycle.count, id: \.self) { i in
                    VStack(spacing: 2) {
                        Image(symbol(Idle.dailyCycle[i])).resizable().frame(width: 24, height: 24)
                        Text(verbatim: short(Idle.dailyCycle[i])).font(.toon(.caption2, .semibold)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(i == position && available ? Noir.onAmber : Noir.paperInk)
                    .background(i == position && available ? Noir.amberFill : Noir.paperEdge.opacity(i < position ? 0.35 : 0.12),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        if i < position {
                            Image("IconCheck").resizable().frame(width: 14, height: 14)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(3)
                        }
                    }
                }
            }
            .accessibilityHidden(true)
            Button {
                store.dispatch(.claimDaily(day: store.today))
            } label: {
                Text(verbatim: t("daily_claim", long(Idle.dailyReward(claims: state.meta.dailyClaims))))
            }
            .noirButton(.primary)
            .disabled(!available)
            .accessibilityIdentifier("rewards.daily")
        }
    }

    private func symbol(_ r: DailyReward) -> String {
        switch r {
        case .favors: "HudFavor"
        case .boost: "IconBoost"
        case .warp: "IconWarp"
        }
    }

    private func short(_ r: DailyReward) -> String {
        switch r {
        case .favors(let n): t.decimal(Double(n), digits: 0)
        case .boost(let seconds), .warp(let seconds): t.duration(seconds)
        }
    }

    private func long(_ r: DailyReward) -> String {
        switch r {
        case .favors(let n): t("daily_favors", n)
        case .boost(let seconds): t("daily_boost", t.duration(seconds))
        case .warp(let seconds): t("daily_warp", t.duration(seconds))
        }
    }
}

