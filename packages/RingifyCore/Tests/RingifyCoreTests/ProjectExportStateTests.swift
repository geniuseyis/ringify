import Foundation
import XCTest
@testable import RingifyCore

final class ProjectExportStateTests: XCTestCase {
    private func project() -> RingtoneProject {
        RingtoneProject(name: "Tone", sourceFilename: "tone.wav", sourceURL: URL(fileURLWithPath: "/source.wav"),
            sourceKind: .audioFile, sourceDuration: 12, selection: EditSelection(start: 1, end: 8))
    }
    private var output: ExportedRingtone {
        ExportedRingtone(url: URL(fileURLWithPath: "/tone.m4a"), duration: 7, byteCount: 100,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000))
    }
    func testSelectingAnotherProjectInvalidatesResult() {
        let original = project()
        var state = ProjectExportState()
        let token = state.begin(for: original)
        XCTAssertTrue(state.complete(output, for: original, token: token))
        state.invalidate(for: project())
        XCTAssertNil(state.result)
        XCTAssertFalse(state.complete(output, for: original, token: token))
    }
    func testSelectionAndEffectEditsInvalidateResult() {
        let original = project()
        for edited in [EditSelection(start: 2, end: 8), original.selection] {
            var changed = original
            changed.selection = edited
            changed.effects.volume = 0.5
            var state = ProjectExportState()
            let token = state.begin(for: original)
            state.invalidate(for: changed)
            XCTAssertFalse(state.complete(output, for: changed, token: token))
        }
    }
    func testLateCompletionFromPreviousExportIsRejected() {
        let original = project()
        var state = ProjectExportState()
        let old = state.begin(for: original)
        let latest = state.begin(for: original)
        XCTAssertFalse(state.complete(output, for: original, token: old))
        XCTAssertTrue(state.complete(output, for: original, token: latest))
    }

    func testOrganizationKeepsActiveTokenAndCompletedAudioButContentInvalidates() {
        let original = project()
        var state = ProjectExportState()
        let token = state.begin(for: original)
        var organized = original
        organized.library = ProjectLibraryMetadata(favorite: true, collectionIDs: [UUID()])
        XCTAssertFalse(state.invalidate(for: organized))
        XCTAssertTrue(state.accepts(organized, token: token))
        XCTAssertTrue(state.complete(output, for: organized, token: token))
        organized.library = .empty
        XCTAssertFalse(state.invalidate(for: organized))
        XCTAssertEqual(state.result, output)
        organized.effects.volume = 0.5
        XCTAssertTrue(state.invalidate(for: organized))
        XCTAssertNil(state.result)
    }
}
