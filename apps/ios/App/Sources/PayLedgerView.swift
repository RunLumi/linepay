import LinePayDomain
import SwiftUI

struct PayLedgerView: View {
    let model: AppModel
    let subscriptionStore: SubscriptionStore

    @State private var showingAddWork = false
    @State private var showingPaystubImport = false
    @State private var showingPaywall = false
    @State private var showingFinishConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LinePaySpacing.spacious) {
                    if let active = model.activePeriod {
                        ledgerHeader(active)
                        paycheckSection(active)
                        ledgerSection
                        finishSection
                    } else {
                        noActivePeriod
                    }
                }
                .padding(LinePaySpacing.section)
            }
            .background(LinePayColor.canvas)
            .navigationTitle("Pay")
            .toolbar {
                if model.activePeriod != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingAddWork = true
                        } label: {
                            Label("Add work", systemImage: "plus")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddWork) {
            AddWorkView(model: model)
        }
        .sheet(isPresented: $showingPaystubImport) {
            PaystubImportView(model: model) {}
        }
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(store: subscriptionStore) {
                showingPaywall = false
            }
        }
        .confirmationDialog(
            "Finish this pay period?",
            isPresented: $showingFinishConfirmation,
            titleVisibility: .visible
        ) {
            Button("Finish and archive") { archive() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "LinePaycheck saves an immutable snapshot of these work facts, rules, calculations, and audit results."
            )
        }
    }

    private func ledgerHeader(_ active: ActivePayPeriod) -> some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
            Text("EXPECTED GROSS")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(LinePayColor.textSecondary)

            Text(expectedPayText)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(LinePayColor.textPrimary)
                .minimumScaleFactor(0.75)

            Text(
                LinePayFormat.payPeriod(
                    active.window,
                    timeZoneIdentifier: model.currentTimeZoneIdentifier
                )
            )
            .font(.subheadline)
            .foregroundStyle(LinePayColor.textSecondary)

            HStack(spacing: LinePaySpacing.standard) {
                Text("\(LinePayFormat.hours(model.totalHours)) h")
                    .monospacedDigit()
                Text("Rule v\(active.agreement.version)")
            }
            .font(.footnote)
            .foregroundStyle(LinePayColor.textSecondary)

            LineGapMark()
        }
    }

    private func paycheckSection(_ active: ActivePayPeriod) -> some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            Text("PAYCHECK")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(LinePayColor.textSecondary)

            if let paystub = active.paystub, let calculation = model.calculation {
                NavigationLink {
                    AuditDetailView(
                        window: active.window,
                        timeZoneIdentifier: model.currentTimeZoneIdentifier,
                        agreement: active.agreement,
                        calculation: calculation,
                        paystub: paystub,
                        reconciliation: active.reconciliation,
                        findings: model.auditFindings(calculation: calculation, paystub: paystub),
                        evidenceURL: paystub.evidence.flatMap(model.evidenceURL),
                        onRemoveEvidence: paystub.evidence == nil
                            ? nil
                            : { try model.removeCurrentPaystubEvidence() }
                    )
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            AuditStatusView(status: model.currentAuditStatus)
                            HStack(spacing: LinePaySpacing.compact) {
                                Text("Expected \(LinePayFormat.money(calculation.total))")
                                Text("·")
                                Text("Paid \(LinePayFormat.money(paystub.grossPay))")
                            }
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(LinePayColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(LinePayColor.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if active.reconciliation == nil {
                    Button {
                        rerunAudit(active: active, paystub: paystub)
                    } label: {
                        Label("Re-run audit with current work", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                } else if model.hasUsedFreeAudit, !subscriptionStore.isPro,
                    SubscriptionStore.commerceEnabled
                {
                    Button {
                        showingPaywall = true
                    } label: {
                        Label("Keep auditing with Pro", systemImage: "checkmark.shield")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }

                Button("Replace or correct paycheck") {
                    beginPaycheckEntry()
                }
                .frame(minHeight: 44)
            } else {
                Text("When the paycheck arrives, compare it with this exact work ledger.")
                    .foregroundStyle(LinePayColor.textSecondary)

                Button {
                    beginPaycheckEntry()
                } label: {
                    Label(
                        model.hasUsedFreeAudit ? "Audit paycheck" : "Audit first paycheck free",
                        systemImage: "doc.text.magnifyingglass"
                    )
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(LinePayColor.brandPrimary)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    private var ledgerSection: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            Text("PAY LEDGER")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(LinePayColor.textSecondary)

            if let calculation = model.calculation, !calculation.components.isEmpty {
                VStack(spacing: 0) {
                    ForEach(calculation.components) { component in
                        ledgerRow(component)
                        Divider()
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
                    Text("Your ledger is empty")
                        .font(.title3.bold())
                    Text(
                        "Add actual work and LinePaycheck will turn it into explainable pay components."
                    )
                    .foregroundStyle(LinePayColor.textSecondary)
                }
            }
        }
    }

    private var finishSection: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            Divider()
            Button {
                showingFinishConfirmation = true
            } label: {
                Label("Finish pay period", systemImage: "archivebox")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
            Text(
                "Finishing creates an immutable historical snapshot. It does not require a paystub audit."
            )
            .font(.footnote)
            .foregroundStyle(LinePayColor.textSecondary)
        }
    }

    private var noActivePeriod: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            Text("No active pay period")
                .font(.title2.bold())
            Text("Start the next manual pay period from Today before logging more work.")
                .foregroundStyle(LinePayColor.textSecondary)
        }
    }

    private func ledgerRow(_ component: PayComponent) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
                LabeledContent("Work date", value: LinePayFormat.localDate(component.localDate))
                if let hours = component.hours {
                    LabeledContent("Hours", value: LinePayFormat.hours(hours))
                }
                if let multiplier = component.multiplier {
                    LabeledContent("Multiplier", value: "\(LinePayFormat.decimal(multiplier))×")
                }
                LabeledContent("Why") {
                    Text(component.explanation)
                        .multilineTextAlignment(.trailing)
                }
            }
            .font(.callout)
            .foregroundStyle(LinePayColor.textSecondary)
            .padding(.vertical, LinePaySpacing.standard)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: LinePaySpacing.standard) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(categoryLabel(component.category))
                        .font(.headline)
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
                }
                Spacer(minLength: LinePaySpacing.standard)
                Text(LinePayFormat.money(component.amount))
                    .font(.headline.monospacedDigit())
            }
            .padding(.vertical, LinePaySpacing.standard)
        }
        .tint(LinePayColor.brandPrimary)
    }

    private var expectedPayText: String {
        guard let calculation = model.calculation else { return "$0.00" }
        return LinePayFormat.money(calculation.total)
    }

    private func categoryLabel(_ category: PayComponentCategory) -> String {
        switch category {
        case .workedHours: "Worked hours"
        case .calloutGuarantee: "Callout guarantee"
        case .perDiem: "Per diem"
        }
    }

    private func beginPaycheckEntry() {
        if model.canRunAudit(hasProAccess: subscriptionStore.hasAuditAccess) {
            showingPaystubImport = true
        } else {
            showingPaywall = true
        }
    }

    private func rerunAudit(active: ActivePayPeriod, paystub: ConfirmedPaystub) {
        guard model.canRunAudit(hasProAccess: subscriptionStore.hasAuditAccess) else {
            showingPaywall = true
            return
        }

        var draft = PaystubConfirmationDraft()
        draft.payPeriodStartDate = active.window.startDate
        draft.payPeriodEndDate = active.window.displayEndDate
        draft.grossPay = LinePayFormat.decimal(paystub.grossPay.amount)
        draft.regularHours = paystub.regularHours.map(LinePayFormat.decimal) ?? ""
        draft.regularPay = paystub.regularPay.map { LinePayFormat.decimal($0.amount) } ?? ""
        draft.overtimeHours = paystub.overtimeHours.map(LinePayFormat.decimal) ?? ""
        draft.overtimePay = paystub.overtimePay.map { LinePayFormat.decimal($0.amount) } ?? ""
        draft.doubleTimeHours = paystub.doubleTimeHours.map(LinePayFormat.decimal) ?? ""
        draft.doubleTimePay = paystub.doubleTimePay.map { LinePayFormat.decimal($0.amount) } ?? ""
        draft.calloutPay = paystub.calloutPay.map { LinePayFormat.decimal($0.amount) } ?? ""
        draft.perDiemPay = paystub.perDiemPay.map { LinePayFormat.decimal($0.amount) } ?? ""
        draft.notes = paystub.notes

        if let evidence = paystub.evidence,
            let url = model.evidenceURL(for: evidence),
            let data = try? Data(contentsOf: url)
        {
            draft.sourceData = data
            draft.originalFilename = evidence.originalFilename
            draft.mediaType = evidence.mediaType
            draft.sourceKind = evidence.sourceKind
            draft.recognizedText = evidence.recognizedText
        }

        do {
            try model.confirmPaystub(draft)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archive() {
        do {
            try model.archiveCurrentPeriod()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
