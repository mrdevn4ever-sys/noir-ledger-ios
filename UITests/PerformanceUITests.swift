import XCTest

/// Frame pacing of the living scene: idle and while scrolling, in the busiest scenarios. The numbers come from the
/// Debug-only frame meter (`-qa-perf`) and are written to the log as `PERF` lines and attached to the result. The
/// simulator is not a phone, so the test records instead of judging; the guard only catches a scene that stalls.
final class PerformanceUITests: NoirUITestCase {

    func testScenePacing() {
        for scenario in ["harbour", "late", "hot"] {
            launch(["-qa-reset", "-qa-scenario", scenario, "-qa-quiet", "-qa-perf"], language: "de")
            wait("screen.ledger", 30)
            dismissSheets()
            sleep(7)
            record(scenario + " idle")
            for _ in 0..<3 {
                app.swipeUp(velocity: .slow)
                app.swipeDown(velocity: .slow)
            }
            record(scenario + " scroll")
            app.terminate()
        }
    }

    private func record(_ label: String) {
        let probe = element("perf.probe")
        XCTAssertTrue(probe.waitForExistence(timeout: 5), "frame meter missing")
        let text = probe.label
        print("PERF \(label): \(text)")
        let attachment = XCTAttachment(string: text)
        attachment.name = "perf " + label
        attachment.lifetime = .keepAlways
        add(attachment)
        if let fps = value("fps", in: text) { XCTAssertGreaterThan(fps, 20, "\(label) stalls: \(text)") }
    }

    private func value(_ key: String, in text: String) -> Double? {
        guard let r = text.range(of: key + "=") else { return nil }
        let rest = text[r.upperBound...].prefix { $0.isNumber || $0 == "." }
        return Double(rest)
    }
}
