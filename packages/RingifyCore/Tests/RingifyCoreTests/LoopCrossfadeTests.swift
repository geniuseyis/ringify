import Foundation
import XCTest
@testable import RingifyCore

final class LoopCrossfadeTests: XCTestCase {
    private func render(_ source: [[Float]], chunk: Int) throws -> [[Float]] {
        var processor = try LoopCrossfadeProcessor(seconds: 0.005, sampleRate: 8_000,
            frames: Int64(source[0].count), channelCount: source.count)
        var output = Array(repeating: [Float](), count: source.count)
        for start in stride(from: 0, to: source[0].count, by: chunk) {
            let end = min(source[0].count, start + chunk)
            let rendered = try processor.process(source.map { Array($0[start..<end]) })
            for channel in rendered.indices { output[channel].append(contentsOf: rendered[channel]) }
        }
        try processor.finish()
        XCTAssertEqual(output[0].count, Int(processor.outputFrames))
        return output
    }
    func testLinearOverlapMatchesGoldenSamplesAndChunkBoundaries() throws {
        let source = (0..<12).map { Float($0) / 100 }
        let small = try render([source], chunk: 2), large = try render([source], chunk: 12)
        XCTAssertEqual(small, large)
        let expected: [Float] = [0.03,0.04,0.05,0.06,0.07,0.08,0.09,0.055,0.02]
        for (actual, expected) in zip(small[0], expected) { XCTAssertEqual(actual, expected, accuracy: 0.000_001) }
    }
    func testWrapUsesAdjacentHeadSamplesAndNeverExceedsInputPeaks() throws {
        let input = [Float](repeating: 0.4, count: 4_000) + [Float](repeating: -0.4, count: 4_000)
        let output = try render([input, input.map { $0 * 0.5 }], chunk: 37)
        XCTAssertEqual(output[0].first, output[0].last)
        XCTAssertTrue(output[0].allSatisfy { abs($0) <= 0.400_001 })
        for i in output[0].indices { XCTAssertEqual(output[1][i], output[0][i] * 0.5, accuracy: 0.000_001) }
    }
    func testNeutralIsBitExactAndInvalidOrIncompleteInputFails() throws {
        var neutral = try LoopCrossfadeProcessor(seconds: 0, sampleRate: 48_000, frames: 2, channelCount: 1)
        let input: [[Float]] = [[-Float.zero, Float.leastNonzeroMagnitude]]
        XCTAssertEqual(try neutral.process(input)[0].map(\.bitPattern), input[0].map(\.bitPattern))
        try neutral.finish()
        XCTAssertThrowsError(try LoopCrossfadeRules.validate(.nan))
        XCTAssertThrowsError(try LoopCrossfadeRules.validate(0.5))
        XCTAssertThrowsError(try LoopCrossfadeRules.sourceOffset(seconds: 0.03, sampleRate: .nan, duration: 3))
        var incomplete = try LoopCrossfadeProcessor(seconds: 0.03, sampleRate: 48_000, frames: 48_000, channelCount: 1)
        XCTAssertThrowsError(try incomplete.process([[.nan]]))
        XCTAssertThrowsError(try incomplete.finish())
    }
    func testLegacyEffectsDecodeLoopOffAndNewSettingsRoundTrip() throws {
        let legacy = Data(#"{"volume":1,"fadeInDuration":0,"fadeOutDuration":0,"normalize":false}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(AudioEffectSettings.self, from: legacy).loopCrossfadeDuration, 0)
        let effects = AudioEffectSettings(loopCrossfadeDuration: 0.03)
        XCTAssertEqual(try JSONDecoder().decode(AudioEffectSettings.self, from: JSONEncoder().encode(effects)), effects)
    }
}
