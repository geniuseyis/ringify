import SwiftUI
import UIKit

enum RingifyTheme {
    // Mirrors design/tokens.json so the native app and Windows preview stay visually aligned.
    static let accent = Color(red: 0.451, green: 0.341, blue: 1.0)
    static let accentSecondary = Color(red: 0.694, green: 0.361, blue: 1.0)
    static let success = Color(red: 0.17, green: 0.68, blue: 0.48)
    static let warning = Color(red: 0.95, green: 0.61, blue: 0.16)
    static let danger = Color(red: 0.91, green: 0.25, blue: 0.31)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let elevatedSurface = Color(uiColor: .tertiarySystemBackground)
    static let pageBackground = Color(uiColor: .systemGroupedBackground)

    static let horizontalPadding: CGFloat = 20
    static let cornerRadius: CGFloat = 22

    static let brandGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Scoped adapter for design/tokens.json.appleV2. Home retains the approved
    // Ringify 2.0 brand; Studio uses these semantic Apple V2 content/control roles.
    enum AppleV2 {
        // design/tokens.json motion.quick, milliseconds -> seconds.
        static let controlPressDuration = 0.16
        static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        static let action = Color(red: 101 / 255.0, green: 67 / 255.0, blue: 213 / 255.0)
        static let accent = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 188 / 255.0, green: 165 / 255.0, blue: 1, alpha: 1)
                : UIColor(red: 98 / 255.0, green: 66 / 255.0, blue: 206 / 255.0, alpha: 1)
        })
        static let wave = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 196 / 255.0, green: 174 / 255.0, blue: 1, alpha: 1)
                : UIColor(red: 114 / 255.0, green: 79 / 255.0, blue: 208 / 255.0, alpha: 1)
        })
        static let cardRadius: CGFloat = 14
        static let controlRadius: CGFloat = 12
    }
}

struct RingifyCardModifier: ViewModifier {
    @Environment(\.ringifyVisualStyle) private var style
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(style == .studio ? RingifyTheme.Studio.surface : RingifyTheme.surface,
                        in: RoundedRectangle(cornerRadius: style == .studio ? 20 : RingifyTheme.cornerRadius))
            .overlay {
                if style == .studio {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(contrast == .increased ? RingifyTheme.Studio.strongBorder : RingifyTheme.Studio.border)
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func ringifyCard() -> some View { modifier(RingifyCardModifier()) }
}
