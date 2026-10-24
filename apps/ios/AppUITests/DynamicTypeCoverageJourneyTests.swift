import UIKit
import XCTest

@MainActor
final class DynamicTypeCoverageJourneyTests: XCTestCase {
    private var app = XCUIApplication()

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func test01ExtraSmall() { check("XS", category: .extraSmall) }
    func test02Small() { check("S", category: .small) }
    func test03Medium() { check("M", category: .medium) }
    func test04Large() { check("L", category: .large) }
    func test05ExtraLarge() { check("XL", category: .extraLarge) }
    func test06ExtraExtraLarge() { check("XXL", category: .extraExtraLarge) }
    func test07ExtraExtraExtraLarge() { check("XXXL", category: .extraExtraExtraLarge) }
    func test08AccessibilityMedium() { check("AccessibilityM", category: .accessibilityMedium) }
    func test09AccessibilityLarge() { check("AccessibilityL", category: .accessibilityLarge) }
    func test10AccessibilityExtraLarge() {
        check("AccessibilityXL", category: .accessibilityExtraLarge)
    }
    func test11AccessibilityExtraExtraLarge() {
        check("AccessibilityXXL", category: .accessibilityExtraExtraLarge)
    }
    func test12AccessibilityExtraExtraExtraLarge() {
        check("AccessibilityXXXL", category: .accessibilityExtraExtraExtraLarge)
    }

    func test13SettingsActionsRemainFullyReadableAtLargestText() {
        continueAfterFailure = false
        executionTimeAllowance = 600
        launch("AccessibilityXXXL")
        app.tabBars.buttons["Settings"].tap()
        for identifier in [
            "settings.payProfile", "settings.edit-rules", "settings.payPeriod",
            "settings.ruleSources", "settings.local-activity", "settings.benefits",
            "settings.agreements", "settings.crew-rules", "settings.view-pro",
            "settings.restore-purchases", "settings.manage-subscription",
            "settings.privacy-data", "backup.open", "settings.exportData", "settings.about",
            "settings.support", "settings.privacy-policy", "settings.terms",
        ].filter({ CrewRuleSharingAvailability.enabled || $0 != "settings.crew-rules" }) {
            let element = app.descendants(matching: .any)
                .matching(identifier: identifier).firstMatch
            revealFully(element)
            measure(identifier, style: .body, category: .accessibilityExtraExtraExtraLarge)
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "settings-largest-text-final-actions"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func revealFully(_ element: XCUIElement) {
        let window = app.windows.firstMatch
        for _ in 0..<40 {
            let top = app.navigationBars.firstMatch.frame.maxY + 4
            let bottom = app.tabBars.firstMatch.frame.minY - 4
            if element.exists, element.isHittable,
                element.frame.minY >= top, element.frame.maxY <= bottom
            {
                return
            }
            let delta: CGFloat
            if element.exists, element.frame.minY < top {
                delta = min(180, top - element.frame.minY + 8)
            } else if element.exists {
                delta = -min(180, max(40, element.frame.maxY - bottom + 8))
            } else {
                delta = -180
            }
            let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)))
        }
        XCTFail("The complete action must fit inside the reading viewport: \(element)")
    }

    private func check(_ argument: String, category: UIContentSizeCategory) {
        continueAfterFailure = false
        executionTimeAllowance = 300
        launch(argument)
        for (identifier, style) in [
            ("today.open-pay", UIFont.TextStyle.body),
            ("audit.status", .subheadline), ("today.work-heading", .headline),
        ] {
            measure(identifier, style: style, category: category)
        }
        measureWorkRow(category)
        app.tabBars.buttons["Settings"].tap()
        measure("settings.restore-purchases", style: .body, category: category)
        measure("backup.open", style: .body, category: category)
        let activity = app.buttons["settings.local-activity"]
        reveal(activity, searchingDown: false)
        activity.tap()
        measure("activity.recording", style: .body, category: category)
        measure("activity.recording-explanation", style: .body, category: category)
        if argument == "L" || argument == "AccessibilityXXXL" {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "font-metrics-activity-\(argument)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func measure(
        _ identifier: String, style: UIFont.TextStyle, category: UIContentSizeCategory
    ) {
        let element = app.descendants(matching: .any)
            .matching(identifier: identifier).firstMatch
        reveal(element)
        XCTAssertFalse(element.label.isEmpty, identifier)
        let font = UIFont.preferredFont(
            forTextStyle: style,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: category))
        let expected = (element.label as NSString).boundingRect(
            with: CGSize(width: element.frame.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font], context: nil)
        print(
            "Font metrics: \(identifier), \(category.rawValue), actual \(element.frame), minimum height \(expected.height)"
        )
        XCTAssertGreaterThanOrEqual(
            element.frame.height + 2, expected.height * 0.95,
            "\(identifier) must show its complete text using the requested system font metrics")
        XCTAssertGreaterThanOrEqual(element.frame.minX, 0)
        XCTAssertLessThanOrEqual(element.frame.maxX, app.windows.firstMatch.frame.maxX)
    }

    private func measureWorkRow(_ category: UIContentSizeCategory) {
        let row = app.buttons["today.edit-work"].firstMatch
        reveal(row)
        let kind = "Regular work · 10 h"
        let note = "Synthetic test shift"
        XCTAssertTrue(row.label.contains(kind) && row.label.contains(note))
        let times = row.label.replacingOccurrences(of: kind, with: "")
            .replacingOccurrences(of: note, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: ", \n"))
        var minimum: CGFloat = 20
        for (text, style) in [
            (kind, UIFont.TextStyle.headline), (times, .subheadline), (note, .footnote),
        ] {
            let font = UIFont.preferredFont(
                forTextStyle: style,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: category))
            minimum +=
                (text as NSString).boundingRect(
                    with: CGSize(width: row.frame.width - 40, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font], context: nil
                ).height
        }
        print(
            "Font metrics: work row, \(category.rawValue), \(row.label), actual \(row.frame), minimum height \(minimum)"
        )
        XCTAssertGreaterThanOrEqual(row.frame.height + 2, minimum * 0.95)
    }

    private func reveal(_ element: XCUIElement, searchingDown: Bool = true) {
        let window = app.windows.firstMatch
        for _ in 0..<40 {
            let top = app.navigationBars.firstMatch.frame.maxY + 4
            let bottom = app.tabBars.firstMatch.frame.minY - 4
            if element.exists, element.isHittable,
                element.frame.maxY > top, element.frame.minY < bottom
            {
                return
            }
            let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            let goDown = element.exists ? element.frame.maxY > top : searchingDown
            let delta: CGFloat = goDown ? -180 : 180
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)))
        }
        XCTFail("Expected text/action is not reachable: \(element)")
    }

    private func launch(_ category: String) {
        app.terminate()
        _ = app.wait(for: .notRunning, timeout: 10)
        XCUIDevice.shared.appearance = .light
        app.launchArguments = [
            "--ui-testing", "--reset-ui-state", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(category)",
        ]
        app.launchEnvironment["LINEPAY_UI_SCENARIO"] = "matches"
        app.launchEnvironment["LINEPAY_COMMERCE_ENABLED"] = "0"
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 15))
    }
}
