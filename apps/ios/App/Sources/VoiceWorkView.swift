import LinePayDomain
import SwiftUI

struct VoiceWorkView: View {
    let timeZoneIdentifier: String
    let periodRange: ClosedRange<Date>?
    let onApply: (VoiceWorkProposal) -> Void
    @State private var day: Date
    @State private var capture = LocalVoiceCapture()
    @State private var reading = ""
    @State private var proposal: VoiceWorkProposal?
    @State private var confirmed = false
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(
        day: Date, timeZoneIdentifier: String, periodRange: ClosedRange<Date>?,
        onApply: @escaping (VoiceWorkProposal) -> Void
    ) {
        _day = State(initialValue: day)
        self.timeZoneIdentifier = timeZoneIdentifier
        self.periodRange = periodRange
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Review a work description") {
                    Text(
                        WorkReadingAvailability.recordingEnabled
                            ? "Record up to one minute in English. Recognition must run on this device; there is no server fallback. Audio is temporary, not an original work record. The reading is not saved until you use reviewed facts in the work editor."
                            : "Type or paste a short work description in English. Review the proposed dates, times and breaks before using them in the work editor. The draft cannot choose pay rules or save work for you."
                    )
                    Text(
                        "Example: ‘Regular from seven AM to three PM. No unpaid breaks.’ For overnight work, add ‘next day’ after the end time. For a break: ‘Unpaid break from noon to twelve thirty PM.’"
                    )
                    .font(.footnote)
                    if let periodRange {
                        DatePicker(
                            "Work starts on", selection: $day, in: periodRange,
                            displayedComponents: .date)
                    } else {
                        DatePicker("Work starts on", selection: $day, displayedComponents: .date)
                    }
                    Text("Payroll timezone: \(timeZoneIdentifier)").font(.footnote)
                    if WorkReadingAvailability.recordingEnabled {
                        if capture.phase == .recording {
                            Label("Recording — stops at one minute", systemImage: "mic.fill")
                            Button("Stop and read on this device") { capture.stopAndTranscribe() }
                                .accessibilityIdentifier("voice.stop")
                        } else if capture.busy {
                            ProgressView(
                                capture.phase == .permission
                                    ? "Waiting for permission" : "Reading on this device")
                            Button("Cancel recording") { capture.cancel() }
                        } else {
                            Button(reading.isEmpty ? "Record work" : "Record again") {
                                proposal = nil
                                confirmed = false
                                message = nil
                                Task { await capture.start() }
                            }.accessibilityIdentifier("voice.record")
                        }
                    }
                    if capture.cleanupIssue {
                        Label(
                            "Temporary audio cleanup is pending. The app retries at next launch; Delete all local data also retries removal. Exported pay backups exclude this audio.",
                            systemImage: "exclamationmark.triangle")
                    }
                    if let issue = capture.message {
                        Label(issue, systemImage: "exclamationmark.triangle")
                    }
                }
                Section("Edit the reading before review") {
                    TextField(
                        "Work type, clock times and unpaid breaks", text: $reading, axis: .vertical
                    )
                    .lineLimit(4...12).accessibilityIdentifier("voice.reading")
                    .disabled(capture.busy)
                    Text(
                        "Use AM/PM or 24-hour times. State every unpaid break or ‘no unpaid breaks’. Unclear wording, missing facts and repeated or nonexistent daylight-saving times require manual entry. Speech does not choose overtime, rates or callout guarantees."
                    )
                    .font(.footnote)
                    Button("Review clock facts") {
                        do {
                            let candidate = try VoiceWorkProposal.parse(
                                reading, day: day,
                                timeZoneIdentifier: timeZoneIdentifier)
                            if let periodRange, !periodRange.contains(candidate.start) {
                                throw AppModelError.workOutsideCurrentPayPeriod
                            }
                            proposal = candidate
                            confirmed = false
                            message = nil
                        } catch {
                            proposal = nil
                            message = error.localizedDescription
                        }
                    }
                    .disabled(
                        reading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || capture.busy
                    )
                    .accessibilityIdentifier("voice.review")
                }
                if let proposal {
                    Section("Proposed work facts — not saved") {
                        LabeledContent("Work type", value: proposal.kind.rawValue.capitalized)
                        LabeledContent("Start") { timestamp(proposal.start) }
                        LabeledContent("End") { timestamp(proposal.end) }
                        if proposal.breaks.isEmpty { Text("No unpaid breaks") }
                        ForEach(proposal.breaks.indices, id: \.self) { index in
                            LabeledContent("Unpaid break \(index + 1)") {
                                VStack(alignment: .trailing) {
                                    timestamp(proposal.breaks[index].start)
                                    timestamp(proposal.breaks[index].end)
                                }
                            }
                        }
                        ConfirmationCheckRow(
                            "I confirm the dates, times, work type and every unpaid break",
                            isOn: $confirmed
                        )
                        .accessibilityIdentifier("voice.confirm")
                        Text(
                            "Using these facts replaces this editor's times, work type and breaks. Your note stays. Review overlaps and callout event choices in the editor, then choose Save work yourself."
                        )
                        .font(.footnote)
                    }
                }
                if let message {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("voice.error")
                    }
                }
            }
            .labeledContentStyle(LinePayValueStyle()).linePayCanvas().linePayKeyboardDismiss()
            .navigationTitle("Work notes draft").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        capture.cancel()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                LinePayBottomBar {
                    Button("Use reviewed facts") {
                        guard confirmed, let proposal, !capture.busy else { return }
                        capture.cancel()
                        onApply(proposal)
                        dismiss()
                    }.buttonStyle(LinePayPrimaryButtonStyle())
                        .disabled(!confirmed || proposal == nil || capture.busy)
                        .accessibilityIdentifier("voice.apply")
                }
            }
        }
        .environment(\.timeZone, TimeZone(identifier: timeZoneIdentifier) ?? .gmt)
        .tint(LinePayColor.actionText)
        .onChange(of: capture.phase) { _, value in
            if value == .finished { reading = capture.text }
        }
        .onChange(of: reading) { _, _ in
            proposal = nil
            confirmed = false
        }
        .onChange(of: day) { _, _ in
            proposal = nil
            confirmed = false
        }
        .onChange(of: scenePhase) { _, value in
            if value == .background || (value == .inactive && capture.phase == .recording) {
                capture.cancel()
                message =
                    "Voice capture stopped when the app left the foreground. No facts were applied."
            }
        }
        .onDisappear { capture.cancel() }
    }

    private func timestamp(_ date: Date) -> some View {
        var style = Date.FormatStyle.dateTime.year().month(.abbreviated).day().hour().minute()
            .timeZone(.specificName(.short))
        style.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .gmt
        return Text(date.formatted(style)).monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }
}
