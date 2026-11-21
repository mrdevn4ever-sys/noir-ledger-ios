import Foundation
import XCTest

// External Debug-only test. The acceptance test stays byte-for-byte unchanged.
final class M1IdleTests: NoirUITestCase {
    func testLate() throws { try hold("late") }
    func testHarbour() throws { try hold("harbour") }

    private func visibleLedger() {
        XCTAssertEqual(app.state, .runningForeground)
        wait("screen.ledger")
        XCTAssertFalse(element("welcome.ok").exists)
        XCTAssertFalse(element("chapter.news.ok").exists)
        XCTAssertTrue(element("perf.probe").exists)
        XCTAssertTrue(element("nav.book").isHittable)
    }

    private func hold(_ scene: String) throws {
        let nonce = UUID().uuidString
        let dir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        launch(["-qa-reset", "-qa-scenario", scene, "-qa-quiet", "-qa-perf", "-m1-token", nonce], language: "de")
        wait("screen.ledger", 30)
        dismissSheets()
        visibleLedger()
        let stamp: [String: String] = ["nonce": nonce, "scene": scene, "sha": "__M1_SHA__"]
        let bytes = try JSONSerialization.data(withJSONObject: stamp)
        try bytes.write(to: dir.appendingPathComponent("m1-ready.json"), options: .atomic)
        // No UI queries, touches or scrolling until the host recorder has exited.
        let ack = dir.appendingPathComponent("m1-stop-" + nonce)
        let deadline = ProcessInfo.processInfo.systemUptime + 120
        while !FileManager.default.fileExists(atPath: ack.path) {
            guard ProcessInfo.processInfo.systemUptime < deadline else { return XCTFail("host did not finish recording") }
            Thread.sleep(forTimeInterval: 0.5)
        }
        visibleLedger()
        try bytes.write(to: dir.appendingPathComponent("m1-done.json"), options: .atomic)
        app.terminate()
    }
}
