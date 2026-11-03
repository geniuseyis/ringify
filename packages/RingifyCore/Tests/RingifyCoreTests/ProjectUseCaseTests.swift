import Foundation
import XCTest
@testable import RingifyCore

final class ProjectUseCaseTests: XCTestCase {
    func testCreateProjectUsesAtMostTwentyNineSeconds() throws {
        let media = ImportedMedia(
            localURL: URL(fileURLWithPath: "/tmp/source.m4a"),
            originalFilename: "Morning.m4a",
            sourceKind: .audioFile
        )
        let metadata = AudioMetadata(
            duration: 42,
            sampleRate: 44_100,
            channelCount: 2,
            formatDescription: "AAC",
            hasAudioTrack: true
        )

        let project = try CreateProjectUseCase()(media: media, metadata: metadata)

        XCTAssertEqual(project.name, "Morning")
        XCTAssertEqual(project.selection, EditSelection(start: 0, end: 29))
        XCTAssertEqual(project.status, .draft)
    }

    func testCreateProjectRejectsMediaWithoutAudio() {
        let media = ImportedMedia(
            localURL: URL(fileURLWithPath: "/tmp/silent.mov"),
            originalFilename: "silent.mov",
            sourceKind: .videoFile
        )
        let metadata = AudioMetadata(
            duration: 12,
            sampleRate: 0,
            channelCount: 0,
            formatDescription: "none",
            hasAudioTrack: false
        )

        XCTAssertThrowsError(try CreateProjectUseCase()(media: media, metadata: metadata)) { error in
            XCTAssertEqual(error as? RingifyError, .missingAudioTrack)
        }
    }

    func testRenameAndExportMutationsUpdateProject() {
        let created = Date(timeIntervalSince1970: 100)
        let updated = Date(timeIntervalSince1970: 200)
        var project = RingtoneProject(
            name: "Old",
            sourceFilename: "old.m4a",
            sourceURL: URL(fileURLWithPath: "/tmp/old.m4a"),
            sourceKind: .audioFile,
            sourceDuration: 10,
            selection: EditSelection(start: 0, end: 10),
            createdAt: created,
            updatedAt: created
        )
        let exportURL = URL(fileURLWithPath: "/tmp/new.m4a")

        project.rename(to: "New", now: updated)
        project.markExported(to: exportURL, now: updated)

        XCTAssertEqual(project.name, "New")
        XCTAssertEqual(project.status, .exported)
        XCTAssertEqual(project.exportedURL, exportURL)
        XCTAssertEqual(project.updatedAt, updated)
    }

    func testSearchIsCaseInsensitiveAndNewestFirst() {
        let older = makeProject(name: "Morning Bell", updated: 10)
        let newer = makeProject(name: "Night Bell", updated: 20)
        let useCase = SearchProjectsUseCase()

        XCTAssertEqual(useCase([older, newer], query: "BELL").map(\.name), ["Night Bell", "Morning Bell"])
        XCTAssertEqual(useCase([older, newer], query: "night").map(\.name), ["Night Bell"])
    }

    private func makeProject(name: String, updated: TimeInterval) -> RingtoneProject {
        RingtoneProject(
            name: name,
            sourceFilename: "source.m4a",
            sourceURL: URL(fileURLWithPath: "/tmp/source.m4a"),
            sourceKind: .audioFile,
            sourceDuration: 5,
            selection: EditSelection(start: 0, end: 5),
            updatedAt: Date(timeIntervalSince1970: updated)
        )
    }
}
