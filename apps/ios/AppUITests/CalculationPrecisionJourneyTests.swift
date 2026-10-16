import XCTest

@MainActor
final class CalculationPrecisionJourneyTests: XCTestCase {
    func testMinuteWorkReachesTheCorrectCentThroughExplicitWorkReview() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = .light
        app.launchArguments = [
            "--ui-testing", "--reset-ui-state", "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US", "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryL",
        ]
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = "precision-profile"
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.launch()
        XCTAssertTrue(app.buttons["activation.add-work"].waitForExistence(timeout: 15))
        app.buttons["activation.add-work"].tap()
        app.buttons["work.voice"].tap()
        let input = app.descendants(matching: .any).matching(identifier: "voice.reading").firstMatch
        func reveal(_ element: XCUIElement) {
            let window = app.windows.firstMatch
            for _ in 0..<20 {
                if element.exists, element.isHittable, element.frame.minY > 130,
                    element.frame.maxY < app.buttons["voice.apply"].frame.minY - 8
                {
                    return
                }
                let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                let delta: CGFloat = element.exists && element.frame.minY < 130 ? 160 : -160
                start.press(
                    forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)))
            }
        }
        reveal(input)
        input.tap()
        input.typeText("Regular from 7 AM to 7:01 AM. No unpaid breaks.")
        if let done = app.buttons.matching(identifier: "keyboard.done").allElementsBoundByIndex
            .first(where: { $0.isHittable })
        {
            done.tap()
        }
        let review = app.buttons["voice.review"].firstMatch
        reveal(review)
        review.tap()
        let confirm = app.buttons["voice.confirm"].firstMatch
        reveal(confirm)
        confirm.tap()
        XCTAssertEqual(confirm.value as? String, "Confirmed")
        app.buttons["voice.apply"].tap()
        XCTAssertTrue(app.navigationBars["Add work"].waitForExistence(timeout: 10))
        app.buttons["work.save"].tap()
        XCTAssertTrue(app.staticTexts["$0.98"].firstMatch.waitForExistence(timeout: 15))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "v2-one-minute-exact-half-cent"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
