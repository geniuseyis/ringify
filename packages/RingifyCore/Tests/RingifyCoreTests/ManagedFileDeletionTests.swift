import Foundation
import XCTest
@testable import RingifyCore

final class ManagedFileDeletionTests: XCTestCase {
    func testRecoveryConflictPreservesBothFilesAndAllowsSafeRetry() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("source.wav")
        let originalBytes = Data([1, 2, 3]), replacement = Data([9, 8, 7])
        try originalBytes.write(to: original)
        let service = ManagedFileDeletion(roots: [root], trash: root.appendingPathComponent("Trash"))
        let batch = try service.stage(candidates: [original], retaining: [])
        try replacement.write(to: original)
        XCTAssertThrowsError(try service.recover(retaining: [original]))
        XCTAssertEqual(try Data(contentsOf: original), replacement)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(batch.moves.first).staged), originalBytes)
        XCTAssertTrue(FileManager.default.fileExists(atPath: batch.directory.appendingPathComponent("journal.json").path))
        try FileManager.default.removeItem(at: original)
        try service.recover(retaining: [original])
        XCTAssertEqual(try Data(contentsOf: original), originalBytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: batch.directory.path))
        try service.recover(retaining: [original])
        XCTAssertEqual(try Data(contentsOf: original), originalBytes)
    }

    func testCorruptJournalNeverRemovesStagedMedia() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("source.wav"), bytes = Data([2, 4, 6])
        try bytes.write(to: original)
        let service = ManagedFileDeletion(roots: [root], trash: root.appendingPathComponent("Trash"))
        let batch = try service.stage(candidates: [original], retaining: [])
        try Data("invalid JSON".utf8).write(to: batch.directory.appendingPathComponent("journal.json"))
        XCTAssertThrowsError(try service.recover(retaining: [original]))
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(batch.moves.first).staged), bytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
        try service.rollback(batch)
        XCTAssertEqual(try Data(contentsOf: original), bytes)
    }

    func testRecoveryRejectsJournalPathsOutsideManagedRoot() throws {
        struct Entry: Codable { let original: URL; let stagedName: String }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let owned = root.appendingPathComponent("Imports"), trash = root.appendingPathComponent("Trash")
        let batch = trash.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: owned, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: batch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let outside = root.appendingPathComponent("outside.wav"), stagedName = UUID().uuidString
        try Data([3, 5]).write(to: outside)
        let payload = batch.appendingPathComponent(stagedName)
        try Data([7, 9]).write(to: payload)
        try JSONEncoder().encode([Entry(original: outside, stagedName: stagedName)])
            .write(to: batch.appendingPathComponent("journal.json"))
        let service = ManagedFileDeletion(roots: [owned], trash: trash)
        XCTAssertThrowsError(try service.recover(retaining: [outside]))
        XCTAssertEqual(try Data(contentsOf: outside), Data([3, 5]))
        XCTAssertEqual(try Data(contentsOf: payload), Data([7, 9]))
    }

    func testSymlinkToExternalFileIsNeverStagedOrDeleted() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let owned = root.appendingPathComponent("Imports")
        try FileManager.default.createDirectory(at: owned, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let outside = root.appendingPathComponent("external.wav"), link = owned.appendingPathComponent("link.wav")
        try Data([8, 6, 4]).write(to: outside)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        let service = ManagedFileDeletion(roots: [owned], trash: root.appendingPathComponent("Trash"))
        let batch = try service.stage(candidates: [link], retaining: [])
        XCTAssertTrue(batch.moves.isEmpty)
        try service.commit(batch)
        XCTAssertEqual(try Data(contentsOf: outside), Data([8, 6, 4]))
        XCTAssertEqual(try Data(contentsOf: link), Data([8, 6, 4]))
    }

    func testInterruptedDeletionRestoresFilesStillReferencedByMetadata() throws {
        try recoveryTest(keepReference: true)
    }
    func testInterruptedCommittedDeletionFinishesCleanup() throws {
        try recoveryTest(keepReference: false)
    }
    private func recoveryTest(keepReference: Bool) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.wav")
        try Data([9, 8]).write(to: source)
        let service = ManagedFileDeletion(roots: [root], trash: root.appendingPathComponent("Trash"))
        _ = try service.stage(candidates: [source], retaining: [])
        // Simulate relaunch without calling rollback or commit.
        try service.recover(retaining: keepReference ? [source] : [])
        XCTAssertEqual(FileManager.default.fileExists(atPath: source.path), keepReference)
        if keepReference { XCTAssertEqual(try Data(contentsOf: source), Data([9, 8])) }
    }
    func testOnlyUnreferencedOwnedFilesAreDeleted() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let owned = root.appendingPathComponent("Imports")
        let sibling = root.appendingPathComponent("ImportsOther")
        try FileManager.default.createDirectory(at: owned, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        let removed = owned.appendingPathComponent("one.wav")
        let shared = owned.appendingPathComponent("shared.wav")
        let external = sibling.appendingPathComponent("external.wav")
        for url in [removed, shared, external] { try Data([1, 2]).write(to: url) }
        let service = ManagedFileDeletion(roots: [owned], trash: root.appendingPathComponent("Trash"))
        let batch = try service.stage(candidates: [removed, shared, external], retaining: [shared])
        try service.commit(batch)
        XCTAssertFalse(FileManager.default.fileExists(atPath: removed.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: shared.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: external.path))
    }
    func testMetadataFailureCanRestoreStagedFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.wav")
        try Data([3, 4, 5]).write(to: source)
        let service = ManagedFileDeletion(roots: [root], trash: root.appendingPathComponent("Trash"))
        let batch = try service.stage(candidates: [source], retaining: [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        try service.rollback(batch)
        XCTAssertEqual(try Data(contentsOf: source), Data([3, 4, 5]))
    }
}
