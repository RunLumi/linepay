import XCTest

@MainActor
final class PaydayJourneyTests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        // Each journey seeds a fresh synthetic store from its launch environment. Terminate any
        // previous app process first so a suite run cannot reuse an earlier fixture session.
        app = XCUIApplication()
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIDevice.shared.appearance = .light
    }

    func testFirstPaydayThenNextWorkAndDelayedPaycheck() throws {
        launch(commerce: true)
        capture("01-welcome")
        tap("onboarding.set-up-pay")
        let rate = app.textFields["pay-profile.hourly-rate"]
        XCTAssertTrue(rate.waitForExistence(timeout: 10))
        rate.tap()
        rate.typeText("50")
        dismissKeyboard()
        capture("02-pay-basics")
        advanceSetupStep(to: "Step 2 of 4")
        capture("03-pay-period")
        advanceSetupStep(to: "Step 3 of 4")
        capture("04-optional-rules")
        advanceSetupStep(to: "Step 4 of 4")
        capture("05-confirm-rules")
        tapSetupSave()
        let addWork = app.buttons["activation.add-work"]
        scrollTo(addWork)
        XCTAssertTrue(addWork.waitForExistence(timeout: 10))
        capture("07-first-work")
        tap("activation.add-work")
        capture("09-add-work")
        tap("work.save")
        XCTAssertTrue(app.staticTexts["$400.00"].firstMatch.waitForExistence(timeout: 10))
        capture("08-today-work")
        app.terminate()
        launch(reset: false, commerce: true)
        XCTAssertTrue(app.staticTexts["$400.00"].firstMatch.waitForExistence(timeout: 10))
        capture("first-expected-pay-proof")
        tap("activation.keep-logging")
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
        capture("late-paycheck-result")
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

    func testUnresolvedPeriodClosesAndNextPeriodRemainsIndependent() {
        launch(scenario: "unresolved")
        tab("Pay")
        let finish = app.buttons["pay.finish-period"]
        scrollTo(finish)
        if !finish.waitForExistence(timeout: 10) {
            let alert = app.alerts.firstMatch
            let fixtureError = alert.exists ? alert.label : "no fixture error alert"
            XCTFail("Missing unresolved-period close action (fixture: \(fixtureError))")
        }
        tap("pay.finish-period")
        let reviewWarning = app.staticTexts["Calculation needs review"]
        scrollTo(reviewWarning)
        XCTAssertTrue(reviewWarning.waitForExistence(timeout: 10))
        let confirmClose = app.buttons["period.confirm-close"]
        scrollTo(confirmClose)
        XCTAssertTrue(confirmClose.waitForExistence(timeout: 10))
        XCTAssertTrue(confirmClose.isEnabled)
        var dismissed = false
        for _ in 0..<3 {
            if !confirmClose.exists {
                dismissed = true
                break
            }
            confirmClose.tap()
            if confirmClose.waitForNonExistence(timeout: 5) {
                dismissed = true
                break
            }
        }
        XCTAssertTrue(
            dismissed,
            "The close sheet did not dismiss before starting the next-period journey.")

        tab("Today")
        let addNextWork = app.buttons["today.add-work"]
        scrollTo(addNextWork)
        XCTAssertTrue(addNextWork.waitForExistence(timeout: 10))
        tap("today.add-work")
        tap("work.save")
        tab("History")
        let historyWarning = app.staticTexts["Calculation needs review"]
        scrollTo(historyWarning)
        XCTAssertTrue(historyWarning.waitForExistence(timeout: 10))

        app.terminate()
        launch(reset: false, scenario: "unresolved")
        tab("History")
        XCTAssertTrue(app.staticTexts["Calculation needs review"].waitForExistence(timeout: 10))
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

    func testCurrentAuditCanOpenItsCorrectionWithoutLosingNavigation() {
        launch(scenario: "matches")
        tab("Pay")
        tap("pay.open-audit")
        tap("audit.correct")
        let correctExisting = app.buttons["paystub.correct-existing"]
        scrollTo(correctExisting)
        XCTAssertTrue(correctExisting.waitForExistence(timeout: 10))
        capture("correction-source-chooser")
        tap("paystub.correct-existing")
        let value = openPaystubValueField("paystub.field.grossPay")
        XCTAssertTrue(value.exists)
        XCTAssertEqual(value.value as? String, "550")
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
        XCUIDevice.shared.appearance = .dark
        launch(scenario: "review", largeText: true)
        capture("large-dark-today")
        tab("Pay")
        tap("Open paycheck audit")
        capture("large-dark-audit")
        tab("Settings")
        capture("37-settings")
        tap("About LinePaycheck")
        capture("45-about")
        let guide = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "User Guide")).firstMatch
        scrollTo(guide)
        XCTAssertTrue(guide.waitForExistence(timeout: 10))
        XCTAssertTrue(guide.isHittable)
        tap("Privacy policy")
        capture("42-privacy")
        app.terminate()
        launch(scenario: "corrupt")
        XCTAssertTrue(app.buttons["recovery.retry"].waitForExistence(timeout: 10))
        capture("46-data-recovery")
        tap("recovery.retry")
        XCTAssertTrue(
            app.buttons["recovery.retry"].exists, "Unreadable data must not silently reset")
    }

    func testEditedWorkDraftResumesItsOriginalEntry() {
        launch(scenario: "work")
        tap("today.edit-work")
        let note = app.descendants(matching: .any).matching(identifier: "work.note").firstMatch
        scrollTo(note)
        note.tap()
        note.typeText(" unfinished correction")
        dismissKeyboard()
        app.terminate()
        launch(reset: false)
        tap("today.add-work")
        let resumed = app.descendants(matching: .any).matching(identifier: "work.note").firstMatch
        scrollTo(resumed)
        XCTAssertTrue(
            String(describing: resumed.value ?? "").contains("unfinished correction"),
            "Resumed note value: \(String(describing: resumed.value))")
        capture("edited-work-draft-resumed")
        tap("work.save")
        XCTAssertEqual(app.buttons.matching(identifier: "today.edit-work").count, 1)
        // The persisted-note and single-entry assertions above prove the draft resumed and was
        // saved. Avoid coupling this recovery journey to OS-specific amount grouping/formatting.
        XCTAssertTrue(app.buttons["today.edit-work"].exists)
        XCTAssertEqual(app.buttons["today.add-work"].label, "Add work")
    }

    func testInterruptedPaycheckReviewRetainsSourceAndCorrection() {
        launch(scenario: "intake")
        tab("Pay")
        tap("pay.check-paycheck")
        tap("paystub.resume")
        tap("paystub.field.grossPay")
        tap("View original paystub")
        capture("29-original-before-correction")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let value = app.textFields["paystub.value"]
        XCTAssertTrue(value.waitForExistence(timeout: 10))
        value.tap()
        value.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "549.50")
        dismissKeyboard()
        app.terminate()
        launch(reset: false)
        tab("Pay")
        tap("pay.check-paycheck")
        tap("paystub.resume")
        let restoredValue = openPaystubValueField("paystub.field.grossPay")
        XCTAssertTrue(restoredValue.exists)
        XCTAssertEqual(restoredValue.value as? String, "549.50")
        tap("View original paystub")
        capture("29-original-after-interruption")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("paystub.confirm-field")
        scrollTo(app.buttons["paystub.audit"])
        capture("23-partially-confirmed-review")
        XCTAssertFalse(
            app.buttons["paystub.audit"].isEnabled,
            "Unconfirmed dates must not become trusted because a draft survived restart")
    }

    private func launch(
        reset: Bool = true, scenario: String = "empty", commerce: Bool = false,
        largeText: Bool = false
    ) {
        app = XCUIApplication()
        app.launchArguments =
            ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            + (reset ? ["--reset-ui-state"] : [])
        if largeText {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
            ]
        }
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = scenario
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = commerce ? "1" : "0"
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        XCTAssertGreaterThan(
            app.windows.firstMatch.frame.height, 600,
            "Supported iPhones must not use the legacy 320-by-480 launch window")
    }
    private func tab(_ label: String) {
        let element = app.tabBars.buttons[label]
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        element.tap()
    }
    private func tap(_ id: String) {
        let element = app.buttons[id].firstMatch
        if !element.waitForExistence(timeout: 8) || !element.isHittable {
            scrollTo(element)
        }
        XCTAssertTrue(element.exists, "Missing control \(id)")
        element.tap()
    }
    private func tapContaining(_ text: String) {
        let element = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
        if !element.waitForExistence(timeout: 3) || !element.isHittable {
            scrollTo(element)
        }
        XCTAssertTrue(element.exists, "Missing row containing \(text)")
        element.tap()
    }
    private func advanceSetupStep(to expectedLabel: String) {
        let indicator = app.staticTexts["pay-profile.step-indicator"].firstMatch
        let next = app.buttons["pay-profile.continue"].firstMatch
        for _ in 0..<3 {
            if indicator.exists, indicator.label == expectedLabel { return }
            XCTAssertTrue(next.waitForExistence(timeout: 8))
            scrollTo(next)
            XCTAssertTrue(next.isHittable)
            next.tap()
            if indicator.waitForExistence(timeout: 5), indicator.label == expectedLabel { return }
        }
        XCTFail("Pay setup did not reach \(expectedLabel); current step: \(indicator.label)")
    }
    private func tapSetupSave() {
        let indicator = app.staticTexts["pay-profile.step-indicator"].firstMatch
        for _ in 0..<4 {
            if indicator.waitForExistence(timeout: 8), indicator.label == "Step 4 of 4" {
                tap("pay-profile.save")
                return
            }
            let next = app.buttons["pay-profile.continue"].firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: 8))
            scrollTo(next)
            XCTAssertTrue(next.isHittable)
            next.tap()
        }
        XCTFail("Pay setup did not expose the review save control; current step: \(indicator.label)")
    }
    private func openPaystubValueField(_ id: String) -> XCUIElement {
        let value = app.textFields["paystub.value"]
        for attempt in 0..<2 {
            if value.waitForExistence(timeout: 5) { return value }
            let field = app.buttons[id].firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 8), "Missing control \(id)")
            field.tap()
            if attempt == 0 { _ = value.waitForExistence(timeout: 3) }
        }
        return value
    }
    private func scrollTo(_ element: XCUIElement) {
        // Dense setup and review Forms can exceed fourteen viewport heights at supported
        // Dynamic Type sizes; keep the search bounded but long enough to reach the row.
        let frontmostWindow = app.windows.element(boundBy: max(0, app.windows.count - 1))
        for _ in 0..<30 {
            if element.exists && element.isHittable { return }
            frontmostWindow.swipeUp()
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
        let completeWork = app.descendants(matching: .any)
            .matching(identifier: "paystub.complete-work").firstMatch
        scrollTo(completeWork)
        completeWork.tap()
        capture("confirmed-period-work")
        XCTAssertTrue(completeWork.isSelected)
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
