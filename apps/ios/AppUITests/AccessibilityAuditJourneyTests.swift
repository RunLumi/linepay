import XCTest

@MainActor
final class AccessibilityAuditJourneyTests: XCTestCase {
    private var app = XCUIApplication()

    func testUnfilteredAppleAuditDiagnostic() throws {
        guard ProcessInfo.processInfo.environment["LINEPAY_RAW_APPLE_AUDIT"] == "1" else {
            throw XCTSkip(
                "Raw SwiftUI font/clipping heuristics are diagnostic; the required font-metrics, layout, visible-contrast and semantic tests run separately. See docs/testing/accessibility-audit.md."
            )
        }
        try auditWorkerScreens()
    }

    func testContrastOnFreshWorkerScreens() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip(
                "The iOS 18 audit cannot identify its SwiftUI contrast reports. Run this required contrast journey on the existing iOS 26 simulator; source contrast and font/layout tests still run here."
            )
        }
        launch(largeText: false)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        try audit("fresh-today", types: .contrast)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        try audit("fresh-settings", types: .contrast)
        let backup = app.buttons["backup.open"]
        for _ in 0..<12 {
            if backup.exists, backup.isHittable,
                backup.frame.maxY < app.tabBars.firstMatch.frame.minY - 8
            {
                break
            }
            app.swipeUp()
        }
        XCTAssertTrue(backup.isHittable)
        try audit("fresh-settings-backup", types: .contrast)
        let activity = app.buttons["settings.local-activity"]
        for _ in 0..<12 where !activity.isHittable { app.swipeDown() }
        XCTAssertTrue(activity.isHittable)
        activity.tap()
        XCTAssertTrue(app.navigationBars["Device-local activity"].waitForExistence(timeout: 10))
        try audit("fresh-activity", types: .contrast)
    }

    func testWorkerScreensPassSemanticAccessibilityAudit() throws {
        try auditWorkerScreens(types: .all.subtracting([.contrast, .dynamicType, .textClipped]))
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
        let largeStatus = app.descendants(matching: .any)
            .matching(identifier: "audit.status").firstMatch
        var statusScrolls = 0
        while !largeStatus.isHittable && statusScrolls < 8 {
            app.swipeUp()
            statusScrolls += 1
        }
        XCTAssertTrue(largeStatus.waitForExistence(timeout: 10))
        XCTAssertTrue(largeStatus.isHittable)
        XCTAssertTrue(largeStatus.label.contains("No difference within compared items"))
        XCTAssertGreaterThan(largeStatus.frame.height, 40)
        let todayNavigationBar = app.navigationBars["Today"].firstMatch
        let todayTabBar = app.tabBars.firstMatch
        var statusTopScrolls = 0
        while largeStatus.frame.minY < todayNavigationBar.frame.maxY && statusTopScrolls < 6 {
            app.swipeDown()
            statusTopScrolls += 1
        }
        XCTAssertGreaterThanOrEqual(largeStatus.frame.minY, todayNavigationBar.frame.maxY)
        let statusScreenshot = XCTAttachment(screenshot: app.screenshot())
        statusScreenshot.name = "large-text-today-status-beginning-dark"
        statusScreenshot.lifetime = .keepAlways
        add(statusScreenshot)
        var statusBottomScrolls = 0
        while largeStatus.frame.maxY > todayTabBar.frame.minY && statusBottomScrolls < 8 {
            app.swipeUp()
            statusBottomScrolls += 1
        }
        XCTAssertLessThanOrEqual(largeStatus.frame.maxY, todayTabBar.frame.minY)
        let statusEndScreenshot = XCTAttachment(screenshot: app.screenshot())
        statusEndScreenshot.name = "large-text-today-status-ending-dark"
        statusEndScreenshot.lifetime = .keepAlways
        add(statusEndScreenshot)
        let largeWorkRow = app.buttons["today.edit-work"].firstMatch
        var workRowScrolls = 0
        while !largeWorkRow.isHittable && workRowScrolls < 8 {
            app.swipeUp()
            workRowScrolls += 1
        }
        XCTAssertTrue(largeWorkRow.waitForExistence(timeout: 10))
        XCTAssertTrue(largeWorkRow.isHittable)
        XCTAssertTrue(largeWorkRow.label.contains("Synthetic test shift"))
        XCTAssertGreaterThan(largeWorkRow.frame.height, 100)
        var workRowAlignmentScrolls = 0
        while largeWorkRow.frame.maxY > todayTabBar.frame.minY && workRowAlignmentScrolls < 4 {
            app.swipeUp()
            workRowAlignmentScrolls += 1
        }
        XCTAssertGreaterThan(largeWorkRow.frame.minY, todayNavigationBar.frame.maxY)
        XCTAssertLessThanOrEqual(largeWorkRow.frame.maxY, todayTabBar.frame.minY)
        let workRowScreenshot = XCTAttachment(screenshot: app.screenshot())
        workRowScreenshot.name = "large-text-today-work-row-dark"
        workRowScreenshot.lifetime = .keepAlways
        add(workRowScreenshot)

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
        let activityDisclosure = app.staticTexts["activity.recording-explanation"].firstMatch
        var disclosureScrolls = 0
        while !activityDisclosure.isHittable && disclosureScrolls < 6 {
            app.swipeUp()
            disclosureScrolls += 1
        }
        XCTAssertTrue(activityDisclosure.waitForExistence(timeout: 10))
        XCTAssertTrue(activityDisclosure.isHittable)
        XCTAssertGreaterThan(activityDisclosure.frame.height, 200)
        let activityNavigationBar = app.navigationBars["Device-local activity"].firstMatch
        let activityTabBar = app.tabBars.firstMatch
        var disclosureStartScrolls = 0
        while activityDisclosure.frame.minY < activityNavigationBar.frame.maxY
            && disclosureStartScrolls < 8
        {
            app.swipeDown()
            disclosureStartScrolls += 1
        }
        XCTAssertGreaterThanOrEqual(
            activityDisclosure.frame.minY, activityNavigationBar.frame.maxY)
        let activityStartScreenshot = XCTAttachment(screenshot: app.screenshot())
        activityStartScreenshot.name = "large-text-device-local-activity-beginning-dark"
        activityStartScreenshot.lifetime = .keepAlways
        add(activityStartScreenshot)
        var disclosureEndScrolls = 0
        while activityDisclosure.frame.maxY > activityTabBar.frame.minY
            && disclosureEndScrolls < 8
        {
            app.swipeUp()
            disclosureEndScrolls += 1
        }
        XCTAssertLessThanOrEqual(activityDisclosure.frame.maxY, activityTabBar.frame.minY)
        let activityEndScreenshot = XCTAttachment(screenshot: app.screenshot())
        activityEndScreenshot.name = "large-text-device-local-activity-ending-dark"
        activityEndScreenshot.lifetime = .keepAlways
        add(activityEndScreenshot)
        app.navigationBars.buttons.firstMatch.tap()

        let agreementDocuments = app.buttons["settings.agreements"].firstMatch
        let crewRuleDrafts = app.buttons["settings.crew-rules"].firstMatch
        alignContentToSafeArea(
            agreementDocuments, navigationBar: app.navigationBars["Settings"].firstMatch,
            tabBar: app.tabBars.firstMatch)
        XCTAssertTrue(agreementDocuments.isHittable)
        XCTAssertGreaterThanOrEqual(
            agreementDocuments.frame.minY, app.navigationBars["Settings"].frame.maxY)
        XCTAssertLessThanOrEqual(
            agreementDocuments.frame.maxY, app.tabBars.firstMatch.frame.minY)
        let agreementScreenshot = XCTAttachment(screenshot: app.screenshot())
        agreementScreenshot.name = "large-text-settings-agreements-dark"
        agreementScreenshot.lifetime = .keepAlways
        add(agreementScreenshot)

        if CrewRuleSharingAvailability.enabled {
            alignContentToSafeArea(
                crewRuleDrafts, navigationBar: app.navigationBars["Settings"].firstMatch,
                tabBar: app.tabBars.firstMatch)
            XCTAssertTrue(crewRuleDrafts.isHittable)
            XCTAssertGreaterThanOrEqual(
                crewRuleDrafts.frame.minY, app.navigationBars["Settings"].frame.maxY)
            XCTAssertLessThanOrEqual(
                crewRuleDrafts.frame.maxY, app.tabBars.firstMatch.frame.minY)
            let settingsRulesScreenshot = XCTAttachment(screenshot: app.screenshot())
            settingsRulesScreenshot.name = "large-text-settings-crew-rules-dark"
            settingsRulesScreenshot.lifetime = .keepAlways
            add(settingsRulesScreenshot)
        } else {
            XCTAssertFalse(crewRuleDrafts.exists)
        }

        let restorePurchases = app.buttons["settings.restore-purchases"].firstMatch
        alignContentToSafeArea(
            restorePurchases, navigationBar: app.navigationBars["Settings"].firstMatch,
            tabBar: app.tabBars.firstMatch)
        XCTAssertTrue(restorePurchases.isHittable)
        XCTAssertGreaterThanOrEqual(
            restorePurchases.frame.minY, app.navigationBars["Settings"].frame.maxY)
        XCTAssertGreaterThan(restorePurchases.frame.height, 44)
        XCTAssertLessThanOrEqual(restorePurchases.frame.maxY, app.tabBars.firstMatch.frame.minY)
        let restorePurchasesScreenshot = XCTAttachment(screenshot: app.screenshot())
        restorePurchasesScreenshot.name = "large-text-settings-restore-purchases-dark"
        restorePurchasesScreenshot.lifetime = .keepAlways
        add(restorePurchasesScreenshot)

        let backupRestore = app.buttons["backup.open"].firstMatch
        alignContentToSafeArea(
            backupRestore, navigationBar: app.navigationBars["Settings"].firstMatch,
            tabBar: app.tabBars.firstMatch)
        XCTAssertTrue(backupRestore.isHittable)
        XCTAssertGreaterThanOrEqual(
            backupRestore.frame.minY, app.navigationBars["Settings"].frame.maxY)
        XCTAssertTrue(backupRestore.label.contains("Backup and restore"))
        XCTAssertGreaterThan(backupRestore.frame.height, 44)
        XCTAssertLessThanOrEqual(backupRestore.frame.maxY, app.tabBars.firstMatch.frame.minY)
        let backupRestoreScreenshot = XCTAttachment(screenshot: app.screenshot())
        backupRestoreScreenshot.name = "large-text-settings-backup-restore-dark"
        backupRestoreScreenshot.lifetime = .keepAlways
        add(backupRestoreScreenshot)
    }

    private func alignContentToSafeArea(
        _ element: XCUIElement,
        navigationBar: XCUIElement,
        tabBar: XCUIElement
    ) {
        for _ in 0..<40 {
            let top = navigationBar.frame.maxY + 4
            let bottom = tabBar.frame.minY - 4
            let delta: CGFloat
            if !element.exists {
                delta = -180
            } else {
                let frame = element.frame
                if frame.minY >= top, frame.maxY <= bottom, element.isHittable { return }
                delta =
                    frame.minY < top
                    ? min(180, top - frame.minY + 8)
                    : -min(180, max(40, frame.maxY - bottom + 8))
            }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            start.press(
                forDuration: 0.05,
                thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)))
        }
        XCTFail("The complete control must be reachable between system bars: \(element.identifier)")
    }

    private func auditWorkerScreens(types: XCUIAccessibilityAuditType = .all) throws {
        launch(largeText: false)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
        assertTodayStatusAndWorkRow()
        try audit("today", types: types)

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        let agreementDocuments = app.buttons["settings.agreements"].firstMatch
        let lastAgreementRow =
            CrewRuleSharingAvailability.enabled
            ? app.buttons["settings.crew-rules"].firstMatch : agreementDocuments
        var settingsScrolls = 0
        while (!lastAgreementRow.isHittable
            || lastAgreementRow.frame.maxY > app.tabBars.firstMatch.frame.minY)
            && settingsScrolls < 16
        {
            app.swipeUp()
            settingsScrolls += 1
        }
        let settingsNavigationBar = app.navigationBars["Settings"].firstMatch
        let settingsTabBar = app.tabBars.firstMatch
        for _ in 0..<20 {
            if agreementDocuments.frame.minY < settingsNavigationBar.frame.maxY {
                app.swipeDown()
            } else if lastAgreementRow.frame.maxY > settingsTabBar.frame.minY {
                app.swipeUp()
            } else {
                break
            }
        }
        XCTAssertTrue(agreementDocuments.isHittable)
        XCTAssertTrue(lastAgreementRow.isHittable)
        XCTAssertGreaterThanOrEqual(
            agreementDocuments.frame.minY, settingsNavigationBar.frame.maxY)
        XCTAssertLessThanOrEqual(lastAgreementRow.frame.maxY, settingsTabBar.frame.minY)
        let alignedSettings = XCTAttachment(screenshot: app.screenshot())
        alignedSettings.name = "accessibility-settings-aligned-before-audit"
        alignedSettings.lifetime = .keepAlways
        add(alignedSettings)
        try audit("settings", types: types)

        let localActivity = app.descendants(matching: .any)
            .matching(identifier: "settings.local-activity").firstMatch
        var localActivityScrolls = 0
        while !localActivity.isHittable && localActivityScrolls < 8 {
            app.swipeDown()
            localActivityScrolls += 1
        }
        XCTAssertTrue(localActivity.waitForExistence(timeout: 10))
        XCTAssertTrue(localActivity.isHittable)
        localActivity.tap()
        XCTAssertTrue(app.navigationBars["Device-local activity"].waitForExistence(timeout: 10))
        try audit("device-local-activity", types: types)
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

    private func audit(_ screen: String, types: XCUIAccessibilityAuditType = .all) throws {
        var attachedHierarchy = false
        let top = app.navigationBars.firstMatch.frame.maxY
        let bottom = app.tabBars.firstMatch.frame.minY
        let viewport = CGRect(
            x: 0, y: top, width: app.windows.firstMatch.frame.width, height: bottom - top)
        print("Audit viewport: \(screen), \(viewport), tab bar \(app.tabBars.firstMatch.frame)")
        try app.performAccessibilityAudit(for: types) { [self] issue in
            let details = """
                Screen: \(screen)
                Text size: System default; Apple audit may vary Dynamic Type
                Type: \(issue.auditType.rawValue)
                Summary: \(issue.compactDescription)
                Details: \(issue.detailedDescription)
                Element: \(issue.element?.debugDescription ?? "unavailable")
                Hittable: \(issue.element.map { String($0.isHittable) } ?? "unavailable")
                """
            print(details)
            let attachment = XCTAttachment(string: details)
            attachment.name = "accessibility-\(screen)-issue-\(issue.auditType.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
            if issue.element == nil && !attachedHierarchy {
                let hierarchy = XCTAttachment(string: app.debugDescription)
                hierarchy.name = "accessibility-\(screen)-unmapped-issue-hierarchy"
                hierarchy.lifetime = .keepAlways
                add(hierarchy)
                attachedHierarchy = true
            }
            // Scrolling content occluded by system bars is not a visible contrast sample.
            // Never dismiss an unmapped report or one fully inside the reading viewport.
            if types == .contrast, let element = issue.element,
                !app.navigationBars.descendants(matching: .any).allElementsBoundByIndex.contains(
                    element),
                !app.tabBars.descendants(matching: .any).allElementsBoundByIndex.contains(element),
                !viewport.contains(element.frame)
            {
                print("Contrast outside readable viewport: \(element.frame), \(element.label)")
                return true
            }
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
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL",
        ]
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = "matches"
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    }
}
