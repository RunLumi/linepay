import XCTest

@MainActor
final class BenefitJourneyTests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = .light
    }

    func testMissingStatementThenCorrectionAndPrivateReportKeepWagesUnchanged() throws {
        launch()
        XCTAssertTrue(app.staticTexts["$2,000.00"].firstMatch.waitForExistence(timeout: 10))
        openBenefits()
        tap("benefits.new")
        enter("benefits.fund-name", "SYNTHETIC PENSION")
        tap("benefits.continue")
        tap("benefits.segment")
        enter("benefits.rate", "8.75")
        enter("benefits.units", "40")
        tap("benefits.segment-done")
        tap("benefits.continue")
        tap("benefits.continue")
        for id in [
            "benefits.confirm-segment", "benefits.confirm-rules", "benefits.confirm-complete",
        ] { confirm(id) }
        tap("benefits.continue")
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "benefits.verdict").firstMatch
                .waitForExistence(timeout: 10))
        capture("v2-benefits-preview-before-assertions")
        XCTAssertEqual(
            app.descendants(matching: .any).matching(identifier: "benefits.verdict").firstMatch
                .label, "Not verified")
        XCTAssertEqual(app.staticTexts["benefits.expected"].label, "USD 350")
        capture("v2-benefits-missing-statement-preview")
        tap("benefits.save-reviewed")
        XCTAssertTrue(app.navigationBars["Benefits result"].waitForExistence(timeout: 15))
        app.terminate()
        launch(reset: false)
        XCTAssertTrue(app.staticTexts["$2,000.00"].firstMatch.waitForExistence(timeout: 10))
        openBenefits()
        tap("benefits.record")
        tap("benefits.correct")
        tap("benefits.continue")
        tap("benefits.continue")
        let statement = app.switches["benefits.has-statement"].firstMatch
        scroll(statement)
        statement.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(statement.value as? String, "1")
        enter("benefits.statement-amount", "310.63")
        enter("benefits.statement-units", "35.5")
        confirm("benefits.statement-fund")
        tap("benefits.continue")
        enter("benefits.note", "SYNTHETIC later statement review")
        for id in [
            "benefits.confirm-segment", "benefits.confirm-rules", "benefits.confirm-complete",
            "benefits.confirm-statement",
        ] { confirm(id) }
        tap("benefits.continue")
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "benefits.verdict").firstMatch
                .waitForExistence(timeout: 10))
        XCTAssertEqual(
            app.descendants(matching: .any).matching(identifier: "benefits.verdict").firstMatch
                .label, "Possible benefits difference")
        capture("v2-benefits-corrected-preview")
        tap("benefits.save-reviewed")
        XCTAssertTrue(app.navigationBars["Benefits result"].waitForExistence(timeout: 15))
        let amount = app.descendants(matching: .any).matching(
            identifier: "benefits.amount-difference"
        ).firstMatch
        scroll(amount)
        XCTAssertTrue(
            amount.label.contains("39.37") || String(describing: amount.value).contains("39.37"))
        chooseRevision("Review 1")
        XCTAssertEqual(
            app.descendants(matching: .any).matching(identifier: "benefits.verdict").firstMatch
                .label, "Not verified")
        capture("v2-benefits-first-revision-preserved")
        chooseRevision("Review 2 · latest")
        let report = app.buttons["benefits.report"].firstMatch
        scroll(report)
        clearOfBottom(report, bottom: app.tabBars.firstMatch)
        report.tap()
        XCTAssertTrue(app.navigationBars["Prepare benefits report"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.switches["benefits.report-sources"].firstMatch.value as? String, "0")
        XCTAssertEqual(app.switches["benefits.report-note"].firstMatch.value as? String, "0")
        XCTAssertFalse(app.buttons["audit.share-report"].exists)
        capture("v2-benefits-private-report-options")
        tap("benefits.report-preview")
        XCTAssertTrue(app.buttons["audit.share-report"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["report.preview-warning"].exists)
        capture("v2-benefits-exact-report-preview")
    }

    func testLargestTextReviewKeepsOriginalAndRequiresFreshConfirmations() throws {
        XCUIDevice.shared.appearance = .dark
        launch(scenario: "benefits-review", largeText: true)
        openBenefits()
        tap("benefits.resume")
        capture("v2-benefits-large-fund")
        tap("benefits.continue")
        tap("benefits.continue")
        tap("benefits.draft-original")
        XCTAssertTrue(app.staticTexts["benefits.original-checked"].waitForExistence(timeout: 15))
        capture("v2-benefits-large-original")
        tap("benefits.source-done")
        tap("benefits.continue")
        tap("benefits.continue")
        XCTAssertFalse(app.buttons["benefits.save-reviewed"].exists)
        for id in [
            "benefits.confirm-segment", "benefits.confirm-rules", "benefits.confirm-complete",
            "benefits.confirm-statement",
        ] { confirm(id) }
        tap("benefits.continue")
        let expected = app.staticTexts["benefits.expected"].firstMatch
        scroll(expected)
        clearOfBottom(expected, bottom: app.buttons["benefits.save-reviewed"].firstMatch)
        XCTAssertEqual(expected.label, "USD 350")
        capture("v2-benefits-large-comparison")
        tap("benefits.save-reviewed")
        XCTAssertTrue(app.navigationBars["Benefits result"].waitForExistence(timeout: 15))
        let report = app.buttons["benefits.report"].firstMatch
        scroll(report)
        clearOfBottom(report, bottom: app.tabBars.firstMatch)
        report.tap()
        XCTAssertTrue(app.navigationBars["Prepare benefits report"].waitForExistence(timeout: 10))
        tap("benefits.report-preview")
        XCTAssertTrue(app.buttons["audit.share-report"].waitForExistence(timeout: 15))
        let pdf = app.descendants(matching: .any).matching(identifier: "report.pdf").firstMatch
        XCTAssertTrue(pdf.exists)
        XCTAssertGreaterThan(
            pdf.frame.height, 100, "The warning and actions must leave a usable PDF viewport")
        capture("v2-benefits-large-dark-report")
    }

    func testSavedCommaDraftReformatsForCurrentRegionWithoutChangingValues() throws {
        launch(scenario: "benefits-review-comma")
        openBenefits()
        tap("benefits.resume")
        let reformatted = app.staticTexts["benefits.format-notice"].firstMatch.waitForExistence(
            timeout: 10)
        if !reformatted { captureDiagnosticState("v2-benefits-comma-missing-conversion") }
        XCTAssertTrue(
            reformatted, "The saved comma draft must finish reformatting before continuing")
        capture("v2-benefits-comma-before-continue")
        tap("benefits.continue")
        capture("v2-benefits-comma-after-continue")
        let rulesStep = app.staticTexts["Step 2 of 4"].firstMatch.waitForExistence(timeout: 10)
        let segment = app.buttons["benefits.segment"].firstMatch.waitForExistence(timeout: 10)
        if !rulesStep || !segment {
            captureDiagnosticState("v2-benefits-comma-unexpected-rules-step")
        }
        XCTAssertTrue(rulesStep, "Continue must open the rules step after number-format conversion")
        XCTAssertTrue(segment, "The converted draft must keep its editable date/rate segment")
        tap("benefits.segment")
        let rate = app.textFields["benefits.rate"].firstMatch
        scroll(rate)
        XCTAssertEqual(rate.value as? String, "8.75")
        tap("benefits.segment-done")
        tap("benefits.continue")
        let amount = app.textFields["benefits.statement-amount"].firstMatch
        scroll(amount)
        XCTAssertEqual(amount.value as? String, "310.63")
        XCTAssertEqual(
            app.textFields["benefits.statement-units"].firstMatch.value as? String, "35.5")
        capture("v2-benefits-converted-number-format")
        app.terminate()
        launch(reset: false, scenario: "benefits-review-comma")
        openBenefits()
        tap("benefits.resume")
        tap("benefits.continue")
        tap("benefits.continue")
        let restored = app.textFields["benefits.statement-amount"].firstMatch
        scroll(restored)
        XCTAssertEqual(restored.value as? String, "310.63")
        XCTAssertFalse(app.buttons["benefits.save-reviewed"].exists)
    }

    private func chooseRevision(_ label: String) {
        let picker = app.descendants(matching: .any).matching(identifier: "benefits.revision")
            .firstMatch
        scroll(picker)
        clearOfBottom(picker, bottom: app.tabBars.firstMatch)
        picker.tap()
        let option = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", label)
        ).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 8))
        option.tap()
    }

    private func launch(reset: Bool = true, scenario: String = "benefits", largeText: Bool = false)
    {
        app = XCUIApplication()
        app.launchArguments =
            [
                "--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                "-UIPreferredContentSizeCategoryName",
                largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL",
            ] + (reset ? ["--reset-ui-state"] : [])
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = scenario
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    }

    private func openBenefits() {
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        tap("settings.benefits")
    }

    private func enter(_ id: String, _ value: String) {
        let field = app.textFields[id].firstMatch
        scroll(field)
        XCTAssertTrue(field.exists, "Missing input \(id)")
        field.tap()
        field.typeText(value)
        if let done = app.buttons.matching(identifier: "keyboard.done").allElementsBoundByIndex
            .first(where: {
                $0.isHittable
            })
        {
            done.tap()
        }
    }

    private func tap(_ id: String) {
        let button = app.buttons[id].firstMatch
        scroll(button)
        XCTAssertTrue(button.exists, "Missing action \(id)")
        if id == "benefits.draft-original" || id == "benefits.segment" {
            clearOfBottom(button, bottom: app.buttons["benefits.continue"].firstMatch)
        }
        if id == "benefits.report-preview" {
            let window = app.windows.element(boundBy: max(0, app.windows.count - 1))
            for _ in 0..<12 {
                if button.frame.minY >= 140 && button.frame.maxY <= window.frame.maxY - 48 { break }
                let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                let delta: CGFloat = button.frame.maxY > window.frame.maxY - 48 ? -120 : 120
                start.press(
                    forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)))
            }
            capture("v2-benefits-report-button-visible")
        }
        button.tap()
        if id == "benefits.report-preview" { capture("v2-benefits-report-after-preview-tap") }
    }

    private func confirm(_ id: String) {
        let button = app.buttons[id].firstMatch
        scroll(button)
        clearOfBottom(button, bottom: app.buttons["benefits.continue"].firstMatch)
        button.tap()
        XCTAssertEqual(button.value as? String, "Confirmed", "Review did not stay confirmed: \(id)")
    }

    private func scroll(_ element: XCUIElement) {
        _ = element.waitForExistence(timeout: 8)
        let window = app.windows.element(boundBy: max(0, app.windows.count - 1))
        for _ in 0..<30 {
            if element.exists && element.isHittable { return }
            if element.exists && element.frame.maxY < 140 {
                window.swipeDown()
            } else {
                window.swipeUp()
            }
        }
        for _ in 0..<30 {
            if element.exists && element.isHittable { return }
            window.swipeDown()
        }
    }

    private func clearOfBottom(_ element: XCUIElement, bottom: XCUIElement) {
        let window = app.windows.element(boundBy: max(0, app.windows.count - 1))
        for _ in 0..<20 {
            guard element.exists, bottom.exists else { return }
            if element.frame.minY > 140 && element.frame.maxY < bottom.frame.minY - 8 { return }
            let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            let delta: CGFloat = element.frame.minY <= 140 ? 160 : -160
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)))
        }
    }

    private func captureDiagnosticState(_ name: String) {
        capture(name)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "\(name)-accessibility"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
