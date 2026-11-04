import AVFoundation
import RingifyCore
import XCTest
@testable import Ringify

@MainActor
final class AudioSegmentsIntegrationTests: XCTestCase {
    func testActualStereoFileRanksEnergyPreservesSourceAndReturnsNonoverlappingRegions() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 8000, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192))
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            for first in stride(from: 0, to: 480000, by: 8192) {
                let count = min(8192, 480000 - first); buffer.frameLength = AVAudioFrameCount(count)
                let channels = try XCTUnwrap(buffer.floatChannelData)
                for index in 0..<count {
                    let frame = first + index
                    let value: Float = frame < 120000 ? 0.2 : (160000..<280000).contains(frame) ? 0.9 : (320000..<440000).contains(frame) ? 0.5 : 0
                    channels[0][index] = value; channels[1][index] = -value
                }
                try file.write(from: buffer)
            }
        }
        let bytes = try Data(contentsOf: url)
        let result = try await AVAudioSegmentSuggestionsService().suggest(sourceURL: url, duration: .short)
        XCTAssertEqual(result.map(\.selection), [EditSelection(start: 20, end: 35), EditSelection(start: 40, end: 55), EditSelection(start: 0, end: 15)])
        XCTAssertEqual(try XCTUnwrap(result.first).rmsDbFS, 20 * log10(0.9), accuracy: 1e-6)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
    func testAlreadyCancelledRequestDoesNotOpenSource() async {
        let task = Task { () throws -> [AudioSegmentSuggestion] in
            while !Task.isCancelled { await Task.yield() }
            return try await AVAudioSegmentSuggestionsService().suggest(sourceURL: URL(fileURLWithPath: "/missing.wav"), duration: .short)
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled request must fail before file access") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
}
