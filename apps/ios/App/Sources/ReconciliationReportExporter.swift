import Foundation
import LinePayDomain
import UIKit

/// A report is a snapshot, not a second calculation engine. It uses the saved assessment and
/// fixed paper colors, regardless of the device's current appearance.
@MainActor
struct ReconciliationReportExporter {
    func export(
        window: PayPeriodWindow,
        timeZoneIdentifier: String,
        agreement: AgreementSnapshot,
        calculation: CalculationResult,
        paystub: ConfirmedPaystub?,
        reconciliation: ReconciliationResult?,
        findings: [AuditFinding],
        privacy: ReportPrivacyOptions = ReportPrivacyOptions()
    ) throws -> URL {
        let created = Date()
        let url = try TemporaryExports.destination(name: "LinePaycheck-audit", extension: "pdf")
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        let assessment = paystub?.assessment
        let isCurrent = AuditAssessment.evaluate(
            calculation: calculation, paystub: paystub, reconciliation: reconciliation
        ).isCurrent

        let data = renderer.pdfData { context in
            var writer = PDFTextWriter(context: context, pageBounds: pageBounds)
            writer.beginPage()
            writer.title("LinePaycheck paycheck reconciliation")
            writer.text(LinePayFormat.payPeriod(window, timeZoneIdentifier: timeZoneIdentifier))
            writer.caption("Payroll timezone: \(timeZoneIdentifier)")
            writer.caption("Report created: \(ISO8601DateFormatter().string(from: created))")

            writer.section("Summary and comparison scope")
            writer.row("Expected wage pay", LinePayFormat.money(calculation.expectedWages))
            writer.row("Expected per diem", LinePayFormat.money(calculation.expectedAllowances))
            if let paystub {
                writer.row("Confirmed paystub gross", LinePayFormat.money(paystub.grossPay))
                writer.row("Gross basis", paystub.confirmation?.grossBasis.title ?? "Not recorded")
                if isCurrent, let assessment {
                    writer.row("Verdict", AuditDisplayStatus.assessment(assessment).title)
                    if let comparable = assessment.expectedGross {
                        writer.row("Expected on the same basis", LinePayFormat.money(comparable))
                    }
                    if let difference = assessment.difference {
                        writer.row("Expected minus confirmed paid", LinePayFormat.money(difference))
                    }
                    for reason in assessment.reviewReasons { writer.text(reason) }
                    for note in assessment.scopeNotes { writer.caption(note) }
                    writer.caption("Comparison engine version: \(assessment.engineVersion)")
                } else {
                    writer.text(
                        "Needs review. This audit has no current evidence-aware comparison. Do not treat the recorded gross difference as a verified shortfall."
                    )
                }
            } else {
                writer.text("Awaiting paycheck. No paid amount has been confirmed.")
            }

            writer.section(ComparisonScopeDisclosure.title)
            writer.text(ComparisonScopeDisclosure.summary)
            writer.caption(ComparisonScopeDisclosure.supported)
            writer.caption(ComparisonScopeDisclosure.unsupported)
            writer.caption(ComparisonScopeDisclosure.combination)

            writer.section("Pay ledger")
            for component in calculation.components {
                writer.text(
                    "\(LinePayFormat.localDate(component.localDate))  \(componentTitle(component))  \(LinePayFormat.money(component.amount))"
                )
                if let hours = component.hours {
                    let rate = component.baseRate ?? agreement.hourlyRate
                    let multiplier = component.multiplier ?? 1
                    writer.caption(
                        "\(LinePayFormat.hours(hours)) \(component.category == .calloutGuarantee ? "paid-hour equivalent" : "hours") x \(LinePayFormat.money(rate)) x \(LinePayFormat.decimal(multiplier))"
                    )
                }
                writer.caption(component.explanation)
                if let reference = component.appliedAgreement {
                    writer.caption("Applied rule version: \(reference.version)")
                }
                writer.caption("Rounded using the recorded agreement's policy.")
            }

            if isCurrent, let assessment {
                writer.section("Confirmed line comparisons")
                for comparison in assessment.comparisons {
                    writer.text(comparison.field.title)
                    writer.row("Expected", format(comparison.expected, comparison))
                    writer.row("Confirmed", format(comparison.paid, comparison))
                    writer.row(
                        "Expected minus confirmed", format(comparison.difference, comparison))
                    if let suggestion = paystub?.confirmation?.suggestions[comparison.field] {
                        writer.caption(
                            "Source: page \(suggestion.region.page + 1), value confirmed by the worker."
                        )
                        if privacy.includeSourceDetails { writer.caption(suggestion.sourceText) }
                    } else {
                        writer.caption("Source: value entered and confirmed by the worker.")
                    }
                }
            }

            for agreement in calculation.agreementSnapshots ?? [agreement] {
                writer.section("Rule snapshot")
                if privacy.includeSourceDetails {
                    writer.row("Profile", agreement.displayName)
                    writer.row("Agreement ID", agreement.id)
                }
                writer.row("Rule version", agreement.version)
                writer.row("Base rate", "\(LinePayFormat.money(agreement.hourlyRate))/hr")
                if let confirmed = agreement.confirmedEpochSeconds {
                    writer.caption(
                        "Rules confirmed: \(ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(confirmed))))"
                    )
                }
                if agreement.sources.isEmpty {
                    writer.caption("Rules confirmed by you; no source attached.")
                }
                if privacy.includeSourceDetails {
                    for source in agreement.sources {
                        writer.text(
                            "\(source.ruleKey?.title ?? "Agreement-level source"): \(source.title)")
                        if !source.url.isEmpty { writer.caption(source.url) }
                        if let section = source.section { writer.caption(section) }
                    }
                } else if !agreement.sources.isEmpty {
                    writer.caption(
                        "Source names, URLs and free-text references omitted from this sharing copy. Review originals in LinePaycheck."
                    )
                }
                if let notes = agreement.unsupportedRuleNotes, !notes.isEmpty {
                    writer.text(
                        privacy.includeSourceDetails
                            ? "Incomplete rule coverage: \(notes)"
                            : "Incomplete rule coverage: a rule is not represented. The private note is retained in LinePaycheck."
                    )
                }
            }
            writer.section("Important")
            writer.caption(
                "LinePaycheck estimates and reconciles only the facts and rules you confirmed. A difference is a reason to review the paycheck, not a legal determination of wages owed. Positive difference means expected was higher, not that recovery is guaranteed."
            )
            writer.caption(ComparisonScopeDisclosure.deadlines)
            writer.caption(
                privacy.includeSourceDetails
                    ? "Sensitive sharing copy: includes optional OCR source text, profile identity and rule references. It is not anonymous. Review before sharing."
                    : "Sensitive sharing copy: pay amounts, dates and rule details can identify a worker. It is not anonymous. Optional OCR source text and profile/source identifiers are omitted."
            )
            writer.caption(
                "Original paystub pages are excluded. No file is uploaded unless you choose to share it. Copies saved outside LinePaycheck remain under your control."
            )
        }
        try data.write(
            to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return url
    }

    private func format(_ value: Decimal, _ comparison: PaycheckComparison) -> String {
        comparison.unit == .hours
            ? "\(LinePayFormat.hours(value)) h"
            : LinePayFormat.money(Money(amount: value, currencyCode: comparison.currencyCode))
    }
}

/// TextKit supplies real line wrapping. Each line is paginated independently, so a long note or
/// URL can span pages rather than being clipped or shrinking to unreadable text.
@MainActor
private struct PDFTextWriter {
    let context: UIGraphicsPDFRendererContext
    let pageBounds: CGRect
    private var y: CGFloat = 48
    private var page = 0

