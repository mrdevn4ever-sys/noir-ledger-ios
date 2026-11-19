import NoirCore
import SwiftUI

/*
 * The cartoon kit: everything the building scene is drawn with, in flat shapes at night. No bitmaps are needed;
 * delivered art can replace single pieces later. Sizes are in points for a figure about 64 pt tall.
 */

enum Toon {
    // Sky and city
    static let skyTop = Color(hex: 0x1B2450)
    static let skyBottom = Color(hex: 0x3A4C8A)
    static let moon = Color(hex: 0xF6F0D8)
    static let skyline = Color(hex: 0x24305E)
    static let skylineFar = Color(hex: 0x2D3B70)
    static let window = Color(hex: 0xFFD66B)
    static let street = Color(hex: 0x3B3F55)
    static let curb = Color(hex: 0x5A5F7A)
    // Building
    static let wall = Color(hex: 0x6E7590)
    static let wallDark = Color(hex: 0x4F5672)
    static let roof = Color(hex: 0xC8463C)
    static let brick = Color(hex: 0x5A3C36)
    static let brickLine = Color(hex: 0x40292A)
    static let floorBoard = Color(hex: 0x7A5638)
    static let floorEdge = Color(hex: 0x4E3420)
    static let dirt = Color(hex: 0x3A2A22)
    static let dirtDark = Color(hex: 0x2A1E18)
    static let shaft = Color(hex: 0x1A1E30)
    // Things
    static let crate = Color(hex: 0xE39A4C)
    static let crateDark = Color(hex: 0xB86F2E)
    static let pot = Color(hex: 0xC8643C)
    static let potDark = Color(hex: 0x9E4A2A)
    static let leaf = Color(hex: 0x4FBF4A)
    static let leafDark = Color(hex: 0x2F8F35)
    static let lamp = Color(hex: 0xFFF2B0)
    static let glass = Color(hex: 0xBFE8F2)
    static let crystal = Color(hex: 0x5FC9F0)
    static let pill = Color(hex: 0xB07CE0)
    static let pillAlt = Color(hex: 0xF07CB0)
    static let block = Color(hex: 0xF3F3F3)
    static let marble = Color(hex: 0xD9DCE6)
    static let metal = Color(hex: 0x9AA2B8)
    static let metalDark = Color(hex: 0x6A7290)
    static let badge = Color(hex: 0xD9433B)
    static let badgeDark = Color(hex: 0xA8302A)
    static let badgeGrey = Color(hex: 0x6C7088)
    static let up = Color(hex: 0x3FC45A)
    // People
    static let skin = [Color(hex: 0xF2C9A0), Color(hex: 0xD9A27A), Color(hex: 0x9C6A46), Color(hex: 0x6E4630)]
    static let outline = Color(hex: 0x1B1B28)
}

// MARK: - People

/// A flat cartoon figure: head, body, arms and legs; walking swings the legs and arms.
struct Figure: View {
    enum Look: Sendable {
        case gardener, chemist, presser, suit, courier, buyer, cop, boss
    }

    let look: Look
    /// Walking phase in radians; nil stands still.
    var walk: Double?
    var facing: CGFloat = 1
    var carrying: Color?
    var skinIndex = 0

    private var shirt: Color {
        switch look {
        case .gardener: Color(hex: 0x4E9F5A)
        case .chemist: Color(hex: 0xF2F2F2)
        case .presser: Color(hex: 0x8A5CC2)
        case .suit: Color(hex: 0x2C2C3A)
        case .courier: Color(hex: 0xF2F2F2)
        case .buyer: Color(hex: 0xE8E2D2)
        case .cop: Color(hex: 0x2B4C9B)
        case .boss: Color(hex: 0x3A3A4A)
        }
    }

    private var pants: Color {
        switch look {
        case .gardener: Color(hex: 0x3B5B8C)
        case .chemist: Color(hex: 0x3D4255)
        case .presser: Color(hex: 0x2E2E3E)
        case .suit, .boss: Color(hex: 0x1F1F2A)
        case .courier: Color(hex: 0x3B5B8C)
        case .buyer: Color(hex: 0x4A3F35)
        case .cop: Color(hex: 0x1D2F66)
        }
    }

