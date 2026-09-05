import SwiftUI

struct HistoryView: View {
    let model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.history.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(model.history) { period in
                            NavigationLink {
                                HistoricalPayPeriodView(model: model, period: period)
                            } label: {
                                historyRow(period)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(LinePayColor.canvas)
            .navigationTitle("History")
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
                Text("No finished pay periods yet")
                    .font(.title2.bold())
                Text(
                    "When you finish a pay period, LinePaycheck freezes its work facts, rule snapshot, "
                        + "calculation, and any paycheck audit here."
                )
                .foregroundStyle(LinePayColor.textSecondary)
            }
            .padding(LinePaySpacing.section)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func historyRow(_ period: CompletedPayPeriod) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(
                LinePayFormat.payPeriod(
                    period.window,
                    timeZoneIdentifier: model.profile?.timeZoneIdentifier
                        ?? TimeZone.current.identifier
                )
            )
            .font(.headline)

            HStack(spacing: LinePaySpacing.standard) {
                Text(LinePayFormat.money(period.calculation.total))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                if let paid = period.paystub?.grossPay {
                    Text("Paid \(LinePayFormat.money(paid))")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(LinePayColor.textSecondary)
                }
            }

            AuditStatusView(status: model.auditStatus(for: period))
        }
        .padding(.vertical, LinePaySpacing.compact)
    }
}

private struct HistoricalPayPeriodView: View {
    let model: AppModel
    let period: CompletedPayPeriod

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var reportURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Snapshot") {
                LabeledContent("Expected gross") {
                    Text(LinePayFormat.money(period.calculation.total))
                        .monospacedDigit()
                }
                if let paystub = period.paystub {
                    LabeledContent("Confirmed paid gross") {
                        Text(LinePayFormat.money(paystub.grossPay))
                            .monospacedDigit()
                    }
                }
                AuditStatusView(status: model.auditStatus(for: period))
                LabeledContent("Rule version", value: period.agreement.version)
            }

            Section("Pay ledger") {
                ForEach(period.calculation.components) { component in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(categoryLabel(component.category))
                                .font(.headline)
                            Spacer()
                            Text(LinePayFormat.money(component.amount))
                                .font(.headline.monospacedDigit())
                        }
                        HStack(spacing: LinePaySpacing.compact) {
                            Text(LinePayFormat.localDate(component.localDate))
                            if let hours = component.hours {
                                Text("\(LinePayFormat.hours(hours)) h").monospacedDigit()
                            }
                            if let multiplier = component.multiplier {
                                Text("\(LinePayFormat.decimal(multiplier))×").monospacedDigit()
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(LinePayColor.textSecondary)
                        Text(component.explanation)
                            .font(.footnote)
                            .foregroundStyle(LinePayColor.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let paystub = period.paystub {
                Section("Audit") {
                    NavigationLink("Open paycheck audit") {
                        AuditDetailView(
                            window: period.window,
                            timeZoneIdentifier: model.profile?.timeZoneIdentifier
                                ?? TimeZone.current.identifier,
                            agreement: period.agreement,
                            calculation: period.calculation,
                            paystub: paystub,
                            reconciliation: period.reconciliation,
                            findings: model.auditFindings(
                                calculation: period.calculation,
                                paystub: paystub
                            ),
                            evidenceURL: paystub.evidence.flatMap(model.evidenceURL),
                            onRemoveEvidence: paystub.evidence == nil
                                ? nil
                                : { try model.removeHistoricalPaystubEvidence(periodID: period.id) }
                        )
                    }
                }
            }

            Section("Work facts") {
                ForEach(period.workEntries) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workKindLabel(entry.interval.kind))
                            .font(.headline)
                        Text(LinePayFormat.workDateRange(entry.interval))
                            .font(.footnote)
                        HStack(spacing: LinePaySpacing.compact) {
                            Text("\(LinePayFormat.hours(entry.interval.durationHours)) h paid work")
                                .monospacedDigit()
                            if let breakText = LinePayFormat.breakDuration(entry.interval) {
                                Text("· \(breakText)")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(LinePayColor.textSecondary)
                        if !entry.note.isEmpty {
                            Text(entry.note)
                                .font(.footnote)
                                .foregroundStyle(LinePayColor.textSecondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }

            Section("Export") {
                if let reportURL {
                    ShareLink(item: reportURL) {
                        Label("Share reconciliation report", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        prepareReport()
                    } label: {
                        Label("Prepare report", systemImage: "doc.richtext")
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete pay period", systemImage: "trash")
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Pay period")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this pay period?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete pay period", role: .destructive) { deletePeriod() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This permanently deletes the historical snapshot and its stored paystub evidence.")
        }
    }

    private func prepareReport() {
        do {
            reportURL = try ReconciliationReportExporter().export(
                window: period.window,
                timeZoneIdentifier: model.profile?.timeZoneIdentifier
                    ?? TimeZone.current.identifier,
                agreement: period.agreement,
                calculation: period.calculation,
                paystub: period.paystub,
                reconciliation: period.reconciliation,
                findings: period.paystub.map {
                    model.auditFindings(calculation: period.calculation, paystub: $0)
                } ?? []
            )
        } catch {
            errorMessage = "LinePaycheck could not prepare the report."
        }
    }

    private func deletePeriod() {
        do {
            try model.deleteHistoryPeriod(id: period.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func categoryLabel(_ category: PayComponentCategory) -> String {
        switch category {
        case .workedHours: "Worked hours"
        case .calloutGuarantee: "Callout guarantee"
        case .perDiem: "Per diem"
        }
    }

    private func workKindLabel(_ kind: WorkKind) -> String {
        switch kind {
        case .regular: "Regular work"
        case .callout: "Callout"
        case .other: "Other work"
        }
    }
}
