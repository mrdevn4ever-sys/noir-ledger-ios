import Testing
import UIKit
@testable import NoirLedger

@Suite("Workshop progress compositor") @MainActor
struct CycleFillTests {
    @Test("One leading rounded fill; no track when hidden, expired, full or detached")
    func lifecycle() throws {
        // A long test interval avoids making lifecycle assertions depend on simulator load.
        func widths(_ cycle: Double) -> CycleWidths {
            CycleWidths(cycle: cycle, seconds: 30, width: 167, interval: 4, timeScale: 1)
        }
        let view = CycleFillView(frame: CGRect(x: 0, y: 0, width: 167, height: 7))
        let window = UIWindow(frame: view.bounds)
        let tick = Date().timeIntervalSinceReferenceDate
        let fill = try #require(view.layer.sublayers?.first)
        view.configure(widths(0.7), tickAt: tick, active: true)
        #expect(fill.animationKeys() == nil)
        window.addSubview(view)
        #expect(view.layer.sublayers?.count == 1)
        #expect(fill.anchorPoint == .zero && fill.position == .zero && fill.cornerRadius == 3.5)
        let first = try #require(fill.animation(forKey: "progress") as? CAKeyframeAnimation)
        #expect(first.keyPath == "bounds.size.width" && first.calculationMode == .linear)
        #expect(fill.bounds.width == widths(0.7).value(at: 6))
        view.configure(widths(0.7), tickAt: tick, active: true)
        #expect(fill.animation(forKey: "progress")?.beginTime == first.beginTime)
        view.configure(widths(0), tickAt: tick, active: true)
        let reset = try #require(fill.animation(forKey: "progress") as? CAKeyframeAnimation)
        let values = try #require(reset.values as? [NSNumber]).map(\.doubleValue)
        #expect(values.first == 7 && values.last == widths(0).value(at: 6))
        #expect(reset.keyTimes?.first?.doubleValue == 0 && reset.keyTimes?.last?.doubleValue == 1)
        view.configure(widths(0), tickAt: tick, active: false)
        #expect(fill.animationKeys() == nil)
        view.configure(widths(0), tickAt: tick - 10, active: true)
        #expect(fill.animationKeys() == nil && fill.bounds.width == widths(0).value(at: 6))
        view.configure(widths(1), tickAt: tick, active: true)
        #expect(fill.animationKeys() == nil && fill.bounds.width == 167)
        view.configure(widths(0.5), tickAt: tick, active: true)
        #expect(fill.animation(forKey: "progress") != nil)
        view.removeFromSuperview()
        #expect(fill.animationKeys() == nil)
    }
}
