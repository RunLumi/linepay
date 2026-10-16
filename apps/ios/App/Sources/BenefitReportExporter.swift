import Foundation
import LinePayDomain
import UIKit

@MainActor
struct BenefitReportExporter {
    func export(
        _ revision: BenefitAuditRevision, privacy: ReportPrivacyOptions = ReportPrivacyOptions()
    ) throws -> URL {
        let result = revision.result
        let input = revision.input
        let url = try TemporaryExports.destination(name: "LinePaycheck-benefits", extension: "pdf")
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            var writer = PDFTextWriter(context: context, pageBounds: bounds)
            writer.beginPage()
            writer.title("Employer benefit contribution review")
            writer.text(benefitPeriodLabel(result.period))
            writer.caption("Payroll timezone: \(result.period.timeZoneIdentifier)")
            writer.caption("Report created: \(ISO8601DateFormatter().string(from: Date()))")
            writer.caption(
                "Check recorded: \(ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(revision.recordedEpochSeconds))))"
            )
            writer.caption("Decimal separator in displayed values: \(NumberEntry.decimalSeparator)")
            writer.section("Comparison scope")
            writer.text(result.comparisonTitle)
            writer.row(
                "Expected employer contribution", benefitMoney(result.expectedEmployerContribution))
            writer.row(
                "Confirmed employer contribution",
                result.confirmedEmployerContribution.map(benefitMoney) ?? "Not available")
            writer.row(
                "Expected minus confirmed",
                result.contributionDifference.map(benefitMoney) ?? "Not compared")
            if let units = result.eligibleQuantity, let basis = result.quantityBasis {
                writer.row(basis.quantityTitle, LinePayFormat.entry(units))
            }
            writer.row(
                "Eligible unit difference",
                result.quantityDifference.map(LinePayFormat.entry) ?? "Not compared")
            if let limitation = result.limitation { writer.text(limitation) }
            writer.caption(
                "Cash wages, allowances and employee deductions are separate and are not compared by this report."
            )
            if let statement = result.statement {
                writer.section("Recorded statement scope")
                writer.text(benefitPeriodLabel(statement.period))
                writer.caption(
                    "Statement timezone: \(statement.period.timeZoneIdentifier); currency: \(statement.currencyCode)"
                )
                writer.caption(
                    statement.fundID == result.fundID
                        ? "Statement identified as the same fund."
                        : "Statement fund match is not established; no same-fund comparison was made."
                )
                writer.caption(
                    statement.confirmed
                        ? "Entered statement facts were confirmed by the worker."
                        : "Statement readings remain unconfirmed and were not compared.")
                if statement.confirmed {
                    if let amount = statement.employerContribution {
                        writer.row("Recorded amount", benefitMoney(amount))
                    }
                    if let units = statement.quantity, let basis = statement.quantityBasis {
                        writer.row(basis.quantityTitle, LinePayFormat.entry(units))
                    }
                }
            } else {
                writer.caption(
                    "Employer contribution statement missing; no payment or unit shortfall is inferred."
                )
            }
            writer.section("Exact reviewed expectation")
            writer.caption(
                "\(result.engineVersion); round once per fund to \(result.rounding.scale) decimal places, \(result.rounding.mode.rawValue)."
            )
            for (index, line) in result.segments.enumerated() {
                writer.section("Segment \(index + 1)")
                writer.row("Eligible work dates", benefitPeriodLabel(line.period))
                writer.row("Applicable rule dates", benefitPeriodLabel(line.rule.effectivePeriod))
                writer.row("Basis", line.rule.basis.title)
                writer.row(
                    "Rate",
                    line.rule.basis == .percentOfEligibleEarnings
                        ? "\(LinePayFormat.entry(line.rule.rate)) percent of eligible earnings"
                        : "\(line.rule.currencyCode) \(LinePayFormat.entry(line.rule.rate))")
                writer.row(line.rule.basis.quantityTitle, LinePayFormat.entry(line.quantity))
                if let component = result.components.first(where: { $0.id == line.id }) {
                    writer.row(
                        "Unrounded contribution from this segment",
                        benefitMoney(component.unroundedContribution))
                }
                if privacy.includeSourceDetails {
                    writer.caption("Recorded snapshot: \(line.rule.version)")
                    for source in line.rule.sources {
                        writer.caption("Recorded reference: \(source.title)")
                        if !source.url.isEmpty { writer.caption(source.url) }
                        if let section = source.section { writer.caption(section) }
                        if let hash = source.documentSHA256 {
                            writer.caption("Recorded agreement fingerprint: \(hash)")
                        }
                        if let page = source.documentPage {
                            writer.caption("Physical PDF page \(page + 1)")
                        }
                        if let quote = source.quotedText {
                            writer.caption("Recorded excerpt: \(quote)")
                        }
                    }
                }
            }
            if privacy.includeSourceDetails {
                writer.section("Optional source details")
                writer.row("Worker's fund label", input.fundName)
                writer.row("Category", input.kind.title)
                if let name = input.statementEvidence?.originalFilename {
                    writer.caption("Recorded original filename: \(name)")
                }
                if let hash = input.statementSHA256 {
                    writer.caption("Recorded statement fingerprint: \(hash)")
                }
                writer.caption(
                    "Fingerprints and references record file identity, not legal validity, current file availability or professional verification. Original pages are excluded."
                )
            } else {
                writer.caption(
                    "Fund/source names, filenames, quotations, fingerprints and snapshot identifiers are omitted from this copy."
                )
            }
            if privacy.includeBenefitNotes, !input.note.isEmpty {
                writer.section("Worker's private note (included by choice)")
                writer.text(input.note)
            }
            writer.section("Limits")
            writer.caption(
                "This compares only explicitly confirmed employer contribution facts and configured eligibility. Caps, exceptions, remittance deadlines, complete benefits coverage, project/fringe compliance, taxes and legally owed amounts are not determined. A difference is a question to review, not a recovery amount or repayment instruction."
            )
            writer.caption(
                "Sensitive, not anonymous: dates and amounts can identify a worker. Nothing is sent automatically. Review every page before choosing a recipient. An exported copy remains outside later local deletion."
            )
        }
        try data.write(
            to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return url
    }
}
