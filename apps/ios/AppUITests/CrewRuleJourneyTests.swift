import XCTest

@MainActor
final class CrewRuleJourneyTests: XCTestCase {
    private var app = XCUIApplication()
    func testRealFilesDraftOmissionAndFutureAdoptionKeepCurrentPaycheck() throws {
        try exchange(large: false)
    }
    func testLargestTextFilesAdoptionKeepsReviewAndCurrentHistoryReachable() throws {
        // Full local file exchange plus consent, editor and relaunch at maximum text size
        // legitimately traverses many more screens; preserve the whole journey under one budget.
        executionTimeAllowance = 900
        try exchange(large: true)
    }
    private func exchange(large: Bool) throws {
        continueAfterFailure = false
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp").terminate()
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = large ? .dark : .light
        app.launchArguments = [
            "--ui-testing", "--reset-ui-state", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName",
            large ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL",
        ]
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = "matches"
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        tap("settings.crew-rules")
        let title = app.textFields["crew-rules.title"].firstMatch
        reveal(title)
        let marker = "A-SYNTHETIC-CREW-" + String(UUID().uuidString.prefix(8))
        title.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        title.typeText(" " + marker)
        XCTAssertTrue((title.value as? String)?.contains(marker) == true)
        dismissKeyboard()
        let include = app.switches["crew-rules.include-amounts"].firstMatch
        reveal(include)
        XCTAssertEqual(include.value as? String, "0")
        XCTAssertFalse(app.buttons["crew-rules.export"].exists)
        toggle("crew-rules.rights")
        tap("crew-rules.review-export")
        let omitted = app.staticTexts["Sender hourly amount: omitted; enter your own"].firstMatch
        reveal(omitted)
        XCTAssertTrue(omitted.exists)
        capture("v2-crew-reviewed-default-omission", large: large)
        toggle("crew-rules.include-amounts", searchingDown: false)
        XCTAssertFalse(
            app.buttons["crew-rules.export"].exists,
            "A material edit invalidates the earlier file review")
        toggle("crew-rules.include-amounts", searchingDown: false)
        let rights = app.switches["crew-rules.rights"].firstMatch
        reveal(rights)
        XCTAssertEqual(rights.value as? String, "0")
        toggle("crew-rules.rights")
        tap("crew-rules.review-export")
        tap("crew-rules.export")
        let picker = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 20))
        let filename = app.textFields.firstMatch
        XCTAssertTrue(filename.waitForExistence(timeout: 10))
        let oldName = try XCTUnwrap(filename.value as? String)
        XCTAssertTrue(oldName.hasPrefix("Crew rules"), oldName)
        filename.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldName.count))
        filename.typeText(marker)
        let editedName = try XCTUnwrap(filename.value as? String)
        XCTAssertTrue(editedName.contains(marker), editedName)
        if !picker.staticTexts["On My iPhone"].exists {
            if picker.buttons["Browse"].exists { picker.buttons["Browse"].tap() }
            let local = app.staticTexts["On My iPhone"].firstMatch
            XCTAssertTrue(local.waitForExistence(timeout: 10))
            local.tap()
        }
        XCTAssertTrue(picker.staticTexts["On My iPhone"].waitForExistence(timeout: 10))
        capture("v2-crew-local-files-destination", large: large)
        let save = picker.buttons["Move"].exists ? picker.buttons["Move"] : picker.buttons["Save"]
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 15))
        let message = app.descendants(matching: .any).matching(identifier: "crew-rules.message")
            .firstMatch
        reveal(message)
        XCTAssertTrue(message.exists)
        XCTAssertTrue(message.label.contains("Saved to the selected location"), message.label)
        tap("crew-rules.choose-file")
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        let localRoot = picker.staticTexts["On My iPhone"].firstMatch
        if !localRoot.waitForExistence(timeout: 2) {
            let browseBack = picker.buttons["Browse"].firstMatch
            if browseBack.isHittable { browseBack.tap() }
        }
        if !localRoot.exists {
            let browseTab = app.tabBars.buttons["Browse"].firstMatch
            XCTAssertTrue(browseTab.waitForExistence(timeout: 10))
            if !browseTab.isSelected { browseTab.tap() }
            let localLocation = app.cells.matching(
                identifier: "DOC.sidebar.item.On My iPhone"
            ).firstMatch
            let browseView = app.descendants(matching: .any).matching(
                NSPredicate(
                    format: "identifier == %@ OR identifier == %@",
                    "Browse View", "Browse View (Picker)")
            ).firstMatch
            for _ in 0..<5 where !localLocation.isHittable {
                XCTAssertTrue(browseView.waitForExistence(timeout: 5))
                browseView.swipeDown()
            }
            XCTAssertTrue(localLocation.isHittable, "Scroll Browse to the On My iPhone location")
            localLocation.tap()
        }
        XCTAssertTrue(localRoot.waitForExistence(timeout: 10))
        let fileList = app.collectionViews.matching(identifier: "File View").firstMatch
        let file = fileList.cells.matching(
            NSPredicate(format: "identifier CONTAINS %@ OR label CONTAINS %@", marker, marker)
        ).firstMatch
        // Files virtualizes rows at large text sizes; reach the actual saved file rather than
        // assuming every cell is already represented in the accessibility tree.
        for _ in 0..<20 where !file.exists || !file.isHittable {
            fileList.swipeUp()
        }
        if !file.waitForExistence(timeout: 10) {
            capture("v2-crew-local-root-file-missing", large: large)
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "crew-files-local-root-before-search"
            tree.lifetime = .keepAlways
            add(tree)
            capture("v2-crew-import-file-missing", large: large)
            let finalTree = XCTAttachment(string: app.debugDescription)
            finalTree.name = "synthetic-crew-files-hierarchy"
            finalTree.lifetime = .keepAlways
            add(finalTree)
        }
        XCTAssertTrue(file.exists, "Wait for the saved local draft to appear")
        XCTAssertTrue(file.label.contains("\(marker).linepayrules"), file.label)
        XCTAssertTrue(file.isHittable, "Select the actual locally exported synthetic draft")
        XCTAssertTrue(file.isEnabled)
        file.tap()
        if picker.exists, picker.buttons["Open"].exists { picker.buttons["Open"].tap() }
        XCTAssertTrue(picker.waitForNonExistence(timeout: 15))
        reveal(message)
        XCTAssertTrue(message.exists)
        XCTAssertTrue(message.label.contains("Draft inspected"), message.label)
        let rate = app.textFields["crew-rules.hourly-rate"].firstMatch
        reveal(rate)
        XCTAssertTrue(rate.waitForExistence(timeout: 15))
        XCTAssertTrue((rate.value as? String) == "Amount" || (rate.value as? String) == "")
        toggle("crew-rules.confirm-applicability")
        toggle("crew-rules.confirm-values")
        tap("crew-rules.prepare-setup")
        reveal(message)
        XCTAssertTrue(
            message.label.contains("could not be prepared"),
            "An omitted recipient rate cannot become zero")
        reveal(rate, searchingDown: false)
        rate.tap()
        rate.typeText("75")
        dismissKeyboard()
        let prepare = app.buttons["crew-rules.prepare-setup"].firstMatch
        reveal(prepare)
        XCTAssertFalse(prepare.isEnabled, "Changing the recipient amount invalidates both reviews")
        toggle("crew-rules.confirm-applicability", searchingDown: false)
        toggle("crew-rules.confirm-values")
        capture("v2-crew-own-values-reviewed", large: large)
        tap("crew-rules.prepare-setup")
        let step = app.staticTexts["pay-profile.step-indicator"].firstMatch
        XCTAssertTrue(step.waitForExistence(timeout: 10))
        for target in 2...4 {
            tap("pay-profile.continue")
            let advanced = NSPredicate(format: "label == %@", "Step \(target) of 4")
            XCTAssertTrue(step.waitForExistence(timeout: 8))
            expectation(for: advanced, evaluatedWith: step)
            waitForExpectations(timeout: 10)
        }
        let scope = app.descendants(matching: .any).matching(identifier: "pay-profile.fixed-scope")
            .firstMatch
        reveal(scope)
        XCTAssertEqual(scope.value as? String, "Future work periods only")
        XCTAssertFalse(app.buttons["pay-profile.change-scope"].exists)
        XCTAssertFalse(app.buttons["pay-profile.scope.current"].exists)
        XCTAssertFalse(app.buttons["pay-profile.scope.dated"].exists)
        tap("pay-profile.save")
        tap("pay-profile.confirm-change")
        XCTAssertTrue(app.navigationBars["Crew rule drafts"].waitForExistence(timeout: 15))
        let retained = app.staticTexts["Worker-confirmed rate: $75.00/hour"].firstMatch
        reveal(retained)
        XCTAssertTrue(retained.exists)
        capture("v2-crew-retained-own-rule-choice", large: large)
        app.tabBars.buttons["Pay"].tap()
        tap("pay.open-audit")
        XCTAssertTrue(
            app.staticTexts["No difference within compared items: gross total only"].firstMatch
                .waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["$550.00"].firstMatch.exists)
        capture("v2-crew-existing-paycheck-stays-550", large: large)
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        app.launchArguments.removeAll { $0 == "--reset-ui-state" }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Pay"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Pay"].tap()
        tap("pay.open-audit")
        XCTAssertTrue(
            app.staticTexts["No difference within compared items: gross total only"].firstMatch
                .waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["$550.00"].firstMatch.exists)
        capture("v2-crew-relaunch-retains-current-paycheck", large: large)
        app.tabBars.buttons["Settings"].tap()
        tap("settings.crew-rules")
        let restoredRate = app.staticTexts["Worker-confirmed rate: $75.00/hour"].firstMatch
        reveal(restoredRate)
        XCTAssertTrue(restoredRate.exists)
        capture("v2-crew-relaunch-retains-own-rate-reference", large: large)
    }
    private func tap(_ id: String) {
        let element = app.buttons[id].firstMatch
        reveal(element)
        XCTAssertTrue(element.isHittable, "Missing reachable action: \(id)")
        XCTAssertTrue(element.isEnabled, "Action requires its visible prerequisites: \(id)")
        element.tap()
    }
    private func toggle(_ id: String, searchingDown: Bool = true) {
        let element = app.switches[id].firstMatch
        reveal(element, searchingDown: searchingDown)
        let window = app.windows.firstMatch
        for _ in 0..<12 {
            let top = max(120, app.navigationBars.firstMatch.frame.maxY + 8)
            let bottom =
                app.tabBars.firstMatch.isHittable
                ? app.tabBars.firstMatch.frame.minY - 8 : window.frame.maxY - 40
            let middle = element.frame.midY
            if middle >= top + 22 && middle <= bottom - 22 && element.isHittable { break }
            let distance =
                middle < top + 22
                ? min(300, top + 44 - middle) : -min(300, middle - bottom + 44)
            let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            start.press(
                forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
        }
        print("Synthetic switch target:", id, element.frame, window.frame)
        XCTAssertTrue(element.isHittable, "Missing reachable review: \(id)")
        let before = element.value as? String
        XCTAssertTrue(before == "0" || before == "1")
        let nativeSwitch = element.switches.firstMatch
        (nativeSwitch.exists ? nativeSwitch : element).tap()
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", before == "1" ? "0" : "1"),
            object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)

    }
    private func reveal(_ element: XCUIElement, searchingDown: Bool = true) {
        let window = app.windows.firstMatch
        for _ in 0..<24 {
            if element.exists && element.isHittable { return }
            let above = element.exists && element.frame.maxY < 120
            let searchEarlier = !element.exists && !searchingDown
            if above || searchEarlier { window.swipeDown() } else { window.swipeUp() }
        }
        if element.exists {
            print(
                "Synthetic UI reveal miss:", element.identifier, element.frame, window.frame,
                "hittable:", element.isHittable)
        }
    }
    private func dismissKeyboard() {
        if let done = app.buttons.matching(identifier: "keyboard.done").allElementsBoundByIndex
            .first(where: { $0.isHittable })
        {
            done.tap()
        }
    }
    private func capture(_ name: String, large: Bool) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name + (large ? "-large-dark" : "-light")
        shot.lifetime = .keepAlways
        add(shot)
    }
}
