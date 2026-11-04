import Foundation
import RingifyCore
import XCTest
@testable import Ringify

private actor ControlledSignalAnalysis: AudioSignalAnalyzing {
    private var pending: [Int: CheckedContinuation<AudioSignalAnalysis, Error>] = [:]
    private(set) var requestCount = 0

    func analyze(sourceURL: URL, selection: EditSelection) async throws -> AudioSignalAnalysis {
        let id = requestCount
        requestCount += 1
        // Deliberately ignores cancellation, to test the caller's late-result guard.
        return try await withCheckedThrowingContinuation { pending[id] = $0 }
    }

    func complete(_ id: Int, result: AudioSignalAnalysis) { pending.removeValue(forKey: id)?.resume(returning: result) }
    func fail(_ id: Int) { pending.removeValue(forKey: id)?.resume(throwing: RingifyError.corruptMedia) }
}

@MainActor
final class AudioAnalysisViewModelTests: XCTestCase {
    private func project() -> RingtoneProject {
        RingtoneProject(name: "Source", sourceFilename: "source.wav", sourceURL: URL(fileURLWithPath: "/source.wav"),
            sourceKind: .audioFile, sourceDuration: 8, selection: EditSelection(start: 2, end: 5))
    }

    private func result(_ project: RingtoneProject) -> AudioSignalAnalysis {
        let range = project.selection
        return AudioSignalAnalysis(selection: range, peakDbFS: -6, rmsDbFS: -8,
            silentRegions: [EditSelection(start: range.start, end: range.start + 0.4),
                EditSelection(start: range.end - 0.5, end: range.end)],
            suggestion: EditSelection(start: range.start + 0.4, end: range.end - 0.5))
    }

    private func waitForRequests(_ count: Int, service: ControlledSignalAnalysis) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < deadline {
            if await service.requestCount == count { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Analysis request did not arrive")
        throw RingifyError.corruptMedia
    }

    func testDoesNotCallServiceWithoutVerifiedPro() async {
        let service = ControlledSignalAnalysis(), model = AudioAnalysisViewModel(service: service)
        XCTAssertNil(model.start(project(), hasVerifiedPro: false))
        XCTAssertEqual(model.state, .locked)
        let requests = await service.requestCount
        XCTAssertEqual(requests, 0)
    }

    func testOlderSourceCannotReplaceNewerResultEvenWhenServiceIgnoresCancellation() async throws {
        let service = ControlledSignalAnalysis(), model = AudioAnalysisViewModel(service: service)
        let original = project()
        let first = try XCTUnwrap(model.start(original, hasVerifiedPro: true))
        try await waitForRequests(1, service: service)
        XCTAssertNil(model.start(original, hasVerifiedPro: true))
        var next = original
        next.sourceURL = URL(fileURLWithPath: "/replacement.wav")
        next.selection = EditSelection(start: 4, end: 7)
        let second = try XCTUnwrap(model.start(next, hasVerifiedPro: true))
        try await waitForRequests(2, service: service)
        await service.complete(1, result: result(next))
        await second.value
        XCTAssertEqual(model.state, .ready(result(next)))
        await service.complete(0, result: result(original))
        await first.value
        XCTAssertEqual(model.state, .ready(result(next)))
        XCTAssertNil(model.suggestion(for: original, hasVerifiedPro: true))
    }

    func testExplicitCancelDiscardsLateResultAndClearsSuggestion() async throws {
        let service = ControlledSignalAnalysis(), model = AudioAnalysisViewModel(service: service), source = project()
        let pending = try XCTUnwrap(model.start(source, hasVerifiedPro: true))
        try await waitForRequests(1, service: service)
        model.cancel()
        await service.complete(0, result: result(source))
        await pending.value
        XCTAssertEqual(model.state, .idle)
        XCTAssertNil(model.suggestion(for: source, hasVerifiedPro: true))
    }

    func testRevokedProGateCancelsAnAlreadyRunningAnalysis() async throws {
        let service = ControlledSignalAnalysis(), model = AudioAnalysisViewModel(service: service), source = project()
        let pending = try XCTUnwrap(model.start(source, hasVerifiedPro: true))
        try await waitForRequests(1, service: service)
        XCTAssertNil(model.start(source, hasVerifiedPro: false))
        await service.complete(0, result: result(source))
        await pending.value
        XCTAssertEqual(model.state, .locked)
        XCTAssertNil(model.suggestion(for: source, hasVerifiedPro: false))
    }

    func testInvalidReplyFailsAndRetryCanSucceed() async throws {
        let service = ControlledSignalAnalysis(), model = AudioAnalysisViewModel(service: service), source = project()
        let first = try XCTUnwrap(model.start(source, hasVerifiedPro: true))
        try await waitForRequests(1, service: service)
        await service.complete(0, result: AudioSignalAnalysis(selection: source.selection,
            peakDbFS: .nan, rmsDbFS: -8, silentRegions: [], suggestion: nil))
        await first.value
        XCTAssertEqual(model.state, .failed)
        let second = try XCTUnwrap(model.start(source, hasVerifiedPro: true))
        try await waitForRequests(2, service: service)
        await service.complete(1, result: result(source))
        await second.value
        XCTAssertEqual(model.state, .ready(result(source)))
        XCTAssertEqual(model.suggestion(for: source, hasVerifiedPro: true), result(source).suggestion)
        XCTAssertNil(model.suggestion(for: source, hasVerifiedPro: false))
    }

    func testFileFailureIsVisibleAndOutOfRangeReplyCannotBeApplied() async throws {
        let service = ControlledSignalAnalysis(), model = AudioAnalysisViewModel(service: service), source = project()
        let first = try XCTUnwrap(model.start(source, hasVerifiedPro: true))
        try await waitForRequests(1, service: service)
        await service.fail(0)
        await first.value
        XCTAssertEqual(model.state, .failed)
        let second = try XCTUnwrap(model.start(source, hasVerifiedPro: true))
        try await waitForRequests(2, service: service)
        await service.complete(1, result: AudioSignalAnalysis(selection: source.selection, peakDbFS: -6, rmsDbFS: -8,
            silentRegions: [], suggestion: EditSelection(start: 0, end: 8)))
        await second.value
        XCTAssertEqual(model.state, .failed)
        XCTAssertNil(model.suggestion(for: source, hasVerifiedPro: true))
    }
}
