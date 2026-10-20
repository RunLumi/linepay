import XCTest

@MainActor
final class AccessibilityAuditJourneyTests: XCTestCase {
    private var app = XCUIApplication()

    func testTodayPassesAppleAccessibilityAudit() throws {
        launch(largeText: false)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        assertTodayStatusAndWorkRow()
        try audit("today")
    }

    func testSettingsPassesAppleAccessibilityAudit() throws {
        launch(largeText: false, scenario: "work")
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        try audit("settings")
    }

    func testDeviceLocalActivityPassesAppleAccessibilityAudit() throws {
        launch(largeText: false, scenario: "work")
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        let localActivity = app.descendants(matching: .any)
            .matching(identifier: "settings.local-activity").firstMatch
        XCTAssertTrue(localActivity.waitForExistence(timeout: 10))
        XCTAssertTrue(localActivity.isHittable)
        localActivity.tap()
        XCTAssertTrue(app.navigationBars["Device-local activity"].waitForExistence(timeout: 10))
        try audit("device-local-activity")
    }

    func testTodayStatusWrapLeavesWorkRowReadableAndReachable() {
        launch(largeText: false)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        assertTodayStatusAndWorkRow()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "today-status-wrapped-work-row"
        screenshot.lifetime = .keepAlways
        add(screenshot)
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

        let backup = app.buttons["backup.open"]
        var backupScrolls = 0
        while !backup.isHittable && backupScrolls < 8 {
            app.swipeUp()
            backupScrolls += 1
        }
        XCTAssertTrue(backup.isHittable)
        XCTAssertTrue(backup.label.contains("Backup and restore"))
        XCTAssertGreaterThanOrEqual(backup.frame.height, 44)
        let backupScreenshot = XCTAttachment(screenshot: app.screenshot())
        backupScreenshot.name = "large-text-settings-backup-row"
        backupScreenshot.lifetime = .keepAlways
        add(backupScreenshot)

        let localActivity = app.buttons["settings.local-activity"]
        var attempts = 0
        while !localActivity.isHittable && attempts < 10 {
            app.swipeDown()
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
        let clear = app.buttons["activity.clear"]
        let activityList = app.collectionViews.firstMatch
        XCTAssertTrue(activityList.exists)
        var clearScrolls = 0
        while (!clear.exists || !clear.isHittable) && clearScrolls < 20 {
            activityList.swipeUp()
            clearScrolls += 1
        }
        XCTAssertTrue(clear.exists)
        XCTAssertTrue(clear.isHittable)
        let activityScreenshot = XCTAttachment(screenshot: app.screenshot())
        activityScreenshot.name = "large-text-device-local-activity-controls"
        activityScreenshot.lifetime = .keepAlways
        add(activityScreenshot)
    }

    private func assertTodayStatusAndWorkRow() {
        let status = app.descendants(matching: .any).matching(identifier: "audit.status").firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(status.label, "No difference within compared items: gross total only")
        XCTAssertGreaterThan(status.frame.height, 24, "The long status should wrap onto two lines")
        let workRow = app.buttons["today.edit-work"].firstMatch
        XCTAssertTrue(workRow.waitForExistence(timeout: 10))
        XCTAssertTrue(workRow.isHittable)
        XCTAssertTrue(workRow.label.contains("Regular work"))
        XCTAssertTrue(workRow.label.contains("Synthetic test shift"))
        XCTAssertGreaterThan(workRow.frame.minY, status.frame.maxY)
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

    private func launch(largeText: Bool, scenario: String = "matches") {
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
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = scenario
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    }
}
