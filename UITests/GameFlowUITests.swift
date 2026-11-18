import XCTest

/// Functional flows on a real simulator, driven through the player UI (taps), with the Debug-only accelerator only
/// preparing a situation or shortening waits.
final class GameFlowUITests: NoirUITestCase {

    func testFirstMinutesTapBuyOpenHire() {
        launch(["-qa-reset", "-qa-seed", "7", "-qa-quiet"])
        wait("screen.tycoon")
        wait("tycoon.hint")
        shot("en_01_first_launch")
        element("floor.WEED").tap()
        sleep(2)
        XCTAssertNotEqual(element("top.cash").label, "Cash 0", "a tap sells a round")
        app.terminate()

        launch(["-qa-scenario", "starter", "-qa-quiet"])
        wait("screen.tycoon")
        tapRevealed("floor.WEED.buy")
        XCTAssertTrue(element("floor.WEED.count").label.contains("2"), "one more plant")
        tapRevealed("floor.PILLS.open")
        wait("floor.PILLS.count")
        shot("en_02_pills_open")
        tapRevealed("floor.WEED.manager")
        XCTAssertFalse(element("floor.WEED.manager").waitForExistence(timeout: 2), "the manager is hired")
        shot("en_03_manager")
    }

    func testDealsAndChangeOfCity() {
        launch(["-qa-reset", "-qa-seed", "11", "-qa-scenario", "change", "-qa-quiet"])
        wait("screen.tycoon")
        tapRevealed("tycoon.deals")
        wait("screen.deals")
        element("deal.crystal_1").tap()
        shot("en_10_deals")
        element("sheet.done").tap()
        tapRevealed("tycoon.city")
        wait("screen.city")
        shot("en_11_city")
        element("city.change").tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Move on'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        wait("screen.tycoon")
        XCTAssertTrue(element("floor.PILLS.open").waitForExistence(timeout: 5), "a new city starts with weed only")
        shot("en_12_new_city")
    }

    func testPoliceBribeAndSuitcase() {
        launch(["-qa-reset", "-qa-scenario", "police", "-qa-quiet"])
        wait("street.bribe")
        shot("en_20_police")
        element("street.bribe").tap()
        XCTAssertFalse(element("street.bribe").waitForExistence(timeout: 2), "the police drive on")
        app.terminate()

        launch(["-qa-reset", "-qa-scenario", "suitcase"])
        wait("street.suitcase")
        shot("en_21_suitcase")
        element("street.suitcase").tap()
        XCTAssertFalse(element("street.suitcase").waitForExistence(timeout: 2), "the suitcase is taken")
    }

    func testRaidIsShownOnce() {
        launch(["-qa-reset", "-qa-scenario", "raid", "-qa-quiet"])
        wait("raid.title")
        shot("en_22_raid")
        element("raid.ack").tap()
        wait("screen.tycoon")
        XCTAssertFalse(element("raid.title").waitForExistence(timeout: 2))
    }

    func testPersistenceAcrossRelaunchAndOfflineReturn() {
        launch(["-qa-reset", "-qa-seed", "21", "-qa-scenario", "rich", "-qa-quiet"])
        wait("screen.tycoon")
        tapRevealed("floor.COKE.buy")
        let before = element("floor.COKE.count").label
        sleep(2)
        app.terminate()

        launch(["-qa-away", "7200", "-qa-quiet"])
        wait("offline.title")
        shot("en_30_offline_return")
        element("offline.ok").tap()
        wait("screen.tycoon")
        reveal(element("floor.COKE.count"))
        XCTAssertEqual(element("floor.COKE.count").label, before, "the purchase survived termination and relaunch")
    }

    func testShopRewardsAndSettings() {
        launch(["-qa-reset", "-qa-scenario", "rich", "-qa-quiet"])
        wait("screen.tycoon")
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
        wait("screen.tycoon")
    }

    func testSystemGermanIsDetected() {
        launch(["-qa-reset", "-qa-scenario", "rich", "-qa-quiet"], language: "de")
        wait("screen.tycoon")
        XCTAssertTrue(app.staticTexts["Gras"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Aufträge"].exists)
    }

    func testLargeDynamicType() {
        launch(["-qa-reset", "-qa-scenario", "rich", "-qa-quiet"], largeText: true)
        wait("screen.tycoon")
        shot("en_50_large_text")
        reveal(element("floor.COKE.buy"))
        shot("en_51_large_text_floors")
    }

    func testResetNeedsConfirmation() {
        launch(["-qa-reset", "-qa-scenario", "rich", "-qa-quiet"])
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
        wait("screen.tycoon")
        XCTAssertTrue(element("tycoon.hint").waitForExistence(timeout: 5), "a fresh city starts with the first hint")
    }

    func testDamagedSaveIsRecoveredFromBackup() {
        launch(["-qa-reset", "-qa-scenario", "rich", "-qa-quiet"])
        wait("screen.tycoon")
        tapRevealed("floor.WEED.buy")
        sleep(6)
        app.terminate()
        launch(["-qa-corrupt-save"])
        XCTAssertTrue(app.alerts["Save recovered"].waitForExistence(timeout: 10))
        shot("en_44_save_recovered")
        app.alerts.buttons.firstMatch.tap()
        wait("screen.tycoon")
    }

    func testSaveFromNewerVersionIsProtected() {
        launch(["-qa-reset", "-qa-future-save"])
        wait("future.restart")
        shot("en_45_future_save")
    }

    func testHomeScreenIcon() {
        launch(["-qa-reset", "-qa-scenario", "rich", "-qa-quiet"])
        wait("screen.tycoon")
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
