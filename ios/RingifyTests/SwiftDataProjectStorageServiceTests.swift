import Foundation
import RingifyCore
import XCTest
@testable import Ringify

@MainActor
final class SwiftDataProjectStorageServiceTests: XCTestCase {
    func testSaveUpdateAndDeleteProject() async throws {
        let service = try SwiftDataProjectStorageService(inMemory: true)
        var project = makeProject(name: "First")

        try await service.save(project)
        let initialProjects = try await service.projects()
        XCTAssertEqual(initialProjects.map(\.name), ["First"])

        project.rename(to: "Renamed")
        try await service.save(project)
        let renamedProject = try await service.project(id: project.id)
        XCTAssertEqual(renamedProject?.name, "Renamed")

        try await service.delete(id: project.id)
        let remainingProjects = try await service.projects()
        XCTAssertTrue(remainingProjects.isEmpty)
    }

    func testDeleteAllProjects() async throws {
        let service = try SwiftDataProjectStorageService(inMemory: true)
        try await service.save(makeProject(name: "One"))
        try await service.save(makeProject(name: "Two"))

        try await service.deleteAll()

        let projects = try await service.projects()
        XCTAssertTrue(projects.isEmpty)
    }

    func testAdvancedSettingsRoundTripAndResetPreserveProjectMetadata() async throws {
        let service = try SwiftDataProjectStorageService(inMemory: true)
        var project = makeProject(name: "Advanced")
        project.effects = AudioEffectSettings(volume: 0.7, fadeInDuration: 0.2, normalize: true,
            studio: StudioAudioSettings(midGainDB: 3, highPassHz: 80, channelMode: .stereo, limiterEnabled: true, ceiling: 0.8))
        project.waveformSamples = [0.1, 0.4, 0.2]
        try await service.save(project)
        let restored = try await service.project(id: project.id)
        XCTAssertEqual(restored, project)
        project.effects.studio = .neutral
        try await service.save(project)
        let reset = try await service.project(id: project.id)
        XCTAssertEqual(reset, project)
    }

    func testLegacyNilStudioMetadataKeepsExistingEffects() throws {
        var project = makeProject(name: "Legacy")
        project.effects = AudioEffectSettings(volume: 0.6, fadeOutDuration: 0.3, normalize: true)
        let row = try StoredProject(project: project)
        XCTAssertNil(row.studioSettingsData)
        XCTAssertEqual(try row.domainModel(), project)
        // This checks nil-field decoding, not migration of a pre-upgrade disk store.
    }

    func testLoopSettingsPersistThroughReopenAndUpdateWithoutChangingSource() async throws {
        let storage = try SwiftDataProjectStorageService(inMemory: true)
        var project = makeProject(name: "Loop")
        project.effects.loopCrossfadeDuration = 0.03
        try await storage.save(project)
        let saved = try await storage.project(id: project.id)
        XCTAssertEqual(saved?.effects.loopCrossfadeDuration, 0.03)
        project.effects.loopCrossfadeDuration = 0
        try await storage.save(project)
        let disabled = try await storage.project(id: project.id)
        XCTAssertEqual(disabled?.effects.loopCrossfadeDuration, 0)
        XCTAssertEqual(disabled?.sourceURL, project.sourceURL)
    }

    func testCorruptStudioMetadataFailsInsteadOfDroppingEffects() throws {
        var project = makeProject(name: "Corrupt")
        project.effects.studio = StudioAudioPreset.warm.settings
        let row = try StoredProject(project: project)
        row.studioSettingsData = Data(#"{"midGainDB":3}"#.utf8)
        XCTAssertThrowsError(try row.domainModel())
        XCTAssertEqual(row.sourcePath, project.sourceURL.path)
        XCTAssertEqual(row.name, project.name)
    }

    func testInvalidSettingsCannotPartiallyUpdateStoredProject() async throws {
        let service = try SwiftDataProjectStorageService(inMemory: true)
        let original = makeProject(name: "Original")
        try await service.save(original)
        let row = try StoredProject(project: original)
        var invalid = original
        invalid.name = "Must not persist"
        invalid.effects.studio.highPassHz = 500
        invalid.effects.studio.lowPassHz = 300
        XCTAssertThrowsError(try row.update(from: invalid))
        XCTAssertEqual(try row.domainModel(), original)
        do { try await service.save(invalid); XCTFail("Expected validation failure") }
        catch { XCTAssertEqual(error as? RingifyError, .corruptMedia) }
        let restored = try await service.project(id: original.id)
        XCTAssertEqual(restored, original)
    }

    private func makeProject(name: String) -> RingtoneProject {
        RingtoneProject(
            name: name,
            sourceFilename: "source.m4a",
            sourceURL: URL(fileURLWithPath: "/tmp/source.m4a"),
            sourceKind: .audioFile,
            sourceDuration: 8,
            selection: EditSelection(start: 0, end: 8)
        )
    }
}
