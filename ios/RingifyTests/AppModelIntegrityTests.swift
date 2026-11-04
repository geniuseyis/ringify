import Foundation
import RingifyCore
import XCTest
@testable import Ringify

private actor FailingStorage: ProjectStorageService {
    func projects() async throws -> [RingtoneProject] { [] }
    func project(id: UUID) async throws -> RingtoneProject? { nil }
    func save(_ project: RingtoneProject) async throws { throw RingifyError.storageUnavailable(reason: "Disk full") }
    func delete(id: UUID) async throws { throw RingifyError.storageUnavailable(reason: "Disk full") }
    func deleteAll() async throws { throw RingifyError.storageUnavailable(reason: "Disk full") }
}

private actor DelayedLibraryStorage: ProjectStorageService {
    private let base = InMemoryProjectStorageService()
    private var shouldBlock = true
    private var blocked = false
    private var readWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?
    func projects() async throws -> [RingtoneProject] { try await base.projects() }
    func project(id: UUID) async throws -> RingtoneProject? { try await base.project(id: id) }
    func exportHistory(projectID: UUID?) async throws -> [ProjectExportRecord] { try await base.exportHistory(projectID: projectID) }
    func save(_ project: RingtoneProject) async throws { try await base.save(project) }
    func delete(id: UUID) async throws { try await base.delete(id: id) }
    func deleteAll() async throws { try await base.deleteAll() }
    func updateLibraryMetadata(projectIDs: Set<UUID>, change: LibraryMetadataChange) async throws -> [RingtoneProject] {
        try await base.updateLibraryMetadata(projectIDs: projectIDs, change: change)
    }
    func collections() async throws -> [ProjectCollection] {
        if shouldBlock {
            shouldBlock = false
            blocked = true
            readWaiter?.resume(); readWaiter = nil
            await withCheckedContinuation { releaseWaiter = $0 }
        }
        return []
    }
    func waitUntilBlocked() async {
        if !blocked { await withCheckedContinuation { readWaiter = $0 } }
    }
    func release() { releaseWaiter?.resume(); releaseWaiter = nil }
}

private actor LibraryExportStarted {
    private var started = false
    private var waiter: CheckedContinuation<Void, Never>?
    func signal() { started = true; waiter?.resume(); waiter = nil }
    func wait() async { if !started { await withCheckedContinuation { waiter = $0 } } }
}

private struct WaitingLibraryExportService: AudioExportService {
    let started: LibraryExportStarted
    let stream: AsyncThrowingStream<ExportProgress, Error>
    func export(_ request: ExportRequest) -> AsyncThrowingStream<ExportProgress, Error> {
        Task { await started.signal() }
        return stream
    }
}

