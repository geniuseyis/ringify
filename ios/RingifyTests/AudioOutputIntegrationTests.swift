import AVFoundation
import AudioToolbox
import RingifyCore
import XCTest
@testable import Ringify

@MainActor
final class AudioOutputIntegrationTests: XCTestCase {
    func testComparisonUsesUnprocessedCutAndPCMProcessedOutputWithoutChangingProject() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture(in: root), bytes = try Data(contentsOf: source)
        let project = RingtoneProject(name: "AB", sourceFilename: "source.wav", sourceURL: source,
            sourceKind: .audioFile, sourceDuration: 2, selection: EditSelection(start: 0.125, end: 1.625))
        let settings = AudioEffectSettings(volume: 0.25, loopCrossfadeDuration: 0.03)
        let renderer = AudioComparisonRenderer(trim: AVAudioTrimService(), effects: AVAudioEffectsService(),
            metadata: AVAudioMetadataService(), directories: AppDirectories(root: root))
        let input = AudioComparisonInput(project: project, effects: settings)
        let original = try await renderer.render(input, mode: .original)
        defer { try? FileManager.default.removeItem(at: original.url) }
        let processed = try await renderer.render(input, mode: .processed)
        defer { try? FileManager.default.removeItem(at: processed.url) }
        let rawFile = try AVAudioFile(forReading: original.url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let effectedFile = try AVAudioFile(forReading: processed.url, commonFormat: .pcmFormatFloat32, interleaved: false)
        XCTAssertEqual(rawFile.length, 72_000)
        XCTAssertEqual(effectedFile.length, 70_560)
        XCTAssertEqual(effectedFile.fileFormat.streamDescription.pointee.mFormatID, kAudioFormatLinearPCM)
        let raw = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: rawFile.processingFormat, frameCapacity: 72_000))
        let effected = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: effectedFile.processingFormat, frameCapacity: 70_560))
        try rawFile.read(into: raw); try effectedFile.read(into: effected)
        XCTAssertEqual(try XCTUnwrap(raw.floatChannelData)[0][100], Float(sin(2 * Double.pi * 440 * 6_100 / 48_000) * 0.5))
        XCTAssertEqual(try XCTUnwrap(effected.floatChannelData)[0][100], try XCTUnwrap(raw.floatChannelData)[0][1540] * 0.25, accuracy: 0.000_001)
        XCTAssertEqual(original.sourceOffset, 0); XCTAssertEqual(processed.sourceOffset, 0.03, accuracy: 1e-9)
        XCTAssertEqual(project.effects, .neutral)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
    }

    private func fixture(in root: URL) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("source.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 96_000))
        buffer.frameLength = 96_000
        let samples = try XCTUnwrap(buffer.floatChannelData)[0]
        for i in 0..<96_000 { samples[i] = Float(sin(2 * Double.pi * 440 * Double(i) / 48_000) * 0.5) }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    func testPCMTrimRetainsSelectedFramesWithoutLossyReencodingOrSourceMutation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture(in: root), bytes = try Data(contentsOf: source)
        let destination = root.appendingPathComponent("trim.caf")
        _ = try await AVAudioTrimService().trimPCM(sourceURL: source,
            selection: EditSelection(start: 0.125, end: 1.625), destinationURL: destination)
        let result = try AVAudioFile(forReading: destination, commonFormat: .pcmFormatFloat32, interleaved: false)
        XCTAssertEqual(result.length, 72_000)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: result.processingFormat, frameCapacity: 72_000))
        try result.read(into: buffer)
        XCTAssertEqual(buffer.frameLength, 72_000)
        let values = try XCTUnwrap(buffer.floatChannelData)[0]
        for i in [0, 10, 8191, 8192, 71_999] {
            XCTAssertEqual(values[i], Float(sin(2 * Double.pi * 440 * Double(i + 6_000) / 48_000) * 0.5))
        }
        XCTAssertEqual(try Data(contentsOf: source), bytes)
    }

    func testPCMWriterFinalizesBeforeReadAndRejectsFurtherWrites() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 127))
        buffer.frameLength = 127
        let samples = try XCTUnwrap(buffer.floatChannelData)[0]
        for index in 0..<127 { samples[index] = Float(index - 63) / 128 }
        let expected = Array(UnsafeBufferPointer(start: samples, count: 127))
        let writer = try FinalizedPCMWriter(url: url, settings: format.settings)
        try writer.write(from: buffer)
        writer.finish()
        writer.finish()
        let result = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let read = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: result.processingFormat, frameCapacity: 127))
        try result.read(into: read)
        XCTAssertEqual(result.length, 127)
        XCTAssertEqual(read.frameLength, 127)
        XCTAssertEqual(Array(UnsafeBufferPointer(start: try XCTUnwrap(read.floatChannelData)[0], count: 127)), expected)
        let bytes = try Data(contentsOf: url)
        XCTAssertThrowsError(try writer.write(from: buffer))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    func testEachRealOutputProfileVerifiesCodecPrecisionDurationAndSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture(in: root), bytes = try Data(contentsOf: source)
        let service = AVAudioExportService(directories: AppDirectories(root: root), trimService: AVAudioTrimService(),
            effectsService: AVAudioEffectsService(), metadataService: AVAudioMetadataService())
        for profile in AudioOutputProfile.allCases {
            let request = ExportRequest(projectID: UUID(), sourceURL: source, filename: profile.rawValue,
                selection: EditSelection(start: 0.125, end: 1.625), effects: AudioEffectSettings(volume: 0.5), profile: profile)
            var completed: ExportedRingtone?
            for try await progress in service.export(request) { if case .completed(let result) = progress { completed = result } }
            let result = try XCTUnwrap(completed)
            let file = try AVAudioFile(forReading: result.url)
            let description = file.fileFormat.streamDescription.pointee
            XCTAssertEqual(result.url.pathExtension, profile.format.fileExtension)
            XCTAssertEqual(result.duration, 1.5, accuracy: profile.bitDepth == nil ? 0.1 : 0.001)
            if let depth = profile.bitDepth {
                XCTAssertEqual(description.mFormatID, kAudioFormatLinearPCM)
                XCTAssertEqual(description.mBitsPerChannel, UInt32(depth))
                XCTAssertEqual(file.length, 72_000)
                XCTAssertEqual(Array(try Data(contentsOf: result.url).prefix(4)), Array("RIFF".utf8))
            } else {
                XCTAssertEqual(description.mFormatID, kAudioFormatMPEG4AAC)
                let metadata = try await AVAudioMetadataService().metadata(for: result.url)
                XCTAssertEqual(metadata.formatDescription, "aac")
            }
            XCTAssertEqual(try Data(contentsOf: source), bytes)
        }
    }

    func testLosslessTrimRefusesSourceOverwriteAndExistingDestination() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture(in: root), bytes = try Data(contentsOf: source)
        let destination = root.appendingPathComponent("retained.caf"), retained = Data([2, 4, 6])
        try retained.write(to: destination)
        for target in [source, destination] {
            do {
                _ = try await AVAudioTrimService().trimPCM(sourceURL: source, selection: EditSelection(start: 0, end: 1), destinationURL: target)
                XCTFail("Existing files must not be overwritten")
            } catch { XCTAssertEqual(error as? RingifyError, .corruptMedia) }
            do {
                _ = try await AVAudioTrimService().trim(sourceURL: source, selection: EditSelection(start: 0, end: 1), destinationURL: target)
                XCTFail("Legacy trim must also reject overwriting existing files")
            } catch { XCTAssertEqual(error as? RingifyError, .corruptMedia) }
        }
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        XCTAssertEqual(try Data(contentsOf: destination), retained)
    }

    func testEffectsNeverOverwriteAnExistingOutputFile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture(in: root), destination = root.appendingPathComponent("retained.m4a")
        let retained = Data([8, 2, 4])
        try retained.write(to: destination)
        do {
            _ = try await AVAudioEffectsService().process(sourceURL: source, destinationURL: destination, settings: .neutral, expectedDuration: 2)
            XCTFail("Must refuse an existing destination")
        } catch { XCTAssertEqual(error as? RingifyError, .corruptMedia) }
        XCTAssertEqual(try Data(contentsOf: destination), retained)
    }

    func testLoopWAVHasTheExactShorterDurationAndOriginalAdjacentJoinSamples() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture(in: root), bytes = try Data(contentsOf: source)
        let service = AVAudioExportService(directories: AppDirectories(root: root), trimService: AVAudioTrimService(),
            effectsService: AVAudioEffectsService(), metadataService: AVAudioMetadataService())
        var result: ExportedRingtone?
        let request = ExportRequest(projectID: UUID(), sourceURL: source, filename: "Loop", selection: EditSelection(start: 0, end: 2),
            effects: AudioEffectSettings(loopCrossfadeDuration: 0.03), profile: .wav16)
        for try await progress in service.export(request) { if case .completed(let output) = progress { result = output } }
        let file = try AVAudioFile(forReading: XCTUnwrap(result).url, commonFormat: .pcmFormatFloat32, interleaved: false)
        XCTAssertEqual(file.length, 94_560)
        XCTAssertEqual(try XCTUnwrap(result).duration, 1.97, accuracy: 0.001)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let channel = try XCTUnwrap(buffer.floatChannelData)[0]
        for (index, sourceFrame) in [(0,1440),(94_559,1439)] {
            XCTAssertEqual(channel[index], Float(sin(2 * Double.pi * 440 * Double(sourceFrame) / 48_000) * 0.5), accuracy: 0.000_1)
        }
        XCTAssertEqual(try Data(contentsOf: source), bytes)
    }
}
