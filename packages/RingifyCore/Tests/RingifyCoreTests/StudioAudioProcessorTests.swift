import Foundation
import XCTest
@testable import RingifyCore

final class StudioAudioProcessorTests: XCTestCase {
    private let rate = 48_000.0

    private func tone(_ frequency: Double, count: Int = 24_000) -> [Float] {
        (0..<count).map { Float(sin(2 * Double.pi * frequency * Double($0) / rate) * 0.05) }
    }

    private func rms(_ values: [Float], dropping: Int = 4_800) -> Double {
        let measured = values.dropFirst(dropping)
        return sqrt(measured.reduce(0) { $0 + Double($1) * Double($1) } / Double(measured.count))
    }

    private func filtered(_ source: [[Float]], settings: StudioAudioSettings, chunk: Int = 8_192) throws -> [[Float]] {
        var filter = try StudioAudioFilter(settings: settings, sampleRate: rate, inputChannels: source.count)
        var output = Array(repeating: [Float](), count: filter.outputChannelCount)
        for start in stride(from: 0, to: source[0].count, by: chunk) {
            let end = min(source[0].count, start + chunk)
            let next = try filter.process(source.map { Array($0[start..<end]) })
            for channel in next.indices { output[channel].append(contentsOf: next[channel]) }
        }
        return output
    }

    private func limited(_ source: [[Float]], sampleRate: Double = 1_000, chunk: Int) throws -> [[Float]] {
        var limiter = try LinkedPeakLimiter(sampleRate: sampleRate, ceiling: 0.8, channelCount: source.count)
        var output = Array(repeating: [Float](), count: source.count)
        for start in stride(from: 0, to: source[0].count, by: chunk) {
            let end = min(source[0].count, start + chunk)
            let next = try limiter.process(source.map { Array($0[start..<end]) })
            for channel in next.indices { output[channel].append(contentsOf: next[channel]) }
        }
        let final = try limiter.process(Array(repeating: [], count: source.count), final: true)
        for channel in final.indices { output[channel].append(contentsOf: final[channel]) }
        return output
    }

