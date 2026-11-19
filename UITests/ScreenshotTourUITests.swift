import XCTest

/// The screenshot tour in both languages: every main state of the game, exported by CI for visual review.
final class ScreenshotTourUITests: NoirUITestCase {

    func testTourEnglish() { tour("en") }
    func testTourGerman() { tour("de") }

    private func tour(_ lang: String) {
        let p = "\(lang)_tour_"

        launch(["-qa-reset", "-qa-seed", "5"], language: lang)
        wait("screen.prologue", 45)
        shot(p + "01_prologue")
        tapRevealed("start.TOOLS")
        wait("screen.ledger")
        shot(p + "02_cellar")
        app.terminate()

        launch(["-qa-reset", "-qa-scenario", "neck", "-qa-quiet"], language: lang)
        wait("neck.WEED", 30)
        shot(p + "03_bottleneck")
        tapRevealed("neck.WEED.fix")
        wait("screen.station")
        shot(p + "04_upgrade_preview")
        app.terminate()

        launch(["-qa-reset", "-qa-scenario", "board"], language: lang)
        wait("screen.ledger", 30)
        tapRevealed("nav.orders")
        wait("offer.1.attention")
        shot(p + "05_orders")
        app.terminate()

        launch(["-qa-reset", "-qa-scenario", "chain", "-qa-quiet"], language: lang)
        wait("screen.ledger", 30)
        sleep(2)
        shot(p + "06_chain")
        element("chapter.strip").tap()
        wait("screen.chapter")
        shot(p + "07_chapter")
        app.terminate()

        launch(["-qa-reset", "-qa-scenario", "harbour", "-qa-quiet"], language: lang)
        wait("screen.ledger", 30)
        sleep(2)
        shot(p + "08_harbour")
        reveal(element("fleet.open"))
        shot(p + "09_harbour_fleet")
        tapRevealed("nav.city")
        wait("screen.city")
        shot(p + "10_city")
        element("sheet.done").tap()
        tapRevealed("nav.crew")
        wait("screen.crew")
        shot(p + "11_crew")
        element("sheet.done").tap()
        tapRevealed("nav.book")
        wait("screen.book")
        shot(p + "12_book")
        app.terminate()

        launch(["-qa-reset", "-qa-scenario", "night", "-qa-quiet"], language: lang)
        wait("screen.ledger", 30)
        sleep(2)
        shot(p + "13_night")
        app.terminate()

        launch(["-qa-reset", "-qa-scenario", "late", "-qa-quiet"], language: lang)
        wait("screen.ledger", 30)
        sleep(2)
        shot(p + "14_late")
        app.terminate()

        launch(["-qa-reset", "-qa-scenario", "hot", "-qa-quiet"], language: lang)
        wait("screen.ledger", 30)
        sleep(1)
        shot(p + "15_hot_quarter")
        element("nav.contacts").tap()
        wait("screen.contacts")
        shot(p + "15b_customers")
        app.terminate()

        launch(["-qa-reset", "-qa-scenario", "finale", "-qa-quiet"], language: lang)
        wait("chapter.strip", 30)
        element("chapter.strip").tap()
        wait("screen.challenges")
        shot(p + "16_challenges")
        app.terminate()

        launch(["-qa-reset", "-qa-seed", "23", "-qa-scenario", "chain", "-qa-quiet"], language: lang)
        wait("screen.ledger", 30)
        sleep(1)
        app.terminate()
        launch(["-qa-away", "18000", "-qa-quiet"], language: lang)
        wait("welcome.title", 30)
        shot(p + "17_return")
        app.terminate()

        launch(["-qa-reset", "-qa-seed", "41", "-qa-scenario", "chain", "-qa-quiet"], language: lang, largeText: true)
        wait("screen.ledger", 30)
        shot(p + "18_large_text")
        app.terminate()
    }
}
