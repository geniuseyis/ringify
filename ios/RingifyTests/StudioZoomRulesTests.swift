import XCTest
@testable import Ringify

final class StudioZoomRulesTests: XCTestCase {
    func testMagnificationIsRelativeToTheGestureStart() {
        XCTAssertEqual(StudioZoomRules.proposed(start: 2, magnification: 1.25), 2.5)
        XCTAssertEqual(StudioZoomRules.proposed(start: 2, magnification: 1.5), 3)
    }

    func testZoomClampsAtBothViewportLimits() {
        XCTAssertEqual(StudioZoomRules.proposed(start: 2, magnification: 0.01), 1)
        XCTAssertEqual(StudioZoomRules.proposed(start: 2, magnification: 100), 4)
    }

    func testInvalidMagnificationCannotChangeAValidZoom() {
        for invalid in [Double.nan, .infinity, -.infinity, 0, -1] {
            XCTAssertEqual(StudioZoomRules.proposed(start: 2, magnification: invalid), 2)
        }
    }

    func testInvalidStartingZoomCannotProduceNonFiniteLayout() {
        for invalid in [Double.nan, .infinity, -.infinity, -1, 0] {
            let result = StudioZoomRules.proposed(start: invalid, magnification: 1)
            XCTAssertTrue(result.isFinite)
            XCTAssertEqual(result, 1)
        }
    }

    func testExtremeFiniteFactorsStayBoundedAndFractionalZoomIsPreserved() {
        XCTAssertEqual(StudioZoomRules.proposed(start: 4, magnification: .greatestFiniteMagnitude), 4)
        XCTAssertEqual(StudioZoomRules.proposed(start: 4, magnification: .leastNonzeroMagnitude), 1)
        XCTAssertEqual(StudioZoomRules.proposed(start: 1.5, magnification: 1.5), 2.25)
    }
}
