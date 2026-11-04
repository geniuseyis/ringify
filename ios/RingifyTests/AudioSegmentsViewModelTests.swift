import Foundation
import RingifyCore
import XCTest
@testable import Ringify

private actor ControlledSegments: AudioSegmentSuggesting {
    private var pending: [Int: CheckedContinuation<[AudioSegmentSuggestion], Error>] = [:]
    private(set) var count = 0
    func suggest(sourceURL: URL, duration: AudioSegmentDuration) async throws -> [AudioSegmentSuggestion] {
        let index = count; count += 1
        return try await withCheckedThrowingContinuation { pending[index] = $0 }
    }
    func complete(_ index: Int, _ result: [AudioSegmentSuggestion]) { pending.removeValue(forKey: index)?.resume(returning: result) }
}
@MainActor
final class AudioSegmentsViewModelTests: XCTestCase {
    private func input(duration: AudioSegmentDuration = .short) -> AudioSegmentsInput {
        AudioSegmentsInput(RingtoneProject(name: "Tone", sourceFilename: "tone.wav", sourceURL: URL(fileURLWithPath: "/tone.wav"),
            sourceKind: .audioFile, sourceDuration: 60, selection: EditSelection(start: 0, end: 29)), duration: duration)
    }
    private func wait(_ count: Int, _ service: ControlledSegments) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < deadline {
            if await service.count == count { return }; try await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Segment request missing"); throw RingifyError.corruptMedia
    }
    func testLateSourceOrDurationReplyCannotReplaceNewResult() async throws {
        let service = ControlledSegments(), model = AudioSegmentsViewModel(service: service)
        let old = input(), next = input(duration: .medium)
        let first = try XCTUnwrap(model.start(old)); try await wait(1, service)
        let second = try XCTUnwrap(model.start(next)); try await wait(2, service)
        let result = [AudioSegmentSuggestion(selection: EditSelection(start: 5, end: 25), rmsDbFS: -6)]
        await service.complete(1, result); await second.value
        await service.complete(0, []); await first.value
        XCTAssertEqual(model.state, .ready(result))
        XCTAssertNil(model.selection(at: 0, input: old))
        XCTAssertEqual(model.selection(at: 0, input: next), result[0].selection)
    }
    func testOverlappingNaNAndWrongLengthRepliesFailAndValidRetrySucceeds() async throws {
        let service = ControlledSegments(), model = AudioSegmentsViewModel(service: service), input = input()
        let invalid = [
            [AudioSegmentSuggestion(selection: EditSelection(start: 0, end: 15), rmsDbFS: .nan)],
            [AudioSegmentSuggestion(selection: EditSelection(start: 0, end: 14), rmsDbFS: -6)],
            [AudioSegmentSuggestion(selection: EditSelection(start: 0, end: 15), rmsDbFS: -6),
             AudioSegmentSuggestion(selection: EditSelection(start: 5, end: 20), rmsDbFS: -9)]
        ]
        for (index, reply) in invalid.enumerated() {
            let task = try XCTUnwrap(model.start(input)); try await wait(index + 1, service)
            await service.complete(index, reply); await task.value
            XCTAssertEqual(model.state, .failed); XCTAssertNil(model.selection(at: 0, input: input))
        }
        let retry = try XCTUnwrap(model.start(input)); try await wait(4, service)
        await service.complete(3, []); await retry.value
        XCTAssertEqual(model.state, .ready([]))
    }
    func testCancelRejectsLateReplyAndInvalidSourceDoesNotStartService() async throws {
        let service = ControlledSegments(), model = AudioSegmentsViewModel(service: service)
        let task = try XCTUnwrap(model.start(input())); try await wait(1, service)
        model.cancel(); await service.complete(0, []); await task.value
        XCTAssertEqual(model.state, .idle)
        var project = RingtoneProject(name: "Long", sourceFilename: "long.wav", sourceURL: URL(fileURLWithPath: "/long.wav"),
            sourceKind: .audioFile, sourceDuration: 121, selection: EditSelection(start: 0, end: 29))
        XCTAssertNil(model.start(AudioSegmentsInput(project, duration: .short)))
        project.sourceDuration = .nan
        XCTAssertNil(model.start(AudioSegmentsInput(project, duration: .short)))
        let count = await service.count; XCTAssertEqual(count, 1)
    }
}
