import SwiftUI
import UIKit

// Presentation only. The classic default preserves approved launch/onboarding
// and project-operation sheets; modern screens opt in at their root.
enum RingifyVisualStyle: Sendable, Equatable {
    case classic
    case studio

    @MainActor var surface: Color { self == .studio ? RingifyTheme.Studio.surface : RingifyTheme.AppleV2.surface }
    @MainActor var accent: Color { self == .studio ? RingifyTheme.Studio.accent : RingifyTheme.AppleV2.accent }
    @MainActor var action: Color { self == .studio ? RingifyTheme.Studio.action : RingifyTheme.AppleV2.action }
    var cardRadius: CGFloat { self == .studio ? 20 : 14 }
    var controlRadius: CGFloat { self == .studio ? 14 : 12 }
}

private struct RingifyVisualStyleKey: EnvironmentKey {
    static let defaultValue: RingifyVisualStyle = .classic
}

extension EnvironmentValues {
    var ringifyVisualStyle: RingifyVisualStyle {
        get { self[RingifyVisualStyleKey.self] }
        set { self[RingifyVisualStyleKey.self] = newValue }
    }
}

extension RingifyTheme {
    @MainActor enum Studio {
        // design/tokens.json.appleVercel, sRGB semantic roles.
        static let background = adaptive(light: 0xF8F9FB, dark: 0x0A0A0B)
        static let surface = adaptive(light: 0xFFFFFF, dark: 0x141416)
        static let raised = adaptive(light: 0xF0F1F4, dark: 0x1D1D21)
        static let text = adaptive(light: 0x18181B, dark: 0xFAFAFA)
        static let secondary = adaptive(light: 0x61616C, dark: 0xB0B0BA)
        static let muted = adaptive(light: 0x72727D, dark: 0x9797A4)
        static let accent = adaptive(light: 0x643CDE, dark: 0xC2ADFF)
        static let soft = adaptive(light: 0xF0EBFF, dark: 0x292135)
        static let border = adaptive(light: 0xE0E1E6, dark: 0x303037)
        static let strongBorder = adaptive(light: 0xC4C5CF, dark: 0x555560)
        static let action = Color(uiColor: uiColor(0x7047EB))
        static let canvas = Color(uiColor: uiColor(0x151319))
        static let canvasBorder = Color(uiColor: uiColor(0x3D354B))
        static let canvasText = Color(uiColor: uiColor(0xFAFAFC))
        static let canvasSecondary = Color(uiColor: uiColor(0xC5BECE))
        static let wave = Color(uiColor: uiColor(0xC3A7FF))
        static let outsideWave = Color(uiColor: uiColor(0x84768F))
        static let heroRadius: CGFloat = 26
        static let cardRadius: CGFloat = 20
        static let controlRadius: CGFloat = 14

        private static func uiColor(_ hex: UInt32) -> UIColor {
            UIColor(red: Double((hex >> 16) & 255) / 255,
                    green: Double((hex >> 8) & 255) / 255,
                    blue: Double(hex & 255) / 255, alpha: 1)
        }

        nonisolated private static func adaptive(light: UInt32, dark: UInt32) -> Color {
            // UIKit/SwiftUI may resolve this provider on AsyncRenderer. The
            // factory and callback must not inherit MainActor isolation.
            let lightRGB = (Double((light >> 16) & 255) / 255, Double((light >> 8) & 255) / 255, Double(light & 255) / 255)
            let darkRGB = (Double((dark >> 16) & 255) / 255, Double((dark >> 8) & 255) / 255, Double(dark & 255) / 255)
            return Color(uiColor: UIColor { @Sendable traits in
                let rgb = traits.userInterfaceStyle == .dark ? darkRGB : lightRGB
                return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
            })
        }
    }
}

struct NativeStudioAppearance: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .environment(\.ringifyVisualStyle, .studio)
            .tint(RingifyTheme.Studio.accent)
            .background(RingifyTheme.Studio.background)
    }
}

extension View {
    func ringifyStudioAppearance() -> some View { modifier(NativeStudioAppearance()) }
}
