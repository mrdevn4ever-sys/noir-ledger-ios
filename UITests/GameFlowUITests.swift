import XCTest

/// Functional flows on a real simulator, driven through the player UI (taps), with the Debug-only accelerator only
/// shortening wall-clock waits or preparing a chapter.
final class GameFlowUITests: NoirUITestCase {

    func testFreshInstallPrologueAndSevenStepBriefing() {
        launch(["-qa-reset", "-qa-seed", "7", "-qa-timescale", "30"])
        wait("screen.prologue")
        shot("en_01_prologue_funeral")
        element("prologue.next").tap()
        shot("en_02_prologue_ledger")
        element("prologue.next").tap()
        XCTAssertFalse(element("prologue.next").isEnabled, "the choice is required")
        element("prologue.choice.CASH_BOX").tap()
        shot("en_03_prologue_choice")
        element("prologue.next").tap()
        shot("en_04_prologue_cellar")
        element("prologue.open").tap()

        // 1 Start the line (Operations).
        wait("coach.title")
        shot("en_05_briefing_coach")
        element("coach.go").tap()
        wait("screen.ops")
        tapRevealed("line.GLIMMER.toggle")
        // 2 Build stock happens on its own; 3 open the route in the Cellar Quarter.
        wait("coach.go", 30).tap()
        wait("screen.district.CELLARS")
        tapRevealed("route.CELLARS.GLIMMER")
        shot("en_06_briefing_route")
        // 4 Earn; 5 buy the laundromat (Money).
        wait("coach.go", 40).tap()
        wait("screen.money")
        tapRevealed("front.LAUNDROMAT.buy")
        shot("en_07_briefing_front")
        // 6 Wash; 7 Heat briefing on the Ledger.
        wait("coach.go", 40).tap()
        wait("screen.ledger")
        shot("en_08_briefing_heat")
        wait("coach.ack").tap()
        XCTAssertFalse(element("coach.title").waitForExistence(timeout: 2), "the briefing is finished")
        wait("ledger.chapterTitle")
        shot("en_09_chapter1")
    }

    func testCoreSystemsThroughTheUI() {
        launch(["-qa-reset", "-qa-seed", "11", "-qa-scenario", "chapter3", "-qa-quiet"])
        wait("screen.ledger")
        // Operations: upgrade a line track and expand the stash.
        tab(1)
        wait("screen.ops")
        tapRevealed("line.GLIMMER.SPEED")
        tapRevealed("ops.stash.upgrade")
        tapRevealed("line.VELVET.buy")
        wait("line.VELVET.toggle")
        // City: open a district, expand a route and push the rivals.
        tab(2)
        wait("screen.city")
        tapRevealed("district.DOCKS")
        wait("screen.district.DOCKS")
        tapRevealed("route.DOCKS.CINDER")
        tapRevealed("turf.DOCKS")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        // Money: pause and resume a front, change the reserve, protection and a donation.
        tab(3)
        wait("screen.money")
        let toggle = element("front.TAXI.active")
        reveal(toggle)
        if toggle.switches.firstMatch.exists {
            toggle.switches.firstMatch.tap()
        } else {
            toggle.tap()
        }
        reveal(element("money.reserve"))
        element("money.reserve").buttons.element(boundBy: 2).tap()
        tapRevealed("money.protection")
        tapRevealed("money.donate")
        // Network: hire, an improvement and the legacy section.
        tab(4)
        wait("screen.network")
        tapRevealed("crew.hire.feld")
        wait("crew.ENFORCER.name")
        element("network.section").buttons.element(boundBy: 1).tap()
        tapRevealed("upgrade.LOOKOUTS")
        tapRevealed("upgrade.POLICE_SCANNER")
        reveal(element("upgrade.row.FALLBACK_STASH"))
        element("network.section").buttons.element(boundBy: 2).tap()
        wait("network.legacy.open")
        XCTAssertFalse(element("notice").exists && element("notice").label.contains("Not enough"), "every tapped action was affordable")
    }

    func testPersistenceAcrossRelaunchAndOfflineReturn() {
        launch(["-qa-reset", "-qa-seed", "21", "-qa-scenario", "chapter2", "-qa-quiet"])
        tab(1)
        wait("screen.ops")
        tapRevealed("ops.stash.upgrade")
        let before = element("ops.stashFill").label.components(separatedBy: " of ").last ?? ""
        XCTAssertFalse(before.isEmpty)
        sleep(2)
        app.terminate()

        launch(["-qa-away", "7200"])
                wait("offline.title")
        shot("en_20_offline_return")
        element("offline.ok").tap()
        tab(1)
        wait("screen.ops")
        let after = element("ops.stashFill").label.components(separatedBy: " of ").last ?? ""
        XCTAssertEqual(before, after, "the expanded stash survived termination and relaunch")
    }

