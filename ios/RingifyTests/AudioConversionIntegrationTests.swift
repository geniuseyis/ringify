import Foundation
import RingifyCore
import XCTest
@testable import Ringify

// Must run on macOS/Xcode with AVFoundation. Windows source presence is NOT a pass.
final class AudioConversionIntegrationTests: XCTestCase {
    func testRealMP3ToWAVAndAACPreservesSourceAndCleansOutput() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var data = Data(repeating: 0, count: 417 * 1_200)
        for frame in 0..<1_200 { data.replaceSubrange(frame * 417..<frame * 417 + 4, with: [0xFF, 0xFB, 0x90, 0xC0]) }
        let source = directory.appendingPathComponent("original.mp3")
        try data.write(to: source)
        let service = AVAudioConversionService(root: directory.appendingPathComponent("work"))
        for format in AudioConversionFormat.allCases {
            let result = try await service.convert(sourceURL: source, format: format, filename: "Converted")
            XCTAssertGreaterThan(result.duration, 30)
            XCTAssertLessThan(result.duration, 33)
            XCTAssertGreaterThan(result.byteCount, 44)
            XCTAssertEqual(try Data(contentsOf: source), data)
            XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
            try await service.discard(result)
            XCTAssertFalse(FileManager.default.fileExists(atPath: result.url.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        }
    }

    func testForgedMP4IsRejectedWithoutLeavingWorkspaceOrDeletingSource() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("fake.mp4"), bytes = Data("not an mp4".utf8)
        try bytes.write(to: source)
        let service = AVAudioConversionService(root: directory.appendingPathComponent("work"))
        do {
            _ = try await service.convert(sourceURL: source, format: .wav, filename: "test")
            XCTFail("Forged container must not produce a result")
        } catch { XCTAssertEqual(try Data(contentsOf: source), bytes) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("work").path))
    }

    func testUnownedDiscardNeverDeletesAnArbitraryFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("retained.wav")
        try Data([1, 2, 3]).write(to: source)
        let service = AVAudioConversionService(root: directory.appendingPathComponent("work"))
        try await service.discard(ConvertedAudio(url: source, duration: 1, byteCount: 3))
        XCTAssertEqual(try Data(contentsOf: source), Data([1, 2, 3]))
    }
}