    func testLegacyEffectJSONDefaultsOnlyTheAbsentStudioFieldAndRoundTripsNewSettings() throws {
        let old = Data(#"{"volume":0.7,"fadeInDuration":0.1,"fadeOutDuration":0.2,"normalize":false}"#.utf8)
        let decoded = try JSONDecoder().decode(AudioEffectSettings.self, from: old)
        XCTAssertEqual(decoded.volume, 0.7)
        XCTAssertEqual(decoded.fadeInDuration, 0.1)
        XCTAssertEqual(decoded.studio, .neutral)
        var advanced = decoded
        advanced.studio = StudioAudioPreset.clear.settings
        XCTAssertEqual(try JSONDecoder().decode(AudioEffectSettings.self, from: JSONEncoder().encode(advanced)), advanced)
        XCTAssertThrowsError(try JSONDecoder().decode(AudioEffectSettings.self,
            from: Data(#"{"volume":1,"fadeInDuration":0,"fadeOutDuration":0,"normalize":false,"studio":null}"#.utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(AudioEffectSettings.self,
            from: Data(#"{"volume":1,"fadeInDuration":0,"fadeOutDuration":0,"normalize":false,"studio":{"midGainDB":4}}"#.utf8)))
    }

    func testInvalidConfigurationAndActualNyquistAreRejected() throws {
        let invalid = [StudioAudioSettings(lowGainDB: .nan), StudioAudioSettings(midGainDB: 13),
            StudioAudioSettings(highPassHz: -1), StudioAudioSettings(highPassHz: 500, lowPassHz: 300),
            StudioAudioSettings(ceiling: 1), StudioAudioSettings(lowPassHz: .infinity)]
        for settings in invalid { XCTAssertThrowsError(try settings.validate()) }
        XCTAssertThrowsError(try StudioAudioSettings(highGainDB: 2).validate(sampleRate: 8_000))
        XCTAssertThrowsError(try StudioAudioSettings(lowPassHz: 12_000).validate(sampleRate: 24_000))
        XCTAssertThrowsError(try StudioAudioSettings.neutral.validate(sampleRate: .nan))
        XCTAssertNoThrow(try StudioAudioSettings.neutral.validate(sampleRate: 8_000))
        XCTAssertNoThrow(try StudioAudioPreset.telephone.settings.validate(sampleRate: 8_000))
        var invalidJSON = try XCTUnwrap(String(data: JSONEncoder().encode(StudioAudioSettings.neutral), encoding: .utf8))
        invalidJSON = invalidJSON.replacingOccurrences(of: "original", with: "surround")
        XCTAssertThrowsError(try JSONDecoder().decode(StudioAudioSettings.self, from: Data(invalidJSON.utf8)))
    }

    func testPresetsMatchWebValuesAndDoNotChangeBasicSettings() throws {
        XCTAssertEqual(StudioAudioPreset.warm.settings, StudioAudioSettings(lowGainDB: 3, highGainDB: -2))
        XCTAssertEqual(StudioAudioPreset.clear.settings, StudioAudioSettings(lowGainDB: -2, midGainDB: 2, highGainDB: 2, highPassHz: 80))
        XCTAssertEqual(StudioAudioPreset.telephone.settings, StudioAudioSettings(highPassHz: 300, lowPassHz: 3_400, channelMode: .mono))
        var effects = AudioEffectSettings(volume: 0.7, fadeInDuration: 0.3, normalize: true)
        effects.studio = StudioAudioPreset.warm.settings
        XCTAssertEqual(effects.volume, 0.7)
        XCTAssertEqual(effects.fadeInDuration, 0.3)
        XCTAssertTrue(effects.normalize)
    }

    func testNeutralPCMIsBitIdenticalAndSourceIsNotMutated() throws {
        let source = [tone(440), tone(880)]
        let snapshot = source
        let output = try filtered(source, settings: .neutral)
        XCTAssertEqual(output.map { $0.map(\.bitPattern) }, source.map { $0.map(\.bitPattern) })
        XCTAssertEqual(try filtered([[-Float.zero, Float.leastNonzeroMagnitude]], settings: .neutral)[0].map(\.bitPattern),
                       [-Float.zero, Float.leastNonzeroMagnitude].map(\.bitPattern))
        _ = try filtered(source, settings: StudioAudioPreset.clear.settings)
        XCTAssertEqual(source, snapshot)
    }

    func testFiltersPassTheirPassbandAndAttenuateTheirStopband() throws {
        let lowPass = StudioAudioSettings(lowPassHz: 1_000)
        let highPass = StudioAudioSettings(highPassHz: 1_000)
        let lowPassing = try rms(filtered([tone(100)], settings: lowPass)[0])
        let lowBlocked = try rms(filtered([tone(8_000)], settings: lowPass)[0])
        let highPassing = try rms(filtered([tone(8_000)], settings: highPass)[0])
        let highBlocked = try rms(filtered([tone(100)], settings: highPass)[0])
        XCTAssertGreaterThan(lowPassing, 0.03)
        XCTAssertLessThan(lowBlocked / lowPassing, 0.03)
        XCTAssertGreaterThan(highPassing, 0.03)
        XCTAssertLessThan(highBlocked / highPassing, 0.03)
    }

    func testCenterFrequencyEQMatchesRequestedDecibels() throws {
        let source = tone(1_000)
        for gain in [-6.0, 6.0] {
            let output = try filtered([source], settings: StudioAudioSettings(midGainDB: gain))[0]
            XCTAssertEqual(20 * log10(rms(output) / rms(source)), gain, accuracy: 0.01)
        }
    }

    func testFilterStateIsChunkInvariantAndIndependentPerChannel() throws {
        let source = [tone(440), [Float](repeating: 0, count: 24_000)]
        let settings = StudioAudioPreset.clear.settings
        let small = try filtered(source, settings: settings, chunk: 37)
        let large = try filtered(source, settings: settings, chunk: 24_000)
        XCTAssertEqual(small, large)
        XCTAssertTrue(small[1].allSatisfy { $0 == 0 })
    }

    func testChannelConversionAveragesOrDuplicatesActualSamples() throws {
        let source: [[Float]] = [[0.2, 0.4], [-0.2, -0.4]]
        XCTAssertEqual(try filtered(source, settings: StudioAudioSettings(channelMode: .mono)), [[0, 0]])
        let stereo = try filtered([source[0]], settings: StudioAudioSettings(channelMode: .stereo))
        XCTAssertEqual(stereo, [source[0], source[0]])
        var filter = try StudioAudioFilter(settings: .neutral, sampleRate: rate, inputChannels: 1)
        XCTAssertThrowsError(try filter.process([[.nan]]))
        XCTAssertThrowsError(try filter.process([[0], [0]]))
        XCTAssertThrowsError(try filter.process([[Float](repeating: 0, count: StudioAudioFilter.maximumChunkFrames + 1)]))
        XCTAssertThrowsError(try StudioAudioFilter(settings: .neutral, sampleRate: rate, inputChannels: 3))
    }

    func testLimiterPreservesImpulseTimeCeilingAndStereoRatio() throws {
        var left = [Float](repeating: 0.1, count: 2_000)
        left[500] = 2
        let source = [left, left.map { $0 * 0.5 }]
        let snapshot = source
        let result = try limited(source, chunk: 37)
        XCTAssertEqual(result[0].count, left.count)
        XCTAssertLessThanOrEqual(result[0].map { abs($0) }.max() ?? 0, 0.800_001)
        XCTAssertEqual(result[0].firstIndex(of: result[0].max()!), 500)
        XCTAssertEqual(result[0][500], 0.8, accuracy: 0.000_001)
        XCTAssertEqual(result[1][500] / result[0][500], 0.5, accuracy: 0.000_001)
        XCTAssertLessThan(result[0][501], result[0][1_500])
        XCTAssertEqual(source, snapshot)
    }

    func testLimiterChunkInvarianceShortEOFAndSilence() throws {
        var signal = tone(440, count: 8_000).map { $0 * 30 }
        signal[4_100] = 3
        XCTAssertEqual(try limited([signal], sampleRate: rate, chunk: 37),
                       try limited([signal], sampleRate: rate, chunk: 8_000))
        XCTAssertEqual(try limited([[0.3, 2]], sampleRate: 192_000, chunk: 1)[0].count, 2)
        XCTAssertEqual(try limited([[2]], sampleRate: 192_000, chunk: 1)[0][0], 0.8, accuracy: 0.000_001)
        XCTAssertEqual(try limited([[0, 0, 0]], chunk: 1), [[0, 0, 0]])
    }

    func testLookaheadSeesAnImpulseAcrossChunkBoundariesAndFlushesWithoutPadding() throws {
        var limiter = try LinkedPeakLimiter(sampleRate: 1_000, ceiling: 0.8, channelCount: 1)
        XCTAssertEqual(try limiter.process([[0.1, 0.1, 0.1]]), [[]])
        let first = try limiter.process([[0.1, 0.1, 2]])[0]
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first[0], 0.04, accuracy: 0.000_001)
        let tail = try limiter.process([[]], final: true)[0]
        XCTAssertEqual(tail.count, 5)
        XCTAssertEqual(tail.last!, 0.8, accuracy: 0.000_001)
    }

    func testLimiterRejectsInvalidInputAndRepeatedFinalization() throws {
        var limiter = try LinkedPeakLimiter(sampleRate: rate, ceiling: 0.8, channelCount: 2)
        XCTAssertThrowsError(try limiter.process([[0], []]))
        XCTAssertThrowsError(try limiter.process([[.nan], [0]]))
        XCTAssertEqual(try limiter.process([[], []], final: true), [[], []])
        XCTAssertThrowsError(try limiter.process([[], []], final: true))
        XCTAssertThrowsError(try LinkedPeakLimiter(sampleRate: .nan, ceiling: 0.8, channelCount: 1))
        XCTAssertThrowsError(try LinkedPeakLimiter(sampleRate: rate, ceiling: 1, channelCount: 1))
    }

    func testLimiterSelectsDynamicAttenuationWithoutChangingLegacySafeGain() throws {
        let legacy = try AudioGainEnvelope(peak: 2, settings: .neutral, sampleRate: rate, frames: 48_000)
        let advanced = try AudioGainEnvelope(peak: 2, settings: AudioEffectSettings(studio: StudioAudioSettings(limiterEnabled: true)),
                                            sampleRate: rate, frames: 48_000)
        XCTAssertEqual(legacy.gain, 0.99 / 2)
        XCTAssertEqual(advanced.gain, 1)
    }

    func testAdvancedPolicyPreservesSavedWorkAndRequiresProForChanges() {
        let saved = StudioAudioPreset.warm.settings
        XCTAssertTrue(ProAccessPolicy.canChangeStudioEffects(current: .neutral, next: saved, hasVerifiedPro: true))
        XCTAssertFalse(ProAccessPolicy.canChangeStudioEffects(current: .neutral, next: saved, hasVerifiedPro: false))
        XCTAssertTrue(ProAccessPolicy.canChangeStudioEffects(current: saved, next: saved, hasVerifiedPro: false))
        XCTAssertTrue(ProAccessPolicy.canChangeStudioEffects(current: saved, next: .neutral, hasVerifiedPro: false))
        XCTAssertFalse(ProAccessPolicy.canChangeStudioEffects(current: saved, next: StudioAudioPreset.clear.settings, hasVerifiedPro: false))
        XCTAssertFalse(ProAccessPolicy.canChangeStudioEffects(current: saved, next: StudioAudioSettings(midGainDB: .nan), hasVerifiedPro: true))
    }
}