    var body: some View {
        let swing = walk.map { sin($0) } ?? 0
        let bob = walk.map { abs(sin($0)) * 1.5 } ?? 0
        let skin = Toon.skin[skinIndex % Toon.skin.count]
        ZStack {
            // Legs
            Capsule().fill(pants).frame(width: 7, height: 20)
                .rotationEffect(.degrees(swing * 24), anchor: .top).offset(x: -4, y: 17)
            Capsule().fill(pants).frame(width: 7, height: 20)
                .rotationEffect(.degrees(-swing * 24), anchor: .top).offset(x: 4, y: 17)
            // Shoes
            Capsule().fill(Toon.outline).frame(width: 10, height: 5).offset(x: -4 + swing * 5, y: 27)
            Capsule().fill(Toon.outline).frame(width: 10, height: 5).offset(x: 4 - swing * 5, y: 27)
            // Back arm
            Capsule().fill(shirt.opacity(0.85)).frame(width: 6, height: 17)
                .rotationEffect(.degrees(carrying != nil ? -70 : -swing * 28), anchor: .top).offset(x: -9, y: 2)
            // Body
            RoundedRectangle(cornerRadius: 7, style: .continuous).fill(shirt).frame(width: 22, height: 24).offset(y: 2)
            details
            // Front arm
            Capsule().fill(shirt).frame(width: 6, height: 17)
                .rotationEffect(.degrees(carrying != nil ? -70 : swing * 28), anchor: .top).offset(x: 9, y: 2)
            if let carrying {
                CrateShape().fill(carrying).frame(width: 16, height: 13).offset(x: 17, y: -4)
            }
            // Head
            Circle().fill(skin).frame(width: 21, height: 21).offset(y: -18)
            Circle().fill(Toon.outline).frame(width: 3, height: 3).offset(x: 5, y: -18)
            Capsule().fill(Toon.outline.opacity(0.7)).frame(width: 6, height: 2).offset(x: 5, y: -12)
            hat
        }
        .frame(width: 44, height: 70)
        .offset(y: -bob)
        .scaleEffect(x: facing, y: 1)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var details: some View {
        switch look {
        case .gardener:
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x6B4A2E)).frame(width: 16, height: 14).offset(y: 6)
        case .chemist:
            Rectangle().fill(Color(hex: 0xCFD6E0)).frame(width: 2, height: 22).offset(y: 2)
        case .suit, .boss:
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 3, y: 10)); p.addLine(to: CGPoint(x: 6, y: 0))
            }.fill(Color(hex: 0xC8463C)).frame(width: 6, height: 10).offset(y: -4)
        case .cop:
            Circle().fill(Color(hex: 0xFFC83D)).frame(width: 5, height: 5).offset(x: -5, y: -2)
        case .courier:
            Rectangle().fill(Color(hex: 0x3FC45A)).frame(width: 22, height: 4).offset(y: 6)
        case .presser, .buyer:
            EmptyView()
        }
    }

    @ViewBuilder private var hat: some View {
        switch look {
        case .gardener:
            Capsule().fill(Color(hex: 0xE8C25A)).frame(width: 30, height: 6).offset(y: -26)
            RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0xE8C25A)).frame(width: 18, height: 9).offset(y: -30)
        case .chemist:
            Capsule().fill(Color(hex: 0x3A3A4A)).frame(width: 20, height: 7).offset(y: -27)
            RoundedRectangle(cornerRadius: 2).stroke(Toon.outline, lineWidth: 1.5).frame(width: 9, height: 6).offset(x: 5, y: -19)
        case .presser:
            Capsule().fill(Color(hex: 0x2E2E3E)).frame(width: 22, height: 8).offset(y: -27)
        case .suit, .boss:
            Capsule().fill(Color(hex: 0x1F1F2A)).frame(width: 30, height: 5).offset(y: -26)
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x1F1F2A)).frame(width: 18, height: 11).offset(y: -31)
        case .courier:
            Circle().trim(from: 0.5, to: 1).fill(Color(hex: 0x3FC45A)).frame(width: 24, height: 24).offset(y: -20)
            Capsule().fill(Color(hex: 0xBFE8F2).opacity(0.8)).frame(width: 9, height: 6).offset(x: 6, y: -19)
        case .buyer:
            Capsule().fill(Toon.outline).frame(width: 18, height: 7).offset(y: -27)
        case .cop:
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x1D2F66)).frame(width: 22, height: 9).offset(y: -29)
            Capsule().fill(Toon.outline).frame(width: 26, height: 3).offset(x: 3, y: -25)
        }
    }
}

// MARK: - Goods and props

