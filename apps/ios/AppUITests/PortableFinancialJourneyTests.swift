import XCTest

@MainActor
final class PortableFinancialJourneyTests: XCTestCase {
    private let app = XCUIApplication()
    private let password = "synthetic portable passphrase 2026"

    func testAndroidPendingFileImportsAdoptsAndExportsBothHistories() throws {
        continueAfterFailure = false
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(
                forResource: "portable-common-weekly-pending", withExtension: "json"))
        let json = try String(contentsOf: url, encoding: .utf8)
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp").terminate()
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = .light
        launch(scenario: "portable-pending", json: json)
        XCTAssertTrue(app.buttons["portable.open-evidence"].waitForExistence(timeout: 15))
        tap("backup.open")
        let filename = try exportPortable()
        tap("backup.done")
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        launch(scenario: "empty")
        tap("backup.open")
        tap("backup.restore")
        let picker = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        selectLocalRoot(picker)
        let file = app.cells.matching(NSPredicate(format: "label CONTAINS %@", filename)).firstMatch
        if !file.waitForExistence(timeout: 5), app.searchFields.firstMatch.exists {
            app.searchFields.firstMatch.tap()
            app.searchFields.firstMatch.typeText(filename)
        }
        XCTAssertTrue(
            file.waitForExistence(timeout: 15),
            "Previously exported canonical pending file must be selectable")
        file.tap()
        if picker.exists, picker.buttons["Open"].exists { picker.buttons["Open"].tap() }
        XCTAssertTrue(picker.waitForNonExistence(timeout: 15))
        enter("backup.unlock-password", password)
        tap("backup.unlock")
        let preview = app.staticTexts["backup.protection-status"].firstMatch
        reveal(preview)
        XCTAssertTrue(preview.label.contains("unlocked"))
        capture("portable-validated-replacement-preview")
        tap("backup.confirm-restore")
        tap("backup.perform-restore")
        let restoredAlert = app.alerts["Backup restore"]
        XCTAssertTrue(restoredAlert.waitForExistence(timeout: 15))
        restoredAlert.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["portable.open-evidence"].waitForExistence(timeout: 15))
        tap("portable.open-evidence")
        let pending = app.staticTexts["Weekly review remains pending"].firstMatch
        reveal(pending)
        XCTAssertTrue(pending.isHittable)
        capture("portable-original-pending-receipt")
        app.navigationBars.buttons.firstMatch.tap()
        tap("portable.configure-new-rules")
        for _ in 0..<3 { tap("pay-profile.continue") }
        for key in ["payRules", "scheduleAndPremiums", "rounding", "periodContext", "workFacts"] {
            tap("portable.confirm." + key)
        }
        capture("portable-new-native-material-confirmations")
        tap("pay-profile.save")
        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 15))
        app.tabBars.buttons["History"].tap()
        tap("history.imported-evidence")
        reveal(pending)
        XCTAssertTrue(
            pending.isHittable, "Adopting new native work must not clear original weekly review")
        capture("portable-adopted-original-still-pending")
        app.navigationBars.buttons.firstMatch.tap()
        app.tabBars.buttons["Settings"].tap()
        tap("backup.open")
        _ = try exportPortable()
        capture("portable-combined-export-saved-in-files")
    }

    func testActualAndroidWebProviderFileImportsAdoptsAndReexportsAllHistories() throws {
        continueAfterFailure = false
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp").terminate()
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = .light
        launch(scenario: "empty")
        tap("backup.open")
        tap("backup.restore")
        let picker = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        selectLocalRoot(picker)
        let filename = "portable-web-provider-a6471ac9.linepaybackup"
        let file = app.cells.matching(NSPredicate(format: "label CONTAINS %@", filename)).firstMatch
        if !file.waitForExistence(timeout: 5), app.searchFields.firstMatch.exists {
            app.searchFields.firstMatch.tap()
            app.searchFields.firstMatch.typeText(filename)
        }
        XCTAssertTrue(
            file.waitForExistence(timeout: 15),
            "The staged real Web download must be selected through Files")
        file.tap()
        if picker.exists, picker.buttons["Open"].exists { picker.buttons["Open"].tap() }
        XCTAssertTrue(picker.waitForNonExistence(timeout: 15))
        enter("backup.unlock-password", "Synthetic portable password 2026")
        tap("backup.unlock")
        let preview = app.staticTexts["backup.protection-status"].firstMatch
        reveal(preview)
        XCTAssertTrue(preview.label.contains("unlocked"))
        capture("portable-android-web-provider-validated-preview")
        tap("backup.confirm-restore")
        tap("backup.perform-restore")
        let restoredAlert = app.alerts["Backup restore"]
        XCTAssertTrue(restoredAlert.waitForExistence(timeout: 15))
        restoredAlert.buttons["OK"].tap()
        tap("portable.open-evidence")
        let pending = app.staticTexts["Weekly review remains pending"].firstMatch
        reveal(pending)
        XCTAssertTrue(pending.isHittable)
        capture("portable-android-web-original-pending")
        app.navigationBars.buttons.firstMatch.tap()
        tap("portable.configure-new-rules")
        for _ in 0..<3 { tap("pay-profile.continue") }
        for key in ["payRules", "scheduleAndPremiums", "rounding", "periodContext", "workFacts"] {
            tap("portable.confirm." + key)
        }
        capture("portable-android-web-ios-explicit-adoption")
        tap("pay-profile.save")
        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Pay"].tap()
        saveFreshEqualGrossCheck("1000")
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        launch(scenario: "empty", reset: false)
        app.tabBars.buttons["Pay"].tap()
        let nativeStatus = app.descendants(matching: .any).matching(identifier: "audit.status")
            .firstMatch
        XCTAssertTrue(nativeStatus.waitForExistence(timeout: 15))
        reveal(nativeStatus)
        XCTAssertTrue(
            nativeStatus.label.contains("Needs review"),
            "The newly saved equal-gross native check must retain inherited review scope after relaunch"
        )
        capture("portable-android-web-ios-fresh-native-check-persisted-needs-review")
        app.tabBars.buttons["History"].tap()
        tap("history.imported-evidence")
        reveal(pending)
        XCTAssertTrue(pending.isHittable)
        capture("portable-android-web-ios-original-still-pending")
        app.navigationBars.buttons.firstMatch.tap()
        app.tabBars.buttons["Settings"].tap()
        tap("backup.open")
        let savedFilename = try exportPortable()
        let saved = XCTAttachment(string: savedFilename)
        saved.name = "portable-cross-client-final-provider-filename"
        saved.lifetime = .keepAlways
        add(saved)
        capture("portable-android-web-ios-final-saved-in-files")
    }

    func testReadOnlyPendingEvidenceAtLargestTextDark() throws {
        continueAfterFailure = false
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(
                forResource: "portable-common-weekly-pending", withExtension: "json"))
        let json = try String(contentsOf: url, encoding: .utf8)
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIDevice.shared.appearance = .dark
        launch(
            scenario: "portable-pending", json: json,
            category: "UICTContentSizeCategoryAccessibilityXXXL")
        tap("portable.open-evidence")
        let pending = app.staticTexts["Weekly review remains pending"].firstMatch
        reveal(pending)
        XCTAssertTrue(pending.isHittable)
        capture("portable-dark-largest-original-pending")
    }

    private func launch(
        scenario: String, json: String? = nil, category: String = "UICTContentSizeCategoryL",
        reset: Bool = true
    ) {
        app.launchArguments = [
            "--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", category,
        ]
        if reset { app.launchArguments.append("--reset-ui-state") }
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = scenario
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.launchEnvironment["LINEPAY_UI_PORTABLE_STATE"] = json
        app.launch()
    }

    private func saveFreshEqualGrossCheck(_ amount: String) {
        tap("pay.check-paycheck")
        tap("paystub.manual")
        tap("paystub.confirm-dates")
        let gross = app.textFields["paystub.inline.gross"].firstMatch
        XCTAssertTrue(gross.waitForExistence(timeout: 10))
        gross.tap()
        gross.typeText(amount)
        if let done = app.buttons.matching(identifier: "keyboard.done").allElementsBoundByIndex
            .first(where: { $0.isHittable })
        {
            done.tap()
        }
        let complete = app.descendants(matching: .any).matching(identifier: "paystub.complete-work")
            .firstMatch
        revealAboveAuditAction(complete)
        complete.tap()
        XCTAssertTrue(complete.isSelected)
        let basis = app.buttons["paystub.gross-basis.wagesOnly"].firstMatch
        revealAboveAuditAction(basis)
        basis.tap()
        capture("portable-android-web-ios-fresh-equal-gross-facts")
        tap("paystub.audit")
        let status = app.descendants(matching: .any).matching(identifier: "audit.status").firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 15))
        reveal(status)
        XCTAssertTrue(
            status.label.contains("Needs review"), "Equal gross cannot waive inherited weekly scope"
        )
        XCTAssertFalse(
            app.staticTexts["No difference within compared items: gross total only"].firstMatch
                .exists)
        capture("portable-android-web-ios-fresh-equal-gross-needs-review")
    }

    private func revealAboveAuditAction(_ element: XCUIElement) {
        let window =
            app.windows.allElementsBoundByIndex.max {
                $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height
            } ?? app.windows.firstMatch
        let action = app.buttons["paystub.audit"].firstMatch
        for _ in 0..<24 {
            if element.exists, element.isHittable, element.frame.minY > 120,
                element.frame.maxY < action.frame.minY - 8
            {
                return
            }
            let point = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            let delta: CGFloat = element.exists && element.frame.minY < 120 ? 180 : -180
            point.press(forDuration: 0.05, thenDragTo: point.withOffset(CGVector(dx: 0, dy: delta)))
        }
        XCTAssertTrue(element.isHittable)
        XCTAssertLessThan(element.frame.maxY, action.frame.minY)
    }

    private func exportPortable() throws -> String {
        tap("backup.protect")
        enter("backup.password", password)
        enter("backup.password-confirm", password)
        tap("backup.password-kept")
        tap("portable.export")
        tap("backup.choose-location")
        let picker = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 20))
        let filenameField = app.textFields.matching(
            NSPredicate(format: "value BEGINSWITH %@", "LinePaycheck-")
        ).firstMatch
        XCTAssertTrue(filenameField.waitForExistence(timeout: 10))
        let filename = try XCTUnwrap(filenameField.value as? String)
        selectLocalRoot(picker)
        let save = picker.buttons["Move"].exists ? picker.buttons["Move"] : picker.buttons["Save"]
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 15))
        let status = app.staticTexts["backup.status"].firstMatch
        reveal(status)
        XCTAssertTrue(status.label.contains("Saved to your selected location"), status.label)
        let saved = XCTAttachment(string: filename)
        saved.name = "portable-saved-provider-filename"
        saved.lifetime = .keepAlways
        add(saved)
        return filename
    }
    private func selectLocalRoot(_ picker: XCUIElement) {
        if !picker.staticTexts["On My iPhone"].exists {
            if picker.buttons["Browse"].exists { picker.buttons["Browse"].tap() }
            let local = app.staticTexts["On My iPhone"].firstMatch
            XCTAssertTrue(local.waitForExistence(timeout: 10))
            local.tap()
        }
        XCTAssertTrue(picker.staticTexts["On My iPhone"].waitForExistence(timeout: 10))
    }
    private func enter(_ id: String, _ text: String) {
        let field = app.secureTextFields[id].firstMatch
        reveal(field)
        XCTAssertTrue(field.isHittable)
        field.tap()
        field.typeText(text)
        if let done = app.buttons.matching(identifier: "keyboard.done").allElementsBoundByIndex
            .first(where: { $0.isHittable })
        {
            done.tap()
        }
    }
    private func tap(_ id: String) {
        let item = app.buttons[id].firstMatch
        if ![
            "backup.done", "pay-profile.continue", "pay-profile.save", "backup.choose-location",
            "backup.perform-restore",
        ].contains(id) {
            reveal(item)
        }
        if !item.isHittable { capture("portable-missing-action-" + id) }
        XCTAssertTrue(item.isHittable, "Missing action: " + id)
        item.tap()
    }
    private func reveal(_ element: XCUIElement) {
        let window =
            app.windows.allElementsBoundByIndex.max {
                $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height
            } ?? app.windows.firstMatch
        for _ in 0..<30 {
            if element.exists, element.isHittable, element.frame.minY > 100,
                element.frame.maxY < window.frame.maxY - 40
            {
                return
            }
            if element.exists, element.frame.height > 0, element.frame.minY < 100 {
                window.swipeDown()
            } else {
                window.swipeUp()
            }
        }
    }
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
