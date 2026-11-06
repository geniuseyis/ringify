import SwiftUI
import UIKit

// Ringify follows the system. Backgrounds, labels, separators and materials are
// iOS semantic colors, so Light, Dark, Increase Contrast and future system looks
// work without a custom palette. Only the brand values below belong to Ringify;
// they mirror design/tokens.json.appleNative. Asset and static colors need no
// UIColor provider closure, which is what crashed on SwiftUI's AsyncRenderer.
enum RingifyTheme {
    /// AccentColor asset: monochrome system tint (near-black in Light, near-white
    /// in Dark). Lists, links, toggles and the tab bar follow it, so the app reads
    /// black and white by default.
    static let accent = Color.accentColor
    /// BrandViolet asset: the only violet in the app. Reserved for the waveform and
    /// its selection, the Home glow and the Pro mark. Do not use it for controls.
    static let violet = Color("BrandViolet")
    /// ActionFill asset: near-black in Light, near-white in Dark (Vercel-style
    /// monochrome primary actions). Always pair it with `onAction`.
    static let action = Color("ActionFill")
    /// ActionLabel asset: the label on `action` (white in Light, near-black in Dark).
    static let onAction = Color("ActionLabel")
    /// HeroCanvas asset: the dark brand card on Home. Near-black in Light, lifted
    /// in Dark so it still reads as a card on a black page. Content on it is white.
    static let heroCanvas = Color("HeroCanvas")
    /// Hairline for outlined cards and tiles.
    static let hairline = Color(uiColor: .separator)

    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
    static let record = Color.red

    /// Page behind grouped content and behind `ringifyCard()`.
    static let background = Color(uiColor: .systemGroupedBackground)
    /// Same surface an inset grouped List row uses.
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    /// Quiet fill for thumbnails and the waveform editor's lane.
    static let subtleFill = Color(uiColor: .tertiarySystemFill)

    /// Matches the inset grouped List margin, so cards and lists share one edge.
    static let horizontalPadding: CGFloat = 16

    /// Matches the system's inset grouped corner, so cards and lists look like one family.
    static var cardRadius: CGFloat {
        if #available(iOS 26, *) { return 26 }
        return 10
    }

    /// Brand mark only: the launch screen. Never a content or control background.
    static let brandGradient = LinearGradient(
        colors: [
            Color(red: 0.451, green: 0.341, blue: 1.0),
            Color(red: 0.694, green: 0.361, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
