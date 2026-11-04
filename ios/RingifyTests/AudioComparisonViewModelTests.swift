import Foundation
import RingifyCore
import XCTest
@testable import Ringify

private actor ControlledComparisonRenderer: AudioComparisonRendering {
    private var continuations: [Int: CheckedContinuation<AudioComparisonArtifact, Error>] = [:]
    private(set) var requests: [(AudioComparisonInput, AudioComparisonMode)] = []
    func render(_ input: AudioComparisonInput, mode: AudioComparisonMode) async throws -> AudioComparisonArtifact {
        let index = requests.count
        requests.append((input, mode))
        // Deliberately ignores cancellation, exercising late-result disposal.
        return try await withCheckedThrowingContinuation { continuations[index] = $0 }
    }
    func complete(_ index: Int, artifact: AudioComparisonArtifact) { continuations.removeValue(forKey: index)?.resume(returning: artifact) }
    func fail(_ index: Int) { continuations.removeValue(forKey: index)?.resume(throwing: RingifyError.corruptMedia) }
}

@MainActor
private final class ComparisonPlayback: AudioPlaybackService {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var url: URL?
    var rejectLoad = false
    func load(url: URL) throws {
        guard !rejectLoad else { throw RingifyError.corruptMedia }
        if self.url != url { currentTime = 0 }; self.url = url
    }
    func play(selection: EditSelection?, loop: Bool) throws { isPlaying = true }
    func pause() { isPlaying = false }
    func stop() { isPlaying = false; currentTime = 0 }
    func seek(to time: TimeInterval) { currentTime = time }
}

