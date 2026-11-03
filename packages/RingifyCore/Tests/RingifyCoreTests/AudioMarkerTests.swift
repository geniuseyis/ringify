import Foundation
import XCTest
@testable import RingifyCore

final class AudioMarkerTests: XCTestCase {
    func testMarkersUseSourceTimeAndSelectAValidRegionNearTheEnd() throws {
        let marker = AudioMarker(time: 118, label: "Chorus")
        let selection = try AudioMarkers.selection(for: marker, sourceDuration: 120, preferredDuration: 15)
        XCTAssertLessThanOrEqual(selection.start, marker.time)
        XCTAssertGreaterThanOrEqual(selection.end, marker.time)
        XCTAssertEqual(selection.duration, 15, accuracy: 0.001)
        XCTAssertNoThrow(try ValidateSelectionUseCase()(selection, sourceDuration: 120))
    }
    func testInvalidDuplicateOrOutOfRangeMarkersAreRejected() {
        let marker = AudioMarker(time: 1, label: "Start")
        for markers in [[marker, marker], [AudioMarker(time: .nan, label: "Bad")],
                        [AudioMarker(time: -1, label: "Bad")], [AudioMarker(time: 10, label: "Bad")],
                        [AudioMarker(time: 1, label: " ")]] {
            XCTAssertThrowsError(try AudioMarkers.validated(markers, sourceDuration: 3))
        }
    }
    func testOnlySmallCodecBoundaryDifferencesAreFitted() throws {
        let marker = AudioMarker(time: 3.05, label: "End")
        XCTAssertEqual(try AudioMarkers.fittingRecording([marker], sourceDuration: 3).first?.time, 3)
        XCTAssertThrowsError(try AudioMarkers.fittingRecording([AudioMarker(time: 4, label: "Invalid")], sourceDuration: 3))
    }
    func testLegacyMissingFieldDefaultsEmptyAndPresentNullFails() throws {
        let project = RingtoneProject(name: "Tone", sourceFilename: "source.wav", sourceURL: URL(fileURLWithPath: "/source.wav"),
            sourceKind: .audioFile, sourceDuration: 3, selection: EditSelection(start: 0, end: 3))
        var value = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(project)) as? [String: Any])
        value.removeValue(forKey: "markers")
        XCTAssertEqual(try JSONDecoder().decode(RingtoneProject.self, from: JSONSerialization.data(withJSONObject: value)).markers, [])
        value["markers"] = NSNull()
        XCTAssertThrowsError(try JSONDecoder().decode(RingtoneProject.self, from: JSONSerialization.data(withJSONObject: value)))
    }
}
