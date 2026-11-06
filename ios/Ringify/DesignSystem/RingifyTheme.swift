import SwiftUI
import UIKit

// Ringify follows the system. Backgrounds, labels, separators and materials are
// iOS semantic colors, so Light, Dark, Increase Contrast and future system looks
// work without a custom palette. Only the brand values below belong to Ringify;
// they mirror design/tokens.json.appleNative. Asset and static colors need no
// UIColor provider closure, which is what crashed on SwiftUI's AsyncRenderer.
enum RingifyTheme {
    /// AccentColor asset: adaptive brand violet for tint, links, selection and waveforms.
    /// The app relies on the global asset, so do not pass this to `.tint(_:)`:
    /// an explicit tint turns neutral bordered buttons into lilac pills.
    static let accent = Color.accentColor
    /// Fixed violet behind white labels (5.5:1) in both appearances.
    static let action = Color(red: 112 / 255, green: 71 / 255, blue: 235 / 255)

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