    init(context: UIGraphicsPDFRendererContext, pageBounds: CGRect) {
        self.context = context
        self.pageBounds = pageBounds
    }

    mutating func beginPage() {
        context.beginPage()
        page += 1
        context.cgContext.setFillColor(UIColor.white.cgColor)
        context.cgContext.fill(pageBounds)
        ("LinePaycheck  |  Page \(page)" as NSString).draw(
            at: CGPoint(x: 48, y: pageBounds.height - 30),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.darkGray,
            ])
        y = 48
    }
    mutating func title(_ value: String) {
        draw(value, font: .boldSystemFont(ofSize: 20), spacingAfter: 10)
    }
    mutating func section(_ value: String) {
        ensureSpace(48)
        y += 12
        draw(value, font: .boldSystemFont(ofSize: 13), spacingAfter: 8)
    }
    mutating func text(_ value: String) {
        draw(value, font: .systemFont(ofSize: 11), spacingAfter: 5)
    }
    mutating func caption(_ value: String) {
        draw(value, font: .systemFont(ofSize: 9), spacingAfter: 5)
    }
    mutating func row(_ label: String, _ value: String) { text("\(label): \(value)") }
    private mutating func ensureSpace(_ height: CGFloat) {
        if y + height > pageBounds.height - 48 { beginPage() }
    }
    private mutating func draw(_ value: String, font: UIFont, spacingAfter: CGFloat) {
        let storage = NSTextStorage(
            string: value,
            attributes: [
                .font: font, .foregroundColor: UIColor.black,
            ])
        let layout = NSLayoutManager()
        let container = NSTextContainer(
            size: CGSize(width: pageBounds.width - 96, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        let range = layout.glyphRange(for: container)
        var lines: [(CGRect, NSRange)] = []
        layout.enumerateLineFragments(forGlyphRange: range) { rect, _, _, glyphs, _ in
            lines.append((rect, glyphs))
        }
        for (rect, glyphs) in lines {
            ensureSpace(ceil(rect.height) + 2)
            layout.drawGlyphs(forGlyphRange: glyphs, at: CGPoint(x: 48, y: y - rect.minY))
            y += ceil(rect.height) + 1
        }
        y += spacingAfter
    }
}
