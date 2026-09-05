import SwiftUI
import UIKit

enum LinePayColor {
    static let canvas = dynamicColor(light: 0xF4F1E8, dark: 0x111417)
    static let surfacePrimary = dynamicColor(light: 0xFBFAF6, dark: 0x1A1F23)
    static let surfaceSecondary = dynamicColor(light: 0xE9E5DB, dark: 0x22282C)
    static let textPrimary = dynamicColor(light: 0x13171A, dark: 0xF4F1E8)
    static let textSecondary = dynamicColor(
        light: 0x5C6468, dark: 0xAAB2B6, highLight: 0x343B40, highDark: 0xD9DFE2)
    static let brandPrimary = dynamicColor(light: 0x0E746C, dark: 0x55C9BE)
    static let onAction = dynamicColor(light: 0xFFFFFF, dark: 0x111417)
    static let review = dynamicColor(light: 0x7D5700, dark: 0xF2C66D)
    static let difference = dynamicColor(light: 0xB13C35, dark: 0xFFB4AB)
    static let match = dynamicColor(light: 0x276749, dark: 0x88D5A6)
    static let lineStrong = dynamicColor(
        light: 0x7A8388, dark: 0x75848D, highLight: 0x4A5358, highDark: 0xB5BEC3)
    static let brandCopper = dynamicColor(light: 0xA94E25, dark: 0xE48A59)

    private static func dynamicColor(
        light: UInt32, dark: UInt32, highLight: UInt32? = nil, highDark: UInt32? = nil
    ) -> Color {
        Color(
            uiColor: UIColor { traits in
                let isDark = traits.userInterfaceStyle == .dark
                let contrast = traits.accessibilityContrast == .high
                return UIColor(
                    rgb: isDark
                        ? (contrast ? highDark ?? dark : dark)
                        : (contrast ? highLight ?? light : light))
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
