import SwiftUI
import UIKit
import XCTest
@testable import Ringify

@MainActor final class StudioPresentationTests: XCTestCase {
    func testAdaptivePaletteResolvesOnBackgroundExecutorInBothAppearances() async {
        let colors = [RingifyTheme.Studio.background, RingifyTheme.Studio.surface,
            RingifyTheme.Studio.raised, RingifyTheme.Studio.text, RingifyTheme.Studio.secondary,
            RingifyTheme.Studio.muted, RingifyTheme.Studio.accent, RingifyTheme.Studio.soft,
            RingifyTheme.Studio.border, RingifyTheme.Studio.strongBorder].map { UIColor($0) }
        let result = await Task.detached {
            var channels: [[CGFloat]] = []
            for style in [UIUserInterfaceStyle.light, .dark] {
                let traits = UITraitCollection(userInterfaceStyle: style)
                for color in colors {
                    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                    let valid = color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                    channels.append(valid ? [red, green, blue, alpha] : [])
                }
            }
            return (!Thread.isMainThread, channels)
        }.value
        XCTAssertTrue(result.0, "Must exercise the off-main resolution that triggered the real crash")
        XCTAssertEqual(result.1.count, 20)
        for channels in result.1 {
            XCTAssertEqual(channels.count, 4)
            XCTAssertTrue(channels.allSatisfy { $0.isFinite && (0...1).contains($0) })
            XCTAssertEqual(channels.last, 1)
        }
        for index in 0..<10 { XCTAssertNotEqual(result.1[index], result.1[index + 10]) }
    }

    private func luminance(_ color: Color, style: UIUserInterfaceStyle) -> Double {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(alpha, 1, accuracy: 0.0001)
        let channels = [red, green, blue].map { channel -> Double in
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
    }
    private func contrast(_ a: Color, _ b: Color, style: UIUserInterfaceStyle) -> Double {
        let x = luminance(a, style: style), y = luminance(b, style: style)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
    func testAdaptiveTextAndSelectedControlsMeetContrastInBothAppearances() {
        for appearance in [UIUserInterfaceStyle.light, .dark] {
            for foreground in [RingifyTheme.Studio.text, RingifyTheme.Studio.secondary, RingifyTheme.Studio.muted, RingifyTheme.Studio.accent] {
                XCTAssertGreaterThanOrEqual(contrast(foreground, RingifyTheme.Studio.surface, style: appearance), 4.5)
            }
            XCTAssertGreaterThanOrEqual(contrast(RingifyTheme.Studio.accent, RingifyTheme.Studio.soft, style: appearance), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(.white, RingifyTheme.Studio.action, style: appearance), 4.5)
        }
    }
    func testTimelineAndWaveRemainReadableOnInkCanvasInBothAppearances() {
        for appearance in [UIUserInterfaceStyle.light, .dark] {
            XCTAssertGreaterThanOrEqual(contrast(RingifyTheme.Studio.canvasSecondary, RingifyTheme.Studio.canvas, style: appearance), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(RingifyTheme.Studio.wave, RingifyTheme.Studio.canvas, style: appearance), 3)
        }
    }
    func testUnscopedPresentationKeepsTheApprovedClassicPalette() {
        XCTAssertEqual(EnvironmentValues().ringifyVisualStyle, .classic)
        for appearance in [UIUserInterfaceStyle.light, .dark] {
            XCTAssertEqual(luminance(RingifyVisualStyle.classic.accent, style: appearance),
                           luminance(RingifyTheme.AppleV2.accent, style: appearance), accuracy: 0.0001)
        }
    }
    func testHelpSearchUsesTurkishCaseFoldingAndFormatKeywords() {
        let locale = Locale(identifier: "tr_TR")
        XCTAssertTrue(RingifyHelpTopic.permissions.matches(query: "  MİKROFON ", localizedTitle: "Mikrofon ve izinler", locale: locale))
        XCTAssertTrue(RingifyHelpTopic.permissions.matches(query: "MI\u{0307}KROFON", localizedTitle: "Mikrofon ve izinler", locale: locale))
        XCTAssertTrue(RingifyHelpTopic.permissions.matches(query: "KAYIT", localizedTitle: "Mikrofon ve izinler", locale: locale))
        XCTAssertTrue(RingifyHelpTopic.formats.matches(query: "BİÇİMLER", localizedTitle: "Desteklenen biçimler", locale: locale))
        XCTAssertTrue(RingifyHelpTopic.formats.matches(query: "MP3", localizedTitle: "Desteklenen biçimler", locale: locale))
        XCTAssertFalse(RingifyHelpTopic.permissions.matches(query: "mp3", localizedTitle: "Mikrofon ve izinler", locale: locale))
        XCTAssertTrue(RingifyHelpTopic.storage.matches(query: "  ", localizedTitle: "Depolama", locale: locale))
    }
    func testHelpCategoryMembershipDoesNotLeakUnrelatedTopics() {
        XCTAssertTrue(RingifyHelpCategory.files.includes(.storage))
        XCTAssertFalse(RingifyHelpCategory.pro.includes(.storage))
        XCTAssertTrue(RingifyHelpCategory.all.includes(.permissions))
    }
}
