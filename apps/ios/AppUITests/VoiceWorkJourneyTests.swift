import XCTest

@MainActor
final class VoiceWorkJourneyTests: XCTestCase {
    private var app = XCUIApplication()

    func testEditableReadingRequiresReviewThenSeparateWorkSave() throws {
        continueAfterFailure = false
        launch()
        let add = app.buttons["activation.add-work"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        add.tap()
        app.buttons["work.voice"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Work notes draft"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["voice.apply"].isEnabled)
        XCTAssertFalse(app.buttons["voice.record"].exists)
        let input = app.descendants(matching: .any).matching(identifier: "voice.reading").firstMatch
        reveal(input)
        input.tap()
        input.typeText("Regular from 7 AM to 3:30 PM. Unpaid break from noon to 12:30 PM.")
        dismissKeyboard()
        tap("voice.review")
        XCTAssertFalse(app.buttons["voice.apply"].isEnabled)
        let confirm = app.buttons["voice.confirm"].firstMatch
        reveal(confirm)
        capture("v2-voice-proposed-clock-facts")
        confirm.tap()
        XCTAssertEqual(confirm.value as? String, "Confirmed")
        XCTAssertTrue(app.buttons["voice.apply"].isEnabled)
        app.buttons["voice.apply"].tap()
        XCTAssertTrue(app.navigationBars["Add work"].waitForExistence(timeout: 10))
        capture("v2-voice-applied-to-unsaved-work-editor")
        app.buttons["work.save"].tap()
        XCTAssertTrue(app.staticTexts["$400.00"].firstMatch.waitForExistence(timeout: 15))
        app.terminate()
        launch(reset: false)
        XCTAssertTrue(app.staticTexts["$400.00"].firstMatch.waitForExistence(timeout: 15))
    }

    func testAmbiguousReadingAtLargestTextCannotBeApplied() throws {
        continueAfterFailure = false
        launch(largeText: true)
        tap("activation.add-work")
        tap("work.voice")
        let input = app.descendants(matching: .any).matching(identifier: "voice.reading").firstMatch
        reveal(input)
        input.tap()
        input.typeText("Regular from 7 to 3. No unpaid breaks.")
        dismissKeyboard()
        tap("voice.review")
        XCTAssertFalse(app.buttons["voice.apply"].isEnabled)
        XCTAssertFalse(app.buttons["voice.confirm"].exists)
        let error = app.descendants(matching: .any).matching(identifier: "voice.error").firstMatch
        reveal(error)
        XCTAssertTrue(error.exists)
        capture("v2-voice-ambiguous-large-dark")
        app.navigationBars["Work notes draft"].buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Add work"].waitForExistence(timeout: 10))
        app.buttons["work.cancel"].tap()
        XCTAssertTrue(app.buttons["activation.add-work"].waitForExistence(timeout: 10))
    }

    private func launch(reset: Bool = true, largeText: Bool = false) {
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = largeText ? .dark : .light
        app.launchArguments =
            [
                "--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-UIPreferredContentSizeCategoryName",
                largeText
                    ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL",
            ]
            + (reset ? ["--reset-ui-state"] : [])
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = "profile"
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    }

    private func tap(_ id: String) {
        let button = app.buttons[id].firstMatch
        reveal(button)
        XCTAssertTrue(button.isHittable, "Missing visible action: \(id)")
        button.tap()
    }

    private func reveal(_ element: XCUIElement) {
        let window = app.windows.firstMatch
        for _ in 0..<30 {
            if element.exists, element.isHittable, element.frame.minY > 115,
                element.frame.maxY < window.frame.maxY - 125
            {
                return
            }
            if element.exists, element.frame.minY < 115 {
                window.swipeDown()
            } else {
                window.swipeUp()
            }
        }
    }

    private func dismissKeyboard() {
        if let done = app.buttons.matching(identifier: "keyboard.done").allElementsBoundByIndex
            .first(where: { $0.isHittable })
        {
            done.tap()
        }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
