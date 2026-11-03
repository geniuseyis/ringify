import Foundation
import XCTest
@testable import RingifyCore

final class ProjectExportRecordTests: XCTestCase {
    private var project: RingtoneProject {
        RingtoneProject(name: "Tone", sourceFilename: "source.wav", sourceURL: URL(fileURLWithPath: "/source.wav"),
            sourceKind: .audioFile, sourceDuration: 8, selection: EditSelection(start: 1, end: 7),
            effects: AudioEffectSettings(volume: 0.6, studio: StudioAudioPreset.clear.settings))
    }
    func testHistoryRoundTripKeepsTheExactEditSnapshotAndProfile() throws {
        let output = ExportedRingtone(url: URL(fileURLWithPath: "/tone.wav"), duration: 6, byteCount: 100)
        let record = ProjectExportRecord(project: project, output: output, profile: .wav24)
        try record.validate()
        let restored = try JSONDecoder().decode(ProjectExportRecord.self, from: JSONEncoder().encode(record))
        try restored.validate()
        XCTAssertEqual(restored, record)
        XCTAssertEqual(restored.effects, project.effects)
    }
    func testInvalidOutputMetadataCannotBeRecordedAsVerifiedHistory() {
        for output in [ExportedRingtone(url: URL(fileURLWithPath: "/tone.m4a"), duration: 6, byteCount: 100),
                       ExportedRingtone(url: URL(fileURLWithPath: "/tone.wav"), duration: .nan, byteCount: 100),
                       ExportedRingtone(url: URL(fileURLWithPath: "/tone.wav"), duration: 6, byteCount: 0)] {
            XCTAssertThrowsError(try ProjectExportRecord(project: project, output: output, profile: .wav24).validate())
        }
    }
}
