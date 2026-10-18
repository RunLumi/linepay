import XCTest

@MainActor
final class AccessibilityAuditJourneyTests: XCTestCase {
    private var app = XCUIApplication()

    func testPrimaryWorkerScreensPassAppleAccessibilityAudit() throws {
        try auditWorkerScreens()
    }

    func testLargestTextDarkWorkerScreensKeepKeyActionsReachable() throws {
        launch(largeText: true)
        XCTAssertTrue(app.buttons["today.add-work"].waitForExistence(timeout: 15))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        let settingsScreenshot = XCTAttachment(screenshot: app.screenshot())
        settingsScreenshot.name = "large-text-settings-dark"
        settingsScreenshot.lifetime = .keepAlways
        add(settingsScreenshot)
        let payPeriod = app.buttons["settings.payPeriod"]
        var payPeriodScrolls = 0
        while !payPeriod.isHittable && payPeriodScrolls < 6 {
            app.swipeUp()
            payPeriodScrolls += 1
        }
        XCTAssertTrue(payPeriod.isHittable)
        payPeriod.tap()
        XCTAssertTrue(app.navigationBars["Pay period"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()

        let localActivity = app.buttons["settings.local-activity"]
        var attempts = 0
        while !localActivity.isHittable && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(localActivity.isHittable)
        localActivity.tap()
        XCTAssertTrue(app.navigationBars["Device-local activity"].waitForExistence(timeout: 10))
        let recording = app.descendants(matching: .any)
            .matching(identifier: "activity.recording").firstMatch
        var recordingScrolls = 0
        while !recording.isHittable && recordingScrolls < 6 {
            app.swipeUp()
            recordingScrolls += 1
        }
        XCTAssertTrue(recording.waitForExistence(timeout: 10))
        XCTAssertTrue(recording.isHittable)
    }

    private func auditWorkerScreens() throws {
        launch(largeText: false)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        try audit("today")

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        try audit("settings")

        let localActivity = app.descendants(matching: .any)
            .matching(identifier: "settings.local-activity").firstMatch
        if !localActivity.isHittable { app.swipeUp() }
        XCTAssertTrue(localActivity.waitForExistence(timeout: 10))
        XCTAssertTrue(localActivity.isHittable)
        localActivity.tap()
        XCTAssertTrue(app.navigationBars["Device-local activity"].waitForExistence(timeout: 10))
        try audit("device-local-activity")
    }

    private func audit(_ screen: String) throws {
        try app.performAccessibilityAudit(for: .all) { [self] issue in
            let details = """
                Screen: \(screen)
                Text size: System default; Apple audit may vary Dynamic Type
                Type: \(issue.auditType.rawValue)
                Summary: \(issue.compactDescription)
                Details: \(issue.detailedDescription)
                Element: \(issue.element?.debugDescription ?? "unavailable")
                """
            print(details)
            let attachment = XCTAttachment(string: details)
            attachment.name = "accessibility-\(screen)-issue-\(issue.auditType.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
            return false
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "accessibility-\(screen)-standard-light"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func launch(largeText: Bool) {
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = largeText ? .dark : .light
        app.launchArguments = [
            "--ui-testing", "--reset-ui-state", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        if largeText {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            ]
        }
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = "matches"
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    }
}
