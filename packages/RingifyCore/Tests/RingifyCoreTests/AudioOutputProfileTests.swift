import Foundation
import XCTest
@testable import RingifyCore

final class AudioOutputProfileTests: XCTestCase {
    private var request: ExportRequest {
        ExportRequest(projectID: UUID(), sourceURL: URL(fileURLWithPath: "/source.wav"), filename: "Tone",
            selection: EditSelection(start: 0, end: 2), effects: .neutral)
    }
    func testEachProfileHasConsistentContainerPrecisionAndAccess() {
        XCTAssertEqual(AudioOutputProfile.aacStandard.bitRate, 192_000)
        XCTAssertEqual(AudioOutputProfile.aacHigh.bitRate, 256_000)
        XCTAssertEqual(AudioOutputProfile.wav16.bitDepth, 16)
        XCTAssertEqual(AudioOutputProfile.wav24.bitDepth, 24)
        XCTAssertFalse(AudioOutputProfile.wav16.requiresPro)
        XCTAssertTrue(AudioOutputProfile.wav24.requiresPro)
        for profile in AudioOutputProfile.allCases {
            XCTAssertEqual(profile.format.fileExtension, profile.bitDepth == nil ? "m4a" : "wav")
        }
    }
    func testLegacyRequestDefaultsToStandardAndNewProfilesRoundTrip() throws {
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        old.removeValue(forKey: "profile")
        let decoded = try JSONDecoder().decode(ExportRequest.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertEqual(decoded.profile, .aacStandard)
        XCTAssertEqual(decoded.effects, request.effects)
        for profile in AudioOutputProfile.allCases {
            let next = ExportRequest(projectID: request.projectID, sourceURL: request.sourceURL, filename: "Tone",
                selection: request.selection, effects: request.effects, profile: profile)
            XCTAssertEqual(try JSONDecoder().decode(ExportRequest.self, from: JSONEncoder().encode(next)), next)
        }
    }
    func testMismatchedAndNullProfilesAreRejectedInsteadOfChangingFormat() throws {
        var data = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        data["profile"] = "wav24"
        XCTAssertThrowsError(try JSONDecoder().decode(ExportRequest.self, from: JSONSerialization.data(withJSONObject: data)))
        data["profile"] = NSNull()
        XCTAssertThrowsError(try JSONDecoder().decode(ExportRequest.self, from: JSONSerialization.data(withJSONObject: data)))
    }
}
