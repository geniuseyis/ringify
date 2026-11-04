import Foundation
import RingifyCore
import XCTest
@testable import Ringify

@MainActor
final class LibraryStorageIntegrationTests: XCTestCase {
    private func store(swiftData: Bool, root: URL) throws -> any ProjectStorageService {
        if swiftData { return try SwiftDataProjectStorageService(inMemory: true, directories: AppDirectories(root: root)) }
        return InMemoryProjectStorageService()
    }

    private func project(root: URL) -> RingtoneProject {
        RingtoneProject(name: "Tone", sourceFilename: "source.wav", sourceURL: root.appendingPathComponent("Imports/source.wav"),
            sourceKind: .audioFile, sourceDuration: 8, selection: EditSelection(start: 1, end: 7),
            effects: AudioEffectSettings(volume: 0.7, studio: StudioAudioPreset.warm.settings),
            waveformSamples: [0.1, 0.4], status: .exported,
            exportedURL: root.appendingPathComponent("Exports/tone.m4a"))
    }

    func testFavoritesAndMultipleMembershipsPreserveAudioAndSurviveStaleContentSave() async throws {
        for useSwiftData in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let storage = try store(swiftData: useSwiftData, root: root)
            let original = project(root: root)
            let first = ProjectCollection(name: "Work"), second = ProjectCollection(name: "Personal")
            try await storage.saveCollection(first)
            try await storage.saveCollection(second)
            try await storage.save(original)
            _ = try await storage.updateLibraryMetadata(projectIDs: [original.id], change: .favorite(true))
            _ = try await storage.updateLibraryMetadata(projectIDs: [original.id], change: .addToCollection(first.id))
            _ = try await storage.updateLibraryMetadata(projectIDs: [original.id], change: .addToCollection(second.id))
            let organized = try await storage.project(id: original.id)
            var expected = original
            expected.library = ProjectLibraryMetadata(favorite: true, collectionIDs: [first.id, second.id])
            XCTAssertEqual(organized, expected)
            var stale = original
            stale.effects.volume = 0.5
            try await storage.save(stale)
            let edited = try await storage.project(id: original.id)
            XCTAssertEqual(edited?.library, expected.library)
            XCTAssertEqual(edited?.effects.volume, 0.5)
            XCTAssertEqual(edited?.effects.studio, original.effects.studio)
            XCTAssertEqual(edited?.exportedURL, original.exportedURL)
        }
    }

    func testDeletingACollectionOnlyUnlinksThatMembershipAndPreservesMediaBytes() async throws {
        for useSwiftData in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            try AppDirectories(root: root).prepare()
            let storage = try store(swiftData: useSwiftData, root: root)
            let original = project(root: root)
            let source = Data([1, 4, 9]), output = Data([2, 5, 8])
            try source.write(to: original.sourceURL)
            try output.write(to: XCTUnwrap(original.exportedURL))
            let first = ProjectCollection(name: "First"), retained = ProjectCollection(name: "Retained")
            try await storage.saveCollection(first)
            try await storage.saveCollection(retained)
            try await storage.save(original)
            _ = try await storage.updateLibraryMetadata(projectIDs: [original.id], change: .favorite(true))
            for group in [first, retained] {
                _ = try await storage.updateLibraryMetadata(projectIDs: [original.id], change: .addToCollection(group.id))
            }
            try await storage.deleteCollection(id: first.id)
            let restored = try await storage.project(id: original.id)
            XCTAssertEqual(restored?.library, ProjectLibraryMetadata(favorite: true, collectionIDs: [retained.id]))
            XCTAssertEqual(restored?.effects, original.effects)
            XCTAssertEqual(restored?.updatedAt, original.updatedAt)
            XCTAssertEqual(try Data(contentsOf: original.sourceURL), source)
            XCTAssertEqual(try Data(contentsOf: XCTUnwrap(original.exportedURL)), output)
            let remaining = try await storage.collections()
            XCTAssertEqual(remaining, [retained])
        }
    }

    func testMissingBatchTargetAndUnknownCollectionNeverPartiallyChangeProjects() async throws {
        for useSwiftData in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let storage = try store(swiftData: useSwiftData, root: root)
            let original = project(root: root)
            try await storage.save(original)
            do {
                _ = try await storage.updateLibraryMetadata(projectIDs: [original.id, UUID()], change: .favorite(true))
                XCTFail("A missing batch target must reject the entire change")
            } catch { XCTAssertEqual(error as? RingifyError, .projectNotFound) }
            do {
                _ = try await storage.updateLibraryMetadata(projectIDs: [original.id], change: .addToCollection(UUID()))
                XCTFail("Unknown membership must be rejected")
            } catch { XCTAssertEqual(error as? RingifyError, .projectNotFound) }
            let restored = try await storage.project(id: original.id)
            XCTAssertEqual(restored, original)
            let empty = try await storage.updateLibraryMetadata(projectIDs: [], change: .addToCollection(UUID()))
            XCTAssertTrue(empty.isEmpty)
        }
    }

    func testCollectionRenameKeepsIdentityAndDuplicateNamesFailWithoutMutation() async throws {
        for useSwiftData in [false, true] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let storage = try store(swiftData: useSwiftData, root: root)
            let original = ProjectCollection(name: "Travel")
            try await storage.saveCollection(original)
            let renamed = ProjectCollection(id: original.id, name: "Nature", createdAt: original.createdAt)
            try await storage.saveCollection(renamed)
            do {
                try await storage.saveCollection(ProjectCollection(name: "nature"))
                XCTFail("Case-insensitive duplicate must be rejected")
            } catch { XCTAssertNotNil(error as? RingifyError) }
            let groups = try await storage.collections()
            XCTAssertEqual(groups, [renamed])
            try await storage.deleteAll()
            let cleared = try await storage.collections()
            XCTAssertTrue(cleared.isEmpty)
        }
    }

    func testLegacyNilAndCorruptLibraryMetadataAreHandledDistinctly() throws {
        let original = project(root: URL(fileURLWithPath: "/tmp/library-test"))
        let row = try StoredProject(project: original)
        XCTAssertNil(row.libraryMetadataData)
        XCTAssertEqual(try row.domainModel(), original)
        row.libraryMetadataData = Data(#"{"favorite":true}"#.utf8)
        XCTAssertThrowsError(try row.domainModel())
        XCTAssertEqual(row.sourcePath, original.sourceURL.path)
        // Nil-field decoding is not an old on-disk SwiftData migration test.
    }

    func testSharedDuplicateSourceSurvivesOriginalDeletionAndIsRemovedWithLastReference() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try AppDirectories(root: root).prepare()
        let storage = try store(swiftData: true, root: root)
        let original = project(root: root)
        let payload = Data([4, 8, 12])
        try payload.write(to: original.sourceURL)
        try Data([1, 2]).write(to: XCTUnwrap(original.exportedURL))
        try await storage.save(original)
        let duplicate = try DuplicateProjectUseCase()(original, name: "Copy")
        try await storage.save(duplicate)
        try await storage.delete(id: original.id)
        XCTAssertEqual(try Data(contentsOf: duplicate.sourceURL), payload)
        XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(original.exportedURL).path))
        let restored = try await storage.project(id: duplicate.id)
        XCTAssertEqual(restored, duplicate)
        try await storage.delete(id: duplicate.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.sourceURL.path))
    }
}
