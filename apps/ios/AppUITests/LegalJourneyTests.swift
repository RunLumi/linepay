import XCTest

/// Native receipts for consent and sharing. Fixtures are synthetic; no recipient is selected.
@MainActor
final class LegalJourneyTests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.terminate()
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = .light
    }

    func testDefaultReportRequiresPreviewBeforeSharing() {
        launch(scenario: "matches")
        tab("Pay")
        tap("pay.open-audit")
        let scope = app.staticTexts["Not a complete wage-law check"].firstMatch
        scrollTo(scope)
        XCTAssertTrue(scope.exists)
        capture("legal-audit-scope")
        tap("audit.export")
        XCTAssertTrue(app.buttons["report.preview"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["audit.share-report"].exists)
        let details = app.switches["report.include-source-details"]
        XCTAssertTrue(details.exists)
        XCTAssertEqual(details.value as? String, "0")
        capture("legal-default-report-options")
        tap("report.preview")
        XCTAssertTrue(app.buttons["audit.share-report"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["report.preview-warning"].exists)
        capture("legal-exact-pdf-preview")
        tap("audit.share-report")
        // A screenshot alone also succeeds when ShareLink never opens. Require the actual
        // system activity, then its non-sending Files destination to exercise PDF transfer.
        let saveToFiles = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Save to Files")).firstMatch
        XCTAssertTrue(
            saveToFiles.waitForExistence(timeout: 30),
            "The system PDF activity sheet did not open; preview alone is not a handoff.")
        scrollTo(saveToFiles)
        XCTAssertTrue(saveToFiles.isHittable)
        capture("legal-system-share-sheet")
        saveToFiles.tap()
        let documentsApp = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        let saveInFiles = documentsApp.buttons["Save"].firstMatch
        let saveInShareSheet = app.buttons["Save"].firstMatch
        let saveVisible =
            saveInFiles.waitForExistence(timeout: 15)
            || saveInShareSheet.waitForExistence(timeout: 15)
        XCTAssertTrue(
            saveVisible,
            "The PDF did not reach the system Files export destination.")
        capture("legal-files-export-ready")
        // Cancel at the native Files destination: no recipient is selected and no synthetic
        // report is persisted into a connected provider.
        let cancelInFiles = documentsApp.buttons["Cancel"].firstMatch
        let cancelInShareSheet = app.buttons["Cancel"].firstMatch
        if cancelInFiles.waitForExistence(timeout: 10) {
            cancelInFiles.tap()
        } else {
            XCTAssertTrue(
                cancelInShareSheet.waitForExistence(timeout: 10),
                "Files did not expose cancellation.")
            cancelInShareSheet.tap()
        }
        XCTAssertTrue(app.buttons["audit.share-report"].waitForExistence(timeout: 10))
        app.terminate()
        XCUIDevice.shared.press(.home)
    }

    func testEachRuleScopeKeepsItsPromisedEffectAtLargestText() {
        for (scope, scopeID, fragment, expected) in [
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
            for expectedStep in 1...2 {
                tap("pay-profile.continue", maxSwipes: 8)
                let next = app.buttons["pay-profile.continue"].firstMatch
                scrollTo(next, maxSwipes: 8)
                XCTAssertEqual(
                    next.value as? String, "step-\(expectedStep)",
                    "The editor did not advance to step \(expectedStep + 1) of 4.")
            }
            var reachedReview = false
            for _ in 0..<3 {
                let finalContinue = app.buttons["pay-profile.continue"].firstMatch
                scrollTo(finalContinue, maxSwipes: 8)
                XCTAssertTrue(finalContinue.isHittable)
                finalContinue.press(forDuration: 0.1)
                if finalContinue.waitForNonExistence(timeout: 3) {
                    reachedReview = true
                    break
                }
            }
            XCTAssertTrue(reachedReview, "The editor did not leave the final rules step.")
            let scopeControl = app.descendants(matching: .any)
                .matching(identifier: "pay-profile.change-scope").firstMatch
            revealReviewElement(scopeControl, maxSwipes: 8)
            XCTAssertTrue(scopeControl.waitForExistence(timeout: 15))
            scopeControl.tap()
            chooseScope(label: scope, identifier: scopeID)
            let explanation = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS %@", fragment)
            ).firstMatch
            revealReviewElement(explanation, maxSwipes: 8)
            XCTAssertTrue(explanation.exists)
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
        if largeText {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            ]
        }
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = scenario
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.terminate()
        app.launch()
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
        let stableOption = app.descendants(matching: .any)
            .matching(identifier: identifier).firstMatch
        if stableOption.exists && stableOption.isHittable {
            stableOption.tap()
            return
        }

        // SwiftUI Menu options can expose their visible label without preserving the child
        // identifier in the hosted accessibility tree. The exact label remains the user-facing
        // contract; prefer the stable identifier whenever the platform exposes it.
        let visibleOption = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label)).firstMatch
        XCTAssertTrue(visibleOption.waitForExistence(timeout: 15), "Missing scope option: \(label)")
        XCTAssertTrue(visibleOption.isHittable, "Scope option is not hittable: \(label)")
        visibleOption.tap()
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
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            frontmostWindow.swipeDown()
        }
        scrollTo(element, maxSwipes: maxSwipes)
    }
    private func revealEarlierContent() {
        let frontmostWindow = app.windows.element(boundBy: max(0, app.windows.count - 1))
        for _ in 0..<8 { frontmostWindow.swipeDown() }
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
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
