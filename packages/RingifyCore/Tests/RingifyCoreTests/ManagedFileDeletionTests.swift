import Foundation
import XCTest
@testable import RingifyCore

final class ManagedFileDeletionTests: XCTestCase {
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