struct CrateShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(roundedRect: r, cornerRadius: min(r.width, r.height) * 0.12)
        p.move(to: CGPoint(x: r.minX, y: r.midY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}

/// A wooden crate with planks.
struct Crate: View {
    var size: CGFloat = 22
    var tint: Color = Toon.crate

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12).fill(tint)
            RoundedRectangle(cornerRadius: size * 0.12).stroke(Toon.crateDark, lineWidth: 2)
            Path { p in
                p.move(to: CGPoint(x: 2, y: 2)); p.addLine(to: CGPoint(x: size - 2, y: size * 0.8 - 2))
                p.move(to: CGPoint(x: size - 2, y: 2)); p.addLine(to: CGPoint(x: 2, y: size * 0.8 - 2))
            }.stroke(Toon.crateDark, lineWidth: 1.5)
        }
        .frame(width: size, height: size * 0.8)
    }
}

/// A seven-fingered cannabis leaf.
struct WeedLeaf: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let base = CGPoint(x: r.midX, y: r.maxY)
        let angles: [Double] = [-80, -50, -22, 0, 22, 50, 80]
        let lengths: [Double] = [0.45, 0.7, 0.9, 1.0, 0.9, 0.7, 0.45]
        for (a, l) in zip(angles, lengths) {
            let rad = (a - 90) * .pi / 180
            let len = Double(r.height) * l
            let tip = CGPoint(x: base.x + CGFloat(cos(rad) * len), y: base.y + CGFloat(sin(rad) * len))
            let side = Double(r.width) * 0.09 * l
            let perp = rad + .pi / 2
            let mid = CGPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
            p.move(to: base)
            p.addQuadCurve(to: tip, control: CGPoint(x: mid.x + CGFloat(cos(perp) * side), y: mid.y + CGFloat(sin(perp) * side)))
            p.addQuadCurve(to: base, control: CGPoint(x: mid.x - CGFloat(cos(perp) * side), y: mid.y - CGFloat(sin(perp) * side)))
        }
        return p
    }
}

/// A potted plant; `stage` (0–5) makes it taller and bushier, `sway` moves it a little.
struct Plant: View {
    let stage: Int
    var sway: Double = 0
    var bud: Color = Toon.leaf

    var body: some View {
        let h = 26 + CGFloat(min(stage, 5)) * 7
        ZStack(alignment: .bottom) {
            ZStack {
                Rectangle().fill(Toon.leafDark).frame(width: 3, height: h).offset(y: -h / 2)
                ForEach(0..<(2 + min(stage, 5)), id: \.self) { i in
                    let y = -h * (0.35 + 0.6 * CGFloat(i) / CGFloat(2 + min(stage, 5)))
                    let w = 30 - CGFloat(i) * 2.5
                    WeedLeaf().fill(i % 2 == 0 ? Toon.leaf : Toon.leafDark)
                        .frame(width: w, height: w * 0.7)
                        .offset(y: y)
                }
                if stage >= 2 {
                    ForEach(0..<min(stage, 5), id: \.self) { i in
                        Circle().fill(bud).frame(width: 7, height: 7)
                            .offset(x: CGFloat(i % 2 == 0 ? -8 : 8), y: -h * (0.45 + 0.1 * CGFloat(i)))
                    }
                }
            }
            .rotationEffect(.degrees(sin(sway) * 2.5), anchor: .bottom)
            .offset(y: -18)
            Pot()
        }
        .frame(width: 40, height: h + 24)
        .accessibilityHidden(true)
    }
}

struct Pot: View {
    var body: some View {
        ZStack(alignment: .top) {
            Path { p in
                p.move(to: CGPoint(x: 2, y: 4)); p.addLine(to: CGPoint(x: 26, y: 4))
                p.addLine(to: CGPoint(x: 22, y: 20)); p.addLine(to: CGPoint(x: 6, y: 20)); p.closeSubpath()
            }.fill(Toon.pot)
            RoundedRectangle(cornerRadius: 2).fill(Toon.potDark).frame(width: 28, height: 6)
        }
        .frame(width: 28, height: 20)
    }
}

