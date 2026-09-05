import Foundation
import LinePayDomain
import UIKit

struct ReconciliationReportExporter {
    func export(
        window: PayPeriodWindow,
        timeZoneIdentifier: String,
        agreement: AgreementSnapshot,
        calculation: CalculationResult,
        paystub: ConfirmedPaystub?,
        reconciliation: ReconciliationResult?,
        findings: [AuditFinding]
    ) throws -> URL {
        let filename =
            "LinePaycheck-\(dateSlug(window.startDate, timeZoneIdentifier: timeZoneIdentifier)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        let data = renderer.pdfData { context in
            var writer = PDFTextWriter(context: context, pageBounds: pageBounds)
            writer.beginPage()
            writer.title("LinePaycheck paycheck reconciliation")
            writer.text(LinePayFormat.payPeriod(window, timeZoneIdentifier: timeZoneIdentifier))
            writer.gap()

            writer.section("Summary")
            writer.row("Expected gross", LinePayFormat.money(calculation.total))
            if let paystub {
                writer.row("Confirmed paid gross", LinePayFormat.money(paystub.grossPay))
            } else {
                writer.row("Confirmed paid gross", "Not entered")
            }
            if let reconciliation {
                writer.row("Status", statusTitle(reconciliation.direction))
                writer.row("Difference", LinePayFormat.money(reconciliation.difference))
            }

            writer.section("Pay ledger")
            for component in calculation.components {
                let hours = component.hours.map { "\(LinePayFormat.hours($0)) h" } ?? ""
                let multiplier = component.multiplier.map { "\(LinePayFormat.decimal($0))×" } ?? ""
                let metadata = [hours, multiplier].filter { !$0.isEmpty }.joined(separator: " · ")
                writer.text(
                    "\(LinePayFormat.localDate(component.localDate))  \(category(component.category))  "
                        + "\(metadata)  \(LinePayFormat.money(component.amount))"
                )
                writer.caption(component.explanation)
            }

            if !findings.isEmpty {
                writer.section("Confirmed comparisons")
                for finding in findings {
                    writer.text(finding.title)
                    writer.caption(
                        "Expected \(LinePayFormat.money(finding.expected)) · Paid "
                            + "\(LinePayFormat.money(finding.paid)) · Difference "
                            + "\(LinePayFormat.money(finding.difference))"
                    )
                    writer.caption(finding.explanation)
                }
            }

            writer.section("Rule snapshot")
            writer.row("Profile", agreement.displayName)
            writer.row("Rule version", agreement.version)
            writer.row("Base rate", "\(LinePayFormat.money(agreement.hourlyRate))/hr")
            for source in agreement.sources {
                writer.text(source.title)
                if !source.url.isEmpty { writer.caption(source.url) }
                if let section = source.section { writer.caption(section) }
            }

            writer.section("Important")
            writer.caption(
                "LinePaycheck is an estimation and reconciliation tool. A flagged difference is a reason "
                    + "to review the paycheck and agreement, not a legal determination of wages owed."
            )
            writer.caption("Original paystub images/PDFs are not included in this report.")
        }

        try data.write(to: url, options: [.atomic])
        return url
    }

    private func dateSlug(_ date: Date, timeZoneIdentifier: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        return formatter.string(from: date)
    }

    private func statusTitle(_ direction: ReconciliationDirection) -> String {
        switch direction {
        case .matches: "Matches"
        case .possibleUnderpayment: "Possible shortfall"
        case .possibleOverpayment: "Possible overpayment"
        }
    }

    private func category(_ category: PayComponentCategory) -> String {
        switch category {
        case .workedHours: "Worked hours"
        case .calloutGuarantee: "Callout guarantee"
        case .perDiem: "Per diem"
        }
    }
}

private struct PDFTextWriter {
    let context: UIGraphicsPDFRendererContext
    let pageBounds: CGRect
    private var y: CGFloat = 0

    init(context: UIGraphicsPDFRendererContext, pageBounds: CGRect) {
        self.context = context
        self.pageBounds = pageBounds
    }

    mutating func beginPage() {
        context.beginPage()
        y = 48
    }

    mutating func title(_ value: String) {
        draw(value, font: .boldSystemFont(ofSize: 20), spacingAfter: 8)
    }

    mutating func section(_ value: String) {
        ensureSpace(42)
        y += 14
        draw(value, font: .boldSystemFont(ofSize: 13), spacingAfter: 7)
    }

    mutating func text(_ value: String) {
        draw(value, font: .systemFont(ofSize: 11), spacingAfter: 4)
    }

    mutating func caption(_ value: String) {
        draw(value, font: .systemFont(ofSize: 9), color: .darkGray, spacingAfter: 5)
    }

    mutating func row(_ label: String, _ value: String) {
        text("\(label):  \(value)")
    }

    mutating func gap() {
        y += 8
    }

    private mutating func ensureSpace(_ height: CGFloat) {
        if y + height > pageBounds.height - 48 {
            beginPage()
        }
    }

    private mutating func draw(
        _ value: String,
        font: UIFont,
        color: UIColor = .label,
        spacingAfter: CGFloat
    ) {
        let width = pageBounds.width - 96
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let bounding = (value as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        ensureSpace(ceil(bounding.height) + spacingAfter)
        (value as NSString).draw(
            in: CGRect(x: 48, y: y, width: width, height: ceil(bounding.height) + 4),
            withAttributes: attributes
        )
        y += ceil(bounding.height) + spacingAfter
    }
}
