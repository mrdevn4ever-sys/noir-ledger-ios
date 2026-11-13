import NoirCore
import SwiftUI

/// How many steps the one-button line upgrade buys at once.
enum BuyMode: Int, CaseIterable, Identifiable, Sendable {
    case one = 1, ten = 10, twentyFive = 25, max = 0

    var id: Int { rawValue }
    var limit: Int { self == .max ? 250 : rawValue }
}

/// A number that rolls to its new value instead of jumping.
struct RollingText: View {
    let text: String
    let value: Double
    @Environment(\.noirReduceMotion) private var reduceMotion

    var body: some View {
        // Keyed on the shown text, short: values move several times a second and must never look smeared.
        Text(verbatim: text)
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText(value: value))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: text)
    }
}

/// A short text that rises from where something happened and fades.
struct Floater: Identifiable, Equatable {
    let id: Int
    let text: String
    let at: CGPoint
}

struct FloaterLayer: View {
    let floaters: [Floater]

    var body: some View {
        ZStack {
            ForEach(floaters) { floater in
                FloaterView(floater: floater)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct FloaterView: View {
    let floater: Floater
    @State private var risen = false
    @Environment(\.noirReduceMotion) private var reduceMotion

    var body: some View {
        Text(verbatim: floater.text)
            .font(.footnote.weight(.heavy))
            .monospacedDigit()
            .foregroundStyle(Noir.amber)
            .shadow(color: Noir.ground, radius: 2)
            .position(floater.at)
            .offset(y: risen && !reduceMotion ? -38 : 0)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.85)) { risen = true }
            }
    }
}

/// The banner for a milestone, a finished chapter or a new start, with a burst of gold.
struct CelebrationBanner: View {
    @Environment(GameStore.self) private var store
    @Environment(\.l10n) private var t
    @Environment(\.noirReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            if let celebration = store.celebration {
                banner(celebration)
                    .id(celebration.id)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .task(id: celebration.id) {
                        AccessibilityNotification.Announcement(title(celebration.kind) + ". " + detail(celebration.kind)).post()
                        try? await Task.sleep(for: .seconds(2.8))
                        store.clearCelebration(celebration.id)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(.spring(duration: 0.45, bounce: 0.3), value: store.celebration)
        .allowsHitTesting(false)
    }

    private func banner(_ c: Celebration) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: title(c.kind)).font(.display(.title3))
            Text(verbatim: detail(c.kind)).font(.subheadline.weight(.semibold))
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(Noir.onAmber)
        .padding(.horizontal, Noir.s5)
        .padding(.vertical, Noir.s3)
        .background(Noir.amberFill, in: RoundedRectangle(cornerRadius: Noir.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Noir.corner, style: .continuous).strokeBorder(Noir.paper.opacity(0.6), lineWidth: 1))
        .background { if !reduceMotion { GoldBurst() } }
        .shadow(color: Noir.amber.opacity(0.45), radius: 18)
        .padding(.top, Noir.s6)
        .padding(.horizontal, Noir.s4)
        .accessibilityIdentifier("celebration")
    }

    private func title(_ kind: Celebration.Kind) -> String {
        switch kind {
        case .milestone: t("celebrate_milestone_t")
        case .chapter: t("celebrate_chapter_t")
        case .prestige: t("celebrate_prestige_t")
        }
    }

    private func detail(_ kind: Celebration.Kind) -> String {
        switch kind {
        case .milestone(let p, let stage): t("celebrate_milestone_b", t(Labels.product(p)), stage)
        case .chapter(let c): t("celebrate_chapter_b", t(Labels.chapterTitle(c)))
        case .prestige(let gain): t("celebrate_prestige_b", gain)
        }
    }
}

/// Gold flecks flying out from behind the banner, once.
private struct GoldBurst: View {
    @State private var out = false

    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { i in
                let angle = Double(i) / 16 * 2 * .pi
                Circle()
                    .fill(i % 3 == 0 ? Noir.paper : Noir.amber)
                    .frame(width: i % 2 == 0 ? 6 : 4, height: i % 2 == 0 ? 6 : 4)
                    .offset(x: out ? cos(angle) * 150 : 0, y: out ? sin(angle) * 70 : 0)
                    .opacity(out ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { out = true }
        }
    }
}
