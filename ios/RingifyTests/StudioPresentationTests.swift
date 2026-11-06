import SwiftUI
import UIKit
import XCTest
@testable import Ringify

private enum BackgroundPaletteResolution {
    // UIKit references stay inside this synchronous call. Only Sendable Color
    // values cross the task boundary; the thread cannot change mid-resolution.
    static func resolve(_ colors: [Color]) -> (Bool, [[CGFloat]]) {
        var channels: [[CGFloat]] = []
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for value in colors {
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                let valid = UIColor(value).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                channels.append(valid ? [red, green, blue, alpha] : [])
            }
        }
        return (!Thread.isMainThread, channels)
    }
}

@MainActor final class StudioPresentationTests: XCTestCase {
    func testSemanticPaletteResolvesOnBackgroundExecutorInBothAppearances() async {
        let colors = [RingifyTheme.background, RingifyTheme.surface, RingifyTheme.action]
        let result = await Task.detached { BackgroundPaletteResolution.resolve(colors) }.value
        XCTAssertTrue(result.0, "Must exercise the off-main resolution that triggered the real crash")
        XCTAssertEqual(result.1.count, 6)
        for channels in result.1 {
            XCTAssertEqual(channels.count, 4)
            XCTAssertTrue(channels.allSatisfy { $0.isFinite && (0...1).contains($0) })
            XCTAssertEqual(channels.last, 1)
        }
        // Grouped backgrounds follow the system appearance.
        XCTAssertNotEqual(result.1[0], result.1[3])
        XCTAssertNotEqual(result.1[1], result.1[4])
    }

    private func luminance(_ color: UIColor, style: UIUserInterfaceStyle) -> Double {
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(alpha, 1, accuracy: 0.0001)
        let channels = [red, green, blue].map { channel -> Double in
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
    }
    private func contrast(_ a: UIColor, _ b: UIColor, style: UIUserInterfaceStyle) -> Double {
        let x = luminance(a, style: style), y = luminance(b, style: style)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
    func testMonochromeActionLabelMeetsContrastAndActionFlipsWithAppearance() throws {
        let fill = try XCTUnwrap(UIColor(named: "ActionFill", in: .main, compatibleWith: nil))
        let label = try XCTUnwrap(UIColor(named: "ActionLabel", in: .main, compatibleWith: nil))
        for appearance in [UIUserInterfaceStyle.light, .dark] {
            XCTAssertGreaterThanOrEqual(contrast(label, fill, style: appearance), 7)
            // The fill must also stand out from the page it sits on.
            XCTAssertGreaterThanOrEqual(contrast(fill, .systemGroupedBackground, style: appearance), 7)
        }
        XCTAssertLessThan(luminance(fill, style: .light), luminance(fill, style: .dark))
    }

    func testHeroCanvasKeepsWhiteTextReadableInBothAppearances() throws {
        let canvas = try XCTUnwrap(UIColor(named: "HeroCanvas", in: .main, compatibleWith: nil))
        for appearance in [UIUserInterfaceStyle.light, .dark] {
            XCTAssertGreaterThanOrEqual(contrast(.white, canvas, style: appearance), 7)
        }
    }
    func testAccentAssetIsReadableOnGroupedBackgroundsAndAdaptsToAppearance() throws {
        let accent = try XCTUnwrap(UIColor(named: "AccentColor", in: .main, compatibleWith: nil))
        for appearance in [UIUserInterfaceStyle.light, .dark] {
            for background in [UIColor.systemGroupedBackground, .secondarySystemGroupedBackground] {
                XCTAssertGreaterThanOrEqual(contrast(accent, background, style: appearance), 4.5)
            }
        }
        XCTAssertNotEqual(luminance(accent, style: .light), luminance(accent, style: .dark), accuracy: 0.01)
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
