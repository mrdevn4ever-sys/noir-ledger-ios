import XCTest

/// Functional flows on a real simulator, driven through the player UI (taps), with the Debug-only accelerator only
/// preparing a situation or shortening waits.
final class GameFlowUITests: NoirUITestCase {

    func testPrologueFirstDeliveryAndUpgrade() {
        launch(["-qa-reset", "-qa-seed", "7"])
        wait("screen.prologue", 45)
        shot("en_01_prologue")
        tapRevealed("start.CASHBOX")
        wait("screen.ledger")
        wait("hint")
        shot("en_02_cellar")
        element("bench.WEED").tap()
        sleep(6)
        tapRevealed("fleet.go")
        sleep(11)
        XCTAssertNotEqual(element("top.cash").label, "Cash: 60", "the first delivery is booked")
        tapRevealed("fleet.open")
        wait("screen.station")
        shot("en_03_upgrade_preview")
        element("station.buy").tap()
        element("sheet.done").tap()
        wait("screen.ledger")
    }

    func testBottleneckIsShownAndFixed() {
        launch(["-qa-reset", "-qa-scenario", "neck", "-qa-quiet"])
        wait("neck.WEED", 30)
        shot("en_04_bottleneck")
        tapRevealed("neck.WEED.fix")
        wait("screen.station")
        XCTAssertTrue(element("station.verdict").exists, "the preview says what the upgrade does")
        shot("en_05_fix_preview")
        element("station.buy").tap()
        element("sheet.done").tap()
        wait("screen.ledger")
    }

    func testOrderChoiceWithAttention() {
        launch(["-qa-reset", "-qa-scenario", "board"])
        wait("screen.ledger", 30)
        tapRevealed("nav.orders")
        wait("screen.orders")
        wait("offer.1.attention")
        shot("en_06_orders")
        tapRevealed("offer.1.accept")
        wait("order.active.0")
        shot("en_07_order_running")
        element("sheet.done").tap()
    }

    func testChapterCloses() {
        launch(["-qa-reset", "-qa-scenario", "chain", "-qa-quiet"])
        wait("chapter.strip", 30)
        element("chapter.strip").tap()
        wait("screen.chapter")
        shot("en_08_chapter_goals")
        tapRevealed("chapter.close")
        wait("chapter.news")
        shot("en_09_chapter_news")
        element("chapter.news.ok").tap()
        wait("screen.ledger")
    }

    func testCityCrewAndLedger() {
        launch(["-qa-reset", "-qa-scenario", "harbour", "-qa-quiet"])
        wait("screen.ledger", 30)
        tapRevealed("nav.city")
        wait("screen.city")
        shot("en_10_city")
        element("sheet.done").tap()
        tapRevealed("nav.crew")
        wait("screen.crew")
        shot("en_11_crew")
        element("sheet.done").tap()
        tapRevealed("nav.book")
        wait("screen.book")
        shot("en_12_book")
        element("sheet.done").tap()
    }

    func testPersistenceAndReturn() {
        launch(["-qa-reset", "-qa-seed", "21", "-qa-scenario", "chain", "-qa-quiet"])
        wait("screen.ledger", 30)
        sleep(2)
        app.terminate()
        launch(["-qa-away", "7200", "-qa-quiet"])
        wait("welcome.title", 30)
        shot("en_13_return")
        element("welcome.ok").tap()
        wait("screen.ledger")
        XCTAssertFalse(element("welcome.title").waitForExistence(timeout: 2), "the summary is shown once")
    }

    func testShopRewardsAndSettings() {
        launch(["-qa-reset", "-qa-scenario", "chain", "-qa-quiet"])
        wait("screen.ledger", 30)
        element("top.favors").tap()
        wait("screen.shop")
        shot("en_40_shop")
        element("shop.done").tap()
        element("top.rewards").tap()
        wait("screen.rewards")
        shot("en_41_rewards")
        element("sheet.done").tap()
        element("top.settings").tap()
        wait("settings.done")
        app.buttons["Deutsch"].tap()
        XCTAssertTrue(app.navigationBars["Einstellungen"].waitForExistence(timeout: 5))
        shot("de_42_settings")
        app.buttons["English"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        element("settings.done").tap()
        wait("screen.ledger")
    }

    func testSystemGermanIsDetected() {
        launch(["-qa-reset", "-qa-scenario", "chain", "-qa-quiet"], language: "de")
        wait("screen.ledger", 30)
        XCTAssertTrue(app.staticTexts["Abnehmer"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Mühlgasse"].exists)
    }

    func testLargeDynamicType() {
        launch(["-qa-reset", "-qa-scenario", "harbour", "-qa-quiet"], largeText: true)
        wait("screen.ledger", 30)
        shot("en_50_large_text")
        reveal(element("fleet.open"))
        shot("en_51_large_text_fleet")
    }

    func testResetNeedsConfirmation() {
        launch(["-qa-reset", "-qa-scenario", "chain", "-qa-quiet"])
        wait("screen.ledger", 30)
        element("top.settings").tap()
        wait("settings.done")
        app.swipeUp()
        tapRevealed("settings.reset")
        let erase = app.alerts.buttons["Erase"].firstMatch
        XCTAssertTrue(erase.waitForExistence(timeout: 5))
        shot("en_43_reset_confirm")
        app.alerts.buttons["Cancel"].firstMatch.tap()
        tapRevealed("settings.reset")
        app.alerts.buttons["Erase"].firstMatch.tap()
        wait("screen.prologue")
    }

    func testDamagedSaveIsRecoveredFromBackup() {
        launch(["-qa-reset", "-qa-scenario", "chain", "-qa-quiet"])
        wait("screen.ledger", 30)
        sleep(6)
        app.terminate()
        launch(["-qa-corrupt-save"])
        XCTAssertTrue(app.alerts["Save recovered"].waitForExistence(timeout: 15))
        shot("en_44_save_recovered")
        app.alerts.buttons.firstMatch.tap()
        wait("screen.ledger")
    }

    func testSaveFromNewerVersionIsProtected() {
        launch(["-qa-reset", "-qa-future-save"])
        wait("future.restart", 30)
        shot("en_45_future_save")
    }

    func testHomeScreenIcon() {
        launch(["-qa-reset", "-qa-scenario", "chain", "-qa-quiet"])
        wait("screen.ledger", 30)
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = springboard.icons["NOIR LEDGER"]
        XCTAssertTrue(icon.waitForExistence(timeout: 10), "the app icon is installed on the home screen")
        var pages = 0
        while !icon.isHittable && pages < 5 {
            springboard.swipeLeft()
            pages += 1
        }
        sleep(1)
        shot("en_60_home_screen_icon")
    }
}
