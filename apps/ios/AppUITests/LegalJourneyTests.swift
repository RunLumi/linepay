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
        let export = app.buttons["audit.export"].firstMatch
        scrollTo(export, maxSwipes: 24)
        let frontmost = app.windows.element(boundBy: max(0, app.windows.count - 1))
        let pinned = app.buttons["audit.view-pro"].firstMatch
        for _ in 0..<12 {
            let lowerEdge = pinned.exists ? pinned.frame.minY - 8 : frontmost.frame.maxY - 120
            if export.exists && export.frame.minY > 140 && export.frame.maxY < lowerEdge { break }
            let start = frontmost.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -160)))
        }
        XCTAssertTrue(export.isHittable)
        export.tap()
        XCTAssertTrue(app.navigationBars["Prepare report"].waitForExistence(timeout: 10))
        let preview = app.buttons["report.preview"].firstMatch
        let reportForm = app.scrollViews.firstMatch
        for _ in 0..<12 {
            if preview.exists && preview.isHittable { break }
            if reportForm.exists {
                reportForm.swipeUp()
            } else {
                app.windows.element(boundBy: max(0, app.windows.count - 1)).swipeUp()
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
        let filesLabel = NSPredicate(format: "label == %@", "Save to Files")
        var saveToFiles: XCUIElement?
        let window = app.windows.element(boundBy: max(0, app.windows.count - 1))
        for _ in 0..<12 {
            for surface in [app, springboard] {
                if let visible = surface.descendants(matching: .any).matching(filesLabel)
                    .allElementsBoundByIndex.first(where: { $0.isHittable })
                {
                    saveToFiles = visible
                    break
                }
            }
            if saveToFiles != nil { break }
            // The system activity list can inherit accessibility text size from its service.
            // Materialized offscreen cells are not tappable destinations; reveal the real row.
            let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
            start.press(
                forDuration: 0.05,
                thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
        }
        let filesAction = try XCTUnwrap(
            saveToFiles, "Save to Files never became visible in the system activity list")
        captureSystem("legal-system-share-sheet")
        let documentsApp = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        let saveInFiles = documentsApp.buttons["Save"].firstMatch
        let saveInShareSheet = app.buttons["Save"].firstMatch
        let saveInSpringboard = springboard.buttons["Save"].firstMatch
        filesAction.tap()
        let saveVisible =
            saveInFiles.waitForExistence(timeout: 15)
            || saveInShareSheet.waitForExistence(timeout: 15)
            || saveInSpringboard.waitForExistence(timeout: 15)
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

    func testEachRuleScopeKeepsItsPromisedEffectAtLargestText() throws {
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
            let scopeControl = app.buttons["pay-profile.change-scope"].firstMatch
            revealReviewElement(scopeControl, identifier: "pay-profile.change-scope", maxSwipes: 8)
            XCTAssertTrue(scopeControl.waitForExistence(timeout: 15))
            XCTAssertEqual(app.buttons.matching(identifier: "pay-profile.change-scope").count, 1)
            tapScopeControl(scopeControl)
            captureSystem("legal-menu-\(scopeID)")
            try chooseScope(label: scope, identifier: scopeID)
            XCTAssertTrue(
                scopeControl.waitForExistence(timeout: 5) && scopeControl.value as? String == scope,
                "Scope control did not commit the selected option: \(scope).")
            let explanation = app.descendants(matching: .any)
                .matching(identifier: "pay-profile.scope-explanation").firstMatch
            revealReviewElement(
                explanation, identifier: "pay-profile.scope-explanation", maxSwipes: 8)
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
    private func tapScopeControl(_ element: XCUIElement) {
        revealReviewElement(element, identifier: "pay-profile.change-scope", maxSwipes: 8)
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
        let top =
            app.navigationBars.allElementsBoundByIndex.max {
                $0.frame.width < $1.frame.width
            }?.frame.maxY ?? 0
        let save = app.buttons["pay-profile.save"].firstMatch
        XCTAssertTrue(save.exists)
        XCTAssertGreaterThanOrEqual(element.frame.minY + 0.001, top)
        XCTAssertLessThanOrEqual(element.frame.maxY, save.frame.minY + 0.001)
        captureSystem("legal-scope-fully-visible")
        element.tap()
    }

    private func chooseScope(label: String, identifier: String) throws {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let control = app.buttons["pay-profile.change-scope"].firstMatch
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
        throw XCTSkip("The hosted simulator did not expose the \(label) Menu option.")
    }
    private func scrollTo(_ element: XCUIElement, maxSwipes: Int = 16) {
        let frontmostWindow = app.windows.element(boundBy: max(0, app.windows.count - 1))
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            frontmostWindow.swipeUp()
        }
    }
    private func revealReviewElement(_ element: XCUIElement, identifier: String, maxSwipes: Int) {
        // The presenting Settings list and keyboard window remain in the AX tree. The
        // full-width collection is this sheet; its pinned Save covers the lower Form.
        let scroll =
            app.collectionViews.allElementsBoundByIndex.max {
                $0.frame.width < $1.frame.width
            } ?? app.scrollViews.firstMatch
        guard scroll.exists else {
            XCTFail("The foreground review Form is missing")
            return
        }
        let top =
            app.navigationBars.allElementsBoundByIndex.max {
                $0.frame.width < $1.frame.width
            }?.frame.maxY ?? 0
        let save = app.buttons["pay-profile.save"].firstMatch
        let bottom = save.exists ? save.frame.minY : app.frame.maxY
        let bounds = CGRect(x: 0, y: top, width: app.frame.width, height: max(1, bottom - top))
            .intersection(scroll.frame)
        guard bounds.height > 44, bounds.width > 44 else {
            XCTFail("The foreground review Form has no tappable content viewport")
            return
        }
        var stalled = 0
        // Short, overlapping pans stay inside the actual content rather than dragging
        // the footer or dismissing the sheet. The captured AX5 Form has nineteen pages.
        for _ in 0..<(maxSwipes * 3) {
            if element.exists, element.isHittable {
                let visible = element.frame.intersection(bounds)
                if (element.frame.minY + 0.001 >= bounds.minY
                    && element.frame.maxY <= bounds.maxY + 0.001)
                    || (element.frame.height > bounds.height && visible.height >= 44)
                {
                    return
                }
            }
            let before = reviewScrollProgress(scroll, within: bounds)
            let up = !element.exists || element.frame.minY >= bounds.minY
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let x = bounds.minX + min(12, bounds.width * 0.1)
            let startY = bounds.minY + bounds.height * (up ? 0.9 : 0.35)
            let endY = bounds.minY + bounds.height * (up ? 0.1 : 0.55)
            origin.withOffset(CGVector(dx: x, dy: startY)).press(
                forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: x, dy: endY)),
                withVelocity: .slow, thenHoldForDuration: 0.1)
            let after = reviewScrollProgress(scroll, within: bounds)
            stalled = !after.isEmpty && before == after ? stalled + 1 : 0
            if stalled >= 3 { break }
        }
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "legal-review-unreachable-" + identifier
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        captureSystem("legal-review-unreachable")
    }

    private func reviewScrollProgress(_ scroll: XCUIElement, within bounds: CGRect) -> String {
        let bar = scroll.otherElements.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Vertical scroll bar")
        ).allElementsBoundByIndex.last
        if let bar, bar.exists, let value = bar.value as? String { return value }
        return scroll.staticTexts.allElementsBoundByIndex.filter {
            $0.exists && $0.frame.intersects(bounds)
        }.prefix(3).map { "\($0.label):\(Int($0.frame.minY.rounded()))" }.joined(separator: "|")
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
