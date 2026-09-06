import LinePayDomain
import SwiftUI

struct EvidenceReceiptView: View {
    let component: PayComponent
    let agreement: AgreementSnapshot
    let work: [WorkEntry]
    var body: some View {
        List {
            Section {
                PayAmount(
                    label: componentTitle(component), money: component.amount, prominent: true)
            }
            Section("Work facts") {
                if let entry = work.first(where: { $0.id == component.workIntervalID }) {
                    Text(workKindTitle(entry.interval.kind)).font(.headline)
                    Text(LinePayFormat.workDateRange(entry.interval))
                    LabeledContent(
                        "Actual work",
                        value: "\(LinePayFormat.hours(entry.interval.durationHours)) h")
                    if let text = LinePayFormat.breakDuration(entry.interval) { Text(text) }
                    Text("Payroll timezone: \(entry.interval.timeZoneIdentifier)").font(.footnote)
                    if !entry.note.isEmpty { Text(entry.note) }
                } else {
                    Text("Work date: \(LinePayFormat.localDate(component.localDate))")
                    Text("This amount applies to the worked date, not an invented extra shift.")
                        .font(.footnote)
                }
            }
            Section("Applied rule and arithmetic") {
                Text(component.explanation)
                if component.category == .calloutGuarantee, let rule = agreement.calloutMinimum {
                    LabeledContent(
                        "Minimum", value: "\(LinePayFormat.hours(rule.minimumHours)) paid h")
                    Text(
                        "Actual clock time remains unchanged. The amount below is a derived top-up."
                    )
                    .font(.footnote)
                }
                if let hours = component.hours, let multiplier = component.multiplier {
                    LabeledContent(
                        component.category == .calloutGuarantee
                            ? "Additional paid equivalent" : "Worked hours",
                        value: "\(LinePayFormat.hours(hours)) h")
                    Text(
                        "\(LinePayFormat.decimal(hours)) × \(LinePayFormat.money(component.baseRate ?? agreement.hourlyRate)) × \(LinePayFormat.decimal(multiplier))"
                    )
                    .monospacedDigit().textSelection(.enabled)
                }
                LabeledContent("Rounded amount", value: LinePayFormat.money(component.amount))
                Text(
                    "Rounded to \(agreement.rounding.scale) decimal places using this rule snapshot."
                )
                .font(.footnote)
            }
            Section("Rule evidence") {
                RuleSnapshotSummary(agreement: agreement)
                NavigationLink("Sources for this amount") {
                    RuleSourcesView(agreement: agreement, keys: component.ruleKeys)
                }
            }
        }
        .navigationTitle("Why this amount?")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ledger.evidence-receipt")
    }
}

struct RuleSnapshotSummary: View {
    let agreement: AgreementSnapshot
    var body: some View {
        LabeledContent("Profile", value: agreement.displayName)
        LabeledContent("Rule version", value: agreement.version)
        if let timestamp = agreement.confirmedEpochSeconds {
            Text(
                "Confirmed by you: \(Date(timeIntervalSince1970: TimeInterval(timestamp)).formatted(date: .abbreviated, time: .shortened))"
            )
            .font(.footnote)
        } else {
            Text("Worker-entered rules. No confirmation date was recorded for this older snapshot.")
                .font(.footnote)
        }
        if let notes = agreement.unsupportedRuleNotes, !notes.isEmpty {
            Label("Incomplete rule coverage", systemImage: "exclamationmark.triangle")
                .foregroundStyle(LinePayColor.review)
            Text(notes)
        }
    }
}

struct RuleSourcesView: View {
    let agreement: AgreementSnapshot
    var keys: [PayRuleKey]? = nil
    var body: some View {
        List {
            Section("Snapshot") { RuleSnapshotSummary(agreement: agreement) }
            if let keys {
                Section("Applied rules") { ForEach(keys, id: \.self) { Text($0.title) } }
            }
            Section("Sources") {
                let relevant = agreement.sources.filter {
                    $0.ruleKey == nil || keys == nil || keys!.contains($0.ruleKey!)
                }
                if relevant.isEmpty {
                    Text("Rule confirmed by you; no source attached.")
                }
                ForEach(Array(relevant.enumerated()), id: \.offset) { _, source in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(source.title).font(.headline)
                        Text(
                            source.ruleKey?.title
                                ?? "Agreement-level reference; not verified for each rule"
                        )
                        .font(.footnote).foregroundStyle(LinePayColor.textSecondary)
                        if let section = source.section { Text(section) }
                        if let url = AppModel.safeSourceURL(source.url) {
                            Link("Open source link", destination: url).frame(minHeight: 44)
                        }
                        Text(
                            "Added by you. LinePaycheck has not independently verified this source."
                        )
                        .font(.footnote)
                    }.padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Rule sources")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PayLedgerRows: View {
    let calculation: CalculationResult
    let agreement: AgreementSnapshot
    let work: [WorkEntry]
    var body: some View {
        let dates = Array(Set(calculation.components.map(\.localDate))).sorted()
        ForEach(dates, id: \.self) { date in
            Section(LinePayFormat.localDate(date)) {
                ForEach(calculation.components.filter { $0.localDate == date }) { component in
                    NavigationLink {
                        EvidenceReceiptView(
                            component: component,
                            agreement: appliedSnapshot(
                                for: component, in: calculation, fallback: agreement), work: work)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(componentTitle(component)).font(.headline)
                            Text(LinePayFormat.money(component.amount)).font(
                                .title3.monospacedDigit())
                            if let hours = component.hours {
                                Text(
                                    "\(LinePayFormat.hours(hours)) \(component.category == .calloutGuarantee ? "additional paid-equivalent hours" : "worked hours")"
                                )
                                .font(.footnote)
                            }
                            if let multiplier = component.multiplier {
                                Text("\(LinePayFormat.decimal(multiplier))× base rate").font(
                                    .footnote)
                            }
                        }
                        .foregroundStyle(LinePayColor.textPrimary)
                        .padding(.vertical, 6)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}
