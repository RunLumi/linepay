import XCTest

@MainActor
final class PaydayJourneyTests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light
    }

    func testFirstPaydayThenNextWorkAndDelayedPaycheck() throws {
        launch()
        capture("01-welcome")
        tap("onboarding.set-up-pay")
        let rate = app.textFields["pay-profile.hourly-rate"]
        XCTAssertTrue(rate.waitForExistence(timeout: 10))
        rate.tap()
        rate.typeText("50")
        dismissKeyboard()
        capture("02-pay-basics")
        tap("pay-profile.continue")
        capture("03-pay-period")
        tap("pay-profile.continue")
        capture("04-optional-rules")
        tap("pay-profile.continue")
        capture("05-confirm-rules")
        tap("pay-profile.save")
        XCTAssertTrue(app.buttons["today.add-work"].waitForExistence(timeout: 10))
        capture("07-today-empty")
        tap("today.add-work")
        capture("09-add-work")
        tap("work.save")
        XCTAssertTrue(app.staticTexts["$400.00"].firstMatch.waitForExistence(timeout: 10))
        capture("08-today-work")
        app.terminate()
        launch(reset: false)
        XCTAssertTrue(app.staticTexts["$400.00"].firstMatch.waitForExistence(timeout: 10))
        tab("Pay")
        capture("15-pay-ledger")
        tap("pay.finish-period")
        capture("30-finish-awaiting")
        tap("period.confirm-close")
        tab("Today")
        tap("today.add-work")
        tap("work.save")
        XCTAssertTrue(app.staticTexts["$400.00"].firstMatch.waitForExistence(timeout: 10))
        tab("History")
        capture("32-history-pending")
        tapContaining("Awaiting paycheck")
        capture("33-historical-period")
        tap("history.audit")
        confirmManualGross("400")
        XCTAssertTrue(
            app.staticTexts["Gross total matches"].firstMatch.waitForExistence(timeout: 10))
        capture("24-late-paycheck-matches")
        tab("Today")
        XCTAssertTrue(
            app.staticTexts["$400.00"].firstMatch.waitForExistence(timeout: 10),
            "Auditing A must not overwrite work in B")
        app.terminate()
        launch(reset: false, commerce: true)
        tab("Pay")
        tap("pay.check-paycheck")
        XCTAssertTrue(app.buttons["paywall.dismiss"].waitForExistence(timeout: 10))
        capture("35-second-audit-paywall")
        tap("paywall.dismiss")
        XCTAssertTrue(app.buttons["pay.check-paycheck"].waitForExistence(timeout: 10))
    }

    func testAuditVerdictsAndEvidenceRoutes() {
        for (scenario, verdict) in [
            ("matches", "Gross total matches"),
            ("shortfall", "Possible shortfall"),
            ("overpayment", "Possible overpayment"),
            ("review", "Needs review"),
            ("not-comparable", "Not ready to compare"),
        ] {
            launch(scenario: scenario)
            tab("Pay")
            tap("Open paycheck audit")
            XCTAssertTrue(app.staticTexts[verdict].firstMatch.waitForExistence(timeout: 10))
            capture("audit-\(scenario)")
            if scenario == "review" {
                tapContaining("Regular pay")
                capture("28-comparison-evidence")
            }
            app.terminate()
        }
    }

    func testDraftRecoveryAndUnsupportedRulePresentation() {
        launch(scenario: "work")
        tap("today.add-work")
        // Multiline TextField uses a different accessibility type across OS releases.
        let input = app.descendants(matching: .any).matching(identifier: "work.note").firstMatch
        scrollTo(input)
        input.tap()
        input.typeText("SAMPLE unfinished shift")
        dismissKeyboard()
        app.terminate()
        launch(reset: false)
        tap("today.add-work")
        let restored = app.descendants(matching: .any).matching(identifier: "work.note").firstMatch
        scrollTo(restored)
        XCTAssertTrue(String(describing: restored.value ?? "").contains("unfinished shift"))
        capture("draft-resumed")
        app.terminate()
        launch(scenario: "unsupported")
        tab("Settings")
        capture("unsupported-rule-settings")
    }

    func testLargeTextDarkSettingsAndRecovery() {
        launch(scenario: "review", largeText: true)
        XCUIDevice.shared.appearance = .dark
        capture("large-dark-today")
        tab("Pay")
        tap("Open paycheck audit")
        capture("large-dark-audit")
        tab("Settings")
        capture("37-settings")
        tap("About LinePaycheck")
        capture("45-about")
        tap("Privacy policy")
        capture("42-privacy")
        app.terminate()
        launch(scenario: "corrupt")
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 10))
        capture("46-data-recovery")
        tap("Try again")
        XCTAssertTrue(app.buttons["Try again"].exists, "Unreadable data must not silently reset")
    }

    private func launch(
        reset: Bool = true, scenario: String = "empty", commerce: Bool = false,
        largeText: Bool = false
    ) {
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + (reset ? ["--reset-ui-state"] : [])
        if largeText {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            ]
        }
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = scenario
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = commerce ? "1" : "0"
        app.launch()
    }
    private func tab(_ label: String) {
        let element = app.tabBars.buttons[label]
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        element.tap()
    }
    private func tap(_ id: String) {
        let element = app.buttons[id].firstMatch
        scrollTo(element)
        XCTAssertTrue(element.exists, "Missing control \(id)")
        element.tap()
    }
    private func tapContaining(_ text: String) {
        let element = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
        scrollTo(element)
        XCTAssertTrue(element.exists, "Missing row containing \(text)")
        element.tap()
    }
    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<14 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
    }
    private func dismissKeyboard() {
        if app.buttons["keyboard.done"].firstMatch.exists {
            app.buttons["keyboard.done"].firstMatch.tap()
        }
    }
    private func confirmManualGross(_ amount: String) {
        tap("paystub.manual")
        capture("20-paystub-review")
        for field in ["periodStart", "periodEnd", "grossPay"] {
            tap("paystub.field.\(field)")
            if field == "grossPay" {
                let value = app.textFields["paystub.value"]
                XCTAssertTrue(value.waitForExistence(timeout: 10))
                value.tap()
                value.typeText(amount)
                dismissKeyboard()
            }
            capture("21-confirm-\(field)")
            tap("paystub.confirm-field")
        }
        tap("paystub.gross-basis")
        tapContaining("Wages only")
        tap("paystub.audit")
    }
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
