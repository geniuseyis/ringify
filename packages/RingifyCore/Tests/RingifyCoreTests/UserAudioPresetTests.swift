import Foundation
import XCTest
@testable import RingifyCore

final class UserAudioPresetTests: XCTestCase {
    func testPresetRoundTripsAllSettingsWithoutAudioOrProjectIdentity() throws {
        let preset = UserAudioPreset(name: "Warm voice", effects: AudioEffectSettings(volume: 0.7, fadeInDuration: 0.5,
            normalize: true, studio: StudioAudioPreset.warm.settings))
        try preset.validate()
        let restored = try JSONDecoder().decode(UserAudioPreset.self, from: JSONEncoder().encode(preset))
        try restored.validate()
        XCTAssertEqual(restored, preset)
    }
    func testApplyingLimitsFadesToSelectionAndPreservesOtherEffects() throws {
        let preset = UserAudioPreset(name: "Short", effects: AudioEffectSettings(volume: 0.8, fadeInDuration: 4, fadeOutDuration: 3,
            studio: StudioAudioPreset.telephone.settings))
        let applied = try preset.applying(selectionDuration: 1, sampleRate: 48_000)
        XCTAssertEqual(applied.fadeInDuration, 0.5)
        XCTAssertEqual(applied.fadeOutDuration, 0.5)
        XCTAssertEqual(applied.volume, 0.8)
        XCTAssertEqual(applied.studio, preset.effects.studio)
        XCTAssertEqual(preset.effects.fadeInDuration, 4)
    }
    func testInvalidNameValuesAndActualNyquistFailSafely() {
        for preset in [UserAudioPreset(name: " ", effects: .neutral),
                       UserAudioPreset(name: "Invalid", effects: AudioEffectSettings(volume: .nan)),
                       UserAudioPreset(name: "Invalid", effects: AudioEffectSettings(fadeOutDuration: 6))] {
            XCTAssertThrowsError(try preset.validate())
        }
        let preset = UserAudioPreset(name: "Clear", effects: AudioEffectSettings(studio: StudioAudioPreset.clear.settings))
        XCTAssertThrowsError(try preset.applying(selectionDuration: 2, sampleRate: 8_000))
    }
}
