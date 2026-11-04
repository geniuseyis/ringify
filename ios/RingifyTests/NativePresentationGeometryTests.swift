import Foundation
import RingifyCore
import XCTest
@testable import Ringify

@MainActor
final class NativePresentationGeometryTests: XCTestCase {
    private func project(duration: TimeInterval = 24, start: TimeInterval = 2.4, end: TimeInterval = 20.8) -> RingtoneProject {
        RingtoneProject(name: "Selection", sourceFilename: "source.wav", sourceURL: URL(fileURLWithPath: "/source.wav"),
            sourceKind: .audioFile, sourceDuration: duration, selection: EditSelection(start: start, end: end))
    }

    func testProcessedElapsedTimeMapsBackToTheActualSourceSelection() {
        let waveform = NativeSelectionWaveform(project: project(), elapsed: 3.6)
        XCTAssertEqual(waveform.selectionRange.lowerBound, 0.1, accuracy: 0.000_001)
        XCTAssertEqual(waveform.selectionRange.upperBound, 20.8 / 24, accuracy: 0.000_001)
        // 3.6 seconds into an edit starting at 2.4 seconds means source time 6s.
        XCTAssertEqual(waveform.cursorFraction, 0.25, accuracy: 0.000_001)
    }

    func testCursorStaysWithinTheSelectedRegionAtPlaybackBoundaries() {
        let source = project()
        let before = NativeSelectionWaveform(project: source, elapsed: -10)
        let after = NativeSelectionWaveform(project: source, elapsed: 100)
        XCTAssertEqual(before.cursorFraction, before.selectionRange.lowerBound)
        XCTAssertEqual(after.cursorFraction, after.selectionRange.upperBound)
        XCTAssertEqual(source.selection.start, 2.4)
        XCTAssertEqual(source.selection.end, 20.8)
    }

    func testMalformedTimingCannotProduceNonFiniteOrReversedDrawingCoordinates() {
        let cases = [
            project(duration: .nan, start: .nan, end: .infinity),
            project(duration: 0, start: -4, end: -1),
            project(duration: 24, start: 20, end: 2),
            project(duration: .infinity, start: 100, end: 200)
        ]
        for source in cases {
            let waveform = NativeSelectionWaveform(project: source, elapsed: .nan)
            XCTAssertTrue(waveform.selectionRange.lowerBound.isFinite)
            XCTAssertTrue(waveform.selectionRange.upperBound.isFinite)
            XCTAssertTrue(waveform.cursorFraction.isFinite)
            XCTAssertTrue((0...1).contains(waveform.selectionRange.lowerBound))
            XCTAssertTrue((0...1).contains(waveform.selectionRange.upperBound))
            XCTAssertTrue(waveform.selectionRange.contains(waveform.cursorFraction))
        }
    }
}
