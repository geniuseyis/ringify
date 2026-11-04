import Foundation
import RingifyCore
import XCTest
@testable import Ringify

private actor RejectingSelectionStorage: ProjectStorageService {
    func projects() async throws -> [RingtoneProject] { [] }
    func project(id: UUID) async throws -> RingtoneProject? { nil }
    func save(_ project: RingtoneProject) async throws { throw RingifyError.storageUnavailable(reason: "Disk full") }
    func delete(id: UUID) async throws { throw RingifyError.storageUnavailable(reason: "Disk full") }
    func deleteAll() async throws { throw RingifyError.storageUnavailable(reason: "Disk full") }
}

@MainActor final class StudioSelectionPersistenceTests: XCTestCase {
    private func model(storage: any ProjectStorageService) -> AppModel {
        let directories = AppDirectories(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let media = SecureMediaImportService(directories: directories), metadata = AVAudioMetadataService()
        let trim = AVAudioTrimService(), effects = AVAudioEffectsService()
        return AppModel(container: AppContainer(mediaImport: media,
            authorizedMediaImport: RestrictedAuthorizedMediaImportService(importService: media), metadata: metadata,
            extraction: AVAudioExtractionService(), waveform: AVWaveformService(), playback: AVAudioPlaybackService(),
            trim: trim, effects: effects,
            export: AVAudioExportService(directories: directories, trimService: trim, effectsService: effects, metadataService: metadata),
            storage: storage, recorder: AVVoiceRecordingService(), purchases: PurchaseManager(startObservingTransactions: false), directories: directories))
    }
    private func project() -> RingtoneProject {
        RingtoneProject(name: "Studio selection", sourceFilename: "tone.wav", sourceURL: URL(fileURLWithPath: "/test-source.wav"),
            sourceKind: .audioFile, sourceDuration: 8, selection: EditSelection(start: 0, end: 8))
    }
    func testCommittedTrimReachesTheExistingPersistenceQueue() async throws {
        let storage = InMemoryProjectStorageService(), app = model(storage: storage), original = project()
        app.currentProject = original
        let next = EditSelection(start: 1, end: 6)
        XCTAssertTrue(StudioSelectionPersistence.commit(next, expectedProjectID: original.id, model: app))
        try await app.waitForPendingWrites()
        let saved = try await storage.projects()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.selection, next)
        XCTAssertEqual(saved.first?.sourceURL, original.sourceURL)
        XCTAssertEqual(saved.first?.effects, original.effects)
    }
    func testNoOpDoesNotInvalidateAnExistingExportOrQueueAWrite() async throws {
        let storage = InMemoryProjectStorageService(), app = model(storage: storage)
        var original = project()
        original.exportedURL = URL(fileURLWithPath: "/test-output.m4a")
        original.status = .exported
        app.currentProject = original
        XCTAssertTrue(StudioSelectionPersistence.commit(original.selection, expectedProjectID: original.id, model: app))
        try await app.waitForPendingWrites()
        let saved = try await storage.projects()
        XCTAssertTrue(saved.isEmpty)
        XCTAssertEqual(app.currentProject?.exportedURL, original.exportedURL)
        XCTAssertEqual(app.currentProject?.status, .exported)
    }
    func testAStaleProjectCommitCannotEditTheNewProject() async throws {
        let storage = InMemoryProjectStorageService(), app = model(storage: storage), current = project()
        app.currentProject = current
        XCTAssertFalse(StudioSelectionPersistence.commit(EditSelection(start: 1, end: 6), expectedProjectID: UUID(), model: app))
        try await app.waitForPendingWrites()
        let saved = try await storage.projects()
        XCTAssertTrue(saved.isEmpty)
        XCTAssertEqual(app.currentProject?.selection, current.selection)
    }
    func testInvalidSelectionIsRejectedWithoutChangingProjectOrStorage() async throws {
        let storage = InMemoryProjectStorageService(), app = model(storage: storage), original = project()
        app.currentProject = original
        for selection in [EditSelection(start: 0, end: 0.5), EditSelection(start: -1, end: 6), EditSelection(start: 0, end: 9), EditSelection(start: 0, end: .nan)] {
            XCTAssertFalse(StudioSelectionPersistence.commit(selection, expectedProjectID: original.id, model: app))
        }
        try await app.waitForPendingWrites()
        let saved = try await storage.projects()
        XCTAssertTrue(saved.isEmpty)
        XCTAssertEqual(app.currentProject?.selection, original.selection)
    }
    func testUndoStyleUpdatesArePersistedInOrder() async throws {
        let storage = InMemoryProjectStorageService(), app = model(storage: storage), original = project()
        app.currentProject = original
        XCTAssertTrue(StudioSelectionPersistence.commit(EditSelection(start: 1, end: 6), expectedProjectID: original.id, model: app))
        XCTAssertTrue(StudioSelectionPersistence.commit(original.selection, expectedProjectID: original.id, model: app))
        try await app.waitForPendingWrites()
        let saved = try await storage.projects()
        XCTAssertEqual(saved.first?.selection, original.selection)
    }
    func testQueuedSaveFailureIsNotReportedAsDurableSuccess() async {
        let app = model(storage: RejectingSelectionStorage()), original = project()
        app.currentProject = original
        XCTAssertTrue(StudioSelectionPersistence.commit(EditSelection(start: 1, end: 6), expectedProjectID: original.id, model: app))
        do { try await app.waitForPendingWrites(); XCTFail("Expected rejected write") } catch { }
    }
}