@MainActor
final class AudioComparisonViewModelTests: XCTestCase {
    private func input(start: Double = 2) -> AudioComparisonInput {
        let project = RingtoneProject(name: "Tone", sourceFilename: "source.wav", sourceURL: URL(fileURLWithPath: "/source.wav"),
            sourceKind: .audioFile, sourceDuration: 12, selection: EditSelection(start: start, end: start + 3))
        return AudioComparisonInput(project: project, effects: AudioEffectSettings(volume: 0.5, loopCrossfadeDuration: 0.03))
    }
    private func artifact(offset: Double = 0) throws -> AudioComparisonArtifact {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
        try Data([1, 2, 3]).write(to: url)
        return AudioComparisonArtifact(url: url, duration: 3 - offset, sourceOffset: offset)
    }
    private func wait(_ count: Int, _ renderer: ControlledComparisonRenderer) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < deadline {
            if await renderer.requests.count == count { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Comparison render did not arrive"); throw RingifyError.corruptMedia
    }

    func testSwitchPreservesSourcePositionAndPlaybackWithoutRerenderingCachedModes() async throws {
        let renderer = ControlledComparisonRenderer(), player = ComparisonPlayback()
        let model = AudioComparisonViewModel(renderer: renderer, playback: player)
        let processed = try artifact(offset: 0.03), original = try artifact()
        defer { model.clear() }
        model.updateInput(input())
        let first = try XCTUnwrap(model.togglePlayback()); try await wait(1, renderer)
        await renderer.complete(0, artifact: processed); await first.value
        player.currentTime = 1.2
        let second = try XCTUnwrap(model.select(.original)); try await wait(2, renderer)
        await renderer.complete(1, artifact: original); await second.value
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(player.currentTime, 1.23, accuracy: 1e-9)
        player.currentTime = 1.6
        XCTAssertNil(model.select(.processed))
        XCTAssertEqual(player.url, processed.url)
        XCTAssertEqual(player.currentTime, 1.57, accuracy: 1e-9)
        XCTAssertEqual(model.elapsed, 1.6, accuracy: 1e-9)
        let requests = await renderer.requests
        XCTAssertEqual(requests.map(\.1), [.processed, .original])
    }

    func testPausedSwitchStaysPausedAndClearRemovesBothOwnedFiles() async throws {
        let renderer = ControlledComparisonRenderer(), player = ComparisonPlayback()
        let model = AudioComparisonViewModel(renderer: renderer, playback: player)
        let processed = try artifact(offset: 0.03), original = try artifact()
        model.updateInput(input())
        let first = try XCTUnwrap(model.togglePlayback()); try await wait(1, renderer)
        await renderer.complete(0, artifact: processed); await first.value
        player.currentTime = 1; model.togglePlayback()
        let second = try XCTUnwrap(model.select(.original)); try await wait(2, renderer)
        await renderer.complete(1, artifact: original); await second.value
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.currentTime, 1.03, accuracy: 1e-9)
        model.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: processed.url.path))
        XCTAssertEqual(model.elapsed, 0)
    }

    func testNewInputRejectsLateResultsEvenWhenRendererIgnoresCancellation() async throws {
        let renderer = ControlledComparisonRenderer(), player = ComparisonPlayback()
        let model = AudioComparisonViewModel(renderer: renderer, playback: player)
        let stale = try artifact(), newest = try artifact()
        defer { model.clear() }
        model.updateInput(input())
        let first = try XCTUnwrap(model.togglePlayback()); try await wait(1, renderer)
        model.updateInput(input(start: 4))
        let second = try XCTUnwrap(model.togglePlayback()); try await wait(2, renderer)
        await renderer.complete(1, artifact: newest); await second.value
        await renderer.complete(0, artifact: stale); await first.value
        XCTAssertEqual(player.url, newest.url)
        XCTAssertTrue(player.isPlaying)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.url.path))
    }

    func testCancelDuringRenderCannotStartLatePlaybackAndFailureCanRetry() async throws {
        let renderer = ControlledComparisonRenderer(), player = ComparisonPlayback()
        let model = AudioComparisonViewModel(renderer: renderer, playback: player)
        let late = try artifact(), success = try artifact()
        defer { model.clear() }
        model.updateInput(input())
        let first = try XCTUnwrap(model.togglePlayback()); try await wait(1, renderer)
        model.clear(); await renderer.complete(0, artifact: late); await first.value
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(FileManager.default.fileExists(atPath: late.url.path))
        let second = try XCTUnwrap(model.togglePlayback()); try await wait(2, renderer)
        await renderer.fail(1); await second.value
        XCTAssertNotNil(model.failure); XCTAssertFalse(model.isRendering)
        let third = try XCTUnwrap(model.togglePlayback()); try await wait(3, renderer)
        await renderer.complete(2, artifact: success); await third.value
        XCTAssertNil(model.failure); XCTAssertTrue(player.isPlaying)
    }

    func testSameProjectEffectChangeInvalidatesCachedAudioWithoutChangingProjectIdentity() async throws {
        let renderer = ControlledComparisonRenderer(), player = ComparisonPlayback()
        let model = AudioComparisonViewModel(renderer: renderer, playback: player), old = input()
        let firstArtifact = try artifact(), nextArtifact = try artifact()
        defer { model.clear() }
        model.updateInput(old)
        let first = try XCTUnwrap(model.togglePlayback()); try await wait(1, renderer)
        await renderer.complete(0, artifact: firstArtifact); await first.value
        let project = RingtoneProject(id: old.projectID, name: "Tone", sourceFilename: "source.wav", sourceURL: old.sourceURL,
            sourceKind: .audioFile, sourceDuration: old.sourceDuration, selection: old.selection)
        model.updateInput(AudioComparisonInput(project: project, effects: AudioEffectSettings(volume: 0.25)))
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstArtifact.url.path))
        let second = try XCTUnwrap(model.togglePlayback()); try await wait(2, renderer)
        await renderer.complete(1, artifact: nextArtifact); await second.value
        let requests = await renderer.requests
        XCTAssertEqual(requests[1].0.projectID, old.projectID)
        XCTAssertEqual(requests[1].0.effects.volume, 0.25)
    }

    func testPlaybackLoadFailureDiscardsBadCacheAndRetryRendersFreshFile() async throws {
        let renderer = ControlledComparisonRenderer(), player = ComparisonPlayback()
        let model = AudioComparisonViewModel(renderer: renderer, playback: player)
        let bad = try artifact(), good = try artifact()
        defer { model.clear() }
        model.updateInput(input()); player.rejectLoad = true
        let first = try XCTUnwrap(model.togglePlayback()); try await wait(1, renderer)
        await renderer.complete(0, artifact: bad); await first.value
        XCTAssertNotNil(model.failure); XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(FileManager.default.fileExists(atPath: bad.url.path))
        player.rejectLoad = false
        let retry = try XCTUnwrap(model.togglePlayback()); try await wait(2, renderer)
        await renderer.complete(1, artifact: good); await retry.value
        XCTAssertNil(model.failure); XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(player.url, good.url)
    }
}
