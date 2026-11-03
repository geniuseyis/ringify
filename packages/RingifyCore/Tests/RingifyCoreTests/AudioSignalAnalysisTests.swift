import Foundation
import XCTest
@testable import RingifyCore

final class AudioSignalAnalysisTests: XCTestCase {
    private struct Segment: Decodable { let frames: Int; let value: Float }
    private struct Expected: Decodable {
        let peakDbFS: Double?
        let rmsDbFS: Double?
        let silentRegions: [EditSelection]
        let suggestion: EditSelection?
        let duration: Double
    }
    private struct Fixture: Decodable {
        let name: String
        let sampleRate: Double
        let channels: [[Segment]]
        let expected: Expected
    }

    func testStreamingResultsMatchRealWebReferenceAcrossChunkBoundaries() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "AudioAnalysisParity", withExtension: "json"))
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
        XCTAssertEqual(fixtures.count, 6)
        let offset = 7.25
        for fixture in fixtures {
            let channels = fixture.channels.map { segments in segments.flatMap { Array(repeating: $0.value, count: $0.frames) } }
            let length = try XCTUnwrap(channels.first?.count)
            for chunkSize in [37, 400, 8_192] {
                var analyzer = try AudioSignalAccumulator(sampleRate: fixture.sampleRate, channelCount: channels.count,
                    frameCount: Int64(length), sourceStart: offset)
                for first in stride(from: 0, to: length, by: chunkSize) {
                    let last = min(length, first + chunkSize)
                    try analyzer.append(channels.map { Array($0[first..<last]) })
                }
                let result = try analyzer.finish(), expected = fixture.expected
                if let peak = expected.peakDbFS {
                    XCTAssertEqual(try XCTUnwrap(result.peakDbFS), peak, accuracy: 1e-9, fixture.name)
                    XCTAssertEqual(try XCTUnwrap(result.rmsDbFS), try XCTUnwrap(expected.rmsDbFS), accuracy: 1e-9, fixture.name)
                } else { XCTAssertNil(result.peakDbFS); XCTAssertNil(result.rmsDbFS) }
                XCTAssertEqual(result.selection.duration, expected.duration, accuracy: 1e-9)
                XCTAssertEqual(result.silentRegions.count, expected.silentRegions.count)
                for (actual, region) in zip(result.silentRegions, expected.silentRegions) {
                    XCTAssertEqual(actual.start, offset + region.start, accuracy: 1e-9)
                    XCTAssertEqual(actual.end, offset + region.end, accuracy: 1e-9)
                }
                if let suggestion = expected.suggestion {
                    XCTAssertEqual(try XCTUnwrap(result.suggestion).start, offset + suggestion.start, accuracy: 1e-9)
                    XCTAssertEqual(try XCTUnwrap(result.suggestion).end, offset + suggestion.end, accuracy: 1e-9)
                } else { XCTAssertNil(result.suggestion) }
            }
        }
    }

    func testInvalidChunkDoesNotPartiallyChangeTheAccumulator() throws {
        var analyzer = try AudioSignalAccumulator(sampleRate: 8_000, channelCount: 1, frameCount: 8_000, sourceStart: 0)
        XCTAssertThrowsError(try analyzer.append([[0, .nan, 1]]))
        try analyzer.append([Array(repeating: 0.5, count: 8_000)])
        let result = try analyzer.finish()
        XCTAssertEqual(try XCTUnwrap(result.rmsDbFS), 20 * log10(0.5), accuracy: 1e-10)
    }

    func testTruncatedOrOverlongStreamsCannotSucceed() throws {
        var analyzer = try AudioSignalAccumulator(sampleRate: 8_000, channelCount: 1, frameCount: 8_000, sourceStart: 0)
        try analyzer.append([Array(repeating: 0, count: 4_000)])
        XCTAssertThrowsError(try analyzer.finish())
        XCTAssertThrowsError(try analyzer.append([Array(repeating: 0, count: 4_001)]))
        try analyzer.append([Array(repeating: 0, count: 4_000)])
        _ = try analyzer.finish()
        XCTAssertThrowsError(try analyzer.finish())
        XCTAssertThrowsError(try analyzer.append([[0]]))
    }

    func testRejectsInvalidFormatAndSelectionBounds() {
        for count in [0, 3] {
            XCTAssertThrowsError(try AudioSignalAccumulator(sampleRate: 8_000, channelCount: count, frameCount: 8_000, sourceStart: 0))
        }
        for rate in [Double.nan, 0, 192_001] {
            XCTAssertThrowsError(try AudioSignalAccumulator(sampleRate: rate, channelCount: 1, frameCount: 8_000, sourceStart: 0))
        }
        XCTAssertThrowsError(try AudioSignalAccumulator(sampleRate: 8_000, channelCount: 1, frameCount: 240_000, sourceStart: 0))
        XCTAssertThrowsError(try AudioSignalAccumulator(sampleRate: 8_000, channelCount: 1, frameCount: 8_000, sourceStart: -1))
        XCTAssertThrowsError(try AudioSignalAccumulator(sampleRate: 8_000, channelCount: 1, frameCount: 8_000, sourceStart: 1_800))
    }
}
