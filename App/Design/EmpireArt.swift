import NoirCore
import SwiftUI
import UIKit

/// Optional rendered artwork. A scene first looks for a delivered image in the asset catalog and otherwise draws
/// itself, so rendered rooms and sprite sheets can be dropped in later without touching the scene code.
///
/// Names: `Room<Product><tier>` (tier 0–3, e.g. `RoomGlimmer2`), `SceneStreet`, `SceneStash`, `SpriteWorker`
/// (a horizontal strip of `ArtBank.spriteFrames` frames).
@MainActor
enum ArtBank {
    static let spriteFrames = 8
    private static var known: [String: Bool] = [:]

    static func has(_ name: String) -> Bool {
        if let hit = known[name] { return hit }
        let hit = UIImage(named: name) != nil
        known[name] = hit
        return hit
    }

    static func image(_ name: String) -> Image? { has(name) ? Image(name) : nil }

    private static func stem(_ p: ProductId) -> String {
        switch p {
        case .glimmer: "RoomGlimmer"
        case .cinder: "RoomCinder"
        case .velvet: "RoomVelvet"
        case .halo: "RoomHalo"
        }
    }

    /// The best delivered room plate at or below `tier`.
    static func room(_ p: ProductId, tier: Int) -> Image? {
        for k in stride(from: min(3, max(0, tier)), through: 0, by: -1) {
            if let image = image(stem(p) + String(k)) { return image }
        }
        return nil
    }
}

/// Scene-only colours: one light per product, on top of the shared token map.
enum SceneTint {
    static let ember = Color(hex: 0xD8742E)
    static let plum = Color(hex: 0xA77BC0)
    static let ice = Color(hex: 0x9FD3E0)
    static let wall = Color(hex: 0x1D1712)
    static let wallDeep = Color(hex: 0x0C0A08)
    static let figure = Color(hex: 0x090807)

    static func product(_ p: ProductId) -> Color {
        switch p {
        case .glimmer: Noir.amber
        case .cinder: ember
        case .velvet: plum
        case .halo: ice
        }
    }
}

/// Draws a delivered plate so that it fills the scene without distortion (centred, cropped at the edges).
@MainActor
private func drawPlate(_ ctx: inout GraphicsContext, _ plate: Image, _ size: CGSize) {
    let resolved = ctx.resolve(plate)
    let source = resolved.size
    guard source.width > 0, source.height > 0, size.width > 0, size.height > 0 else { return }
    let scale = max(size.width / source.width, size.height / source.height)
    let fitted = CGSize(width: source.width * scale, height: source.height * scale)
    let origin = CGPoint(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2)
    var clipped = ctx
    clipped.clip(to: Path(CGRect(origin: .zero, size: size)))
    clipped.draw(resolved, in: CGRect(origin: origin, size: fitted))
}

/// Cheap deterministic noise in 0..<1, so skylines, rain and flicker look the same on every launch.
private func grain(_ n: Int) -> Double {
    let x = sin(Double(n) * 127.1 + 311.7) * 43_758.5453
    return x - x.rounded(.down)
}

// MARK: - A production room

/// One floor of the operation seen from the side: a lit room, the line's apparatus, the crew at work and crates
/// leaving on the belt. The room fills up as the line passes its milestones.
struct RoomScene: View {
    let product: ProductId
    /// 0–3: how built-out the room is.
    let tier: Int
    let workers: Int
    let running: Bool
    @Environment(\.noirReduceMotion) private var reduceMotion

