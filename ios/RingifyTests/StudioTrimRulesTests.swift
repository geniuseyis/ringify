import RingifyCore
import XCTest
@testable import Ringify

final class StudioTrimRulesTests: XCTestCase {
    func testFineKeyboardStepOnlyChangesTheFocusedBoundary() {
        let original = EditSelection(start: 2, end: 12)
        let next = StudioTrimRules.adjustedSelection(original, boundary: .start, delta: 0.1, sourceDuration: 20)
        XCTAssertEqual(next.start, 2.1, accuracy: 0.000001)
        XCTAssertEqual(next.end, original.end)
    }
    func testFractionalStartCannotTurnMaximumLengthIntoAnInvalidSelection() {
        // IEEE-754: (3.2 + 29) - 3.2 can be 29.000000000000004.
        let original = EditSelection(start: 3.2, end: 10)
        let next = StudioTrimRules.adjustedSelection(original, boundary: .end, delta: 100, sourceDuration: 60)
        XCTAssertEqual(next.start, original.start)
        XCTAssertLessThanOrEqual(next.duration, RingtoneRules.maximumDuration)
        XCTAssertEqual(next.duration, 29, accuracy: 0.0000000001)
        if case .failure = RingtoneRules().validate(selection: next, sourceDuration: 60) {
            XCTFail("Fractional start rejected a valid maximum-length edit")
        }
    }
    func testFractionalStartCannotTurnMinimumLengthIntoAnInvalidSelection() {
        let original = EditSelection(start: 0.4, end: 12)
        let next = StudioTrimRules.adjustedSelection(original, boundary: .end, delta: -100, sourceDuration: 20)
        XCTAssertEqual(next.start, original.start)
        XCTAssertGreaterThanOrEqual(next.duration, RingtoneRules.minimumDuration)
        XCTAssertEqual(next.duration, 1, accuracy: 0.0000000001)
    }
    func testCoarseKeyboardStepAndVoiceOverDecrementShareValidBounds() {
        let original = EditSelection(start: 2, end: 12)
        let coarse = StudioTrimRules.adjustedSelection(original, boundary: .end, delta: -1, sourceDuration: 20)
        let fine = StudioTrimRules.adjustedSelection(original, boundary: .end, delta: -0.1, sourceDuration: 20)
        XCTAssertEqual(coarse, EditSelection(start: 2, end: 11))
        XCTAssertEqual(fine.end, 11.9, accuracy: 0.000001)
        XCTAssertEqual(fine.start, original.start)
    }
    func testKeyboardCannotCrossTheOtherHandleOrSourceBoundary() {
        let original = EditSelection(start: 2, end: 12)
        XCTAssertEqual(StudioTrimRules.adjustedSelection(original, boundary: .start, delta: 100, sourceDuration: 20),
            EditSelection(start: 11, end: 12))
        XCTAssertEqual(StudioTrimRules.adjustedSelection(original, boundary: .end, delta: -100, sourceDuration: 20),
            EditSelection(start: 2, end: 3))
    }
    func testInvalidAdjustmentDoesNotReplaceTheCurrentEdit() {
        let valid = EditSelection(start: 2, end: 12)
        for delta in [Double.nan, .infinity, -.infinity] {
            XCTAssertEqual(StudioTrimRules.adjustedSelection(valid, boundary: .start, delta: delta, sourceDuration: 20), valid)
        }
        let invalid = EditSelection(start: 2, end: 2.5)
        XCTAssertEqual(StudioTrimRules.adjustedSelection(invalid, boundary: .end, delta: 1, sourceDuration: 20), invalid)
    }
    func testAdjustmentsRemainValidAcrossBothBoundariesAndDurationLimits() {
        let cases: [(EditSelection, Double)] = [(EditSelection(start: 0, end: 8), 8),
            (EditSelection(start: 10, end: 30), 60), (EditSelection(start: 31, end: 60), 60),
            (EditSelection(start: 0, end: 29), 60)]
        for (selection, duration) in cases {
            for boundary in StudioTrimRules.Boundary.allCases {
                for delta in [-100.0, -1, -0.1, 0, 0.1, 1, 100] {
                    let next = StudioTrimRules.adjustedSelection(selection, boundary: boundary, delta: delta, sourceDuration: duration)
                    if case .failure = RingtoneRules().validate(selection: next, sourceDuration: duration) {
                        XCTFail("Keyboard adjustment broke selection bounds")
                    }
                }
            }
        }
    }
    func testNearStartSnapsToActualSourceStart() {
        XCTAssertEqual(StudioTrimRules.snappedSourceBoundary(0.04, duration: 30), 0)
    }
    func testNearEndSnapsToActualSourceEnd() {
        XCTAssertEqual(StudioTrimRules.snappedSourceBoundary(29.96, duration: 30), 30)
    }
    func testPreciseInteriorPositionIsNotQuantized() {
        XCTAssertEqual(StudioTrimRules.snappedSourceBoundary(12.345, duration: 30), 12.345)
    }
    func testSnapCannotOverrideMaximumRingtoneDuration() {
        let end = StudioTrimRules.snappedSourceBoundary(59.96, duration: 60)
        let selection = RingtoneRules().clampedSelection(start: 30.95, end: end, sourceDuration: 60)
        XCTAssertLessThanOrEqual(selection.duration, RingtoneRules.maximumDuration + 0.000001)
        XCTAssertLessThan(selection.end, 60)
    }
    func testNonFiniteCoordinatesCannotEscapeIntoDrawing() {
        for invalid in [Double.nan, .infinity, -.infinity] {
            XCTAssertTrue(StudioTrimRules.snappedSourceBoundary(invalid, duration: 30).isFinite)
        }
    }
}
