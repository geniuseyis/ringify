import Foundation
import AVFoundation
import AudioToolbox
import RingifyCore
import XCTest
@testable import Ringify

// Must run on macOS/Xcode with AVFoundation. Windows source presence is NOT a pass.
final class AudioConversionIntegrationTests: XCTestCase {
    func testRealAACMP4ContainerConvertsToWAVAndM4AWithFiniteAudibleSamples() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.mp4")
        let rate = 48_000.0, frames = AVAudioFrameCount(48_000)
        let pcm = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: pcm, frameCapacity: frames))
        buffer.frameLength = frames
        let samples = try XCTUnwrap(buffer.floatChannelData)[0]
        for index in 0..<Int(frames) { samples[index] = Float(sin(2 * .pi * 440 * Double(index) / rate) * 0.25) }
        let writer = try FinalizedPCMWriter(url: source, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: rate, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 128_000])
        try writer.write(from: buffer)
        writer.finish()
        let original = try Data(contentsOf: source)
        XCTAssertEqual(String(data: original[4..<8], encoding: .ascii), "ftyp")
        let service = AVAudioConversionService(root: directory.appendingPathComponent("work"))
        for format in AudioConversionFormat.allCases {
            let result = try await service.convert(sourceURL: source, format: format, filename: "Converted MP4")
            XCTAssertEqual(result.duration, 1, accuracy: 0.15)
            let decoded = try AVAudioFile(forReading: result.url)
            XCTAssertEqual(decoded.processingFormat.channelCount, 1)
            let chunk = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: decoded.processingFormat, frameCapacity: 4_096))
            var count = 0, energy = 0.0
            while decoded.framePosition < decoded.length {
                try decoded.read(into: chunk)
                guard chunk.frameLength > 0 else { XCTFail("Decoder stopped before the declared end"); break }
                let channel = try XCTUnwrap(chunk.floatChannelData)[0]
                for index in 0..<Int(chunk.frameLength) {
                    XCTAssertTrue(channel[index].isFinite)
                    XCTAssertLessThanOrEqual(abs(channel[index]), 1)
                    energy += Double(channel[index] * channel[index])
                }
                count += Int(chunk.frameLength)
            }
            XCTAssertGreaterThan(count, 40_000)
            XCTAssertGreaterThan(energy / Double(max(1, count)), 0.001, "A silent or empty result is not successful conversion")
            XCTAssertEqual(try Data(contentsOf: source), original)
            try await service.discard(result)
            XCTAssertFalse(FileManager.default.fileExists(atPath: result.url.path))
            XCTAssertEqual(try Data(contentsOf: source), original)
        }
    }

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
