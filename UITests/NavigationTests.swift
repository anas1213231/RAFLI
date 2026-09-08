import XCTest

final class NavigationTests: XCTestCase {
    func testPrivateAccessAndNativeDestinations() {
        let app = XCUIApplication()
        app.launch()
        let code = app.secureTextFields["access-code"]
        XCTAssertTrue(code.waitForExistence(timeout: 10))
        capture("01-access")
        code.tap(); code.typeText("wrong")
        app.buttons["access-continue"].tap()
        XCTAssertTrue(app.staticTexts["access-error"].exists)
        code.tap()
        code.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "1v")
        app.buttons["access-continue"].tap()
        XCTAssertTrue(app.buttons["choose-photos"].waitForExistence(timeout: 10))
        capture("02-studio-arabic")
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        app.tabBars.buttons.element(boundBy: 1).tap()
        capture("03-library")
        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.staticTexts["@ucorc"].firstMatch.exists)
        capture("04-profile")
        app.tabBars.buttons.element(boundBy: 3).tap()
        capture("05-settings")
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
