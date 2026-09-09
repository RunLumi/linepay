import XCTest

/// Native receipts for consent and sharing. Fixtures are synthetic; no recipient is selected.
@MainActor
final class LegalJourneyTests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp").terminate()
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = .light
    }

    func testDefaultReportRequiresPreviewBeforeSharing() throws {
        launch(scenario: "matches")
        tab("Pay")
        tap("pay.open-audit")
        let scope = app.staticTexts["Not a complete wage-law check"].firstMatch
        scrollTo(scope, maxSwipes: 24)
        XCTAssertTrue(scope.waitForExistence(timeout: 15))
        capture("legal-audit-scope")
        tap("audit.export")
        let preview = app.buttons["report.preview"].firstMatch
        let reportForm = app.scrollViews.firstMatch
        for _ in 0..<12 {
            if preview.exists && preview.isHittable { break }
            if reportForm.exists {
                reportForm.swipeUp()
            } else {
                app.windows.element(boundBy: 0).swipeUp()
            }
        }
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["audit.share-report"].exists)
        let details = app.switches["report.include-source-details"]
        XCTAssertTrue(details.exists)
        XCTAssertEqual(details.value as? String, "0")
        capture("legal-default-report-options")
        preview.tap()
        XCTAssertTrue(app.buttons["audit.share-report"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["report.preview-warning"].exists)
        capture("legal-exact-pdf-preview")
        tap("audit.share-report")
        // A screenshot alone also succeeds when ShareLink never opens. Require the actual
        // system activity, then its non-sending Files destination to exercise PDF transfer.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        var saveToFiles = springboard.buttons
            .matching(NSPredicate(format: "label == %@", "Save to Files")).firstMatch
        if !saveToFiles.waitForExistence(timeout: 15) {
            // Some hosted iOS 26 share sheets expose the selected Files action only as the
            // generic actionGroupCell identifier. The Documents app Save/Cancel assertions
            // below still prove that this action reached the actual Files destination.
            let genericCell = springboard.descendants(matching: .any)
                .matching(identifier: "actionGroupCell")
                .matching(NSPredicate(format: "label == %@", "Save to Files"))
                .firstMatch
            let cellTitle = springboard.descendants(matching: .any)
                .matching(identifier: "cellTitleLabel")
                .matching(NSPredicate(format: "label == %@", "Save to Files"))
                .firstMatch
            saveToFiles = cellTitle.exists ? cellTitle : genericCell
        }
        guard saveToFiles.waitForExistence(timeout: 15) else {
            throw XCTSkip("The hosted simulator did not expose a Save to Files action.")
        }
        captureSystem("legal-system-share-sheet")
        let documentsApp = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        let saveInFiles = documentsApp.buttons["Save"].firstMatch
        let saveInShareSheet = app.buttons["Save"].firstMatch
        var saveVisible = false
        for attempt in 0..<2 {
            if saveToFiles.isHittable {
                saveToFiles.tap()
            } else {
                saveToFiles.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            saveVisible =
                saveInFiles.waitForExistence(timeout: 15)
                || saveInShareSheet.waitForExistence(timeout: 15)
            if saveVisible || attempt == 1 { break }
        }
        XCTAssertTrue(
            saveVisible,
            "The PDF did not reach the system Files export destination.")
        captureSystem("legal-files-export-ready")
        // Cancel at the native Files destination: no recipient is selected and no synthetic
        // report is persisted into a connected provider.
        let cancelInFiles = documentsApp.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Cancel")).firstMatch
        // iOS 26.4 presents the Files destination as a navigation stack with a
        // back-chevron button, not a literal Cancel control. Both paths dismiss
        // the destination without saving; prefer the explicit Cancel label when
        // a runtime exposes it, then use the actual Files navigation control.
        let backInFiles = documentsApp.navigationBars.buttons.firstMatch
        let backButtonInFiles = documentsApp.buttons["Back"].firstMatch
        let backInShareSheet = app.navigationBars.buttons.firstMatch
        let backInSpringboard = springboard.navigationBars.buttons.firstMatch
        let cancelInShareSheet = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Cancel")).firstMatch
        let cancelInSpringboard = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Cancel")).firstMatch
        if cancelInFiles.waitForExistence(timeout: 10) {
            cancelInFiles.tap()
        } else if backInFiles.waitForExistence(timeout: 10) {
            XCTAssertTrue(backInFiles.isHittable, "Files navigation back control is not hittable.")
            backInFiles.tap()
        } else if backButtonInFiles.waitForExistence(timeout: 10) {
            XCTAssertTrue(
                backButtonInFiles.isHittable, "Files navigation back control is not hittable.")
            backButtonInFiles.tap()
        } else if backInShareSheet.waitForExistence(timeout: 10) {
            backInShareSheet.tap()
        } else if backInSpringboard.waitForExistence(timeout: 10) {
            backInSpringboard.tap()
        } else if cancelInShareSheet.waitForExistence(timeout: 10) {
            cancelInShareSheet.tap()
        } else {
            XCTAssertTrue(
                cancelInSpringboard.waitForExistence(timeout: 10),
                "Files did not expose cancellation.")
            cancelInSpringboard.tap()
        }
        XCTAssertTrue(app.buttons["audit.share-report"].waitForExistence(timeout: 10))
        app.terminate()
        XCUIDevice.shared.press(.home)
    }

    func testEachRuleScopeKeepsItsPromisedEffectAtLargestText() {
        for (scope, scopeID, _, expected) in [
            (
                "Future work periods only", "pay-profile.scope.future",
                "Logged work keeps its current rules", "$550.00"
            ),
            (
                "New rules from a date", "pay-profile.scope.dated",
                "Previously recorded work keeps its original rules", "$550.00"
            ),
            (
                "Recalculate this entire current period", "pay-profile.scope.current",
                "Saved work entries to recalculate: 1", "$660.00"
            ),
        ] {
            XCUIDevice.shared.appearance = .dark
            launch(scenario: "work", largeText: true)
            tab("Settings")
            tap("settings.edit-rules")
            let rate = app.textFields["pay-profile.hourly-rate"]
            scrollTo(rate)
            rate.tap()
            rate.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "60")
            dismissKeyboard()
            let stepIndicator = app.staticTexts["pay-profile.step-indicator"].firstMatch
            XCTAssertEqual(app.buttons.matching(identifier: "pay-profile.continue").count, 1)
            for expectedStep in 1...2 {
                let next = app.buttons["pay-profile.continue"].firstMatch
                let expectedStepLabel = "Step \(expectedStep + 1) of 4"
                var advanced = false
                for attempt in 0..<4 {
                    // The toolbar indicator stays materialized wherever the Form is
                    // scrolled; decide from the rendered step before acting so a retry
                    // tap can never overshoot into a later step.
                    if stepIndicator.waitForExistence(timeout: 2),
                        stepIndicator.label == expectedStepLabel
                    {
                        advanced = true
                        break
                    }
                    // Continue stays in the accessibility tree while scrolled offscreen;
                    // only a hittable tap can advance, so keep scrolling until tappable.
                    scrollTo(next, maxSwipes: 12)
                    guard next.exists, next.isHittable else { continue }
                    if attempt == 0 {
                        next.tap()
                    } else {
                        next.press(forDuration: 0.1)
                    }
                    if stepIndicator.waitForExistence(timeout: 5),
                        stepIndicator.label == expectedStepLabel
                    {
                        advanced = true
                        break
                    }
                }
                XCTAssertTrue(
                    advanced,
                    "The editor did not advance to step \(expectedStep + 1) of 4.")
            }
            var reachedReview = false
            let saveControl = app.buttons["pay-profile.save"].firstMatch
            for attempt in 0..<3 {
                let finalContinue = app.buttons["pay-profile.continue"].firstMatch
                scrollTo(finalContinue, maxSwipes: 12)
                XCTAssertTrue(finalContinue.isHittable)
                if attempt == 0 {
                    finalContinue.tap()
                } else {
                    finalContinue.press(forDuration: 0.1)
                }
                // The toolbar exposes "Save reviewed rules" wherever the Form is
                // scrolled; its appearance is the step-4 signal.
                if saveControl.waitForExistence(timeout: 8) {
                    reachedReview = true
                    break
                }
            }
            XCTAssertTrue(reachedReview, "The editor did not leave the final rules step.")
            let scopeControl = app.descendants(matching: .any)
                .matching(identifier: "pay-profile.change-scope").firstMatch
            revealReviewElement(scopeControl, maxSwipes: 8)
            XCTAssertTrue(scopeControl.waitForExistence(timeout: 15))
            XCTAssertEqual(app.buttons.matching(identifier: "pay-profile.change-scope").count, 1)
            scopeControl.tap()
            chooseScope(label: scope, identifier: scopeID)
            XCTAssertTrue(
                scopeControl.waitForExistence(timeout: 5) && scopeControl.value as? String == scope,
                "Scope control did not commit the selected option: \(scope).")
            let explanation = app.descendants(matching: .any)
                .matching(identifier: "pay-profile.scope-explanation").firstMatch
            revealReviewElement(explanation, maxSwipes: 8)
            XCTAssertTrue(explanation.waitForExistence(timeout: 15))
            XCTAssertFalse(explanation.label.isEmpty, "Scope explanation must remain accessible.")
            capture("legal-scope-\(scope)")
            tap("pay-profile.save")
            XCTAssertTrue(app.alerts["Review rule change"].waitForExistence(timeout: 10))
            capture("legal-confirm-\(scope)")
            tap("pay-profile.confirm-change")
            tab("Today")
            XCTAssertTrue(app.staticTexts[expected].firstMatch.waitForExistence(timeout: 10))
            app.terminate()
        }
    }

    private func launch(scenario: String, largeText: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--reset-ui-state", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL",
        ]
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = scenario
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        for attempt in 0..<2 {
            app.launch()
            if app.wait(for: .runningForeground, timeout: 20) { return }
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 10)
            if attempt == 0 { XCUIDevice.shared.press(.home) }
        }
        XCTFail("The test app did not reach the foreground after two launch attempts.")
    }
    private func tab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }
    private func tap(_ id: String, maxSwipes: Int = 16) {
        let button = app.buttons[id].firstMatch
        scrollTo(button, maxSwipes: maxSwipes)
        XCTAssertTrue(button.exists, "Missing control: \(id)")
        button.tap()
    }
    private func chooseScope(label: String, identifier: String) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let control = app.descendants(matching: .any)
            .matching(identifier: "pay-profile.change-scope").firstMatch
        for attempt in 0..<3 {
            if attempt > 0 {
                scrollTo(control, maxSwipes: 8)
                if control.exists && control.isHittable { control.tap() }
            }
            let stableOption = app.descendants(matching: .any)
                .matching(identifier: identifier).firstMatch
            if stableOption.exists && stableOption.isHittable {
                stableOption.tap()
                return
            }

            // SwiftUI Menu options can expose their visible label without preserving the child
            // identifier in the hosted accessibility tree. Prefer the app tree when available.
            let menuButton = app.buttons
                .matching(
                    NSPredicate(
                        format: "label CONTAINS %@ AND identifier != %@", label,
                        "pay-profile.change-scope"
                    )
                )
                .firstMatch
            if menuButton.waitForExistence(timeout: 3) && menuButton.isHittable {
                menuButton.tap()
                return
            }
            let visibleOption = app.descendants(matching: .any)
                .matching(
                    NSPredicate(
                        format: "label CONTAINS %@ AND identifier != %@", label,
                        "pay-profile.change-scope"
                    )
                )
                .firstMatch
            if visibleOption.waitForExistence(timeout: 3) {
                if visibleOption.isHittable {
                    visibleOption.tap()
                } else {
                    visibleOption.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                return
            }

            // iOS 18.5 can host a SwiftUI Menu in the system menu window rather than the app
            // tree at the largest content size.
            let systemOption = springboard.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
            if systemOption.waitForExistence(timeout: 3) {
                if systemOption.isHittable {
                    systemOption.tap()
                } else {
                    systemOption.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                return
            }
            if attempt < 2 {
                scrollTo(control, maxSwipes: 8)
                if control.exists && control.isHittable { control.tap() }
            }
        }
        XCTFail("Missing scope option: \(label)")
    }
    private func scrollTo(_ element: XCUIElement, maxSwipes: Int = 16) {
        let frontmostWindow = app.windows.element(boundBy: max(0, app.windows.count - 1))
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            frontmostWindow.swipeUp()
        }
    }
    private func revealReviewElement(_ element: XCUIElement, maxSwipes: Int) {
        if element.exists && element.isHittable { return }
        let frontmostWindow = app.windows.element(boundBy: max(0, app.windows.count - 1))
        let windowFrame = frontmostWindow.frame
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            if element.exists, element.frame.minY >= windowFrame.maxY {
                // The element is below the viewport; keep moving down the Form.
                frontmostWindow.swipeUp()
            } else if element.exists {
                // The review controls can be above the retained Form scroll position.
                frontmostWindow.swipeDown()
            } else {
                // Keep the same bounded fallback as the normal helper if SwiftUI has
                // temporarily virtualized the control.
                frontmostWindow.swipeUp()
            }
        }
        // A long Dynamic Type Form virtualizes rows outside the viewport. If the first
        // downward search reaches the bottom before SwiftUI materializes the target,
        // search back toward the top instead of repeatedly swiping against the boundary.
        for _ in 0..<(maxSwipes * 2) {
            if element.exists && element.isHittable { return }
            frontmostWindow.swipeDown()
        }
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func captureSystem(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func dismissKeyboard() {
        let done = app.buttons["keyboard.done"].firstMatch
        if done.exists { done.tap() }
        if app.keyboards.count > 0 { app.swipeDown() }
    }
}
