import XCTest

@MainActor
final class PremiumComparisonJourneyTests: XCTestCase {
    private var app = XCUIApplication()
    func testExplicitReviewCorrectsPremiumOnlyBaseAndKeepsOriginalReceipt() throws {
        try reviewLegacy(large: false)
    }
    func testLargestTextPremiumReviewRetainsOriginalAcrossArchiveAndRelaunch() throws {
        try reviewLegacy(large: true)
    }

    private func reviewLegacy(large: Bool) throws {
        continueAfterFailure = false
        let source = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "native-assessment-v4", withExtension: "json"))
        let original = String(decoding: try Data(contentsOf: source), as: UTF8.self)
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = large ? .dark : .light
        app.launchArguments = [
            "--ui-testing", "--reset-ui-state", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName",
            large ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL",
        ]
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = "premium-legacy"
        app.launchEnvironment["LINEPAY_UI_PREMIUM_LEGACY"] = original
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Pay"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Pay"].tap()
        tap("pay.open-audit")
        XCTAssertTrue(app.staticTexts["Needs review"].firstMatch.waitForExistence(timeout: 10))
        tap("audit.recorded-comparison")
        let legacy = app.staticTexts["audit.legacy-weekly-scope"].firstMatch
        reveal(legacy)
        XCTAssertTrue(legacy.label.contains("Earlier premium-only comparison"))
        let old = app.buttons["audit.line.regularPay"].firstMatch
        reveal(old)
        XCTAssertTrue(old.label.contains("Expected $0.97"), old.label)
        capture("v2-premium-original-recorded-097", large: large)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("audit.correct")
        tap("paystub.correct-existing")
        let gross = app.textFields["paystub.inline.gross"].firstMatch
        reveal(gross)
        XCTAssertTrue(gross.waitForExistence(timeout: 10))
        XCTAssertEqual(gross.value as? String, "1.46")
        let compare = app.buttons["paystub.audit"].firstMatch
        reveal(compare)
        XCTAssertTrue(
            compare.isEnabled,
            "A correction of confirmed existing facts stays available without a new paid audit")
        capture("v2-premium-explicit-review", large: large)
        compare.tap()
        XCTAssertTrue(
            app.staticTexts["Compared values match"].firstMatch.waitForExistence(timeout: 15))
        let base = app.buttons["audit.line.regularPay"].firstMatch
        reveal(base)
        XCTAssertTrue(base.label.contains("Expected $0.98"), base.label)
        let premium = app.buttons["audit.line.overtimePay"].firstMatch
        reveal(premium)
        XCTAssertTrue(premium.label.contains("Expected $0.48"), premium.label)
        capture("v2-premium-current-base098-extra048", large: large)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("pay.finish-period")
        tap("period.confirm-close")
        app.tabBars.buttons["History"].tap()
        tap("history.period.75000000-0000-0000-0000-000000000001")
        tap("history.revision.74000000-0000-0000-0000-000000000001")
        let archived = app.buttons["audit.line.regularPay"].firstMatch
        reveal(archived)
        XCTAssertTrue(archived.label.contains("Expected $0.97"), archived.label)
        capture("v2-premium-archived-original-kept", large: large)
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        app.launchArguments.removeAll { $0 == "--reset-ui-state" }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 15))
        app.tabBars.buttons["History"].tap()
        tap("history.period.75000000-0000-0000-0000-000000000001")
        tap("history.revision.74000000-0000-0000-0000-000000000001")
        let reopened = app.buttons["audit.line.regularPay"].firstMatch
        reveal(reopened)
        XCTAssertTrue(reopened.label.contains("Expected $0.97"), reopened.label)
        capture("v2-premium-relaunched-original-kept", large: large)
    }
    private func tap(_ id: String) {
        let element = app.buttons[id].firstMatch
        reveal(element)
        XCTAssertTrue(element.isHittable, "Missing reachable action: \(id)")
        element.tap()
    }
    private func reveal(_ element: XCUIElement) {
        let window = app.windows.firstMatch
        for _ in 0..<24 {
            if element.exists && element.isHittable { return }
            let above = element.exists && element.frame.maxY < 120
            let searchEarlier = !element.exists && !true
            if above || searchEarlier { window.swipeDown() } else { window.swipeUp() }
        }
        if element.exists {
            print(
                "Synthetic UI reveal miss:", element.identifier, element.frame, window.frame,
                "hittable:", element.isHittable)
        }
    }
    private func capture(_ name: String, large: Bool) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name + (large ? "-large-dark" : "-light")
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
