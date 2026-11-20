import XCTest

/// Complement the overview tour: reach the decisions that a top-of-building still cannot show.
final class ChapterTourUITests: NoirUITestCase {
    func testChapterDecisionsEnglish() { tour("en") }
    func testChapterDecisionsGerman() { tour("de") }

    private func tour(_ lang: String) {
        let p = "\(lang)_flow_"
        launch(["-qa-reset", "-qa-seed", "11", "-qa-scenario", "chain", "-qa-quiet"], language: lang)
        wait("chapter.strip", 45).tap()
        tapRevealed("chapter.close")
        wait("chapter.news.ok").tap()
        wait("chapter.strip").tap()
        wait("goal.c2_altmarkt")
        shot(p + "01_old_town")
        app.terminate()

        launch(["-qa-reset", "-qa-seed", "11", "-qa-scenario", "crown", "-qa-quiet"], language: lang)
        wait("chapter.strip", 45).tap()
        wait("goal.c5_trust")
        shot(p + "02_crown_goals")
        element("sheet.done").tap()
        let open = wait("workshop.COKE.open")
        reveal(open)
        XCTAssertTrue(open.isEnabled && open.isHittable)
        shot(p + "03_before_floor")
        open.tap()
        let bench = wait("bench.COKE.open")
        reveal(bench)
        XCTAssertTrue(bench.isHittable)
        shot(p + "04_after_floor")
        app.terminate()

        // Only the prerequisite economy is seeded. Accept, deliver, close and start the challenge through Flow.
        launch(["-qa-reset", "-qa-seed", "11", "-qa-scenario", "contract", "-qa-quiet", "-qa-timescale", "15"], language: lang)
        wait("nav.orders", 45).tap()
        wait("offer.0.pay")
        shot(p + "05_last_contract")
        tapRevealed("offer.0.accept")
        wait("order.active.0")
        shot(p + "06_contract_running")
        element("sheet.done").tap()
        wait("chapter.strip").tap()
        let close = wait("chapter.close")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: close)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 150), .completed, "the last contract must actually pay out")
        tapRevealed("chapter.close")
        wait("chapter.news")
        shot(p + "07_finale")
        element("chapter.news.ok").tap()
        wait("chapter.strip").tap()
        tapRevealed("challenge.STRIKE")
        XCTAssertFalse(element("challenge.FOG").isEnabled, "a second challenge cannot start while one is active")
        scrollToTop()
        shot(p + "08_active_challenge")
        app.terminate()
    }
}
