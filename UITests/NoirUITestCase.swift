import XCTest

/// Shared helpers: launching with the Debug-only QA accelerator, language and text size, stable scrolling under the
/// pinned header/briefing coach, and named screenshot attachments (exported from the .xcresult by CI).
class NoirUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func launch(_ qa: [String] = [], language: String = "en", largeText: Bool = false) {
        app = XCUIApplication()
        var args = qa
        args += ["-AppleLanguages", "(\(language))", "-AppleLocale", language == "de" ? "de_DE" : "en_US"]
        if largeText { args += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"] }
        app.launchArguments = args
        app.launch()
    }

    func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @discardableResult
    func wait(_ id: String, _ timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let e = element(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "\(id) did not appear", file: file, line: line)
        return e
    }

    func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func tab(_ index: Int) {
        let button = app.tabBars.buttons.element(boundBy: index)
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }

    /// The lowest y at which content is not covered by the coach, notices or the tab bar.
    private func visibleBottom() -> CGFloat {
        var bottom = app.frame.maxY
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists { bottom = min(bottom, tabBar.frame.minY) }
        let coach = element("coach.toggle")
        if coach.exists && coach.frame.height > 0 { bottom = min(bottom, coach.frame.minY - 8) }
        return bottom - 8
    }

    /// The highest y below the pinned header (accounts, Heat gauge and any alert strip under it).
    private func visibleTop() -> CGFloat {
        var top = app.frame.minY + 120
        for id in ["heat.gauge", "hud.investigation", "hud.event"] {
            let e = element(id)
            if e.exists && e.frame.height > 0 { top = max(top, e.frame.maxY + 8) }
        }
        return top
    }

    /// Scrolls the current screen until `e` is fully visible and tappable.
    func reveal(_ e: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(e.waitForExistence(timeout: 10), "missing \(e)", file: file, line: line)
        for _ in 0..<25 {
            let f = e.frame
            if e.isHittable && f.maxY <= visibleBottom() && f.minY >= visibleTop() { return }
            let start: CGVector
            let end: CGVector
            if f.minY < visibleTop() || (!e.isHittable && f.minY < visibleTop() + 60) {
                start = CGVector(dx: 0.5, dy: 0.45)
                end = CGVector(dx: 0.5, dy: 0.62)
            } else {
                start = CGVector(dx: 0.5, dy: 0.62)
                end = CGVector(dx: 0.5, dy: 0.42)
            }
            app.coordinate(withNormalizedOffset: start).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: end))
        }
        XCTAssertTrue(e.isHittable, "could not reveal \(e)", file: file, line: line)
    }

    func tapRevealed(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let e = element(id)
        reveal(e, file: file, line: line)
        e.tap()
    }

    func scrollToTop() {
        for _ in 0..<6 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        }
    }

    func dismissSheets() {
        for id in ["offline.ok", "raid.ack"] where element(id).exists {
            element(id).tap()
        }
    }
}
