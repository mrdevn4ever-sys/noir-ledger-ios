import Testing
import UIKit
@testable import NoirLedger

@Suite("Staffed floor rendering") @MainActor
struct CrewLayerTests {
    @Test("A floor reuses its route, keeps mirrored art registered, and stops offscreen")
    func crewLifecycle() throws {
        let image = try #require(UIImage(named: "CrateSlot")?.cgImage)
        let sheets = [8, 4, 8].map { count in
            SpriteSheet(frames: Array(repeating: image, count: count), crop: CGRect(x: 0.1, y: 0.1, width: 0.6, height: 0.8))
        }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 196))
        let surface = CrewLayerView(frame: window.bounds)
        func set(_ active: Bool) { surface.configure(sheets: sheets, count: 3, shelf: 144, start: 150, end: 317, active: active) }
        set(true)
        #expect(surface.layer.sublayers?.count == 3)
        #expect(surface.layer.sublayers?.first?.animationKeys() == nil)
        window.addSubview(surface)
        let first = try #require(surface.layer.sublayers?.first)
        let route = try #require(first.animation(forKey: "route") as? CAKeyframeAnimation)
        #expect(route.duration == CrewRoute.period)
        let times = try #require(route.keyTimes).map(\.doubleValue)
        #expect(times == [0.0, 0.3, 0.6, 1.0])
        let xs = try #require(route.values as? [NSNumber]).map(\.doubleValue)
        let station = Double(CrewRoute.station(0, start: 150, end: 317))
        #expect(xs == [144, station, station, 144])
        let poses = try #require(first.sublayers)
        #expect(poses.count == 3)
        let carry = try #require(poses.last)
        #expect(carry.affineTransform().a == -1)
        #expect(abs(carry.frame.minX - 0.3 * first.bounds.width) < 0.001)
        #expect(poses.allSatisfy { $0.animation(forKey: "frames") != nil && $0.animation(forKey: "pose") != nil })
        set(true)
        #expect(first === surface.layer.sublayers?.first)
        set(false)
        #expect(surface.layer.sublayers?.allSatisfy { $0.animationKeys() == nil && $0.sublayers?.count == 1 && $0.sublayers?.first?.animationKeys() == nil } == true)
        set(true)
        surface.removeFromSuperview()
        #expect(surface.layer.sublayers?.allSatisfy { $0.animationKeys() == nil && $0.sublayers?.first?.animationKeys() == nil } == true)
    }
}
