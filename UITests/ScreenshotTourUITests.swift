import XCTest

/// The screenshot tour in both languages: every main state of the game, exported by CI for visual review.
final class ScreenshotTourUITests: NoirUITestCase {

    func testTourEnglish() { tour("en") }
    func testTourGerman() { tour("de") }

    private func tour(_ lang: String) {
        let p = "\(lang)_tour_"

        launch(["-qa-reset", "-qa-seed", "5", "-qa-quiet"], language: lang)
        wait("screen.tycoon")
        shot(p + "01_first_launch")
        app.terminate()

        launch(["-qa-reset", "-qa-seed", "9", "-qa-scenario", "rich", "-qa-quiet"], language: lang)
        wait("screen.tycoon")
        sleep(1)
        shot(p + "02_building")
        reveal(element("floor.CRYSTAL.buy"))
        shot(p + "03_floors")
        reveal(element("tycoon.city"))
        shot(p + "04_floors_end")
        element("tycoon.deals").tap()
        wait("screen.deals")
        shot(p + "05_deals")
        element("sheet.done").tap()
        element("tycoon.city").tap()
        wait("screen.city")
        shot(p + "06_change_city")
        element("sheet.done").tap()
        element("top.favors").tap()
        wait("screen.shop")
        shot(p + "07_shop")
        reveal(element("shop.restore"))
        shot(p + "08_shop_offers")
        element("shop.done").tap()
        element("top.rewards").tap()
        wait("screen.rewards")
        shot(p + "09_rewards")
        element("sheet.done").tap()
        element("top.settings").tap()
        wait("settings.done")
        shot(p + "10_settings")
        app.terminate()

        launch(["-qa-reset", "-qa-scenario", "police", "-qa-quiet"], language: lang)
        wait("street.bribe")
        shot(p + "11_police")
        app.terminate()

        launch(["-qa-reset", "-qa-scenario", "suitcase"], language: lang)
        wait("street.suitcase")
        shot(p + "12_suitcase")
        app.terminate()

        launch(["-qa-reset", "-qa-scenario", "call", "-qa-quiet"], language: lang)
        wait("call.option.0")
        shot(p + "16_call")
        app.terminate()

        launch(["-qa-reset", "-qa-seed", "5", "-qa-scenario", "starter", "-qa-quiet"], language: lang)
        wait("screen.tycoon")
        reveal(element("floor.WEED.manager.ghost"))
        shot(p + "17_manager_pick")
        app.terminate()

        launch(["-qa-reset", "-qa-scenario", "raid", "-qa-quiet"], language: lang)
        wait("raid.title")
        shot(p + "13_raid")
        app.terminate()

        launch(["-qa-reset", "-qa-seed", "23", "-qa-scenario", "rich", "-qa-quiet"], language: lang)
        wait("screen.tycoon")
        sleep(1)
        app.terminate()
        launch(["-qa-away", "18000", "-qa-quiet"], language: lang)
        wait("offline.title")
        shot(p + "14_offline_return")
        app.terminate()

        launch(["-qa-reset", "-qa-seed", "41", "-qa-scenario", "rich", "-qa-quiet"], language: lang, largeText: true)
        wait("screen.tycoon")
        shot(p + "15_large_text")
        app.terminate()
    }
}
