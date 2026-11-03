import Foundation
import XCTest
@testable import RingifyCore

final class AudioSegmentSuggestionsTests: XCTestCase {
    private struct Fixture: Decodable {
        struct Item: Decodable {
            struct Region: Decodable { let start: Int; let end: Int; let value: Float }
            struct Expected: Decodable { let start: Double; let end: Double; let rmsDbFS: Double }
            let name: String; let rate: Double; let length: Int; let seconds: Int
            let channels: [[Region]]; let expected: [Expected]
        }
        let cases: [Item]
    }
    func testStreamingMatchesWebGoldenVectorsAcrossChunkSizesAndNonintegerGrid() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "AudioSegmentsParity", withExtension: "json"))
        let fixtures = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        for item in fixtures.cases {
            let channels = item.channels.map { regions -> [Float] in
                var values = [Float](repeating: 0, count: item.length)
                for region in regions { for index in region.start..<region.end { values[index] = region.value } }
                return values
            }
            for chunk in [137, 8192] {
                var scan = try AudioSegmentAccumulator(sampleRate: item.rate, channelCount: channels.count, frameCount: Int64(item.length),
                    duration: XCTUnwrap(AudioSegmentDuration(rawValue: item.seconds)))
                for first in stride(from: 0, to: item.length, by: chunk) {
                    try scan.append(channels.map { Array($0[first..<min(item.length, first + chunk)]) })
                }
                let result = try scan.finish()
                XCTAssertEqual(result.count, item.expected.count, item.name)
                for (actual, expected) in zip(result, item.expected) {
                    XCTAssertEqual(actual.selection.start, expected.start, accuracy: 1 / item.rate, item.name)
                    XCTAssertEqual(actual.selection.end, expected.end, accuracy: 1 / item.rate, item.name)
                    XCTAssertEqual(actual.rmsDbFS, expected.rmsDbFS, accuracy: 1e-7, item.name)
                }
                XCTAssertThrowsError(try scan.finish())
            }
        }
    }
    func testBoundsRejectNonfiniteMismatchedIncompleteAndOversizedInput() throws {
        for rate in [Double.nan, .infinity, 0, 200_000] {
            XCTAssertThrowsError(try AudioSegmentAccumulator(sampleRate: rate, channelCount: 1, frameCount: 8000, duration: .short))
        }
        XCTAssertThrowsError(try AudioSegmentAccumulator(sampleRate: 192_000, channelCount: 2, frameCount: 23_040_000, duration: .short))
        XCTAssertThrowsError(try AudioSegmentAccumulator(sampleRate: 8000, channelCount: 1, frameCount: 968_000, duration: .short))
        var scan = try AudioSegmentAccumulator(sampleRate: 8000, channelCount: 2, frameCount: 8000, duration: .short)
        XCTAssertThrowsError(try scan.append([[.nan], [0]]))
        XCTAssertThrowsError(try scan.append([[0], []]))
        XCTAssertThrowsError(try scan.append([[0]]))
        XCTAssertThrowsError(try scan.finish())
    }
    func testSubsecondAndSilenceYieldNoMisleadingSuggestion() throws {
        for count in [7999, 8000] {
            var scan = try AudioSegmentAccumulator(sampleRate: 8000, channelCount: 1, frameCount: Int64(count), duration: .ringtone)
            try scan.append([[Float](repeating: count < 8000 ? 0.5 : 0, count: count)])
            XCTAssertEqual(try scan.finish(), [])
        }
    }
}
