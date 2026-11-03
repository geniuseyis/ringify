import XCTest
@testable import RingifyCore

final class AudioGainEnvelopeTests: XCTestCase {
    func testVolumeReducesGlobalGainBeforeClipping() throws {
        let envelope = try AudioGainEnvelope(peak: 0.8, settings: AudioEffectSettings(volume: 2), sampleRate: 100, frames: 200)
        XCTAssertEqual(envelope.gain, 0.99 / 0.8, accuracy: 1e-12)
        XCTAssertEqual(envelope.gain(at: 100) * 0.8, 0.99, accuracy: 1e-12)
    }
    func testNormalizationDoesNotHaveAnArbitraryFourTimesCap() throws {
        let envelope = try AudioGainEnvelope(peak: 0.01, settings: AudioEffectSettings(normalize: true), sampleRate: 100, frames: 200)
        XCTAssertEqual(envelope.gain * 0.01, 0.95, accuracy: 1e-12)
        let tinyPeak = Double(Float.leastNonzeroMagnitude)
        let tiny = try AudioGainEnvelope(peak: tinyPeak, settings: AudioEffectSettings(normalize: true), sampleRate: 100, frames: 200)
        XCTAssertEqual(tiny.gain * tinyPeak, 0.95, accuracy: 1e-12)
    }
    func testFadesUseActualFirstAndLastFramesAndClampToHalfDuration() throws {
        let original = AudioEffectSettings(volume: 0.7, fadeInDuration: 4, fadeOutDuration: 3, normalize: true)
        let adapted = try original.limitingFades(to: 2)
        XCTAssertEqual(adapted.fadeInDuration, 1)
        XCTAssertEqual(adapted.fadeOutDuration, 1)
        XCTAssertEqual(adapted.volume, original.volume)
        XCTAssertEqual(adapted.normalize, original.normalize)
        XCTAssertEqual(original.fadeInDuration, 4)
        XCTAssertThrowsError(try original.limitingFades(to: .nan))
        let envelope = try AudioGainEnvelope(peak: 0.5, settings: AudioEffectSettings(fadeInDuration: 20, fadeOutDuration: 20), sampleRate: 100, frames: 200)
        XCTAssertEqual(envelope.gain(at: 0), 0)
        XCTAssertEqual(envelope.gain(at: 50), 0.5, accuracy: 1e-12)
        XCTAssertEqual(envelope.gain(at: 199), 0)
        XCTAssertEqual(envelope.gain(at: -1), 0)
    }
    func testSilenceAndInvalidParameters() throws {
        XCTAssertEqual(try AudioGainEnvelope(peak: 0, settings: AudioEffectSettings(normalize: true), sampleRate: 100, frames: 100).gain, 0)
        XCTAssertThrowsError(try AudioGainEnvelope(peak: .nan, settings: .neutral, sampleRate: 100, frames: 100))
        XCTAssertThrowsError(try AudioGainEnvelope(peak: 1, settings: AudioEffectSettings(volume: .infinity), sampleRate: 100, frames: 100))
        XCTAssertThrowsError(try AudioGainEnvelope(peak: 1, settings: .neutral, sampleRate: 0, frames: 100))
    }
}
