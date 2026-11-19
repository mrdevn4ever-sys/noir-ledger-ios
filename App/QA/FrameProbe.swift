#if NOIR_QA
import QuartzCore
import SwiftUI

/// Debug/UI-test-only frame meter, switched on with `-qa-perf`. It watches every display refresh and reports the
/// last five seconds once per second: frames per second, the slowest frames, and the hitch time per second (time the
/// screen waited beyond the expected frame). The report sits in an invisible element `perf.probe` for the UI test.
@MainActor
@Observable
final class FrameProbe {
    static let shared = FrameProbe()
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("-qa-perf") }

    private(set) var summary = "perf: waiting"
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var samples: [(at: CFTimeInterval, interval: CFTimeInterval, expected: CFTimeInterval)] = []
    @ObservationIgnored private var last: CFTimeInterval = 0
    @ObservationIgnored private var lastReport: CFTimeInterval = 0
    @ObservationIgnored private var target = DisplayLinkTarget()

    func start() {
        guard link == nil else { return }
        target.probe = self
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    fileprivate func step(_ link: CADisplayLink) {
        let now = link.timestamp
        let expected = max(1.0 / 120, link.targetTimestamp - link.timestamp)
        if last > 0 { samples.append((now, now - last, expected)) }
        last = now
        samples.removeAll { now - $0.at > 5 }
        if now - lastReport >= 1, samples.count > 10 {
            lastReport = now
            let span = max(0.001, (samples.last?.at ?? now) - (samples.first?.at ?? now))
            let fps = Double(samples.count) / span
            let sorted = samples.map(\.interval).sorted()
            let p95 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
            let worst = sorted.last ?? 0
            let hitch = samples.reduce(0.0) { $0 + max(0, $1.interval - $1.expected * 1.5) } / span
            let dropped = samples.filter { $0.interval > $0.expected * 1.5 }.count
            summary = String(format: "perf fps=%.1f p95=%.1fms worst=%.1fms hitch=%.1fms/s dropped=%d frames=%d",
                             fps, p95 * 1000, worst * 1000, hitch * 1000, dropped, samples.count)
        }
    }
}

private final class DisplayLinkTarget: NSObject {
    weak var probe: FrameProbe?
    @MainActor @objc func step(_ link: CADisplayLink) { probe?.step(link) }
}

/// The invisible report element.
struct FrameProbeView: View {
    @State private var probe = FrameProbe.shared

    var body: some View {
        Text(verbatim: probe.summary)
            .font(.system(size: 6))
            .opacity(0.02)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: probe.summary))
            .accessibilityIdentifier("perf.probe")
            .onAppear { probe.start() }
    }
}
#endif
