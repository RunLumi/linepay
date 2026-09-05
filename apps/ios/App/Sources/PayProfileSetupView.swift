import SwiftUI

struct PayProfileSetupView: View {
    let model: AppModel
    let isEditing: Bool
    let showsIntro: Bool
    let onSaved: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: PayProfileDraft
    @State private var errorMessage: String?

    init(
        model: AppModel,
        draft: PayProfileDraft = PayProfileDraft(),
        isEditing: Bool = false,
        showsIntro: Bool = true,
        onSaved: (() -> Void)? = nil
    ) {
        self.model = model
        self.isEditing = isEditing
        self.showsIntro = showsIntro
        self.onSaved = onSaved
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LinePaySpacing.spacious) {
                    if showsIntro && !isEditing {
                        intro
                    }

                    identitySection
                    basePaySection
                    overtimeSection
                    sundaySection
                    calloutSection
                    perDiemSection

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }

                    Button(isEditing ? "Save pay rules" : "Save my pay rules") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(LinePayColor.brandPrimary)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("pay-profile.save")
                    .accessibilityHint(
                        "Saves the rules you entered and uses them for expected pay calculations"
                    )
                }
                .padding(LinePaySpacing.section)
            }
            .background(LinePayColor.canvas)
            .navigationTitle(isEditing ? "Pay rules" : "Set up your pay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .tint(LinePayColor.brandPrimary)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            Text("Know what your work should pay.")
                .font(.largeTitle.bold())
                .foregroundStyle(LinePayColor.textPrimary)

            Text(
                "LinePay calculates from the rules you confirm. Optional rules stay off until "
                    + "you turn them on. Your pay data stays on this device by default."
            )
            .font(.body)
            .foregroundStyle(LinePayColor.textSecondary)

            LineGapMark()
        }
    }

    private var identitySection: some View {
        ruleSection(title: "Profile") {
            TextField("Current contractor or agreement", text: $draft.name)
                .textContentType(.organizationName)
                .textFieldStyle(.roundedBorder)

            Picker("Work timezone", selection: $draft.timeZoneIdentifier) {
                ForEach(Self.timeZones, id: \.self) { identifier in
                    Text(Self.timeZoneLabel(identifier)).tag(identifier)
                }
            }
        }
    }

    private var basePaySection: some View {
        ruleSection(title: "Base pay") {
            LabeledContent("Hourly rate") {
                TextField("58.40", text: $draft.hourlyRate)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Hourly rate in US dollars")
                    .accessibilityIdentifier("pay-profile.hourly-rate")
            }

            Text("USD for the initial US release. LinePay stores currency with each amount.")
                .font(.footnote)
                .foregroundStyle(LinePayColor.textSecondary)
        }
    }

    private var overtimeSection: some View {
        ruleSection(title: "Daily overtime") {
            Toggle("Use a daily overtime tier", isOn: $draft.useDailyOvertime)
                .tint(LinePayColor.brandPrimary)

            if draft.useDailyOvertime {
                decimalField("After hours", text: $draft.overtimeAfterHours, placeholder: "8")
                decimalField(
                    "Multiplier",
                    text: $draft.overtimeMultiplier,
                    placeholder: "1.5"
                )
            }
        }
    }

    private var sundaySection: some View {
        ruleSection(title: "Sunday") {
            Toggle("Use a Sunday premium", isOn: $draft.useSundayPremium)
                .tint(LinePayColor.brandPrimary)

            if draft.useSundayPremium {
                decimalField(
                    "Multiplier",
                    text: $draft.sundayMultiplier,
                    placeholder: "2"
                )
            }
        }
    }

    private var calloutSection: some View {
        ruleSection(title: "Callouts") {
            Toggle("Use a callout minimum", isOn: $draft.useCalloutMinimum)
                .tint(LinePayColor.brandPrimary)

            if draft.useCalloutMinimum {
                decimalField(
                    "Minimum paid hours",
                    text: $draft.calloutMinimumHours,
                    placeholder: "4"
                )
            }
        }
    }

    private var perDiemSection: some View {
        ruleSection(title: "Per diem") {
            Toggle("Add a flat per diem for each worked local date", isOn: $draft.usePerDiem)
                .tint(LinePayColor.brandPrimary)

            if draft.usePerDiem {
                decimalField(
                    "Amount per worked date",
                    text: $draft.perDiemAmount,
                    placeholder: "125"
                )
            }
        }
    }

    private func ruleSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: LinePaySpacing.standard) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(LinePayColor.textSecondary)

            content()

            Divider()
        }
    }

    private func decimalField(
        _ label: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        LabeledContent(label) {
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func save() {
        do {
            try model.saveProfile(draft)
            errorMessage = nil
            if isEditing {
                dismiss()
            } else {
                onSaved?()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static let timeZones = [
        "America/Los_Angeles",
        "America/Denver",
        "America/Phoenix",
        "America/Chicago",
        "America/New_York",
        "America/Anchorage",
        "Pacific/Honolulu",
    ]

    private static func timeZoneLabel(_ identifier: String) -> String {
        switch identifier {
        case "America/Los_Angeles": "Pacific"
        case "America/Denver": "Mountain"
        case "America/Phoenix": "Arizona"
        case "America/Chicago": "Central"
        case "America/New_York": "Eastern"
        case "America/Anchorage": "Alaska"
        case "Pacific/Honolulu": "Hawaii"
        default: identifier
        }
    }
}

struct LineGapMark: View {
    var body: some View {
        HStack(spacing: 7) {
            Rectangle()
                .frame(width: 62, height: 2)
            Rectangle()
                .frame(width: 34, height: 2)
        }
        .foregroundStyle(LinePayColor.brandCopper)
        .accessibilityHidden(true)
    }
}
