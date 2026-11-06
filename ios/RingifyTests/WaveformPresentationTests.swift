import XCTest
@testable import Ringify

final class WaveformPresentationTests: XCTestCase {
    func testDownsamplingKeepsEachBucketPeak() {
        let samples: [Float] = [0.1, -0.9, 0.2, 0.3, 0.05, -0.4, 0.6, 0.0]
        XCTAssertEqual(WaveformBars.peaks(samples, maximumBars: 4), [0.9, 0.3, 0.4, 0.6])
    }

    func testShortInputIsKeptButSanitized() {
        let samples: [Float] = [-0.5, .nan, 2, .infinity]
        XCTAssertEqual(WaveformBars.peaks(samples, maximumBars: 10), [0.5, 0, 1, 0])
    }

    func testBarCountNeverExceedsTheAvailableWidth() {
        let samples = (0..<240).map { Float($0 % 10) / 10 }
        let bars = WaveformBars.peaks(samples, maximumBars: 57)
        XCTAssertEqual(bars.count, 57)
        XCTAssertTrue(bars.allSatisfy { (0...1).contains($0) })
    }

    func testEmptyInputOrZeroBarsDrawsNothing() {
        XCTAssertTrue(WaveformBars.peaks([], maximumBars: 8).isEmpty)
        XCTAssertTrue(WaveformBars.peaks([0.5, 0.5], maximumBars: 0).isEmpty)
    }
}
