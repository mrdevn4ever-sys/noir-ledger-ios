import Testing
import UIKit
@testable import NoirLedger

@Suite("Single-layer staffed crew") @MainActor
struct CrewLayerTests {
    @Test("Three registered poses share one synchronized image layer for each worker")
    func routeAndLifecycle() throws {
        let sheets = try [SceneArt.Move.walk, .work, .carry].map { move in
            try #require(SceneImages.make(SceneArt.worker(.weed, move), frames: move.frames))
        }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 70))
        let view = CrewLayerView(frame: window.bounds)
        func set(_ active: Bool) { view.configure(sheets: sheets, count: 3, shelf: 144, start: 150, end: 317, active: active) }
        set(true)
        #expect(view.layer.sublayers?.first?.animationKeys() == nil)
        window.addSubview(view)
        let actors = try #require(view.layer.sublayers)
        #expect(actors.count == 3)
        for (i, actor) in actors.enumerated() {
            #expect(actor.sublayers?.isEmpty ?? true)
            #expect(Set(actor.animationKeys() ?? []) == Set(["position.x", "transform", "contents"]))
            let art = try #require(actor.animation(forKey: "contents") as? CAKeyframeAnimation)
            let flip = try #require(actor.animation(forKey: "transform") as? CAKeyframeAnimation)
            let route = try #require(actor.animation(forKey: "position.x") as? CAKeyframeAnimation)
            #expect(art.calculationMode == .discrete && flip.calculationMode == .discrete && route.calculationMode == .linear)
            #expect([art, flip, route].allSatisfy { $0.duration == 7 && $0.beginTime == art.beginTime && $0.repeatCount.isInfinite })
            let station = Double(CrewRoute.station(i, start: 150, end: 317))
            let positions = try #require(route.values as? [NSNumber]).map(\.doubleValue)
            #expect(positions == [144, station, station, 144])
            let offsets = try #require(art.keyTimes).map(\.doubleValue)
            let images = try #require(art.values as? [CGImage])
            #expect(offsets.count == images.count)
            // Independent of the production key list: check the frame on every 1/30-second boundary.
            for tick in 0..<210 {
                let time = Double(tick) / 210
                let k = try #require(offsets.lastIndex { $0 <= time })
                let (pose, frame) = tick < 63 ? (0, tick / 3 % 8) : tick < 126 ? (1, (tick - 63) / 5 % 4) : (2, (tick - 126) / 3 % 8)
                #expect(images[k] === sheets[pose].frames[frame])
            }
            #expect(offsets.last == 1 && images.last === sheets[0].frames.first)
            let transforms = try #require(flip.values as? [NSValue])
            let bounds = try #require(flip.keyTimes).map(\.doubleValue)
            #expect(bounds == [0, 0.3, 0.6, 1])
            let mirror = CATransform3DGetAffineTransform(transforms[2].caTransform3DValue)
            #expect(mirror.a < 0)
        }
        let a = try #require(actors.first)
        let b = try #require(actors.dropFirst().first)
        let origin = try #require(a.animation(forKey: "contents")).beginTime
        let second = try #require(b.animation(forKey: "contents")).beginTime
        let shift = (origin - second + 7).truncatingRemainder(dividingBy: 7)
        #expect(abs(shift - 2.3) < 0.0001)
        set(true)
        #expect(a.animation(forKey: "contents")?.beginTime == origin)
        set(false)
        #expect(actors.allSatisfy { $0.animationKeys() == nil && $0.contents != nil })
        set(true)
        #expect(a === view.layer.sublayers?.first && a.animation(forKey: "contents") != nil)
        view.removeFromSuperview()
        #expect(actors.allSatisfy { $0.animationKeys() == nil })
    }

    @Test("Asymmetric crops mirror about the original 44-point canvas")
    func cropRegistration() {
        let crop = CGRect(x: 0.10, y: 0.15, width: 0.60, height: 0.65)
        let size = CGSize(width: 44, height: 70)
        let canvas = CGRect(x: -22, y: -35, width: 44, height: 70)
        for mirrored in [false, true] {
            let rect = canvas.applying(CrewRoute.registration(crop, size: size, mirrored: mirrored)).standardized
            #expect(abs(rect.minX + 22 - (mirrored ? 1 - crop.maxX : crop.minX) * 44) < 0.0001)
            #expect(abs(rect.minY + 35 - crop.minY * 70) < 0.0001)
            #expect(abs(rect.width - crop.width * 44) < 0.0001)
            #expect(abs(rect.height - crop.height * 70) < 0.0001)
        }
    }
}
