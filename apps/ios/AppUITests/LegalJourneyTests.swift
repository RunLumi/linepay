import XCTest

/// Native receipts for consent and sharing. Fixtures are synthetic; no recipient is selected.
@MainActor
final class LegalJourneyTests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
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
        capture("legal-system-share-sheet")
    }

    func testEachRuleScopeKeepsItsPromisedEffectAtLargestText() {
        for (scope, fragment, expected) in [
            ("Future work periods only", "Logged work keeps its current rules", "$550.00"),
            (
                "New rules from a date", "Previously recorded work keeps its original rules",
                "$550.00"
            ),
            (
                "Recalculate this entire current period", "Saved work entries to recalculate: 1",
                "$660.00"
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
            if app.keyboards.count > 0 {
                let done = app.buttons["keyboard.done"].firstMatch
                if done.exists { done.tap() } else { app.swipeDown() }
            }
            for _ in 0..<3 { tap("pay-profile.continue") }
            tap("pay-profile.change-scope")
            tap(scope)
            let explanation = app.staticTexts["pay-profile.scope-explanation"]
            scrollTo(explanation)
            XCTAssertTrue(explanation.label.contains(fragment))
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
        app.launch()
    }
    private func tab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }
    private func tap(_ id: String) {
        let button = app.buttons[id].firstMatch
        scrollTo(button)
        XCTAssertTrue(button.exists, "Missing control: \(id)")
        button.tap()
    }
    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<16 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
