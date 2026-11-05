import Foundation
import RingifyCore
import XCTest
@testable import Ringify

/// Each case owns a fresh SQLite store and real media files, never app data.
@MainActor final class DiskStorageIntegrationTests: XCTestCase {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RingifyDiskTests-\(UUID().uuidString)")
        try AppDirectories(root: root).prepare()
        return root
    }

    private func store(_ root: URL) throws -> SwiftDataProjectStorageService {
        try SwiftDataProjectStorageService(directories: AppDirectories(root: root),
            storeURL: root.appendingPathComponent("integration.store"))
    }

    private func writeProject(_ root: URL) async throws -> RingtoneProject {
        let source = root.appendingPathComponent("Imports/source.wav")
        try Data([4, 8, 15, 16, 23, 42]).write(to: source)
        var project = RingtoneProject(name: "Disk project", sourceFilename: "source.wav", sourceURL: source,
            sourceKind: .audioFile, sourceDuration: 8, selection: EditSelection(start: 1, end: 7),
            effects: AudioEffectSettings(volume: 0.65, fadeInDuration: 0.2, fadeOutDuration: 0.3,
                studio: StudioAudioPreset.warm.settings), waveformSamples: [0.1, 0.4, 0.2])
        project.effects.loopCrossfadeDuration = 0.02
        let storage = try store(root)
        try await storage.save(project)
        return project
    }

    private func deletion(_ root: URL) -> ManagedFileDeletion {
        let directories = AppDirectories(root: root)
        return ManagedFileDeletion(roots: [directories.imports, directories.exports, directories.recordings],
            trash: root.appendingPathComponent("PendingDeletion", isDirectory: true))
    }

    func testActualDiskReopenPreservesEditingSettingsAndSourceBytes() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try await writeProject(root)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("integration.store").path))
        let reopened = try store(root)
        let restored = try await reopened.project(id: original.id)
        XCTAssertEqual(restored, original)
        XCTAssertEqual(try Data(contentsOf: original.sourceURL), Data([4, 8, 15, 16, 23, 42]))
    }

    func testStartupRestoresStagedFileWhenDiskMetadataStillReferencesIt() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try await writeProject(root)
        // Process interruption after moving bytes, before committing metadata.
        _ = try deletion(root).stage(candidates: [original.sourceURL], retaining: [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.sourceURL.path))
        let reopened = try store(root)
        let restored = try await reopened.project(id: original.id)
        XCTAssertEqual(restored, original)
        XCTAssertEqual(try Data(contentsOf: original.sourceURL), Data([4, 8, 15, 16, 23, 42]))
        let journals = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("PendingDeletion").path)
        XCTAssertTrue(journals.isEmpty)
    }

    func testStartupConflictKeepsBothVersionsAndJournalForRecovery() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try await writeProject(root)
        _ = try deletion(root).stage(candidates: [original.sourceURL], retaining: [])
        let replacement = Data([99, 98, 97])
        try replacement.write(to: original.sourceURL)
        XCTAssertThrowsError(try store(root))
        XCTAssertEqual(try Data(contentsOf: original.sourceURL), replacement)
        let trash = root.appendingPathComponent("PendingDeletion")
        let batches = try FileManager.default.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil)
        XCTAssertEqual(batches.count, 1)
        let staged = try FileManager.default.contentsOfDirectory(at: XCTUnwrap(batches.first), includingPropertiesForKeys: nil)
        let payload = try XCTUnwrap(staged.first { $0.lastPathComponent != "journal.json" })
        XCTAssertEqual(try Data(contentsOf: payload), Data([4, 8, 15, 16, 23, 42]))
        // User resolves the conflict; restart recovers the original bytes.
        try FileManager.default.removeItem(at: original.sourceURL)
        let reopened = try store(root)
        let restored = try await reopened.project(id: original.id)
        XCTAssertEqual(restored, original)
        XCTAssertEqual(try Data(contentsOf: original.sourceURL), Data([4, 8, 15, 16, 23, 42]))
    }

    func testUnreferencedInterruptedDeletionFinishesOnNextStartup() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try await writeProject(root)
        let orphan = root.appendingPathComponent("Exports/orphan.wav")
        try Data([7, 7, 7]).write(to: orphan)
        _ = try deletion(root).stage(candidates: [orphan], retaining: [])
        let reopened = try store(root)
        let projects = try await reopened.projects()
        XCTAssertEqual(projects.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("PendingDeletion").path).isEmpty)
    }

    private func saveDuplicateAndDeleteOriginal(_ root: URL, original: RingtoneProject) async throws -> RingtoneProject {
        let storage = try store(root)
        let copy = try DuplicateProjectUseCase()(original, name: "Disk copy")
        try await storage.save(copy)
        try await storage.delete(id: original.id)
        return copy
    }

    func testSharedSourceSurvivesDeleteAndDiskReopenUntilLastReference() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try await writeProject(root)
        let copy = try await saveDuplicateAndDeleteOriginal(root, original: original)
        let reopened = try store(root)
        let projects = try await reopened.projects()
        XCTAssertEqual(projects, [copy])
        XCTAssertEqual(try Data(contentsOf: copy.sourceURL), Data([4, 8, 15, 16, 23, 42]))
        try await reopened.delete(id: copy.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: copy.sourceURL.path))
        let finalStore = try store(root)
        let remaining = try await finalStore.projects()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testInvalidExplicitStoreConfigurationIsRejected() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try SwiftDataProjectStorageService(inMemory: true, directories: AppDirectories(root: root),
            storeURL: root.appendingPathComponent("unused.store")))
        XCTAssertThrowsError(try SwiftDataProjectStorageService(directories: AppDirectories(root: root),
            storeURL: XCTUnwrap(URL(string: "https://example.invalid/store"))))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("unused.store").path))
    }
}
