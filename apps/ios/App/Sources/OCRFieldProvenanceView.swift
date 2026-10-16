import SwiftUI

struct OCRFieldProvenanceView: View {
    let suggestion: OCRFieldSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Original OCR reading", value: suggestion.value ?? "No safe suggestion")
                .monospacedDigit()
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("paystub.ocr-original-reading")
            LabeledContent(
                "Source page",
                value: (0..<10_000).contains(suggestion.region.page)
                    ? String(suggestion.region.page + 1) : "Unavailable"
            )
            .monospacedDigit()
            LabeledContent("Text recognition confidence") {
                if suggestion.confidence.isFinite, (0...1).contains(suggestion.confidence) {
                    Text(suggestion.confidence, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                } else {
                    Text("Unavailable")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("paystub.ocr-confidence")
            Text(
                "This score describes the original text recognition. It does not verify the amount, period or pay rule. Check the original before confirming."
            )
            .font(.footnote)
            .foregroundStyle(LinePayColor.textSecondary)
            if let reason = suggestion.reason {
                Label(reason, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(LinePayColor.review)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paystub.ocr-provenance")
    }
}
