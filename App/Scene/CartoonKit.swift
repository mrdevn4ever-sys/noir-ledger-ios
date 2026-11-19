import NoirCore
import SwiftUI

/*
 * The cartoon kit: the night palette and the small pieces laid over the scene art (level plaques, the bottleneck
 * bubble, the empty manager place, coin labels). The scene itself is composed from the delivered art (SceneArt).
 */

enum Toon {
    static let skyTop = Color(hex: 0x1B2450)
    static let skyBottom = Color(hex: 0x3A4C8A)
    static let window = Color(hex: 0xFFD66B)
    static let pill = Color(hex: 0xB07CE0)
    static let badge = Color(hex: 0xD9433B)
    static let badgeGrey = Color(hex: 0x6C7088)
    static let up = Color(hex: 0x3FC45A)
    static let outline = Color(hex: 0x1B1B28)
}

// MARK: - Badges and slots

/// The red "Level N" plaque on a station; a green arrow when the next level is affordable, the red bubble when this
/// station holds the flow back.
struct LevelBadge: View {
    let level: Int
    let caption: String
    var affordable = false
    var bottleneck = false
    var locked = false
    @Environment(\.l10n) private var t
    @Environment(\.noirReduceMotion) private var reduceMotion
    @State private var bounce = false

    var body: some View {
        VStack(spacing: -2) {
            Text(verbatim: t("l4_badge_level")).font(.system(size: 11, weight: .bold, design: .rounded))
            Text(verbatim: "\(level)").font(.system(size: 21, weight: .heavy, design: .rounded)).monospacedDigit()
                .minimumScaleFactor(0.6).lineLimit(1)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 0, y: 1)
        .padding(.bottom, 4)
        .frame(width: 62, height: 50)
        .background(Image(locked ? "BadgePlateGrey" : "BadgePlate").resizable())
        .overlay(alignment: .topLeading) {
            if affordable {
                Image("ArrowUp").resizable().frame(width: 22, height: 22)
                    .offset(x: -9, y: bounce && !reduceMotion ? -14 : -10)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: bounce)
                    .onAppear { bounce = true }
            }
        }
        .overlay(alignment: .topTrailing) {
            if bottleneck { BottleneckDot().offset(x: 10, y: -12) }
        }
        .overlay(alignment: .bottom) {
            Text(verbatim: caption).font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Color.black.opacity(0.55), in: Capsule())
                .offset(y: 15)
        }
    }
}

/// The red bubble with "!" that bobs over the station that holds the flow back.
struct BottleneckDot: View {
    @State private var pulse = false
    @Environment(\.noirReduceMotion) private var reduceMotion

    var body: some View {
        Image("BottleneckBubble").resizable().frame(width: 26, height: 26)
            .scaleEffect(pulse && !reduceMotion ? 1.15 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
            .accessibilityHidden(true)
    }
}

/// Where a manager would stand: the dashed silhouette with a plus and the price.
struct ManagerSlot: View {
    let crew: String
    let hired: Bool
    let cost: Double
    let affordable: Bool
    @Environment(\.l10n) private var t

    var body: some View {
        VStack(spacing: 1) {
            if hired {
                Portrait(crewId: crew, size: 40).clipShape(Circle())
                    .overlay(Circle().stroke(Toon.window, lineWidth: 2))
            } else {
                Image("ManagerSlot").resizable().frame(width: 30, height: 46)
                    .opacity(affordable ? 1 : 0.75)
                Text(verbatim: t.money(cost)).font(.system(size: 11, weight: .heavy, design: .rounded)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .foregroundStyle(affordable ? Color(hex: 0x1B1B28) : .white)
                    .background(affordable ? Toon.window : Color.black.opacity(0.6), in: Capsule())
            }
        }
        .frame(minWidth: 44, minHeight: 44)
    }
}

/// A small coin label with an amount.
struct CoinLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Image("Coin").resizable().frame(width: 14, height: 14)
            Text(verbatim: text).font(.system(size: 12, weight: .heavy, design: .rounded)).monospacedDigit()
                .foregroundStyle(.white).shadow(color: .black.opacity(0.6), radius: 1, y: 1)
        }
    }
}
