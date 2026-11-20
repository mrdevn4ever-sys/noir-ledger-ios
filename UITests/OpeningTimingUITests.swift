import XCTest

/// The first minute on the real UI, for every start, on the unaccelerated clock: from the first interactive screen
/// (the cellar door, not the launch) to the visible pickup booking and to the confirmed first van level. The
/// automation taps as soon as a control is there, so the numbers measure what the game makes the player wait for,
/// not how fast a person reads; they are printed as `OPENING` lines and attached to the result.
final class OpeningTimingUITests: NoirUITestCase {

    func testOpeningTimingCashbox() { measureOpening("CASHBOX") }
    func testOpeningTimingAddressBook() { measureOpening("ADDRESS_BOOK") }
    func testOpeningTimingTools() { measureOpening("TOOLS") }

    private func measureOpening(_ start: String) {
        launch(["-qa-reset", "-qa-seed", "3"])
        let collect = wait("estate.collect", 45)
        XCTAssertTrue(collect.isHittable, "the first screen is interactive")
        let t0 = Date()
        collect.tap()
        wait("estate.receipt", 10)
        let reward = Date().timeIntervalSince(t0)
        tapRevealed("start.\(start)")
        wait("van.offer", 15).tap()
        wait("van.confirm", 10).tap()
        waitValue("van.slots", "2", 10)
        let upgrade = Date().timeIntervalSince(t0)
        let line = String(format: "OPENING start=%@ reward_s=%.2f confirmed_upgrade_s=%.2f", start, reward, upgrade)
        print(line)
        let attachment = XCTAttachment(string: line)
        attachment.name = "opening " + start
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertLessThanOrEqual(reward, 5, "first player-triggered booking within 5 s of the first interactive screen")
        XCTAssertLessThanOrEqual(upgrade, 20, "first confirmed upgrade within 20 s of the first interactive screen")
        // After the upgrade the cellar teaches production.
        wait("hint")
        wait("bench.WEED")
    }
}
