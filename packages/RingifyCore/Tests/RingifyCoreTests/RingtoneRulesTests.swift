import XCTest
@testable import RingifyCore

final class RingtoneRulesTests: XCTestCase {
    private let rules = RingtoneRules()

    func testAcceptsExactDurationBounds() {
        XCTAssertEqual(
            rules.validate(selection: EditSelection(start: 0, end: 1), sourceDuration: 60),
            .success(EditSelection(start: 0, end: 1))
        )
        XCTAssertEqual(
            rules.validate(selection: EditSelection(start: 4, end: 33), sourceDuration: 60),
            .success(EditSelection(start: 4, end: 33))
        )
    }

    func testRejectsNegativeStart() {
        XCTAssertEqual(
            rules.validate(selection: EditSelection(start: -0.1, end: 5), sourceDuration: 60),
            .failure(.negativeStart)
        )
    }

    func testRejectsNonFiniteValues() {
        XCTAssertEqual(
            rules.validate(selection: EditSelection(start: .nan, end: 5), sourceDuration: 60),
            .failure(.nonFiniteValue)
        )
        XCTAssertEqual(
            rules.validate(selection: EditSelection(start: 0, end: .infinity), sourceDuration: 60),
            .failure(.nonFiniteValue)
        )
    }

    func testRejectsReversedAndZeroLengthSelection() {
        XCTAssertEqual(
            rules.validate(selection: EditSelection(start: 5, end: 5), sourceDuration: 60),
            .failure(.endNotAfterStart)
        )
        XCTAssertEqual(
            rules.validate(selection: EditSelection(start: 8, end: 4), sourceDuration: 60),
            .failure(.endNotAfterStart)
        )
    }

    func testRejectsTooShortAndTooLongSelection() {
        XCTAssertEqual(
            rules.validate(selection: EditSelection(start: 0, end: 0.99), sourceDuration: 60),
            .failure(.shorterThanMinimum(minimum: 1))
        )
        XCTAssertEqual(
            rules.validate(selection: EditSelection(start: 0, end: 29.01), sourceDuration: 60),
            .failure(.longerThanMaximum(maximum: 29))
        )
    }

    func testRejectsSelectionBeyondSource() {
        XCTAssertEqual(
            rules.validate(selection: EditSelection(start: 5, end: 10), sourceDuration: 9),
            .failure(.exceedsSourceDuration)
        )
    }

    func testFilenameValidationAndSanitizing() {
        XCTAssertEqual(rules.validate(filename: "  My Tone  "), .success("My Tone"))
        XCTAssertEqual(rules.validate(filename: "../tone"), .failure(.containsPathSeparator))
        XCTAssertEqual(rules.validate(filename: " "), .failure(.empty))
        XCTAssertEqual(rules.safeFilename(from: "My/Tone:m4a"), "My-Tone-m4a")
    }
}
