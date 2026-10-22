import XCTest

@MainActor
final class EditorDynamicTypeJourneyTests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        continueAfterFailure = false
    }

    func testWorkEditScalesBeyondAX2AndSavesAtAX5() {
        launch(size: "AccessibilityL")
        openWork()
        let smallerHeight = fieldHeight("work.note")
        launch(size: "AccessibilityXXXL")
        openWork()
        assertExpandedField("work.note", beyond: smallerHeight)
        replaceField("work.note", with: "AX5 work note")
        capture("work-editor-ax5")
        tap("work.save")
        assertSavedNote("AX5 work note")
        launch(size: "AccessibilityXXXL", reset: false)
        assertSavedNote("AX5 work note")
    }

    func testRepeatEditScalesBeyondAX2AndSavesAtAX5() {
        launch(size: "AccessibilityL")
        openRepeat()
        let smallerHeight = fieldHeight("repeat.note")
        launch(size: "AccessibilityXXXL")
        openRepeat()
        assertExpandedField("repeat.note", beyond: smallerHeight)
        replaceField("repeat.note", with: "AX5 repeat note")
        capture("repeat-editor-ax5")
        tap("repeat.save")
        assertSavedNote("AX5 repeat note")
        launch(size: "AccessibilityXXXL", reset: false)
        assertSavedNote("AX5 repeat note")
    }

    func testProfileEditScalesBeyondAX2AndSavesAtAX5() {
        launch(size: "AccessibilityL")
        openProfile()
        let smallerHeight = fieldHeight("pay-profile.name")
        launch(size: "AccessibilityXXXL")
        openProfile()
        let timezone = app.buttons["pay-profile.selected-timezone"].firstMatch
        reveal(timezone, identifier: "pay-profile.selected-timezone")
        XCTAssertEqual(timezone.value as? String, "Central Time (Chicago)")
        capture("profile-timezone-full-label-ax5")
        assertExpandedField("pay-profile.name", beyond: smallerHeight)
        replaceField("pay-profile.name", with: "AX5 Profile")
        capture("profile-editor-ax5")
        let step = app.staticTexts["pay-profile.step-indicator"].firstMatch
        for expected in ["Step 2 of 4", "Step 3 of 4", "Step 4 of 4"] {
            tap("pay-profile.continue")
            let reached = expectation(
                for: NSPredicate(format: "label == %@", expected), evaluatedWith: step)
            wait(for: [reached], timeout: 10)
        }
        tap("pay-profile.save")
        let alert = app.alerts["Review rule change"].firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        let confirm = alert.buttons["pay-profile.confirm-change"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertTrue(confirm.isHittable)
        XCTAssertGreaterThanOrEqual(confirm.frame.minY + 0.001, alert.frame.minY)
        XCTAssertLessThanOrEqual(confirm.frame.maxY, alert.frame.maxY + 0.001)
        capture("profile-required-confirmation-ax5")
        confirm.tap()
        launch(size: "AccessibilityXXXL", reset: false)
        app.tabBars.buttons["Settings"].tap()
        let profile = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "AX5 Profile")
        ).firstMatch
        reveal(profile, identifier: "saved-profile-name")
        XCTAssertTrue(profile.exists, "The explicitly saved future profile must survive relaunch")
    }

    func testPaystubEditScalesBeyondAX2AndSavesAtAX5() {
        launch(size: "AccessibilityL")
        openPaystub()
        let smallerHeight = fieldHeight("paystub.inline.gross")
        launch(size: "AccessibilityXXXL")
        openPaystub()
        assertExpandedField("paystub.inline.gross", beyond: smallerHeight)
        replaceField("paystub.inline.gross", with: "543.21")
        let complete = app.descendants(matching: .any)
            .matching(identifier: "paystub.complete-work").firstMatch
        reveal(complete, identifier: "paystub.complete-work")
        complete.tap()
        XCTAssertTrue(complete.isSelected)
        tap("paystub.gross-basis.wagesOnly")
        XCTAssertEqual(app.buttons["paystub.audit"].label, "Compare with expected pay")
        capture("paystub-editor-ax5")
        tap("paystub.audit")
        launch(size: "AccessibilityXXXL", reset: false)
        app.tabBars.buttons["Pay"].tap()
        // LabeledContent exposes the semantic subject together with its value. A standalone
        // amount query also loses the distinction between expected wages and paid gross.
        let gross = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label == %@ OR (label == %@ AND value == %@)",
                "Paystub gross, $543.21", "Paystub gross", "$543.21")
        ).firstMatch
        reveal(gross, identifier: "saved-paystub-gross")
        XCTAssertTrue(gross.exists, "The edited paycheck amount must survive relaunch")
        print("Saved paycheck gross label=\(gross.label), value=\(String(describing: gross.value))")
        let evidence = XCTAttachment(string: gross.debugDescription + "\n" + app.debugDescription)
        evidence.name = "saved-paystub-gross-semantics-ax5"
        evidence.lifetime = .keepAlways
        add(evidence)
        if gross.label == "Paystub gross" {
            XCTAssertEqual(gross.value as? String, "$543.21")
        } else {
            XCTAssertEqual(gross.label, "Paystub gross, $543.21")
        }
        capture("saved-paystub-gross-ax5")
    }

    private func launch(size: String, reset: Bool = true) {
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = .dark
        app.launchArguments = [
            "--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory" + size,
        ]
        if reset { app.launchArguments.append("--reset-ui-state") }
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = "work"
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 20))
    }

    private func openWork() { tap("today.edit-work") }

    private func openRepeat() {
        tap("today.repeat-shift")
        tap("repeat.edit-details")
    }

    private func openProfile() {
        app.tabBars.buttons["Settings"].tap()
        tap("settings.edit-rules")
    }

    private func openPaystub() {
        app.tabBars.buttons["Pay"].tap()
        tap("pay.check-paycheck")
        tap("paystub.manual")
        XCTAssertTrue(app.navigationBars["Review paystub"].waitForExistence(timeout: 10))
        tap("paystub.confirm-dates")
    }

    // Comparing the same native text field at AX2 and AX5 catches an editor-wide AX2 cap:
    // control existence or a large enclosing row alone cannot prove its text actually grew.
    private func fieldHeight(_ id: String) -> CGFloat {
        let field = app.descendants(matching: .any).matching(identifier: id).firstMatch
        reveal(field, identifier: id)
        XCTAssertTrue(field.exists, "Missing text field \(id)")
        return field.frame.height
    }

    private func assertExpandedField(_ id: String, beyond smallerHeight: CGFloat) {
        XCTAssertGreaterThan(smallerHeight, 0)
        XCTAssertGreaterThan(
            fieldHeight(id), smallerHeight * 1.15,
            "AX5 must enlarge the editable text beyond AX2, rather than silently cap it")
    }

    private func replaceField(_ id: String, with text: String) {
        let field = app.descendants(matching: .any).matching(identifier: id).firstMatch
        reveal(field, identifier: id)
        field.tap()
        if id == "repeat.note" || id == "work.note" {
            // The real two-line note ends in "shift" on its last line. Tapping the right
            // of that line places the caret after all text; the midpoint only reaches the
            // first line. The actual word-selection menu does not offer Select All.
            let original = field.value as? String ?? ""
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.85)).tap()
            capture("native-note-end-caret-" + id)
            field.typeText(
                String(repeating: XCUIKeyboardKey.delete.rawValue, count: original.count))
        } else if id == "pay-profile.name" {
            // The retained full-run video shows a focused end caret, but Command-A did
            // not select the name: Delete removed only the final character. Use that
            // native caret with the exact known fixture value, without a deletion retry.
            let original = field.value as? String ?? ""
            XCTAssertEqual(original, "SAMPLE - synthetic work")
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.85)).tap()
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "native-profile-end-caret-hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            capture("native-profile-end-caret")
            field.typeText(
                String(repeating: XCUIKeyboardKey.delete.rawValue, count: original.utf16.count))
        } else {
            field.typeKey("a", modifierFlags: .command)
            field.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        let cleared = field.value as? String ?? ""
        XCTAssertTrue(
            cleared.isEmpty || cleared == field.placeholderValue,
            "Selecting and deleting must clear the original input before typing its replacement")
        field.typeText(text)
        if app.buttons["keyboard.done"].firstMatch.exists {
            app.buttons["keyboard.done"].firstMatch.tap()
        }
        XCTAssertEqual(field.value as? String, text)
    }

    private func assertSavedNote(_ note: String) {
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", note)).firstMatch
        reveal(row, identifier: "saved-work-note", minimumVisibleHeight: 44)
        XCTAssertTrue(row.exists, "Saved work must retain the edited note")
        XCTAssertTrue(row.label.contains(note))
        print(
            "Saved note row: \(row.frame); viewport: \(contentBounds(excluding: "saved-work-note"))"
        )
    }

    private func tap(_ id: String) {
        let button = app.buttons[id].firstMatch
        reveal(button, identifier: id)
        XCTAssertTrue(button.isHittable, "Control is not reachable: \(id)")
        button.tap()
    }

    private func reveal(
        _ element: XCUIElement, identifier: String, minimumVisibleHeight: CGFloat? = nil
    ) {
        _ = element.waitForExistence(timeout: 5)
        var previousProgress: String?
        var stalledPans = 0
        for _ in 0..<24 {
            if visible(element, identifier: identifier, minimumHeight: minimumVisibleHeight) {
                return
            }
            let bounds = contentBounds(excluding: identifier)
            let scroll = foregroundScroll()
            let before = scrollProgress(scroll, within: bounds)
            print(
                "Reveal \(identifier): exists=\(element.exists), bounds=\(bounds), scroll=\(scroll.frame), progress=\(before)"
            )
            if element.exists {
                print("Target frame=\(element.frame), hittable=\(element.isHittable)")
            }
            // Only a materialized frame proves that the target is above us. Searching for
            // unknown content never blindly reverses into the sheet-dismissal gesture.
            let up = !element.exists || element.frame.minY >= bounds.minY
            dragContent(up: up, within: bounds, scroll: scroll)
            let after = scrollProgress(scroll, within: bounds)
            if !after.isEmpty && (after == before || after == previousProgress) {
                stalledPans += 1
                if stalledPans >= 3 { break }
            } else {
                stalledPans = 0
            }
            previousProgress = after
        }
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "editor-unreachable-" + identifier
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        capture("editor-unreachable-" + identifier)
        XCTFail("Element is not reachable in the foreground editor: \(identifier)")
    }

    private func visible(
        _ element: XCUIElement, identifier: String, minimumHeight: CGFloat?
    ) -> Bool {
        guard element.exists, element.isHittable else { return false }
        let bounds = contentBounds(excluding: identifier)
        if let minimumHeight, element.frame.height > bounds.height {
            // A saved AX5 work row can exceed a viewport. Its complete accessible label and
            // a comfortably tappable visible portion prove access without shrinking its text.
            let intersection = element.frame.intersection(bounds)
            return intersection.height >= minimumHeight && intersection.width >= 44
        }
        // AX reported an otherwise exact viewport edge as 769.0000000000001 rather than
        // 769. This subpixel tolerance covers numeric representation, not visible clipping.
        return element.frame.minY + 0.001 >= bounds.minY
            && element.frame.maxY <= bounds.maxY + 0.001
    }

    private func foregroundScroll() -> XCUIElement {
        // The presenting screen is scaled/inset behind the full-width sheet. Query order
        // is not front-to-back: its last collection was the background Pay screen.
        app.collectionViews.allElementsBoundByIndex.max { $0.frame.width < $1.frame.width }
            ?? app.scrollViews.firstMatch
    }

    private func scrollProgress(_ scroll: XCUIElement, within bounds: CGRect) -> String {
        let bar = scroll.otherElements.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Vertical scroll bar")
        ).allElementsBoundByIndex.last
        if let bar, bar.exists, let value = bar.value as? String { return value }
        return scroll.staticTexts.allElementsBoundByIndex.filter {
            $0.exists && $0.frame.intersects(bounds)
        }.prefix(3).map { "\($0.label):\(Int($0.frame.minY.rounded()))" }.joined(separator: "|")
    }

    private func contentBounds(excluding identifier: String) -> CGRect {
        // A sheet leaves its presenting tab/navigation bars in the AX tree. Only its front
        // navigation bar and an actually hittable tab bar bound this editor's content.
        let top =
            app.navigationBars.allElementsBoundByIndex.max {
                $0.frame.width < $1.frame.width
            }?.frame.maxY ?? 0
        var bottom =
            app.tabBars.firstMatch.exists && app.tabBars.firstMatch.isHittable
            ? app.tabBars.firstMatch.frame.minY : app.frame.maxY
        for id in [
            "work.save", "repeat.save", "pay-profile.continue", "pay-profile.save", "paystub.audit",
        ]
        where id != identifier {
            let action = app.buttons[id].firstMatch
            // Disabled actions still cover the scroll view; the gross field starts below the
            // fold even before the worker has confirmed enough facts to enable Save.
            if action.exists { bottom = min(bottom, action.frame.minY) }
        }
        return CGRect(x: 0, y: top, width: app.frame.width, height: max(1, bottom - top))
    }

    private func dragContent(up: Bool, within bounds: CGRect, scroll: XCUIElement) {
        XCTAssertTrue(scroll.exists)
        let viewport = bounds.intersection(scroll.frame)
        XCTAssertGreaterThan(viewport.height, 44)
        // Stay in the collection's leading gutter, outside text fields/date controls. A
        // downward correction is deliberately small so it cannot fling past the list top.
        let lower = viewport.minY + viewport.height * (up ? 0.8 : 0.55)
        let upper = viewport.minY + viewport.height * (up ? 0.25 : 0.35)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let x = viewport.minX + min(12, viewport.width * 0.1)
        let start = origin.withOffset(CGVector(dx: x, dy: up ? lower : upper))
        let end = origin.withOffset(CGVector(dx: x, dy: up ? upper : lower))
        start.press(
            forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