    var body: some View {
        let plate = ArtBank.room(product, tier: tier)
        let sprite = ArtBank.image("SpriteWorker")
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !running)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                if let plate {
                    drawPlate(&ctx, plate, size)
                } else {
                    drawRoom(&ctx, size, time)
                    drawApparatus(&ctx, size, time)
                }
                drawBelt(&ctx, size, time)
                drawCrew(&ctx, size, time, sprite: sprite)
                if !running {
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SceneTint.wallDeep.opacity(0.55)))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var accent: Color { SceneTint.product(product) }

    private func drawRoom(_ ctx: inout GraphicsContext, _ size: CGSize, _ time: Double) {
        let w = size.width, h = size.height
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [SceneTint.wall, SceneTint.wallDeep]),
                                       startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))
        // Brick courses.
        var bricks = Path()
        var y: CGFloat = 10
        var row = 0
        while y < h * 0.78 {
            bricks.move(to: CGPoint(x: 0, y: y))
            bricks.addLine(to: CGPoint(x: w, y: y))
            var x: CGFloat = row % 2 == 0 ? 0 : 14
            while x < w {
                bricks.move(to: CGPoint(x: x, y: y))
                bricks.addLine(to: CGPoint(x: x, y: y + 10))
                x += 28
            }
            y += 10
            row += 1
        }
        ctx.stroke(bricks, with: .color(Noir.hairline.opacity(0.35)), lineWidth: 0.5)
        // Floor.
        ctx.fill(Path(CGRect(x: 0, y: h * 0.82, width: w, height: h * 0.18)), with: .color(SceneTint.wallDeep))
        ctx.fill(Path(CGRect(x: 0, y: h * 0.82, width: w, height: 1)), with: .color(Noir.brass.opacity(0.35)))

        if tier >= 1 {
            // Shelves with stock on the back wall.
            for shelf in 0..<2 {
                let sy = h * (0.30 + 0.17 * CGFloat(shelf))
                ctx.fill(Path(CGRect(x: w * 0.60, y: sy, width: w * 0.34, height: 2)), with: .color(Noir.brass.opacity(0.5)))
                for i in 0..<5 {
                    let bh = CGFloat(8 + 6 * grain(i + shelf * 7 + 3))
                    let bx: CGFloat = w * 0.615 + CGFloat(i) * w * 0.064
                    let box = CGRect(x: bx, y: sy - bh, width: w * 0.05, height: bh)
                    ctx.fill(Path(roundedRect: box, cornerRadius: 1.5), with: .color(accent.opacity(0.25 + 0.3 * grain(i * 3 + shelf))))
                }
            }
        }
        if tier >= 2 {
            // Ceiling pipes.
            var pipe = Path()
            pipe.move(to: CGPoint(x: 0, y: 9))
            pipe.addLine(to: CGPoint(x: w, y: 9))
            pipe.move(to: CGPoint(x: w * 0.42, y: 9))
            pipe.addLine(to: CGPoint(x: w * 0.42, y: h * 0.3))
            ctx.stroke(pipe, with: .color(Noir.brass.opacity(0.45)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        if tier >= 3 {
            // The house sign: a lit frame in the line's colour.
            let sign = CGRect(x: w * 0.44, y: h * 0.10, width: w * 0.13, height: h * 0.16)
            let glow = 0.7 + 0.3 * sin(time * 2.3)
            ctx.fill(Path(ellipseIn: sign.insetBy(dx: -18, dy: -14)),
                     with: .radialGradient(Gradient(colors: [accent.opacity(0.28 * glow), .clear]),
                                           center: CGPoint(x: sign.midX, y: sign.midY), startRadius: 2, endRadius: 46))
            ctx.stroke(Path(roundedRect: sign, cornerRadius: 4), with: .color(accent.opacity(0.6 + 0.4 * glow)), lineWidth: 2)
            ctx.stroke(Path(ellipseIn: sign.insetBy(dx: sign.width * 0.3, dy: sign.height * 0.3)),
                       with: .color(accent.opacity(0.6 + 0.4 * glow)), lineWidth: 1.5)
        }
        // The bare bulb.
        lamp(&ctx, at: CGPoint(x: w * 0.24, y: h * 0.20), radius: h * 0.62, time: time, seed: 1)
        if tier >= 2 { lamp(&ctx, at: CGPoint(x: w * 0.74, y: h * 0.16), radius: h * 0.5, time: time, seed: 5) }
    }

    private func lamp(_ ctx: inout GraphicsContext, at p: CGPoint, radius: CGFloat, time: Double, seed: Int) {
        let flicker = 0.86 + 0.08 * sin(time * 7.3 + Double(seed)) + 0.06 * sin(time * 23.1 + Double(seed) * 2)
        var cord = Path()
        cord.move(to: CGPoint(x: p.x, y: 0))
        cord.addLine(to: p)
        ctx.stroke(cord, with: .color(Noir.inkMuted.opacity(0.6)), lineWidth: 1)
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius * 0.6, width: radius * 2, height: radius * 1.7)),
                 with: .radialGradient(Gradient(colors: [Noir.amber.opacity(0.30 * flicker), Noir.amber.opacity(0.07 * flicker), .clear]),
                                       center: p, startRadius: 1, endRadius: radius))
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)), with: .color(Noir.paper.opacity(flicker)))
    }

    private func drawApparatus(_ ctx: inout GraphicsContext, _ size: CGSize, _ time: Double) {
        let w = size.width, h = size.height
        let floor = h * 0.82
        let live = running ? 1.0 : 0.0
        // The bench every line works at.
        let bench = CGRect(x: w * 0.30, y: floor - h * 0.20, width: w * 0.26, height: 4)
        ctx.fill(Path(bench), with: .color(Noir.brassDark))
        ctx.fill(Path(CGRect(x: bench.minX + 4, y: bench.maxY, width: 3, height: floor - bench.maxY)), with: .color(Noir.brassDark.opacity(0.8)))
        ctx.fill(Path(CGRect(x: bench.maxX - 7, y: bench.maxY, width: 3, height: floor - bench.maxY)), with: .color(Noir.brassDark.opacity(0.8)))
        switch product {
        case .glimmer:
            // Three flasks with a slow simmer.
            for i in 0..<3 {
                let cx = bench.minX + bench.width * (0.2 + 0.3 * CGFloat(i))
                var flask = Path()
                flask.move(to: CGPoint(x: cx - 3, y: bench.minY - 26))
                flask.addLine(to: CGPoint(x: cx + 3, y: bench.minY - 26))
                flask.addLine(to: CGPoint(x: cx + 3, y: bench.minY - 16))
                flask.addLine(to: CGPoint(x: cx + 10, y: bench.minY))
                flask.addLine(to: CGPoint(x: cx - 10, y: bench.minY))
                flask.addLine(to: CGPoint(x: cx - 3, y: bench.minY - 16))
                flask.closeSubpath()
                ctx.fill(flask, with: .color(accent.opacity(0.22)))
                ctx.stroke(flask, with: .color(accent.opacity(0.8)), lineWidth: 1)
                ctx.fill(Path(CGRect(x: cx - 8, y: bench.minY - 6, width: 16, height: 6)), with: .color(accent.opacity(0.75)))
                for b in 0..<3 {
                    let phase = (time * (0.7 + 0.2 * Double(b)) * live + grain(i * 5 + b)).truncatingRemainder(dividingBy: 1)
                    let by: CGFloat = bench.minY - 6 - CGFloat(phase) * 20
                    let bx: CGFloat = cx - 2 + CGFloat(b - 1) * 3
                    ctx.fill(Path(ellipseIn: CGRect(x: bx, y: by, width: 3, height: 3)), with: .color(accent.opacity(0.9 * (1 - phase))))
                }
            }
        case .cinder:
            // A furnace with a breathing door and sparks.
            let body = CGRect(x: bench.minX + bench.width * 0.2, y: bench.minY - 44, width: bench.width * 0.6, height: 44)
            ctx.fill(Path(roundedRect: body, cornerRadius: 3), with: .color(SceneTint.figure))
            ctx.stroke(Path(roundedRect: body, cornerRadius: 3), with: .color(Noir.brassDark), lineWidth: 1)
            let door = CGRect(x: body.midX - 11, y: body.maxY - 22, width: 22, height: 14)
            let pulse = 0.65 + 0.35 * sin(time * 3.1) * live
            ctx.fill(Path(ellipseIn: door.insetBy(dx: -22, dy: -18)),
                     with: .radialGradient(Gradient(colors: [accent.opacity(0.5 * pulse), .clear]),
                                           center: CGPoint(x: door.midX, y: door.midY), startRadius: 2, endRadius: 34))
            ctx.fill(Path(roundedRect: door, cornerRadius: 3), with: .color(accent.opacity(0.55 + 0.45 * pulse)))
            ctx.fill(Path(CGRect(x: body.midX - 4, y: 0, width: 8, height: body.minY)), with: .color(SceneTint.figure))
            for k in 0..<5 {
                let phase = (time * 0.9 * live + grain(k * 11)).truncatingRemainder(dividingBy: 1)
                let spread = CGFloat(grain(k * 3) - 0.5) * 30
                let sway = CGFloat(sin(time * 2 + Double(k))) * 3
                let spark = CGRect(x: door.midX + spread + sway, y: door.minY - CGFloat(phase) * 34, width: 2, height: 2)
                ctx.fill(Path(ellipseIn: spark), with: .color(accent.opacity(1 - phase)))
            }
        case .velvet:
            // A copper still with a coil and rising vapour.
            let pot = CGRect(x: bench.minX + bench.width * 0.12, y: bench.minY - 30, width: 34, height: 30)
            ctx.fill(Path(ellipseIn: pot), with: .color(Noir.brassDark))
            ctx.stroke(Path(ellipseIn: pot), with: .color(Noir.brass), lineWidth: 1)
            var coil = Path()
            coil.move(to: CGPoint(x: pot.midX, y: pot.minY))
            coil.addCurve(to: CGPoint(x: bench.maxX - 16, y: bench.minY - 12),
                          control1: CGPoint(x: pot.midX + 10, y: pot.minY - 30), control2: CGPoint(x: bench.maxX - 16, y: pot.minY - 30))
            ctx.stroke(coil, with: .color(Noir.brass), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            let jar = CGRect(x: bench.maxX - 24, y: bench.minY - 14, width: 16, height: 14)
            ctx.fill(Path(roundedRect: jar, cornerRadius: 2), with: .color(accent.opacity(0.7)))
            for k in 0..<4 {
                let phase = (time * 0.35 * live + grain(k * 17)).truncatingRemainder(dividingBy: 1)
                let r: CGFloat = 5 + CGFloat(phase) * 9
                let drift = CGFloat(sin(time + Double(k))) * 4
                let puff = CGRect(x: pot.midX - r + drift, y: pot.minY - 8 - CGFloat(phase) * 30, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: puff), with: .color(accent.opacity(0.22 * (1 - phase))))
            }
        case .halo:
            // Rings turning in a cold light.
            let c = CGPoint(x: bench.midX, y: bench.minY - 24)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 40, y: c.y - 34, width: 80, height: 68)),
                     with: .radialGradient(Gradient(colors: [accent.opacity(0.32), .clear]), center: c, startRadius: 2, endRadius: 40))
            for k in 0..<3 {
                let angle = time * (0.9 + 0.35 * Double(k)) * live + Double(k) * 1.1
                let ry: CGFloat = 20 - CGFloat(k) * 5
                let squash = CGFloat(abs(cos(angle)).clamped(to: 0.12...1))
                let rx: CGFloat = ry * squash
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2)),
                           with: .color(accent.opacity(0.95 - 0.2 * Double(k))), lineWidth: 1.6)
            }
            var stand = Path()
            stand.move(to: CGPoint(x: c.x, y: c.y + 20))
            stand.addLine(to: CGPoint(x: c.x, y: bench.minY))
            ctx.stroke(stand, with: .color(Noir.brass), lineWidth: 2)
        }
    }

    private func drawBelt(_ ctx: inout GraphicsContext, _ size: CGSize, _ time: Double) {
        let w = size.width, h = size.height
        let y = h * 0.93
        ctx.fill(Path(CGRect(x: 0, y: y, width: w, height: 2)), with: .color(Noir.hairline))
        guard running else { return }
        let spacing: CGFloat = 54
        let shift = CGFloat((time * 26).truncatingRemainder(dividingBy: Double(spacing)))
        var x = -spacing + shift
        while x < w {
            let crate = CGRect(x: x, y: y - 9, width: 12, height: 9)
            ctx.fill(Path(roundedRect: crate, cornerRadius: 1.5), with: .color(accent.opacity(0.85)))
            ctx.fill(Path(CGRect(x: crate.minX, y: crate.midY - 0.5, width: crate.width, height: 1)), with: .color(SceneTint.wallDeep.opacity(0.6)))
            x += spacing
        }
    }

    private func drawCrew(_ ctx: inout GraphicsContext, _ size: CGSize, _ time: Double, sprite: Image?) {
        let w = size.width, h = size.height
        let floor = h * 0.82
        let count = min(4, max(1, workers))
        let slots: [CGFloat] = [0.20, 0.50, 0.66, 0.84]
        for i in 0..<count {
            let x = w * slots[i]
            let height = h * 0.44
            if let sprite {
                let frame = running ? Int(time * 10 + Double(i) * 3) % ArtBank.spriteFrames : 0
                let dest = CGRect(x: x - height * 0.4, y: floor - height, width: height * 0.8, height: height)
                var clipped = ctx
                clipped.clip(to: Path(dest))
                clipped.draw(sprite, in: CGRect(x: dest.minX - CGFloat(frame) * dest.width, y: dest.minY,
                                                width: dest.width * CGFloat(ArtBank.spriteFrames), height: dest.height))
            } else {
                figure(&ctx, x: x, floor: floor, height: height, time: time, seed: i)
            }
        }
    }

    /// A coat-and-hat silhouette with a warm rim light, working with one arm.
    private func figure(_ ctx: inout GraphicsContext, x: CGFloat, floor: CGFloat, height: CGFloat, time: Double, seed: Int) {
        let live = running ? 1.0 : 0.0
        let bob = CGFloat(sin(time * 3.2 + Double(seed) * 1.7)) * 1.2 * CGFloat(live)
        let head = height * 0.16
        let bodyTop = floor - height * 0.78 + bob
        var shape = Path()
        // Legs.
        shape.addRect(CGRect(x: x - height * 0.10, y: floor - height * 0.30, width: height * 0.08, height: height * 0.30))
        shape.addRect(CGRect(x: x + height * 0.02, y: floor - height * 0.30, width: height * 0.08, height: height * 0.30))
        // Coat.
        shape.addRoundedRect(in: CGRect(x: x - height * 0.15, y: bodyTop, width: height * 0.30, height: height * 0.52),
                             cornerSize: CGSize(width: 5, height: 5))
        // Head and hat.
        shape.addEllipse(in: CGRect(x: x - head / 2, y: bodyTop - head * 0.95, width: head, height: head))
        shape.addRect(CGRect(x: x - head * 0.55, y: bodyTop - head * 1.25, width: head * 1.1, height: head * 0.42))
        shape.addEllipse(in: CGRect(x: x - head * 0.95, y: bodyTop - head * 0.92, width: head * 1.9, height: head * 0.26))
        ctx.fill(shape, with: .color(SceneTint.figure))
        ctx.stroke(shape, with: .color(Noir.amber.opacity(0.42)), lineWidth: 0.8)
        // The working arm.
        let swing = sin(time * 5.0 + Double(seed) * 2.1) * 0.55 * live + 0.35
        let shoulder = CGPoint(x: x + height * 0.12, y: bodyTop + height * 0.10)
        let reach = height * 0.26
        let hand = CGPoint(x: shoulder.x + CGFloat(cos(swing)) * reach, y: shoulder.y + CGFloat(sin(swing)) * reach)
        var arm = Path()
        arm.move(to: shoulder)
        arm.addLine(to: hand)
        ctx.stroke(arm, with: .color(SceneTint.figure), style: StrokeStyle(lineWidth: height * 0.085, lineCap: .round))
        ctx.stroke(arm, with: .color(Noir.amber.opacity(0.35)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double { Swift.min(range.upperBound, Swift.max(range.lowerBound, self)) }
}

// MARK: - The street above the operation

/// The night street over the cellar: Varnholm's skyline in the rain, lit windows, the signs of the owned fronts and
/// the van that takes the goods out while the routes are selling.
struct StreetScene: View {
    let fronts: Int
    let selling: Bool
    let danger: Bool
    @Environment(\.noirReduceMotion) private var reduceMotion

    var body: some View {
        let plate = ArtBank.image("SceneStreet")
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                if let plate {
                    drawPlate(&ctx, plate, size)
                } else {
                    drawSky(&ctx, size, time)
                }
                drawStreet(&ctx, size, time)
                if !reduceMotion { drawRain(&ctx, size, time) }
            }
        }
        .accessibilityHidden(true)
    }

    private func drawSky(_ ctx: inout GraphicsContext, _ size: CGSize, _ time: Double) {
        let w = size.width, h = size.height
        let horizon = h * 0.80
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [SharedTokens.night, Color(hex: 0x1B1A22), Color(hex: 0x3A2A1C)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))
        // Far skyline, then the near one with lit windows.
        var x: CGFloat = -6
        var i = 0
        while x < w {
            let bw: CGFloat = 16 + CGFloat(grain(i * 2 + 1)) * 22
            let bh: CGFloat = h * (0.18 + 0.30 * CGFloat(grain(i * 5 + 2)))
            ctx.fill(Path(CGRect(x: x, y: horizon - bh, width: bw, height: bh)), with: .color(Color(hex: 0x15131A)))
            x += bw + 2
            i += 1
        }
        x = -10
        i = 0
        while x < w {
            let bw: CGFloat = 26 + CGFloat(grain(i * 3 + 40)) * 30
            let bh: CGFloat = h * (0.26 + 0.34 * CGFloat(grain(i * 7 + 41)))
            let building = CGRect(x: x, y: horizon - bh, width: bw, height: bh)
            ctx.fill(Path(building), with: .color(SceneTint.figure))
            var wy = building.minY + 6
            var row = 0
            while wy < horizon - 8 {
                var wx = building.minX + 4
                var col = 0
                while wx < building.maxX - 5 {
                    let seed = i * 131 + row * 17 + col
                    let lit = grain(seed) > 0.62
                    if lit {
                        let flick = grain(seed + Int(time * 0.2)) > 0.04 ? 1.0 : 0.3
                        ctx.fill(Path(CGRect(x: wx, y: wy, width: 3, height: 4)), with: .color(Noir.amber.opacity(0.75 * flick)))
                    }
                    wx += 7
                    col += 1
                }
                wy += 9
                row += 1
            }
            x += bw + 3
            i += 1
        }
    }

    private func drawStreet(_ ctx: inout GraphicsContext, _ size: CGSize, _ time: Double) {
        let w = size.width, h = size.height
        let horizon = h * 0.80
        ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)), with: .color(SceneTint.wallDeep))
        ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: 1)), with: .color(Noir.brass.opacity(0.3)))
        // Signs of the fronts the house owns.
        for k in 0..<min(5, fronts) {
            let sx = w * (0.10 + 0.19 * CGFloat(k))
            let sign = CGRect(x: sx, y: horizon - 20, width: 26, height: 10)
            let tint = [Noir.amber, Noir.influenceInk, SceneTint.plum, Noir.cleanInk, SceneTint.ice][k]
            let glow = 0.75 + 0.25 * sin(time * (1.7 + Double(k) * 0.4) + Double(k))
            ctx.fill(Path(ellipseIn: sign.insetBy(dx: -14, dy: -12)),
                     with: .radialGradient(Gradient(colors: [tint.opacity(0.35 * glow), .clear]),
                                           center: CGPoint(x: sign.midX, y: sign.midY), startRadius: 1, endRadius: 28))
            ctx.stroke(Path(roundedRect: sign, cornerRadius: 3), with: .color(tint.opacity(0.9 * glow)), lineWidth: 1.5)
            ctx.fill(Path(CGRect(x: sign.minX + 5, y: sign.midY - 1, width: sign.width - 10, height: 2)), with: .color(tint.opacity(0.9 * glow)))
            // Wet reflection.
            ctx.fill(Path(CGRect(x: sign.minX + 3, y: horizon + 3, width: sign.width - 6, height: h - horizon - 6)),
                     with: .color(tint.opacity(0.10 * glow)))
        }
        if danger {
            // Blue-less noir: a slow red sweep when the law is close.
            let sweep = 0.5 + 0.5 * sin(time * 4)
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)), with: .color(Noir.danger.opacity(0.10 * sweep)))
        }
        guard selling else { return }
        // The van.
        let span = w + 120
        let vx = CGFloat((time * 46).truncatingRemainder(dividingBy: Double(span))) - 60
        let ground = horizon + (h - horizon) * 0.62
        var beam = Path()
        beam.move(to: CGPoint(x: vx + 44, y: ground - 9))
        beam.addLine(to: CGPoint(x: vx + 104, y: ground - 18))
        beam.addLine(to: CGPoint(x: vx + 104, y: ground + 2))
        beam.closeSubpath()
        ctx.fill(beam, with: .linearGradient(Gradient(colors: [Noir.paper.opacity(0.35), .clear]),
                                             startPoint: CGPoint(x: vx + 44, y: ground), endPoint: CGPoint(x: vx + 104, y: ground)))
        var van = Path()
        van.addRoundedRect(in: CGRect(x: vx, y: ground - 20, width: 30, height: 18), cornerSize: CGSize(width: 2, height: 2))
        van.addRoundedRect(in: CGRect(x: vx + 29, y: ground - 14, width: 15, height: 12), cornerSize: CGSize(width: 2, height: 2))
        ctx.fill(van, with: .color(Color(hex: 0x241C14)))
        ctx.stroke(van, with: .color(Noir.amber.opacity(0.5)), lineWidth: 0.8)
        ctx.fill(Path(CGRect(x: vx + 33, y: ground - 12, width: 8, height: 5)), with: .color(Noir.amber.opacity(0.55)))
        for wheel in [vx + 7, vx + 34] {
            ctx.fill(Path(ellipseIn: CGRect(x: wheel, y: ground - 5, width: 7, height: 7)), with: .color(SceneTint.figure))
        }
    }

    private func drawRain(_ ctx: inout GraphicsContext, _ size: CGSize, _ time: Double) {
        let w = size.width, h = size.height
        var rain = Path()
        for k in 0..<46 {
            let x: CGFloat = CGFloat(grain(k * 13 + 5)) * (w + 30) - 15
            let speed: Double = 150 + 120 * grain(k * 7 + 9)
            let fall = grain(k * 3 + 1) * Double(h) + time * speed
            let y = CGFloat(fall.truncatingRemainder(dividingBy: Double(h + 20))) - 10
            rain.move(to: CGPoint(x: x, y: y))
            rain.addLine(to: CGPoint(x: x - 2.5, y: y + 9))
        }
        ctx.stroke(rain, with: .color(Noir.influenceInk.opacity(0.28)), lineWidth: 0.7)
    }
}

