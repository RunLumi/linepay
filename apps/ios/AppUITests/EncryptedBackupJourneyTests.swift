import XCTest

@MainActor
final class EncryptedBackupJourneyTests: XCTestCase {
    private var app = XCUIApplication()
    private func fixturePhrase() throws -> String {
        let url = try XCTUnwrap(
            Bundle(for: EncryptedBackupJourneyTests.self).url(
                forResource: "encryption-v1", withExtension: "json"))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try XCTUnwrap(object["uiPhraseASCII"] as? String)
    }

    func testProtectedBackupUsesFilesAndNeedsPasswordBeforeReplacement() throws {
        let password = try fixturePhrase()
        continueAfterFailure = false
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp").terminate()
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = .light
        app.launchArguments = [
            "--ui-testing", "--reset-ui-state", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
        ]
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = "work"
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.launch()
        XCTAssertTrue(app.staticTexts["$550.00"].firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        tap("backup.open")
        let protect = app.buttons["backup.protect"].firstMatch
        XCTAssertTrue(protect.waitForExistence(timeout: 10))
        protect.tap()
        XCTAssertEqual(protect.value as? String, "Confirmed")
        enter("backup.password", password)
        enter("backup.password-confirm", password)
        tap("backup.password-kept")
        capture("v2-backup-password-consent")
        tap("backup.save")
        tap("backup.choose-location")
        let picker = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 20))
        let filenameField = app.textFields.matching(
            NSPredicate(format: "value BEGINSWITH %@", "LinePaycheck-")
        ).firstMatch
        if !filenameField.waitForExistence(timeout: 10) {
            capture("v2-backup-export-filename-field-missing")
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "v2-backup-export-picker-accessibility"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        let filename = try XCTUnwrap(filenameField.value as? String)
        if !picker.staticTexts["On My iPhone"].exists {
            if picker.buttons["Browse"].exists { picker.buttons["Browse"].tap() }
            let local = app.staticTexts["On My iPhone"].firstMatch
            XCTAssertTrue(local.waitForExistence(timeout: 10), "Use a local destination only")
            local.tap()
        }
        XCTAssertTrue(picker.staticTexts["On My iPhone"].waitForExistence(timeout: 10))
        capture("v2-backup-encrypted-files-destination")
        let save = picker.buttons["Move"].exists ? picker.buttons["Move"] : picker.buttons["Save"]
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 15))
        let savedCopy =
            "Saved to your selected location. For iCloud Drive, confirm upload in Files."
        let savedStatus = try revealSavedStatus(savedCopy)
        capture("v2-backup-provider-save-status")
        XCTAssertEqual(savedStatus.label, savedCopy)
        tap("backup.done")
        tap("settings.privacy-data")
        tap("settings.delete-all")
        tap("settings.confirm-delete-all")
        XCTAssertTrue(app.buttons["onboarding.set-up-pay"].waitForExistence(timeout: 15))
        tap("backup.open")
        tap("backup.restore")
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        capture("v2-backup-restore-picker-initial")
        if !picker.staticTexts["On My iPhone"].exists {
            if picker.buttons["Browse"].exists { picker.buttons["Browse"].tap() }
            let local = app.staticTexts["On My iPhone"].firstMatch
            XCTAssertTrue(local.waitForExistence(timeout: 10), "Choose the local Files location")
            local.tap()
        }
        XCTAssertTrue(picker.staticTexts["On My iPhone"].waitForExistence(timeout: 10))
        let file = app.cells.matching(NSPredicate(format: "label CONTAINS %@", filename)).firstMatch
        if !file.waitForExistence(timeout: 5) {
            let search = app.searchFields.firstMatch
            if search.exists {
                search.tap()
                search.typeText(filename)
            }
        }
        if !file.waitForExistence(timeout: 15) {
            capture("v2-backup-restore-file-missing")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "synthetic-backup-restore-picker-accessibility"
            tree.lifetime = .keepAlways
            add(tree)
        }
        XCTAssertTrue(file.exists, "The locally saved synthetic backup must be selectable")
        capture("v2-backup-selected-local-file")
        file.tap()
        if picker.exists, picker.buttons["Open"].exists { picker.buttons["Open"].tap() }
        XCTAssertTrue(picker.waitForNonExistence(timeout: 15))
        let unlock = app.secureTextFields["backup.unlock-password"].firstMatch
        // The retained picker-return snapshot ends at "Unlock selected backup". Its
        // password control is the following virtualized row, so reveal it before waiting.
        reveal(unlock)
        XCTAssertTrue(unlock.waitForExistence(timeout: 12))
        XCTAssertTrue(unlock.exists)
        XCTAssertFalse(app.buttons["backup.confirm-restore"].exists)
        enter("backup.unlock-password", password + " wrong")
        tap("backup.unlock")
        XCTAssertTrue(unlock.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["backup.confirm-restore"].exists)
        let rejected = app.staticTexts["backup.status"].firstMatch
        reveal(rejected)
        XCTAssertTrue(rejected.label.contains("password did not unlock"))
        capture("v2-backup-wrong-password-keeps-data")
        enter("backup.unlock-password", password)
        tap("backup.unlock")
        let status = app.staticTexts["backup.protection-status"].firstMatch
        reveal(status)
        XCTAssertTrue(status.label.contains("Password-protected copy unlocked"))
        capture("v2-backup-unlocked-preview-before-replace")
        tap("backup.confirm-restore")
        tap("backup.perform-restore")
        XCTAssertTrue(app.staticTexts["$550.00"].firstMatch.waitForExistence(timeout: 15))
    }

    func testMismatchedPasswordAtLargestTextDoesNotExportOrChangeWages() throws {
        let password = try fixturePhrase()
        continueAfterFailure = false
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.appearance = .dark
        app.launchArguments = [
            "--ui-testing", "--reset-ui-state", "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US", "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = "work"
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.launch()
        XCTAssertTrue(app.staticTexts["$550.00"].firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        tap("backup.open")
        tap("backup.protect")
        enter("backup.password", password)
        enter("backup.password-confirm", password + " mismatch")
        tap("backup.password-kept")
        tap("backup.save")
        let status = app.staticTexts["backup.status"].firstMatch
        reveal(status)
        XCTAssertTrue(status.label.contains("confirmation does not match"))
        XCTAssertFalse(app.buttons["backup.choose-location"].exists)
        XCTAssertFalse(app.navigationBars["FullDocumentManagerViewControllerNavigationBar"].exists)
        capture("v2-backup-large-dark-password-mismatch")
        tap("backup.done")
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["$550.00"].firstMatch.waitForExistence(timeout: 15))
    }

    private func enter(_ id: String, _ value: String) {
        let field = app.secureTextFields[id].firstMatch
        reveal(field)
        XCTAssertTrue(field.isHittable)
        field.tap()
        field.typeText(value)
        if let done = app.buttons.matching(identifier: "keyboard.done").allElementsBoundByIndex
            .first(where: { $0.isHittable })
        {
            done.tap()
        }
    }
    private func tap(_ id: String) {
        let button = app.buttons[id].firstMatch
        if id != "backup.done" { reveal(button) }
        XCTAssertTrue(button.isHittable, "Missing visible action: \(id)")
        button.tap()
    }
    private func revealSavedStatus(_ expectedText: String) throws -> XCUIElement {
        // The Label's identifier propagates to its decorative Image as well as its text.
        // Verify the observed semantic message, not the first identifier match or icon hit test.
        let status = app.staticTexts.matching(
            NSPredicate(format: "label == %@", expectedText)
        ).firstMatch
        let list = try XCTUnwrap(
            app.collectionViews.allElementsBoundByIndex.max { $0.frame.width < $1.frame.width })
        let navigation = app.navigationBars["Backup"].firstMatch
        XCTAssertTrue(navigation.waitForExistence(timeout: 10))
        for _ in 0..<15 {
            let top = navigation.frame.maxY
            let bottom = min(list.frame.maxY, app.frame.maxY - 40)
            if status.exists, status.frame.height > 0,
                status.frame.minY >= top, status.frame.maxY <= bottom
            {
                return status
            }
            let up = !status.exists || status.frame.minY >= top
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let x = list.frame.minX + 12
            let upper = top + (bottom - top) * 0.25
            let lower = top + (bottom - top) * 0.8
            origin.withOffset(CGVector(dx: x, dy: up ? lower : upper)).press(
                forDuration: 0.05,
                thenDragTo: origin.withOffset(CGVector(dx: x, dy: up ? upper : lower)))
        }
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "backup-save-semantic-status-missing"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        capture("backup-save-semantic-status-missing")
        XCTFail("The exact backup-save message must be fully visible in the foreground Backup list")
        return status
    }
    private func reveal(_ element: XCUIElement) {
        let window =
            app.windows.allElementsBoundByIndex.max {
                $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height
            } ?? app.windows.firstMatch
        for _ in 0..<25 {
            if element.exists, element.isHittable, element.frame.minY > 120,
                element.frame.maxY < window.frame.maxY - 100
            {
                return
            }
            if element.exists, element.frame.minY < 120 {
                window.swipeDown()
            } else {
                window.swipeUp()
            }
        }
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