/// Crystal lab: a table with flasks of bubbling blue liquid and a tray of crystals.
struct LabBench: View {
    let stage: Int
    let time: Double

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3).fill(Toon.metalDark).frame(width: 96, height: 8).offset(y: -30)
            Rectangle().fill(Toon.metalDark).frame(width: 6, height: 30).offset(x: -40)
            Rectangle().fill(Toon.metalDark).frame(width: 6, height: 30).offset(x: 40)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<(2 + min(stage, 3)), id: \.self) { i in
                    Flask(fill: 0.4 + 0.1 * Double(i % 3), time: time + Double(i))
                }
            }
            .offset(y: -38)
            if stage >= 2 {
                HStack(spacing: 2) {
                    ForEach(0..<min(stage + 2, 6), id: \.self) { _ in
                        Diamond().fill(Toon.crystal).frame(width: 8, height: 10)
                    }
                }
                .offset(x: 0, y: -2)
            }
        }
        .frame(width: 110, height: 90)
        .accessibilityHidden(true)
    }
}

struct Flask: View {
    let fill: Double
    let time: Double

    var body: some View {
        ZStack(alignment: .bottom) {
            Circle().fill(Toon.glass.opacity(0.35)).frame(width: 18, height: 18)
            Circle().trim(from: 0, to: 0.5).fill(Toon.crystal).rotationEffect(.degrees(0)).frame(width: 16, height: 16).offset(y: -1)
            Rectangle().fill(Toon.glass.opacity(0.5)).frame(width: 5, height: 10).offset(y: -16)
            Circle().fill(Color.white.opacity(0.7)).frame(width: 3, height: 3)
                .offset(x: CGFloat(sin(time * 3) * 3), y: -10 - CGFloat((time * 12).truncatingRemainder(dividingBy: 14)))
        }
        .frame(width: 20, height: 30)
    }
}

struct Diamond: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.midY)); p.closeSubpath()
        return p
    }
}

/// Pill press: a stamping head over a belt of coloured tablets.
struct PillPress: View {
    let stage: Int
    let time: Double
    let running: Bool

    var body: some View {
        let stamp = running ? CGFloat(abs(sin(time * 4))) * 10 : 0
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4).fill(Toon.metalDark).frame(width: 34, height: 54).offset(x: -34, y: -10)
            RoundedRectangle(cornerRadius: 2).fill(Toon.metal).frame(width: 22, height: 10).offset(x: -34, y: -40 + stamp)
            RoundedRectangle(cornerRadius: 3).fill(Toon.floorEdge).frame(width: 110, height: 8).offset(y: -4)
            HStack(spacing: 5) {
                ForEach(0..<(4 + min(stage, 5)), id: \.self) { i in
                    Capsule().fill(i % 2 == 0 ? Toon.pill : Toon.pillAlt).frame(width: 9, height: 5)
                }
            }
            .offset(x: running ? CGFloat((time * 18).truncatingRemainder(dividingBy: 14)) : 0, y: -12)
            .mask(Rectangle().frame(width: 110, height: 20).offset(y: -12))
            if stage >= 2 {
                HStack(spacing: 4) {
                    ForEach(0..<min(stage, 4), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 3).fill(Toon.pill.opacity(0.85)).frame(width: 12, height: 16)
                    }
                }
                .offset(x: 34, y: -16)
            }
        }
        .frame(width: 120, height: 90)
        .accessibilityHidden(true)
    }
}

/// Luxury: a marble table with a scale and stacked white blocks.
struct BlockTable: View {
    let stage: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3).fill(Toon.marble).frame(width: 100, height: 9).offset(y: -28)
            Rectangle().fill(Toon.metal).frame(width: 6, height: 28).offset(x: -40)
            Rectangle().fill(Toon.metal).frame(width: 6, height: 28).offset(x: 40)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<(1 + min(stage, 4)), id: \.self) { i in
                    VStack(spacing: 1) {
                        ForEach(0..<(1 + i % 3), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 2).fill(Toon.block).frame(width: 16, height: 7)
                                .overlay(RoundedRectangle(cornerRadius: 2).stroke(Toon.marble, lineWidth: 1))
                        }
                    }
                }
            }
            .offset(x: -12, y: -37)
            // Scale
            ZStack {
                Rectangle().fill(Toon.metal).frame(width: 2, height: 14)
                Capsule().fill(Toon.metal).frame(width: 18, height: 3).offset(y: -7)
            }
            .offset(x: 34, y: -38)
        }
        .frame(width: 110, height: 90)
        .accessibilityHidden(true)
    }
}

