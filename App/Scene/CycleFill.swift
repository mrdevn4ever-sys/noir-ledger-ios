import SwiftUI
import UIKit

/// The simulation supplies a new short track each tick; the render server draws the intervening frames.
struct CycleFill: UIViewRepresentable {
    let widths: CycleWidths
    let tickAt: Double
    let active: Bool

    func makeUIView(context: Context) -> CycleFillView { CycleFillView(frame: .zero) }
    func updateUIView(_ view: CycleFillView, context: Context) {
        view.configure(widths, tickAt: tickAt, active: active)
    }
}

final class CycleFillView: UIView {
    private let fill = CALayer()
    private var widths: CycleWidths?
    private var tickAt = 0.0
    private var requested = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        fill.anchorPoint = CGPoint(x: 0, y: 0)
        fill.position = .zero
        fill.cornerRadius = 3.5
        fill.cornerCurve = .circular
        fill.backgroundColor = UIColor(Toon.up).cgColor
        layer.addSublayer(fill)
    }
    required init?(coder: NSCoder) { nil }

    func configure(_ next: CycleWidths, tickAt: Double, active: Bool) {
        guard widths != next || self.tickAt != tickAt || requested != active else { return }
        widths = next
        self.tickAt = tickAt
        requested = active
        refresh()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refresh()
    }

    private func refresh() {
        guard let widths else { return }
        let age = max(0, Date().timeIntervalSinceReferenceDate - tickAt)
        let now = fill.convertTime(CACurrentMediaTime(), from: nil)
        let current = widths.value(at: age)
        let end = widths.value(at: widths.duration)
        let travel = requested && window != nil && age < widths.duration && current < end
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        fill.removeAnimation(forKey: "progress")
        fill.bounds = CGRect(x: 0, y: 0, width: travel ? end : current, height: 7)
        guard travel else { return }
        let times = widths.stops
        let track = CAKeyframeAnimation(keyPath: "bounds.size.width")
        track.values = times.map { NSNumber(value: widths.value(at: $0)) }
        track.keyTimes = times.map { NSNumber(value: $0 / widths.duration) }
        track.calculationMode = .linear
        track.timingFunction = CAMediaTimingFunction(name: .linear)
        track.duration = widths.duration
        track.beginTime = now - age
        fill.add(track, forKey: "progress")
    }
}
