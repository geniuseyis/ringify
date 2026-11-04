import Foundation
import RingifyCore
import XCTest
@testable import Ringify

@MainActor
final class ExportHistoryStorageTests: XCTestCase {
    private func project(in root: URL) throws -> RingtoneProject {
        try AppDirectories(root: root).prepare()
        let source = root.appendingPathComponent("Imports/source.wav")
        try Data([8, 4, 2]).write(to: source)
        return RingtoneProject(name: "Tone", sourceFilename: "source.wav", sourceURL: source, sourceKind: .audioFile,
            sourceDuration: 2, selection: EditSelection(start: 0, end: 2), effects: AudioEffectSettings(volume: 0.7))
    }
    private func output(in root: URL, name: String, date: Double) throws -> ExportedRingtone {
        let url = root.appendingPathComponent("Exports/" + name)
        try Data([1, 2, 3, 4]).write(to: url)
        return ExportedRingtone(url: url, duration: 2, byteCount: 4, createdAt: Date(timeIntervalSince1970: date))
    }

    func testReexportAndContentEditsKeepHistoricalFilesUntilExplicitDeletion() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var original = try project(in: root)
        let storage = try SwiftDataProjectStorageService(inMemory: true, directories: AppDirectories(root: root))
        try await storage.save(original)
        let first = try output(in: root, name: "first.m4a", date: 10)
        let second = try output(in: root, name: "second.wav", date: 20)
        try await storage.commitExport(project: original, output: first, profile: .aacStandard)
        try await storage.commitExport(project: original, output: second, profile: .wav16)
        original.effects.volume = 0.3
        try await storage.save(original)
        let history = try await storage.exportHistory(projectID: original.id)
        XCTAssertEqual(history.map { $0.output }, [second, first])
        XCTAssertTrue(history.allSatisfy { $0.effects.volume == 0.7 })
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.url.path))
        try await storage.deleteExport(id: XCTUnwrap(history.last).id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.url.path))
        XCTAssertEqual(try Data(contentsOf: original.sourceURL), Data([8, 4, 2]))
    }

    func testDeletingAProjectDeletesItsHistoryButRetainsSharedDuplicateSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try project(in: root)
        let storage = try SwiftDataProjectStorageService(inMemory: true, directories: AppDirectories(root: root))
        try await storage.save(original)
        let result = try output(in: root, name: "tone.wav", date: 10)
        try await storage.commitExport(project: original, output: result, profile: .wav16)
        let duplicate = try DuplicateProjectUseCase()(original, name: "Copy")
        try await storage.save(duplicate)
        try await storage.delete(id: original.id)
        let remaining = try await storage.exportHistory(projectID: nil)
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.sourceURL.path))
        try await storage.delete(id: duplicate.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.sourceURL.path))
    }

    func testUnownedOrSizeMismatchedOutputCannotCreateHistoryOrAlterProject() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try project(in: root)
        let storage = try SwiftDataProjectStorageService(inMemory: true, directories: AppDirectories(root: root))
        try await storage.save(original)
        let outside = root.appendingPathComponent("unowned.wav")
        try Data([1, 2, 3, 4]).write(to: outside)
        let owned = try output(in: root, name: "size.wav", date: 10)
        for result in [ExportedRingtone(url: outside, duration: 2, byteCount: 4), ExportedRingtone(url: owned.url, duration: 2, byteCount: 9)] {
            do { try await storage.commitExport(project: original, output: result, profile: .wav16); XCTFail("Must reject invalid ownership/size") }
            catch { XCTAssertEqual(error as? RingifyError, .exportVerificationFailed) }
        }
        let restored = try await storage.project(id: original.id)
        let history = try await storage.exportHistory(projectID: nil)
        XCTAssertEqual(restored, original)
        XCTAssertTrue(history.isEmpty)
        XCTAssertEqual(try Data(contentsOf: outside), Data([1, 2, 3, 4]))
    }

    func testDeletingLatestHistoryClearsOnlyTheOutputReference() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try project(in: root)
        let storage = try SwiftDataProjectStorageService(inMemory: true, directories: AppDirectories(root: root))
        try await storage.save(original)
        let result = try output(in: root, name: "latest.wav", date: 10)
        try await storage.commitExport(project: original, output: result, profile: .wav24)
        let records = try await storage.exportHistory(projectID: original.id)
        try await storage.deleteExport(id: XCTUnwrap(records.first).id)
        let restored = try await storage.project(id: original.id)
        XCTAssertNil(restored?.exportedURL)
        XCTAssertEqual(restored?.status, .draft)
        XCTAssertEqual(restored?.effects, original.effects)
        XCTAssertEqual(try Data(contentsOf: original.sourceURL), Data([8, 4, 2]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.url.path))
    }
}
