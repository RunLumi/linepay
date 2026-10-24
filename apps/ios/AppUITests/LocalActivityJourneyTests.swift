import XCTest

@MainActor
final class LocalActivityJourneyTests: XCTestCase {
    private var app = XCUIApplication()

    func testManualPreviewOptOutRelaunchAndClearKeepPayRecords() throws {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light
        launch(reset: true)
        XCTAssertTrue(app.staticTexts["$2,000.00"].firstMatch.waitForExistence(timeout: 15))
        openActivity()
        capture("v2-local-activity")
        let recording = app.switches["activity.recording"].firstMatch
        reveal(recording)
        XCTAssertEqual(recording.value as? String, "1")
        let nativeSwitch = recording.switches.firstMatch
        (nativeSwitch.exists ? nativeSwitch : recording).tap()
        XCTAssertEqual(recording.value as? String, "0")
        tap("activity.preview")
        XCTAssertTrue(app.navigationBars["Review local diagnostics"].waitForExistence(timeout: 10))
        let preview = app.staticTexts["activity.preview-json"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertTrue(preview.label.contains("\"recordingEnabled\" : false"))
        XCTAssertFalse(preview.label.contains("deduplicationDigests"))
        capture("v2-local-diagnostics-preview")
        tap("activity.export")
        let picker = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 15), "Files export destination must open")
        XCTAssertTrue(app.textFields.firstMatch.exists)
        capture("v2-local-diagnostics-files-destination")
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists {
            cancel.tap()
        } else {
            let browse = picker.buttons["Browse"].firstMatch
            XCTAssertTrue(browse.exists)
            browse.tap()
            if cancel.waitForExistence(timeout: 3) {
                cancel.tap()
            } else {
                picker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
                    .press(
                        forDuration: 0.1,
                        thenDragTo: app.coordinate(
                            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
            }
        }
        XCTAssertTrue(picker.waitForNonExistence(timeout: 10))
        app.buttons["Close"].firstMatch.tap()
        app.terminate()
        launch(reset: false, largeText: true)
        XCTAssertTrue(app.staticTexts["$2,000.00"].firstMatch.waitForExistence(timeout: 15))
        openActivity()
        reveal(app.switches["activity.recording"].firstMatch)
        XCTAssertEqual(app.switches["activity.recording"].firstMatch.value as? String, "0")
        capture("v2-local-activity-large-dark")
        tap("activity.clear")
        tap("activity.confirm-clear")
        tap("activity.preview")
        let clearedPreview = app.staticTexts["activity.preview-json"].firstMatch
        XCTAssertTrue(clearedPreview.waitForExistence(timeout: 10))
        capture("v2-local-activity-cleared")
        let data = try XCTUnwrap(clearedPreview.label.data(using: .utf8))
        let cleared = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(cleared["recordingEnabled"] as? Bool, false)
        let totals = try XCTUnwrap(cleared["totals"] as? [[String: Any]])
        XCTAssertTrue(totals.allSatisfy { ($0["count"] as? Int) == 0 }, "\(totals)")
        XCTAssertEqual((cleared["days"] as? [Any])?.count, 0)
        app.buttons["Close"].firstMatch.tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["$2,000.00"].firstMatch.waitForExistence(timeout: 10))
    }

    private func launch(reset: Bool, largeText: Bool = false) {
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = largeText ? .dark : .light
        app.launchArguments =
            [
                "--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-UIPreferredContentSizeCategoryName",
                largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL",
            ] + (reset ? ["--reset-ui-state"] : [])
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = "benefits"
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    }

    private func openActivity() {
        app.tabBars.buttons["Settings"].tap()
        tap("settings.local-activity")
    }

    private func tap(_ id: String) {
        let button = app.buttons[id].firstMatch
        if id != "activity.export" { reveal(button) }
        XCTAssertTrue(button.isHittable, "Missing visible action: \(id)")
        button.tap()
    }

    private func reveal(_ element: XCUIElement) {
        let window = app.windows.firstMatch
        for _ in 0..<20 {
            if element.exists, element.isHittable, element.frame.minY > 110,
                element.frame.maxY < window.frame.maxY - 90
            {
                return
            }
            if element.exists, element.frame.minY < 110 {
                window.swipeDown()
            } else {
                window.swipeUp()
            }
        }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