@MainActor
final class AppModelIntegrityTests: XCTestCase {
    private func container(storage: any ProjectStorageService, exportService: (any AudioExportService)? = nil) -> AppContainer {
        let directories = AppDirectories(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let media = SecureMediaImportService(directories: directories)
        let metadata = AVAudioMetadataService()
        let trim = AVAudioTrimService()
        let effects = AVAudioEffectsService()
        return AppContainer(mediaImport: media,
            authorizedMediaImport: RestrictedAuthorizedMediaImportService(importService: media),
            metadata: metadata, extraction: AVAudioExtractionService(), waveform: AVWaveformService(),
            playback: AVAudioPlaybackService(), trim: trim, effects: effects,
            export: exportService ?? AVAudioExportService(directories: directories, trimService: trim, effectsService: effects, metadataService: metadata),
            storage: storage, recorder: AVVoiceRecordingService(),
            purchases: PurchaseManager(startObservingTransactions: false), directories: directories)
    }

    private func project() -> RingtoneProject {
        RingtoneProject(name: "Original", sourceFilename: "tone.wav", sourceURL: URL(fileURLWithPath: "/missing.wav"),
            sourceKind: .audioFile, sourceDuration: 8, selection: EditSelection(start: 0, end: 8))
    }

    func testRenameFailureKeepsCurrentNameAndShowsStorageError() async {
        let model = AppModel(container: container(storage: FailingStorage()))
        let original = project()
        model.currentProject = original
        let saved = await model.renameProject(original, to: "Renamed")
        XCTAssertFalse(saved)
        XCTAssertEqual(model.currentProject?.name, "Original")
        XCTAssertEqual(model.issue, .storageFailed)
        XCTAssertNotNil(model.errorMessage)
    }

    func testEditSaveFailureIsReportedInsteadOfSwallowed() async {
        let model = AppModel(container: container(storage: FailingStorage()))
        model.currentProject = project()
        model.updateCurrentProject { $0.effects.volume = 0.5 }
        do { try await model.waitForPendingWrites(); XCTFail("Expected save failure") }
        catch { /* The failed write remains observable to callers. */ }
        for _ in 0..<10 where model.issue == nil { await Task.yield() }
        XCTAssertEqual(model.issue, .storageFailed)
    }

    func testRejectedAdvancedEditKeepsProjectAndDoesNotQueueStorage() async throws {
        let storage = InMemoryProjectStorageService()
        let model = AppModel(container: container(storage: storage))
        let original = project()
        model.currentProject = original
        XCTAssertFalse(model.updateCurrentProject { $0.effects.studio = StudioAudioPreset.clear.settings })
        XCTAssertEqual(model.currentProject, original)
        XCTAssertNotNil(model.errorMessage)
        let saved = try await storage.projects()
        XCTAssertTrue(saved.isEmpty)
        model.currentProject = nil
        XCTAssertFalse(model.updateCurrentProject { $0.effects.volume = 0.5 })
    }

    func testSavedAdvancedSettingsSurviveBasicEditWithoutProAndCanBeReset() async throws {
        let storage = InMemoryProjectStorageService()
        let model = AppModel(container: container(storage: storage))
        var original = project()
        original.effects.studio = StudioAudioPreset.telephone.settings
        model.currentProject = original
        XCTAssertTrue(model.updateCurrentProject { $0.effects.volume = 0.5 })
        try await model.waitForPendingWrites()
        let edited = try await storage.project(id: original.id)
        XCTAssertEqual(edited?.effects.studio, original.effects.studio)
        XCTAssertEqual(edited?.effects.volume, 0.5)
        XCTAssertTrue(model.updateCurrentProject { $0.effects.studio = .neutral })
        try await model.waitForPendingWrites()
        let reset = try await storage.project(id: original.id)
        XCTAssertEqual(reset?.effects.studio, .neutral)
        XCTAssertEqual(reset?.sourceURL, original.sourceURL)
    }

    func testInvalidAdvancedEditIsRejectedBeforeChangingCurrentProject() {
        let model = AppModel(container: container(storage: InMemoryProjectStorageService()))
        let original = project()
        model.currentProject = original
        XCTAssertFalse(model.updateCurrentProject { $0.effects.studio.ceiling = .nan })
        XCTAssertEqual(model.currentProject, original)
        XCTAssertNotNil(model.errorMessage)
    }

    func testUnavailableStoreNeverAcceptsEphemeralWrites() async {
        let storage = UnavailableProjectStorageService(reason: "Store could not open")
        do { try await storage.save(project()); XCTFail("Expected storage failure") }
        catch { XCTAssertEqual(error as? RingifyError, .storageUnavailable(reason: "Store could not open")) }
    }

    func testQueuedEditCannotResurrectDeletedProject() async throws {
        let storage = InMemoryProjectStorageService()
        let model = AppModel(container: container(storage: storage))
        let original = project()
        try await storage.save(original)
        model.currentProject = original
        model.updateCurrentProject { $0.effects.volume = 0.8 }
        model.updateCurrentProject { $0.effects.volume = 0.6 }
        await model.deleteProject(id: original.id)
        let remaining = try await storage.project(id: original.id)
        XCTAssertNil(remaining)
        XCTAssertNil(model.currentProject)
    }

    func testNewFavoriteAndCollectionCreationRequireVerifiedProWithoutChangingSavedProject() async throws {
        let storage = InMemoryProjectStorageService()
        let original = project()
        try await storage.save(original)
        let model = AppModel(container: container(storage: storage))
        model.currentProject = original
        let accepted = await model.updateProjectLibrary(projectIDs: [original.id], change: .favorite(true))
        XCTAssertFalse(accepted)
        XCTAssertEqual(model.issue, .purchaseFailed)
        XCTAssertEqual(model.currentProject, original)
        let created = await model.saveCollection(name: "Work")
        XCTAssertFalse(created)
        let stored = try await storage.project(id: original.id)
        let groups = try await storage.collections()
        XCTAssertEqual(stored, original)
        XCTAssertTrue(groups.isEmpty)
    }

    func testExpiredProCanRemoveOrganizationWithoutChangingAudioOrExportMetadata() async throws {
        let storage = InMemoryProjectStorageService()
        let group = ProjectCollection(name: "Existing")
        try await storage.saveCollection(group)
        var original = project()
        original.library = ProjectLibraryMetadata(favorite: true, collectionIDs: [group.id])
        original.exportedURL = URL(fileURLWithPath: "/existing.m4a")
        original.status = .exported
        try await storage.save(original)
        let model = AppModel(container: container(storage: storage))
        model.currentProject = original
        let removedFavorite = await model.updateProjectLibrary(projectIDs: [original.id], change: .favorite(false))
        XCTAssertTrue(removedFavorite)
        let removedCollection = await model.deleteCollection(id: group.id)
        XCTAssertTrue(removedCollection)
        XCTAssertEqual(model.currentProject?.library, .empty)
        XCTAssertEqual(model.currentProject?.effects, original.effects)
        XCTAssertEqual(model.currentProject?.exportedURL, original.exportedURL)
        XCTAssertEqual(model.currentProject?.updatedAt, original.updatedAt)
    }

    func testOlderLibraryReadCannotOverwriteACommittedFavoriteRemoval() async throws {
        let storage = DelayedLibraryStorage()
        var original = project()
        original.library.favorite = true
        try await storage.save(original)
        let model = AppModel(container: container(storage: storage))
        model.currentProject = original
        let oldRead = Task { await model.reloadLibrary() }
        await storage.waitUntilBlocked()
        let removed = await model.updateProjectLibrary(projectIDs: [original.id], change: .favorite(false))
        XCTAssertTrue(removed)
        await storage.release()
        let acceptedOldRead = await oldRead.value
        XCTAssertFalse(acceptedOldRead)
        XCTAssertEqual(model.projects.first?.library.favorite, false)
        XCTAssertEqual(model.currentProject?.library.favorite, false)
    }

    func testOrganizationDuringAnActiveExportKeepsProgressVisible() async throws {
        let storage = InMemoryProjectStorageService()
        var original = project()
        original.library.favorite = true
        try await storage.save(original)
        let started = LibraryExportStarted()
        let pair = AsyncThrowingStream<ExportProgress, Error>.makeStream()
        let model = AppModel(container: container(storage: storage,
            exportService: WaitingLibraryExportService(started: started, stream: pair.stream)))
        model.currentProject = original
        let export = Task { await model.exportCurrentProject(filename: "Tone") }
        await started.wait()
        model.exportProgress = .processing(0.5)
        let removed = await model.updateProjectLibrary(projectIDs: [original.id], change: .favorite(false))
        XCTAssertTrue(removed)
        XCTAssertEqual(model.exportProgress, .processing(0.5))
        let marked = await model.updateProjectMarkers(id: original.id, markers: [AudioMarker(time: 1, label: "Start")])
        XCTAssertTrue(marked)
        XCTAssertEqual(model.exportProgress, .processing(0.5))
        XCTAssertTrue(model.isWorking)
        pair.continuation.finish(throwing: CancellationError())
        await export.value
    }

    func testFailedDeleteReturnsFalseAndKeepsCurrentProjectForRetry() async {
        let model = AppModel(container: container(storage: FailingStorage()))
        let original = project()
        model.currentProject = original
        let deleted = await model.deleteProject(id: original.id)
        XCTAssertFalse(deleted)
        XCTAssertEqual(model.currentProject, original)
        XCTAssertEqual(model.issue, .storageFailed)
    }

    func testDuplicateRespectsNormalCapacityBeforeCreatingAnotherProject() async throws {
        let storage = InMemoryProjectStorageService(), original = project()
        try await storage.save(original)
        let model = AppModel(container: container(storage: storage))
        let duplicated = await model.duplicateProject(id: original.id)
        XCTAssertFalse(duplicated)
        XCTAssertTrue(model.requiresProForProjectLimit)
        XCTAssertEqual(model.issue, .purchaseFailed)
        let saved = try await storage.projects()
        XCTAssertEqual(saved, [original])
    }

    func testExpiredProCannotUseBatchRemovalToBypassBatchAccessGate() async throws {
        let storage = InMemoryProjectStorageService()
        var first = project(), second = project()
        first.library.favorite = true
        second.library.favorite = true
        try await storage.save(first)
        try await storage.save(second)
        let model = AppModel(container: container(storage: storage))
        let changed = await model.updateProjectLibrary(projectIDs: [first.id, second.id], change: .favorite(false))
        XCTAssertFalse(changed)
        let saved = try await storage.projects()
        XCTAssertTrue(saved.allSatisfy { $0.library.favorite })
    }

    func testProOutputProfilesCannotStartWithoutVerifiedEntitlement() async {
        let model = AppModel(container: container(storage: InMemoryProjectStorageService()))
        model.currentProject = project()
        for profile in [AudioOutputProfile.aacHigh, .wav24] {
            await model.exportCurrentProject(filename: "Tone", profile: profile)
            XCTAssertFalse(model.isWorking)
            XCTAssertNil(model.exportedRingtone)
            XCTAssertEqual(model.issue, .purchaseFailed)
        }
    }

    func testDeletingCommittedHistoryClearsResultButKeepsSourceAndEditSettings() async throws {
        let storage = InMemoryProjectStorageService(), original = project()
        try await storage.save(original)
        let pair = AsyncThrowingStream<ExportProgress, Error>.makeStream()
        let result = ExportedRingtone(url: URL(fileURLWithPath: "/tone.m4a"), duration: original.selection.duration, byteCount: 10)
        pair.continuation.yield(.completed(result)); pair.continuation.finish()
        let model = AppModel(container: container(storage: storage,
            exportService: WaitingLibraryExportService(started: LibraryExportStarted(), stream: pair.stream)))
        model.currentProject = original
        await model.exportCurrentProject(filename: "Tone")
        XCTAssertEqual(model.exportedRingtone, result)
        let record = try XCTUnwrap(model.exportHistory.first)
        let deleted = await model.deleteExport(record)
        XCTAssertTrue(deleted)
        XCTAssertNil(model.exportedRingtone)
        XCTAssertNil(model.currentProject?.exportedURL)
        XCTAssertEqual(model.currentProject?.sourceURL, original.sourceURL)
        XCTAssertEqual(model.currentProject?.effects, original.effects)
        XCTAssertTrue(model.exportHistory.isEmpty)
    }
}
