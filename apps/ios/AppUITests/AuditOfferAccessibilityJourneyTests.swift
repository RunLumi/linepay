import XCTest

@MainActor
final class AuditOfferAccessibilityJourneyTests: XCTestCase {
    private var app = XCUIApplication()
    private var largeText = false

    func testStandardAuditKeepsPinnedOfferAndReadableResult() {
        auditJourney(largeText: false)
    }

    func testLargestTextDarkAuditKeepsResultScopeAndOfferReachable() {
        auditJourney(largeText: true)
    }

    private func auditJourney(largeText: Bool) {
        continueAfterFailure = false
        self.largeText = largeText
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = largeText ? .dark : .light
        app.launchArguments = [
            "--ui-testing", "--reset-ui-state", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName",
            largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL",
        ]
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = "shortfall"
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "1"
        app.launchEnvironment["LINEPAY_UI_STORE"] = "trial"
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        let pay = app.tabBars.buttons["Pay"]
        XCTAssertTrue(pay.waitForExistence(timeout: 10))
        pay.tap()
        let openResult = app.buttons["pay.open-audit"].firstMatch
        reveal(openResult)
        openResult.tap()
        XCTAssertTrue(app.navigationBars["Paycheck result"].waitForExistence(timeout: 10))

        let offer = app.buttons["audit.view-pro"].firstMatch
        if largeText {
            XCTAssertFalse(
                offer.exists && offer.isHittable,
                "The optional offer must not cover the first result page")
        } else {
            XCTAssertTrue(offer.waitForExistence(timeout: 10))
            XCTAssertTrue(offer.isHittable, "The standard-size offer must remain pinned")
        }
        let difference = app.descendants(matching: .any)
            .matching(identifier: "audit.difference").firstMatch
        reveal(difference)
        XCTAssertTrue(difference.label.contains("$50.00"))
        capture("audit-offer-\(variant)-result")

        let scope = app.staticTexts["audit.scope"].firstMatch
        reveal(scope)
        XCTAssertEqual(scope.label, "Compared: gross total")
        capture("audit-offer-\(variant)-scope")

        let limitations = app.buttons["Supported rules and limitations"].firstMatch
        reveal(limitations)
        limitations.tap()
        let supported = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Supported when configured:")
        ).firstMatch
        revealDisclosure(supported)
        capture("audit-offer-\(variant)-coverage")

        let report = app.buttons["audit.export"].firstMatch
        reveal(report)
        capture("audit-offer-\(variant)-report-action")
        report.tap()
        let reportSheet = app.navigationBars["Prepare report"].firstMatch
        XCTAssertTrue(reportSheet.waitForExistence(timeout: 10))
        reportSheet.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Paycheck result"].waitForExistence(timeout: 10))

        reveal(offer, isOffer: true)
        capture("audit-offer-\(variant)-offer")
        offer.tap()
        let dismiss = app.buttons["paywall.dismiss"].firstMatch
        XCTAssertTrue(dismiss.waitForExistence(timeout: 10))
        capture("audit-offer-\(variant)-pro-sheet")
        dismiss.tap()
        XCTAssertTrue(app.navigationBars["Paycheck result"].waitForExistence(timeout: 10))
    }

    private var variant: String { largeText ? "largest-dark" : "standard-light" }

    private func revealDisclosure(_ element: XCUIElement) {
        if !largeText {
            reveal(element)
            return
        }
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        XCTAssertTrue(element.label.hasPrefix("Supported when configured:"))
        XCTAssertTrue(element.label.hasSuffix("flat per diem."))
        let window = app.windows.firstMatch
        // A complete paragraph can be taller than the viewport at accessibility sizes.
        // Verify both ends are readable by scrolling; controls still require full visibility.
        for beginning in [true, false] {
            for _ in 0..<30 {
                let top = app.navigationBars.firstMatch.frame.maxY + 8
                let bottom = app.tabBars.firstMatch.frame.minY - 8
                let edge = beginning ? element.frame.minY : element.frame.maxY
                let lower = top + (beginning ? 0 : 80)
                let upper = bottom - (beginning ? 80 : 0)
                if element.isHittable, edge >= lower, edge <= upper { break }
                let delta = edge < lower ? min(180, lower - edge + 8) : -min(180, edge - upper + 8)
                let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
                start.press(
                    forDuration: 0.05,
                    thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)))
            }
            let edge = beginning ? element.frame.minY : element.frame.maxY
            XCTAssertTrue(element.isHittable)
            XCTAssertGreaterThanOrEqual(edge, app.navigationBars.firstMatch.frame.maxY + 8)
            XCTAssertLessThanOrEqual(edge, app.tabBars.firstMatch.frame.minY - 8)
            capture("audit-offer-\(variant)-coverage-\(beginning ? "beginning" : "ending")")
        }
    }

    private func reveal(_ element: XCUIElement, isOffer: Bool = false) {
        _ = element.waitForExistence(timeout: 10)
        let window = app.windows.firstMatch
        for _ in 0..<60 {
            let top = app.navigationBars.firstMatch.frame.maxY + 8
            var bottom = app.tabBars.firstMatch.frame.minY - 8
            let offer = app.buttons["audit.view-pro"].firstMatch
            if !largeText, !isOffer, offer.exists, offer.isHittable {
                bottom = min(bottom, offer.frame.minY - 8)
            }
            if element.exists, element.isHittable,
                element.frame.minY >= top, element.frame.maxY <= bottom
            {
                return
            }
            let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            let delta: CGFloat = element.exists && element.frame.minY < top ? 220 : -220
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)))
        }
        capture("audit-offer-\(variant)-unreachable")
        XCTFail("The audit content must remain fully readable and reachable: \(element)")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
