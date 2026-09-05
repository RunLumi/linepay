import LinePayDomain
import SwiftUI

struct PayLedgerView: View {
    let model: AppModel

    @State private var showingAddWork = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LinePaySpacing.spacious) {
                    ledgerHeader

                    if let calculation = model.calculation, !calculation.components.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(calculation.components) { component in
                                ledgerRow(component)
                                Divider()
                            }
                        }
                    } else {
                        emptyState
                    }
                }
                .padding(LinePaySpacing.section)
            }
            .background(LinePayColor.canvas)
            .navigationTitle("Pay")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddWork = true
                    } label: {
                        Label("Add work", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddWork) {
            AddWorkView(model: model)
        }
    }

    private var ledgerHeader: some View {
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

            HStack(spacing: LinePaySpacing.standard) {
                Text("\(LinePayFormat.hours(model.totalHours)) h")
                    .monospacedDigit()
                if let profile = model.profile {
                    Text(profile.name)
                }
            }
            .font(.footnote)
            .foregroundStyle(LinePayColor.textSecondary)

            HStack(spacing: 7) {
                Rectangle().frame(height: 1)
                Rectangle().frame(width: 26, height: 1)
            }
            .foregroundStyle(LinePayColor.brandCopper)
            .accessibilityHidden(true)
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
                        .foregroundStyle(LinePayColor.textPrimary)

                    HStack(spacing: LinePaySpacing.compact) {
                        Text(LinePayFormat.localDate(component.localDate))
                        if let hours = component.hours {
                            Text("\(LinePayFormat.hours(hours)) h")
                                .monospacedDigit()
                        }
                        if let multiplier = component.multiplier {
                            Text("\(LinePayFormat.decimal(multiplier))×")
                                .monospacedDigit()
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(LinePayColor.textSecondary)
                }

                Spacer(minLength: LinePaySpacing.standard)

                Text(LinePayFormat.money(component.amount))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(LinePayColor.textPrimary)
            }
            .padding(.vertical, LinePaySpacing.standard)
        }
        .tint(LinePayColor.brandPrimary)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            Text("Your ledger is empty")
                .font(.title3.bold())
                .foregroundStyle(LinePayColor.textPrimary)

            Text("Add the hours you actually worked. LinePay will break expected pay into traceable lines here.")
                .foregroundStyle(LinePayColor.textSecondary)

            Button {
                showingAddWork = true
            } label: {
                Label("Add work", systemImage: "plus")
                    .frame(minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(LinePayColor.brandPrimary)
        }
    }

    private var expectedPayText: String {
        guard let calculation = model.calculation else {
            return "$0.00"
        }
        return LinePayFormat.money(calculation.total)
    }

    private func categoryLabel(_ category: PayComponentCategory) -> String {
        switch category {
        case .workedHours: "Worked hours"
        case .calloutGuarantee: "Callout guarantee"
        case .perDiem: "Per diem"
        }
    }
}
