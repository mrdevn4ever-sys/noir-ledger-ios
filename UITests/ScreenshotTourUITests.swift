import XCTest

/// Captures every principal state in English and German from the running app on the simulator.
/// Attachment names: `<lang>_tour_<NN>_<state>`; CI exports them from the .xcresult as PNG files.
final class ScreenshotTourUITests: NoirUITestCase {

    func testTourEnglish() { tour("en") }
    func testTourGerman() { tour("de") }

    private func tour(_ lang: String) {
        let p = "\(lang)_tour_"

        // Prologue (fresh install).
        launch(["-qa-reset", "-qa-seed", "5"], language: lang)
        wait("screen.prologue")
        shot(p + "01_prologue")
        element("prologue.next").tap()
        element("prologue.next").tap()
        element("prologue.choice.TOOLS").tap()
        usleep(600_000)
        shot(p + "02_prologue_choice")
        element("prologue.next").tap()
        element("prologue.open").tap()
        wait("coach.title")
        shot(p + "03_briefing")
        app.terminate()

        // Main play in chapter 3: ledger, operations, city, district, money, crew, improvements, legacy, settings.
        launch(["-qa-reset", "-qa-seed", "9", "-qa-scenario", "chapter3", "-qa-quiet"], language: lang)
        wait("screen.ledger")
        shot(p + "04_ledger")
        reveal(element("ledger.journal"))
        shot(p + "05_ledger_books")
        tab(1)
        wait("screen.ops")
        shot(p + "06_operations")
        reveal(element("line.VELVET.buy"))
        shot(p + "07_operations_lines")
        tab(2)
        wait("screen.city")
        shot(p + "08_city")
        reveal(element("district.FOUNDRY"))
        shot(p + "09_city_districts")
        reveal(element("district.CROWN_HILL"))
        shot(p + "10_city_districts_end")
        scrollToTop()
        tapRevealed("district.DOCKS")
        wait("screen.district.DOCKS")
        shot(p + "11_district")
        reveal(element("route.DOCKS.CINDER"))
        shot(p + "12_routes")
        tab(3)
        wait("screen.money")
        shot(p + "13_money_heat")
        reveal(element("front.TAXI"))
        shot(p + "14_fronts")
        tab(4)
        wait("screen.network")
        shot(p + "15_crew")
        reveal(element("crew.ENFORCER"))
        shot(p + "16_crew_candidates")
        element("network.section").buttons.element(boundBy: 1).tap()
        shot(p + "17_improvements")
        element("network.section").buttons.element(boundBy: 2).tap()
        shot(p + "18_legacy_summary")
        element("toolbar.settings").tap()
        wait("settings.done")
        shot(p + "19_settings")
        app.terminate()

        // A decision.
        launch(["-qa-reset", "-qa-seed", "13", "-qa-scenario", "event"], language: lang)
        wait("hud.event").tap()
        wait("event.title")
        shot(p + "20_event")
        app.terminate()

        // Investigation and raid.
        launch(["-qa-reset", "-qa-seed", "17", "-qa-scenario", "investigation", "-qa-quiet"], language: lang)
        wait("hud.investigation").tap()
        wait("money.investigation")
        shot(p + "21_investigation")
        app.terminate()
        launch(["-qa-reset", "-qa-seed", "19", "-qa-scenario", "raid", "-qa-quiet"], language: lang)
        wait("raid.recover")
        shot(p + "22_raid")
        element("raid.ack").tap()
        app.terminate()

        // Offline return.
        launch(["-qa-reset", "-qa-seed", "23", "-qa-scenario", "chapter2", "-qa-quiet"], language: lang)
        wait("screen.ledger")
        sleep(1)
        app.terminate()
        launch(["-qa-away", "18000"], language: lang)
        wait("offline.title")
        shot(p + "23_offline_return")
        app.terminate()

        // Final operation.
        launch(["-qa-reset", "-qa-seed", "29", "-qa-scenario", "final_ready", "-qa-quiet"], language: lang)
        tapRevealed("ledger.finalOp")
        wait("screen.finalOp")
        shot(p + "24_final_requirements")
        tapRevealed("final.start")
        wait("final.phaseNumber")
        shot(p + "25_final_phase")
        app.terminate()

        // Epilogue and New Game+.
        launch(["-qa-reset", "-qa-seed", "31", "-qa-scenario", "won"], language: lang)
        wait("epilogue.title")
        shot(p + "26_epilogue")
        reveal(element("epilogue.newGamePlus"))
        shot(p + "27_epilogue_books_credits")
        app.terminate()
        launch(["-qa-reset", "-qa-seed", "37", "-qa-scenario", "ngplus", "-qa-quiet"], language: lang)
        wait("ledger.ngLevel")
        shot(p + "28_new_game_plus")
        app.terminate()

        // Large text.
        launch(["-qa-reset", "-qa-seed", "41", "-qa-scenario", "chapter2", "-qa-quiet"], language: lang, largeText: true)
        wait("screen.ledger")
        shot(p + "29_large_text")
        tab(1)
        wait("screen.ops")
        shot(p + "30_large_text_ops")
        app.terminate()
    }
}