// MARK: - The stash

/// The shared stash as shelves that fill up; red when there is no room left.
struct StashScene: View {
    let fraction: Double
    let full: Bool

    var body: some View {
        let plate = ArtBank.image("SceneStash")
        Canvas { ctx, size in
            let w = size.width, h = size.height
            if let plate {
                drawPlate(&ctx, plate, size)
            } else {
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: [SceneTint.wall, SceneTint.wallDeep]),
                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            }
            let columns = 12, rows = 2
            let filled = Int((max(0, min(1, fraction)) * Double(columns * rows)).rounded(.up))
            let cw = (w - 24) / CGFloat(columns)
            let tint = full ? Noir.danger : Noir.amber
            for r in 0..<rows {
                let shelfY = h * (0.48 + 0.42 * CGFloat(r))
                ctx.fill(Path(CGRect(x: 8, y: shelfY, width: w - 16, height: 2)), with: .color(Noir.brass.opacity(0.5)))
                for c in 0..<columns {
                    let index = (rows - 1 - r) * columns + c
                    let crateX: CGFloat = 14 + CGFloat(c) * cw
                    let crate = CGRect(x: crateX, y: shelfY - h * 0.30, width: cw - 4, height: h * 0.30)
                    if index < filled {
                        ctx.fill(Path(roundedRect: crate, cornerRadius: 2), with: .color(tint.opacity(0.55 + 0.35 * grain(index))))
                        ctx.fill(Path(CGRect(x: crate.minX, y: crate.midY, width: crate.width, height: 1)), with: .color(SceneTint.wallDeep.opacity(0.5)))
                    } else {
                        ctx.stroke(Path(roundedRect: crate, cornerRadius: 2), with: .color(Noir.hairline.opacity(0.7)),
                                   style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
