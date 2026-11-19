import NoirCore
import SwiftUI

/// How many units the buy button takes at once (0 = as many as the cash allows).
enum BuyMode: Int, CaseIterable, Identifiable, Sendable {
    case one = 1, ten = 10, hundred = 100, max = 0

    var id: Int { rawValue }
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

struct FloaterView: View {
    let floater: Floater
    @State private var risen = false
    @Environment(\.noirReduceMotion) private var reduceMotion

    var body: some View {
        Text(verbatim: floater.text)
            .font(.toon(.footnote, .heavy))
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
    @Environment(LedgerStore.self) private var store
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

    /// The ribbon with title and detail; confetti for milestones, chapters and new floors, a stamp for a paid order.
    private func banner(_ c: Celebration) -> some View {
        VStack(spacing: 0) {
            Text(verbatim: title(c.kind)).font(.display(.title2))
                .foregroundStyle(Color(hex: 0x5A3A00))
                .padding(.horizontal, 70).padding(.top, 18).padding(.bottom, 28)
                .frame(minWidth: 300)
                .background(Image("LevelUpRibbon").resizable())
            Text(verbatim: detail(c.kind)).font(.toon(.subheadline, .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background { ToonPlate(name: "ChipPill", corner: 10) }
                .offset(y: -10)
        }
        .multilineTextAlignment(.center)
        .lineLimit(2).minimumScaleFactor(0.8)
        .background {
            if !reduceMotion {
                switch c.kind {
                case .orderDone:
                    TimedSprite(name: "StampPaid6", frames: 6, size: 110, fps: 10).offset(x: 140, y: 10)
                default:
                    TimedSprite(name: "Confetti12", frames: 12, size: 320, fps: 10)
                }
            }
        }
        .shadow(color: Noir.amber.opacity(0.35), radius: 16)
        .padding(.top, Noir.s6)
        .padding(.horizontal, Noir.s4)
        .accessibilityIdentifier("celebration")
    }

    private func title(_ kind: Celebration.Kind) -> String {
        switch kind {
        case .milestone: t("l4_cel_milestone_t")
        case .opened: t("l4_cel_opened_t")
        case .hired: t("l4_cel_hired_t")
        case .orderDone: t("l4_cel_order_t")
        case .chapterReady: t("l4_cel_chapter_t")
        }
    }

    private func detail(_ kind: Celebration.Kind) -> String {
        switch kind {
        case .milestone(let station, let level): t("l4_cel_milestone_b", StationText.title(station, t), level)
        case .opened(let g): t("l4_cel_opened_b", t(GoodText.name(g)))
        case .hired(let crew): t("l4_cel_hired_b", Content.crewDef(crew)?.name ?? "")
        case .orderDone(let paid): t("l4_cel_order_b", t.money(paid))
        case .chapterReady(let n): t("l4_cel_chapter_b", t(ChapterText.title(n)))
        }
    }
}

/// A sprite sheet played once from the moment it appears.
struct TimedSprite: View {
    let name: String
    let frames: Int
    let size: CGFloat
    var fps: Double = 12
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / fps)) { tl in
            let f = Int(tl.date.timeIntervalSince(start) * fps)
            if f < frames {
                SpriteStrip(name: name, frames: frames, frame: f, size: CGSize(width: size, height: size))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

