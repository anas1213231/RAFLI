import XCTest

final class NavigationTests: XCTestCase {
    func testPrivateAccessAndNativeDestinations() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let code = app.secureTextFields["access-code"]
        XCTAssertTrue(code.waitForExistence(timeout: 10))
        capture("01-access")
        code.tap(); code.typeText("wrong")
        app.buttons["access-continue"].tap()
        XCTAssertTrue(app.staticTexts["access-error"].exists)
        code.typeText("1v")
        app.buttons["access-continue"].tap()
        XCTAssertTrue(app.buttons["choose-photos"].waitForExistence(timeout: 10))
        capture("02-studio-arabic")
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        app.tabBars.buttons["فيديوهاتي"].tap()
        capture("03-library")
        app.tabBars.buttons["حسابي"].tap()
        XCTAssertTrue(app.staticTexts["@ucorc"].firstMatch.exists)
        capture("04-profile")
        app.tabBars.buttons["الإعدادات"].tap()
        capture("05-settings")
        app.buttons["language-setting"].tap()
        app.buttons["English"].tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["appearance-setting"].tap()
        app.buttons["Dark"].tap()
        app.tabBars.buttons["Studio"].tap()
        capture("06-studio-english-dark")
    }
    func testVideoPreparationResultAndLibrary() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-video-fixture"]
        app.launch()
        let code = app.secureTextFields["access-code"]
        XCTAssertTrue(code.waitForExistence(timeout: 10))
        code.tap(); code.typeText("1v"); app.buttons["access-continue"].tap()
        let prepare = app.buttons["prepare-video"]
        XCTAssertTrue(prepare.waitForExistence(timeout: 40))
        capture("07-selected-video")
        prepare.tap()
        XCTAssertTrue(app.staticTexts["result-ready"].waitForExistence(timeout: 90))
        capture("08-verified-result")
        let libraryTab = app.tabBars.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "My Videos", "فيديوهاتي")).firstMatch
        libraryTab.tap()
        capture("09-persisted-library")
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
