import SwiftUI
import UIKit

enum LinePayColor {
    static let canvas = dynamicColor(light: 0xF4F1E8, dark: 0x111417)
    static let surfacePrimary = dynamicColor(light: 0xFBFAF6, dark: 0x1A1F23)
    static let surfaceSecondary = dynamicColor(light: 0xE9E5DB, dark: 0x22282C)
    static let textPrimary = dynamicColor(light: 0x13171A, dark: 0xF4F1E8)
    static let textSecondary = dynamicColor(
        light: 0x5C6468, dark: 0xAAB2B6, highLight: 0x13171A, highDark: 0xF4F1E8)
    static let brandPrimary = dynamicColor(
        light: 0x0E746C, dark: 0x55C9BE, highLight: 0x064C47, highDark: 0x8AE1D5)
    static let actionText = dynamicColor(
        light: 0x0B6D66, dark: 0x55C9BE, highLight: 0x063E3A, highDark: 0x8AE1D5)
    static let actionOnFill = dynamicColor(light: 0xFFFFFF, dark: 0x111417)
    static let review = dynamicColor(light: 0x7D5700, dark: 0xF2C66D)
    static let difference = dynamicColor(light: 0xB13C35, dark: 0xFFB4AB)
    static let match = dynamicColor(light: 0x276749, dark: 0x88D5A6)
    static let information = dynamicColor(light: 0x2C5F90, dark: 0xA7C8F5)
    static let brandCopper = dynamicColor(light: 0xA94E25, dark: 0xE48A59)

    private static func dynamicColor(
        light: UInt32, dark: UInt32, highLight: UInt32? = nil, highDark: UInt32? = nil
    ) -> Color {
        Color(
            uiColor: UIColor { traits in
                let isDark = traits.userInterfaceStyle == .dark
                if traits.accessibilityContrast == .high {
                    return UIColor(rgb: isDark ? (highDark ?? dark) : (highLight ?? light))
                }
                return UIColor(rgb: isDark ? dark : light)
            }
        )
    }
}

extension UIColor {
    fileprivate convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum LinePaySpacing {
    static let compact: CGFloat = 8
    static let standard: CGFloat = 16
    static let section: CGFloat = 24
    static let spacious: CGFloat = 32
}

/// Keeps exact values readable when a row no longer has room for two columns.
struct LinePayValueStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: LinePaySpacing.standard) {
                configuration.label.fixedSize()
                Spacer(minLength: 0)
                configuration.content.fixedSize()
            }
            VStack(alignment: .leading, spacing: LinePaySpacing.compact) {
                configuration.label
                configuration.content
                    .foregroundStyle(LinePayColor.textPrimary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct LinePayPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, LinePaySpacing.standard)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(isEnabled ? LinePayColor.actionOnFill : LinePayColor.textSecondary)
            .background(isEnabled ? LinePayColor.brandPrimary : LinePayColor.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// A persistent label prevents a typed amount from losing its meaning.
struct LinePayTextField: View {
    let title: String
    @Binding var text: String
    let focus: FocusState<String?>.Binding
    let identifier: String

    init(
        _ title: String, text: Binding<String>, focus: FocusState<String?>.Binding,
        identifier: String = ""
    ) {
        self.title = title
        _text = text
        self.focus = focus
        self.identifier = identifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(LinePayColor.textSecondary)
                .accessibilityHidden(true)
            TextField("", text: $text, prompt: Text("Enter value"))
                .focused(focus, equals: identifier.isEmpty ? title : identifier)
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            focus.wrappedValue = identifier.isEmpty ? title : identifier
        }
    }
}
