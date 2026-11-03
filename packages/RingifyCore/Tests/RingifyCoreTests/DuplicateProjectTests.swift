import Foundation
import XCTest
@testable import RingifyCore

final class DuplicateProjectTests: XCTestCase {
    private func project() -> RingtoneProject {
        RingtoneProject(name: "Original", sourceFilename: "source.wav", sourceURL: URL(fileURLWithPath: "/source.wav"),
            sourceKind: .audioFile, sourceDuration: 8, selection: EditSelection(start: 1, end: 7),
            effects: AudioEffectSettings(volume: 0.7, studio: StudioAudioPreset.telephone.settings),
            waveformSamples: [0.1, 0.4], status: .exported, exportedURL: URL(fileURLWithPath: "/old.m4a"),
            library: ProjectLibraryMetadata(favorite: true, collectionIDs: [UUID()]))
    }

    func testDuplicateHasIndependentIdentityAndEditsWithRealSharedSource() throws {
        let original = project()
        var copy = try DuplicateProjectUseCase()(original, name: "Copy")
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.sourceURL, original.sourceURL)
        XCTAssertEqual(copy.effects, original.effects)
        XCTAssertEqual(copy.library, original.library)
        XCTAssertEqual(copy.selection, original.selection)
        XCTAssertEqual(copy.waveformSamples, original.waveformSamples)
        copy.effects.volume = 0.1
        XCTAssertEqual(original.effects.volume, 0.7)
    }

    func testDuplicateStartsAsDraftWithoutSharingOldExportAndUsesNewDates() throws {
        let original = project(), now = Date(timeIntervalSince1970: 10)
        let copy = try DuplicateProjectUseCase()(original, name: "Copy", now: now)
        XCTAssertNil(copy.exportedURL)
        XCTAssertEqual(copy.status, .draft)
        XCTAssertEqual(copy.createdAt, now)
        XCTAssertEqual(copy.updatedAt, now)
        XCTAssertNotNil(original.exportedURL)
    }

    func testInvalidSelectionIdentityAndFilenameCannotBeCloned() {
        var original = project()
        XCTAssertThrowsError(try DuplicateProjectUseCase()(original, name: "../bad"))
        XCTAssertThrowsError(try DuplicateProjectUseCase()(original, name: "Copy", id: original.id))
        original.selection.end = .nan
        XCTAssertThrowsError(try DuplicateProjectUseCase()(original, name: "Copy"))
        original = project()
        original.effects.volume = .nan
        XCTAssertThrowsError(try DuplicateProjectUseCase()(original, name: "Copy"))
    }
}
