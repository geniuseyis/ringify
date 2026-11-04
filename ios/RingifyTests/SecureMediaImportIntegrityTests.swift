import Foundation
import RingifyCore
import XCTest
@testable import Ringify

final class SecureMediaImportIntegrityTests: XCTestCase {
    func testRejectsSymbolicLinkWithoutCreatingAnImport() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.wav"), link = root.appendingPathComponent("link.wav")
        try Data([1, 2, 3]).write(to: source)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        let service = SecureMediaImportService(directories: AppDirectories(root: root.appendingPathComponent("app")))
        do { _ = try await service.importMedia(from: link, kind: .audioFile); XCTFail("Must reject symlink") }
        catch { XCTAssertEqual(error as? RingifyError, .corruptMedia) }
        XCTAssertEqual(try Data(contentsOf: source), Data([1, 2, 3]))
    }

    func testRejectsDirectoryAndEmptyMedia() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let empty = root.appendingPathComponent("empty.wav")
        try Data().write(to: empty)
        let service = SecureMediaImportService(directories: AppDirectories(root: root.appendingPathComponent("app")))
        for source in [root, empty] {
            do { _ = try await service.importMedia(from: source, kind: .audioFile); XCTFail("Must reject non-media") }
            catch { XCTAssertEqual(error as? RingifyError, .corruptMedia) }
        }
    }
}