/// A hanging grow lamp with a soft cone of light.
struct HangingLamp: View {
    var on = true

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Toon.outline).frame(width: 2, height: 8)
            Capsule().fill(Toon.metal).frame(width: 22, height: 5).offset(y: 8)
            if on {
                Path { p in
                    p.move(to: CGPoint(x: 8, y: 0)); p.addLine(to: CGPoint(x: 14, y: 0))
                    p.addLine(to: CGPoint(x: 22, y: 60)); p.addLine(to: CGPoint(x: 0, y: 60)); p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Toon.lamp.opacity(0.45), Toon.lamp.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 22, height: 60).offset(y: 12)
            }
        }
        .frame(width: 22, height: 72)
        .accessibilityHidden(true)
    }
}

// MARK: - Vehicles

struct Scooter: View {
    let wheel: Double
    var load: Color = Toon.crate

    var body: some View {
        ZStack {
            Wheel(angle: wheel).frame(width: 18, height: 18).offset(x: -18, y: 14)
            Wheel(angle: wheel).frame(width: 18, height: 18).offset(x: 18, y: 14)
            Path { p in
                p.move(to: CGPoint(x: 6, y: 22)); p.addQuadCurve(to: CGPoint(x: 46, y: 22), control: CGPoint(x: 26, y: 6))
                p.addLine(to: CGPoint(x: 50, y: 8)); p.addLine(to: CGPoint(x: 44, y: 6))
            }
            .stroke(Toon.badge, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            .frame(width: 56, height: 28).offset(y: 2)
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x3A9AD9)).frame(width: 20, height: 16).offset(x: -18, y: -6)
            Crate(size: 14, tint: load).offset(x: -18, y: -8)
            Figure(look: .courier, walk: nil, facing: 1).scaleEffect(0.62).offset(x: 2, y: -14)
        }
        .frame(width: 64, height: 56)
        .accessibilityHidden(true)
    }
}

struct Wheel: View {
    let angle: Double

    var body: some View {
        ZStack {
            Circle().fill(Toon.outline)
            Circle().fill(Toon.metal).padding(5)
            Rectangle().fill(Toon.outline).frame(width: 2, height: 10).rotationEffect(.radians(angle))
        }
    }
}

struct PoliceCar: View {
    let time: Double
    var siren = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0x2B4C9B)).frame(width: 76, height: 20).offset(y: 4)
            RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0xF2F2F2)).frame(width: 40, height: 16).offset(x: 2, y: -8)
            RoundedRectangle(cornerRadius: 2).fill(Toon.glass.opacity(0.8)).frame(width: 14, height: 9).offset(x: -6, y: -8)
            RoundedRectangle(cornerRadius: 2).fill(Toon.glass.opacity(0.8)).frame(width: 14, height: 9).offset(x: 12, y: -8)
            Capsule().fill(siren && Int(time * 4) % 2 == 0 ? Color(hex: 0xE5484D) : Color(hex: 0x3A6BE0))
                .frame(width: 12, height: 5).offset(x: 2, y: -18)
            Wheel(angle: 0).frame(width: 16, height: 16).offset(x: -24, y: 14)
            Wheel(angle: 0).frame(width: 16, height: 16).offset(x: 24, y: 14)
            if siren {
                Circle().fill(Color(hex: 0xE5484D).opacity(Int(time * 4) % 2 == 0 ? 0.35 : 0))
                    .frame(width: 60, height: 60).blur(radius: 10).offset(x: 2, y: -18)
            }
        }
        .frame(width: 80, height: 50)
        .accessibilityHidden(true)
    }
}

// MARK: - City

/// Skyline silhouettes with lit windows, deterministic.
struct Skyline: View {
    var body: some View {
        Canvas { ctx, size in
            func building(_ x: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color, seed: Int) {
                let rect = CGRect(x: x, y: size.height - h, width: w, height: h)
                ctx.fill(Path(rect), with: .color(color))
                var n = seed
                for wy in stride(from: rect.minY + 8, to: rect.maxY - 6, by: 12) {
                    for wx in stride(from: rect.minX + 5, to: rect.maxX - 6, by: 10) {
                        n = (n &* 1103515245 &+ 12345) & 0x7fffffff
                        if n % 3 == 0 {
                            ctx.fill(Path(CGRect(x: wx, y: wy, width: 4, height: 5)), with: .color(Toon.window.opacity(0.75)))
                        }
                    }
                }
            }
            let widths: [CGFloat] = [46, 30, 58, 36, 52, 28, 44, 62, 34, 48]
            let heights: [CGFloat] = [0.55, 0.8, 0.45, 0.95, 0.6, 0.75, 0.5, 0.85, 0.65, 0.5]
            var x: CGFloat = -10
            var i = 0
            while x < size.width {
                let w = widths[i % widths.count]
                building(x, w, size.height * heights[i % heights.count], i % 2 == 0 ? Toon.skylineFar : Toon.skyline, seed: i * 7 + 3)
                x += w + 2
                i += 1
            }
        }
        .accessibilityHidden(true)
    }
}

