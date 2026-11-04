import AVFoundation
import RingifyCore
import XCTest
@testable import Ringify

@MainActor
final class AudioIntegrityIntegrationTests: XCTestCase {
    private func fixture(sampleRate: Double = 48_000) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
        let frames = AVAudioFrameCount(sampleRate * 2)
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let channel = try XCTUnwrap(buffer.floatChannelData)[0]
        for frame in 0..<Int(frames) { channel[frame] = Float(sin(2 * Double.pi * 440 * Double(frame) / sampleRate)) * 0.8 }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    func testReloadOfSameSourceRetainsPausedPositionAndStopResets() throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let service = AVAudioPlaybackService()
        try service.load(url: url)
        service.seek(to: 0.7)
        service.pause()
        try service.load(url: url)
        XCTAssertEqual(service.currentTime, 0.7, accuracy: 0.001)
        try service.play(selection: EditSelection(start: 0.2, end: 1.7), loop: false)
        service.pause()
        XCTAssertGreaterThanOrEqual(service.currentTime, 0.7)
        service.stop()
        XCTAssertEqual(service.currentTime, 0.2, accuracy: 0.001)
    }

    func testInvalidRangesCannotStartPlayback() throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let service = AVAudioPlaybackService()
        try service.load(url: url)
        XCTAssertThrowsError(try service.play(selection: EditSelection(start: .nan, end: 1), loop: false))
        XCTAssertThrowsError(try service.play(selection: EditSelection(start: 1.5, end: 0.5), loop: false))
        XCTAssertFalse(service.isPlaying)
    }

    func testRefreshingActiveLoopDoesNotRestartTheSelectedRegion() throws {
        let url = try fixture()
        let service = AVAudioPlaybackService()
        defer { service.stop(); try? FileManager.default.removeItem(at: url) }
        try service.load(url: url)
        let selection = EditSelection(start: 0.2, end: 1.7)
        try service.play(selection: selection, loop: false)
        service.seek(to: 0.7)
        try service.play(selection: selection, loop: true)
        service.pause()
        XCTAssertEqual(service.currentTime, 0.7, accuracy: 0.05)
        try service.play(selection: selection, loop: false)
        service.pause()
        XCTAssertEqual(service.currentTime, 0.7, accuracy: 0.05)
    }

    func testStoppingBeforeAnEditedSelectionRestartsWithinTheNewRegion() throws {
        let url = try fixture()
        let original = try Data(contentsOf: url)
        let service = AVAudioPlaybackService()
        defer { service.stop(); try? FileManager.default.removeItem(at: url) }
        try service.load(url: url)
        try service.play(selection: EditSelection(start: 0, end: 1.7), loop: false)
        service.seek(to: 1.5)
        service.stop()
        XCTAssertFalse(service.isPlaying)
        try service.play(selection: EditSelection(start: 0.2, end: 1.2), loop: false)
        service.pause()
        XCTAssertEqual(service.currentTime, 0.2, accuracy: 0.05)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testEffectsPreserveSourceAndProduceReadableAudio() async throws {
        let source = try fixture(), destination = source.deletingPathExtension().appendingPathExtension("m4a")
        defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: destination) }
        let original = try Data(contentsOf: source)
        _ = try await AVAudioEffectsService().process(sourceURL: source, destinationURL: destination,
            settings: AudioEffectSettings(volume: 2, fadeInDuration: 0.1, fadeOutDuration: 0.1), expectedDuration: 2)
        XCTAssertEqual(try Data(contentsOf: source), original)
        let result = try AVAudioFile(forReading: destination)
        XCTAssertEqual(Double(result.length) / result.processingFormat.sampleRate, 2, accuracy: 0.1)
        XCTAssertEqual(result.processingFormat.channelCount, 1)
    }

    func testAdvancedEffectsProduceStereoAudioWithoutChangingSourceOrDuration() async throws {
        let source = try fixture(), destination = source.deletingPathExtension().appendingPathExtension("m4a")
        defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: destination) }
        let original = try Data(contentsOf: source)
        let studio = StudioAudioSettings(lowGainDB: 3, midGainDB: 2, highPassHz: 80, lowPassHz: 6_000,
            channelMode: .stereo, limiterEnabled: true, ceiling: 0.7)
        _ = try await AVAudioEffectsService().process(sourceURL: source, destinationURL: destination,
            settings: AudioEffectSettings(volume: 2, fadeInDuration: 0.1, fadeOutDuration: 0.1, normalize: true, studio: studio),
            expectedDuration: 2)
        XCTAssertEqual(try Data(contentsOf: source), original)
        let result = try AVAudioFile(forReading: destination, commonFormat: .pcmFormatFloat32, interleaved: false)
        XCTAssertEqual(result.processingFormat.channelCount, 2)
        XCTAssertEqual(Double(result.length) / result.processingFormat.sampleRate, 2, accuracy: 0.1)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: result.processingFormat, frameCapacity: 4_096))
        try result.read(into: buffer)
        let channels = try XCTUnwrap(buffer.floatChannelData)
        XCTAssertGreaterThan(buffer.frameLength, 0)
        for channel in 0..<2 {
            XCTAssertTrue((0..<Int(buffer.frameLength)).allSatisfy { channels[channel][$0].isFinite })
        }
        // AAC can overshoot the PCM ceiling; exact ceiling assertions belong to Core PCM tests.
    }

    func testEffectsRejectFrequenciesAboveActualSourceNyquistWithoutCreatingOutput() async throws {
        let source = try fixture(sampleRate: 8_000), destination = source.deletingPathExtension().appendingPathExtension("m4a")
        defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: destination) }
        let original = try Data(contentsOf: source)
        do {
            _ = try await AVAudioEffectsService().process(sourceURL: source, destinationURL: destination,
                settings: AudioEffectSettings(studio: StudioAudioSettings(highGainDB: 3)), expectedDuration: 2)
            XCTFail("6 kHz EQ is invalid at an 8 kHz sample rate")
        } catch { XCTAssertEqual(error as? RingifyError, .corruptMedia) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertEqual(try Data(contentsOf: source), original)
    }

    func testEffectsRefuseToOverwriteSource() async throws {
        let source = try fixture()
        defer { try? FileManager.default.removeItem(at: source) }
        let original = try Data(contentsOf: source)
        do {
            _ = try await AVAudioEffectsService().process(sourceURL: source, destinationURL: source, settings: .neutral, expectedDuration: 2)
            XCTFail("Must reject source as destination")
        } catch { XCTAssertEqual(error as? RingifyError, .corruptMedia) }
        XCTAssertEqual(try Data(contentsOf: source), original)
    }
}
