import XCTest

/// Drive real taps and read the app's frozen report. XCTest queries have no clock authority.
final class OpeningTimingUITests: NoirUITestCase {

    func testOpeningTimingCashbox() { measureOpening("CASHBOX") }
    func testOpeningTimingAddressBook() { measureOpening("ADDRESS_BOOK") }
    func testOpeningTimingTools() { measureOpening("TOOLS") }

    private func tapVanButton(_ id: String, timeout: TimeInterval, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons.matching(NSPredicate(format: "identifier == %@", id)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Missing van button: \(id)", file: file, line: line)
        button.tap()
    }

    private func measureOpening(_ start: String) {
        launch(["-qa-reset", "-qa-seed", "3", "-qa-opening", start])
        let collect = wait("estate.collect", 45)
        XCTAssertTrue(collect.isHittable, "the first screen is interactive")
        collect.tap()
        wait("estate.receipt", 10)
        let heirloom = wait("start.\(start)")
        if !heirloom.isHittable { reveal(heirloom) }
        heirloom.tap()
        tapVanButton("van.offer", timeout: 15)
        tapVanButton("van.confirm", timeout: 10)
        waitForVanCapacity(2)
        let json = wait("opening.result").label
        guard let m = try? JSONDecoder().decode([String: Double].self, from: Data(json.utf8)),
              let reward = m["receiptRaw"], let offer = m["offerRaw"], let upgrade = m["upgrade"],
              let raw = m["upgradeRaw"], let robot = m["robot"] else { return XCTFail("No complete app timestamps: \(json)") }
        let line = "OPENING start=\(start) reward_s=\(reward) offer_s=\(offer) confirmed_upgrade_s=\(upgrade) raw_upgrade_s=\(raw) robot_wait_s=\(robot)"
        print(line)
        let attachment = XCTAttachment(string: line + "\n" + json)
        attachment.name = "opening " + start
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertLessThanOrEqual(reward, 5, "first player-triggered booking within 5 s of the first interactive screen")
        XCTAssertLessThanOrEqual(offer, 20, "first visible affordable offer, raw app time")
        XCTAssertEqual(raw - robot, upgrade, accuracy: 0.000001)
        XCTAssertGreaterThanOrEqual(upgrade, 0)
        XCTAssertLessThanOrEqual(upgrade, 20, "confirmed capacity change excluding only responsive, ready-for-input intervals")
        // After the upgrade the cellar teaches production.
        wait("hint")
        wait("bench.WEED")
    }
}