struct StreetLamp: View {
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Toon.outline).frame(width: 4, height: 70).offset(y: 6)
            Capsule().fill(Toon.outline).frame(width: 18, height: 6)
            Circle().fill(Toon.lamp).frame(width: 10, height: 10).offset(y: 3)
            Circle().fill(Toon.lamp.opacity(0.25)).frame(width: 46, height: 46).blur(radius: 8).offset(y: -14)
        }
        .frame(width: 46, height: 80)
        .accessibilityHidden(true)
    }
}

// MARK: - Badges and slots

/// The red "Level N" badge on a station; a green arrow when the next level is affordable, a pulsing ring when
/// this station is the bottleneck.
struct LevelBadge: View {
    let level: Int
    let caption: String
    var affordable = false
    var bottleneck = false
    var locked = false
    @Environment(\.l10n) private var t

    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: t("l4_badge_level")).font(.system(size: 11, weight: .bold, design: .rounded))
            Text(verbatim: "\(level)").font(.system(size: 22, weight: .heavy, design: .rounded)).monospacedDigit()
                .minimumScaleFactor(0.6).lineLimit(1)
        }
        .foregroundStyle(.white)
        .frame(width: 62, height: 50)
        .background(locked ? Toon.badgeGrey : Toon.badge, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(locked ? Color.black.opacity(0.2) : Toon.badgeDark)
                .frame(height: 5).offset(y: 0).mask(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .overlay(alignment: .topLeading) {
            if affordable {
                Image(systemName: "arrowshape.up.fill").font(.system(size: 16, weight: .heavy)).foregroundStyle(Toon.up)
                    .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                    .offset(x: -8, y: -10)
            }
        }
        .overlay(alignment: .topTrailing) {
            if bottleneck { BottleneckDot().offset(x: 8, y: -8) }
        }
        .overlay(alignment: .bottom) {
            Text(verbatim: caption).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
                .shadow(color: .black, radius: 2)
                .offset(y: 16)
        }
    }
}

/// A red "!" that pulses on the station that holds the flow back.
struct BottleneckDot: View {
    @State private var pulse = false
    @Environment(\.noirReduceMotion) private var reduceMotion

    var body: some View {
        Text(verbatim: "!").font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Color(hex: 0xE5484D), in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .scaleEffect(pulse && !reduceMotion ? 1.18 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
            .accessibilityHidden(true)
    }
}

/// Where a manager would stand: a dashed silhouette with a plus and the price, or the manager's portrait.
struct ManagerSlot: View {
    let crew: String
    let hired: Bool
    let cost: Double
    let affordable: Bool
    @Environment(\.l10n) private var t

    var body: some View {
        VStack(spacing: 2) {
            if hired {
                Portrait(crewId: crew, size: 40).clipShape(Circle())
                    .overlay(Circle().stroke(Toon.window, lineWidth: 2))
            } else {
                ZStack {
                    Capsule().stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 3])).foregroundStyle(.white.opacity(0.85))
                        .frame(width: 30, height: 46)
                    Image(systemName: "plus").font(.system(size: 16, weight: .heavy)).foregroundStyle(.white)
                }
                Text(verbatim: t.money(cost)).font(.system(size: 11, weight: .heavy, design: .rounded)).monospacedDigit()
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .foregroundStyle(affordable ? Color(hex: 0x1B1B28) : .white)
                    .background(affordable ? Toon.window : Color.black.opacity(0.45), in: Capsule())
            }
        }
        .frame(minWidth: 44, minHeight: 44)
    }
}

/// A small coin label with an amount, as floating over stations.
struct CoinLabel: View {
    let text: String
    var tint: Color = Toon.window

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(tint).frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color(hex: 0xC89520), lineWidth: 1.5))
            Text(verbatim: text).font(.system(size: 13, weight: .heavy, design: .rounded)).monospacedDigit()
                .foregroundStyle(.white).shadow(color: .black.opacity(0.6), radius: 1, y: 1)
        }
    }
}
