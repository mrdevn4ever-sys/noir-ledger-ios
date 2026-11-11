import NoirCore
import SwiftUI

/// The daily reward and the achievements with their favors.
struct RewardsView: View {
    @Environment(GameStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.l10n) private var t

    var body: some View {
        let s = store.state
        ScrollView {
            VStack(alignment: .leading, spacing: Noir.s4) {
                DailyPanel(state: s)
                SectionHeading(title: t("ach_title"), detail: t("ach_detail", s.meta.claimed.count, AchievementId.allCases.count))
                ForEach(sorted(s), id: \.self) { a in
                    AchievementRow(achievement: a, state: s)
                }
            }
            .padding(Noir.s4)
            .background(alignment: .topLeading) { ScreenMarker(identifier: "screen.rewards", title: t("rewards_title")) }
        }
        .background(Noir.ground)
        .navigationTitle(Text(verbatim: t("rewards_title")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Noir.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { router.showRewards = false } label: { Text(verbatim: t("btn_done")) }
                    .accessibilityIdentifier("rewards.done")
            }
        }
    }

    /// Rewards waiting first, then open ones, collected ones last.
    private func sorted(_ s: GameState) -> [AchievementId] {
        func rank(_ a: AchievementId) -> Int {
            if Idle.achievementClaimed(s, a) { return 2 }
            return Idle.achievementUnlocked(s, a) ? 0 : 1
        }
        return AchievementId.allCases.enumerated().sorted { l, r in
            (rank(l.element), l.offset) < (rank(r.element), r.offset)
        }.map(\.element)
    }
}

private struct DailyPanel: View {
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let available = Idle.dailyAvailable(state, day: store.today)
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

private struct AchievementRow: View {
    let achievement: AchievementId
    let state: GameState
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t

    var body: some View {
        let unlocked = Idle.achievementUnlocked(state, achievement)
        let claimed = Idle.achievementClaimed(state, achievement)
        let target = Idle.achievementTarget(achievement)
        let current = min(target, Idle.achievementCurrent(state, achievement))
        Panel(unlocked && !claimed ? .leather : .anthracite) {
            HStack(spacing: Noir.s3) {
                Image(systemName: claimed ? "checkmark.seal.fill" : (unlocked ? "seal.fill" : "seal"))
                    .font(.title3).foregroundStyle(claimed ? Noir.inkMuted : Noir.brass).frame(width: 30).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: t(Labels.achievement(achievement))).font(.subheadline.weight(.semibold))
                        .foregroundStyle(claimed ? Noir.inkSoft : Noir.ink)
                    Text(verbatim: Labels.achievementGoal(achievement, t)).font(.caption).foregroundStyle(Noir.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if !unlocked {
                        Meter(fraction: target > 0 ? current / target : 0, tint: Noir.brass, height: 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if claimed {
                    StatusChip(text: t("ach_claimed"), symbol: "checkmark")
                } else {
                    Button {
                        store.dispatch(.claimAchievement(achievement))
                    } label: {
                        Label { Text(verbatim: "+" + t.decimal(Double(Idle.achievementReward(achievement)), digits: 0)).monospacedDigit() } icon: {
                            Image(systemName: "seal.fill")
                        }
                    }
                    .noirButton(unlocked ? .primary : .secondary, fullWidth: false)
                    .disabled(!unlocked)
                    .accessibilityIdentifier("rewards.ach.\(achievement.rawValue)")
                }
            }
        }
    }
}