    func testInvestigationRaidAndRecovery() {
        launch(["-qa-reset", "-qa-seed", "31", "-qa-scenario", "investigation", "-qa-quiet", "-qa-timescale", "8"])
        wait("hud.investigation").tap()
        wait("screen.money")
        wait("money.investigation")
        shot("en_21_investigation")
        tapRevealed("money.bribe")
        wait("raid.title", 40)
        wait("raid.recover")
        shot("en_22_raid")
        element("raid.ack").tap()
        XCTAssertFalse(element("raid.title").waitForExistence(timeout: 3))
        XCTAssertFalse(element("hud.investigation").exists, "the raid closed the case")
        tab(2)
        wait("screen.city")
        tapRevealed("district.CELLARS")
        wait("screen.district.CELLARS")
        shot("en_23_raid_recovery_district")
    }

    func testFinalOperationEpilogueAndNewGamePlus() {
        launch(["-qa-reset", "-qa-seed", "41", "-qa-scenario", "final_ready", "-qa-quiet", "-qa-timescale", "20"])
        tapRevealed("ledger.finalOp")
        wait("screen.finalOp")
        shot("en_30_final_requirements")
        tapRevealed("final.start")
        tapRevealed("final.choice.votes")
        tapRevealed("final.choice.payoff")
        shot("en_31_final_phase3")
        var attempts = 0
        while !element("screen.epilogue").exists && attempts < 10 {
            attempts += 1
            let choice = element("final.choice.lawyer")
            if choice.exists {
                reveal(choice)
                if choice.isEnabled { choice.tap() } else { sleep(2) }
            }
            _ = element("screen.epilogue").waitForExistence(timeout: 3)
        }
        wait("epilogue.title", 10)
        shot("en_32_epilogue")
        reveal(element("epilogue.legacy"))
        shot("en_33_epilogue_books")
        tapRevealed("epilogue.newGamePlus")
        wait("screen.legacy")
        tapRevealed("perk.STARTING_CAPITAL")
        shot("en_34_legacy")
        tapRevealed("legacy.startNewGamePlus")
        let confirm = app.alerts.buttons["Begin New Game+"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        wait("ledger.ngLevel")
        wait("ledger.chapterTitle")
        shot("en_35_new_game_plus")
    }

    func testLanguageSwitchInSettings() {
        launch(["-qa-reset", "-qa-scenario", "chapter2", "-qa-quiet"])
        wait("screen.ledger")
        XCTAssertTrue(app.tabBars.buttons["Ledger"].exists)
        element("toolbar.settings").tap()
        wait("settings.done")
        app.buttons["Deutsch"].tap()
        XCTAssertTrue(app.navigationBars["Einstellungen"].waitForExistence(timeout: 5))
        shot("de_40_settings")
        element("settings.done").tap()
        XCTAssertTrue(app.tabBars.buttons["Buch"].waitForExistence(timeout: 5))
        element("toolbar.settings").tap()
        app.buttons["English"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        shot("en_40_settings")
        element("settings.done").tap()
        XCTAssertTrue(app.tabBars.buttons["Ledger"].waitForExistence(timeout: 5))
    }

    func testSystemGermanIsDetected() {
        launch(["-qa-reset", "-qa-scenario", "chapter2", "-qa-quiet"], language: "de")
        XCTAssertTrue(app.tabBars.buttons["Buch"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Stadt"].exists)
    }

    func testLargeDynamicType() {
        launch(["-qa-reset", "-qa-scenario", "chapter3", "-qa-quiet"], largeText: true)
        wait("screen.ledger")
        shot("en_50_large_text_ledger")
        tab(1)
        wait("screen.ops")
        tapRevealed("line.GLIMMER.toggle")
        shot("en_51_large_text_ops")
        tab(3)
        wait("screen.money")
        reveal(element("money.bribe"))
        shot("en_52_large_text_money")
    }

    func testResetNeedsConfirmation() {
        launch(["-qa-reset", "-qa-scenario", "chapter2", "-qa-quiet"])
        element("toolbar.settings").tap()
        wait("settings.done")
        tapRevealed("settings.reset")
        let erase = app.alerts.buttons["Erase"].firstMatch
        XCTAssertTrue(erase.waitForExistence(timeout: 5))
        shot("en_41_reset_confirm")
        app.alerts.buttons["Cancel"].firstMatch.tap()
        tapRevealed("settings.reset")
        app.alerts.buttons["Erase"].firstMatch.tap()
        wait("screen.prologue")
    }

    func testDamagedSaveIsRecoveredFromBackup() {
        launch(["-qa-reset", "-qa-scenario", "chapter2", "-qa-quiet"])
        wait("screen.ledger")
        tab(1)
        tapRevealed("ops.stash.upgrade")
        sleep(1)
        app.terminate()
        launch(["-qa-corrupt-save"])
        XCTAssertTrue(app.alerts["Save recovered"].waitForExistence(timeout: 10))
        shot("en_42_save_recovered")
        app.alerts.buttons.firstMatch.tap()
        wait("ledger.chapterTitle")
    }

    func testSaveFromNewerVersionIsProtected() {
        launch(["-qa-reset", "-qa-future-save"])
        wait("future.restart")
        shot("en_43_future_save")
    }

    func testHomeScreenIcon() {
        launch(["-qa-reset", "-qa-scenario", "chapter2", "-qa-quiet"])
        wait("screen.ledger")
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
