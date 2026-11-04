import AVFoundation
import Foundation
import RingifyCore
import XCTest
@testable import Ringify

@MainActor
final class AudioSignalAnalysisIntegrationTests: XCTestCase {
    private func fixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 8_000, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 24_000))
        buffer.frameLength = 24_000
        let channels = try XCTUnwrap(buffer.floatChannelData)
        for i in 0..<24_000 {
            let active = i >= 3_200 && i < 20_000
            channels[0][i] = active ? 0.25 : 0
            channels[1][i] = active ? -0.25 : 0
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    func testRealFileIsNotModifiedAndStereoEnergyDoesNotCancel() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let original = try Data(contentsOf: url)
        let result = try await AVAudioSignalAnalysisService().analyze(sourceURL: url, selection: EditSelection(start: 0, end: 3))
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertEqual(try XCTUnwrap(result.peakDbFS), 20 * log10(0.25), accuracy: 1e-8)
        XCTAssertEqual(try XCTUnwrap(result.rmsDbFS), 10 * log10(0.25 * 0.25 * 16_800 / 24_000), accuracy: 1e-8)
        XCTAssertEqual(result.silentRegions.count, 2)
        XCTAssertEqual(try XCTUnwrap(result.suggestion).start, 0.4, accuracy: 1e-8)
        XCTAssertEqual(try XCTUnwrap(result.suggestion).end, 2.5, accuracy: 1e-8)
    }

    func testInvalidRangeAndMissingFileCannotReturnSuccess() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let service = AVAudioSignalAnalysisService()
        for source in [url, url.appendingPathExtension("missing")] {
            do {
                _ = try await service.analyze(sourceURL: source, selection: EditSelection(start: 2, end: 4))
                XCTFail("Expected invalid range or missing source to fail")
            } catch { /* Both are user-visible failure paths in the view model. */ }
        }
    }
}
