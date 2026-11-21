#if NOIR_QA
import Foundation
import SwiftUI
import UIKit

/// App-process uptime, independent of the simulation speed and XCTest's query/idle clock.
struct OpeningStamps {
    enum Point: String { case door, receipt, heirloom, offer, confirm }
    private(set) var shown: [Point: Double] = [:]
    private(set) var taps: [Point: Double] = [:]
    private var previous: [Point: Double] = [:]
    private(set) var wait: [Point: Double] = [:]
    private(set) var booked: Double?

    mutating func frame(_ point: Point, at now: Double, visible: Bool) {
        let eligible: Bool
        switch point {
        case .door: eligible = taps[.door] == nil
        case .receipt, .heirloom: eligible = taps[.door] != nil && taps[.heirloom] == nil
        case .offer: eligible = taps[.heirloom] != nil && taps[.offer] == nil
        case .confirm: eligible = taps[.offer] != nil && taps[.confirm] == nil
        }
        guard visible, eligible, taps[point] == nil else { previous[point] = nil; return }
        if shown[point] == nil { shown[point] = now }
        guard point != .receipt else { return }
        // Only discount consecutive responsive, visible frames awaiting the robot's next touch.
        // Never remove a main-thread stall, a screen transition, or time after a tap.
        if let last = previous[point], now >= last, now - last <= 0.15 { wait[point, default: 0] += now - last }
        previous[point] = now
    }

    mutating func touch(_ point: Point, at now: Double) {
        guard taps[point] == nil else { return }
        taps[point] = now
        previous[point] = nil
    }

    mutating func purchase(at now: Double) { if booked == nil { booked = now } }

    func report() -> [String: Double]? {
        guard let door = shown[.door], let collect = taps[.door], let receipt = shown[.receipt],
              let heirloom = shown[.heirloom], let choose = taps[.heirloom], let offer = shown[.offer],
              let open = taps[.offer], let confirm = shown[.confirm], let buy = taps[.confirm], let booked,
              door <= collect, collect <= receipt, receipt <= choose, collect <= heirloom, heirloom <= choose,
              choose <= offer, offer <= open, open <= confirm, confirm <= buy, buy <= booked else { return nil }
        let pickupWait = wait[.door, default: 0]
        let robot = wait.values.reduce(0, +)
        return ["interactive": door, "receipt": receipt, "offer": offer, "confirmed": booked,
                "receiptRaw": receipt - door, "reward": receipt - door - pickupWait, "offerRaw": offer - door,
                "upgradeRaw": booked - door, "robot": robot, "upgrade": booked - door - robot,
                "collectTap": collect, "heirloomReady": heirloom, "chooseTap": choose,
                "offerTap": open, "confirmReady": confirm, "confirmTap": buy, "pickupWait": pickupWait]
    }
}

@Observable @MainActor final class OpeningProbe {
    static let shared = OpeningProbe()
    static let choice: String? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-qa-opening"), args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }()
    @ObservationIgnored private var stamps = OpeningStamps()
    private(set) var result = ""
    private var now: Double { ProcessInfo.processInfo.systemUptime }
    func frame(_ point: OpeningStamps.Point, visible: Bool) { stamps.frame(point, at: now, visible: visible) }
    func touch(_ point: OpeningStamps.Point) { if Self.choice != nil { stamps.touch(point, at: now) } }
    func purchased() {
        guard Self.choice != nil else { return }
        stamps.purchase(at: now)
        if let values = stamps.report(), let data = try? JSONEncoder().encode(values) { result = String(decoding: data, as: UTF8.self) }
    }
}

/// A marker attached to the actual control, not view construction or a launch callback.
/// The clock exists only in this QA opening. The release scene has neither markers nor clocks.
@MainActor struct OpeningMarker: UIViewRepresentable {
    let point: OpeningStamps.Point
    func makeUIView(context: Context) -> Marker { Marker(point) }
    func updateUIView(_ view: Marker, context: Context) {}
    static func dismantleUIView(_ view: Marker, coordinator: ()) { view.stop() }

    final class Marker: UIView {
        let point: OpeningStamps.Point
        private var link: CADisplayLink?
        init(_ point: OpeningStamps.Point) {
            self.point = point; super.init(frame: .zero); isUserInteractionEnabled = false; accessibilityElementsHidden = true
        }
        required init?(coder: NSCoder) { return nil }
        override func didMoveToWindow() {
            super.didMoveToWindow(); stop()
            guard window != nil else { return }
            let next = CADisplayLink(target: self, selector: #selector(sample))
            next.preferredFramesPerSecond = 15; next.add(to: .main, forMode: .common); link = next
        }
        func stop() { link?.invalidate(); link = nil; OpeningProbe.shared.frame(point, visible: false) }
        @objc private func sample() {
            guard let w = window else { stop(); return }
            var r = convert(bounds, to: w).intersection(w.bounds)
            var node: UIView? = self
            while let v = node, !r.isEmpty {
                if v.isHidden || v.alpha <= 0.01 { r = .null; break }
                if v.clipsToBounds { r = r.intersection(v.convert(v.bounds, to: w)) }; node = v.superview
            }
            // For actionable markers require a usable center, not merely a sliver peeking out of a scroll view.
            let center = convert(CGPoint(x: bounds.midX, y: bounds.midY), to: w)
            let visible = !r.isEmpty && r.contains(center) && w.isKeyWindow && !w.isHidden &&
                w.rootViewController?.presentedViewController == nil && w.windowScene?.activationState == .foregroundActive
            OpeningProbe.shared.frame(point, visible: visible)
            if visible && point == .receipt { stop() }
        }
    }
}

extension View {
    @MainActor @ViewBuilder func openingMarker(_ point: OpeningStamps.Point, choice: String? = nil) -> some View {
        if let selected = OpeningProbe.choice, choice == nil || choice == selected {
            background { OpeningMarker(point: point).allowsHitTesting(false).accessibilityHidden(true) }
        } else { self }
    }
}
#endif
