import NoirCore
import SwiftUI

/// The daily envelope and the board of missions.
struct RewardsView: View {
    @Environment(TycoonStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        SheetFrame("rewards_title", identifier: "screen.rewards") {
            DailyPanel(state: s)
            MissionBoard(state: s)
            Text(verbatim: t("ty_missions_done", s.claimedMissions.count, TycoonContent.missions.count))
                .font(.footnote).foregroundStyle(Noir.inkSoft)
        }
    }
}

private struct DailyPanel: View {
    let state: TycoonState
    @Environment(TycoonStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let available = store.today > state.meta.dailyLastDay
        let position = state.meta.dailyClaims % Idle.dailyCycle.count
        Panel(.paper) {
            Text(verbatim: t("daily_title")).font(.headline).accessibilityAddTraits(.isHeader)
            Text(verbatim: t(available ? "daily_ready" : "daily_done")).font(.subheadline).foregroundStyle(Noir.paperInkSoft)
            HStack(spacing: Noir.s1) {
                ForEach(0..<Idle.dailyCycle.count, id: \.self) { i in
                    VStack(spacing: 2) {
                        Image(systemName: symbol(Idle.dailyCycle[i]))
                        Text(verbatim: short(Idle.dailyCycle[i])).font(.caption2.weight(.semibold)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundStyle(i == position && available ? Noir.onAmber : Noir.paperInk)
                    .background(i == position && available ? Noir.amberFill : Noir.paperEdge.opacity(i < position ? 0.35 : 0.12),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        if i < position {
                            Image(systemName: "checkmark").font(.caption2.weight(.heavy)).foregroundStyle(Noir.paperInk)
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
        case .favors: "seal.fill"
        case .boost: "bolt.fill"
        case .warp: "forward.fill"
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

