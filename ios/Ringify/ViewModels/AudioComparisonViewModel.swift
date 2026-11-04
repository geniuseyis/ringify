import Combine
import Foundation
import RingifyCore

enum AudioComparisonMode: String, CaseIterable, Sendable { case original, processed }

struct AudioComparisonInput: Equatable, Sendable {
    let projectID: UUID
    let sourceURL: URL
    let sourceDuration: TimeInterval
    let selection: EditSelection
    let effects: AudioEffectSettings

    init(project: RingtoneProject, effects: AudioEffectSettings) {
        projectID = project.id; sourceURL = project.sourceURL; sourceDuration = project.sourceDuration
        selection = project.selection; self.effects = effects
    }
}

struct AudioComparisonArtifact: Sendable {
    let url: URL
    let duration: TimeInterval
    let sourceOffset: TimeInterval
}

protocol AudioComparisonRendering: Sendable {
    func render(_ input: AudioComparisonInput, mode: AudioComparisonMode) async throws -> AudioComparisonArtifact
}

/// Only disposable, app-generated files are returned. The original is a PCM cut,
/// not a neutral DSP render (which could otherwise alter over-range samples).
struct AudioComparisonRenderer: AudioComparisonRendering {
    let trim: any AudioTrimService
    let effects: any AudioEffectsService
    let metadata: any AudioMetadataService
    let directories: AppDirectories

    func render(_ input: AudioComparisonInput, mode: AudioComparisonMode) async throws -> AudioComparisonArtifact {
        _ = try ValidateSelectionUseCase()(input.selection, sourceDuration: input.sourceDuration)
        try Task.checkCancellation()
        let cut = directories.temporaryURL(extension: "caf")
        let output = directories.temporaryURL(extension: "wav")
        var retained: URL?
        defer {
            for url in [cut, output] where url != retained { try? FileManager.default.removeItem(at: url) }
        }
        _ = try await trim.trimPCM(sourceURL: input.sourceURL, selection: input.selection, destinationURL: cut)
        try Task.checkCancellation()
        let cutMetadata = try await metadata.metadata(for: cut)
        var offset: TimeInterval = 0
        let destination: URL
        if mode == .original { destination = cut }
        else {
            if input.effects.loopCrossfadeDuration > 0 {
                offset = try LoopCrossfadeRules.sourceOffset(seconds: input.effects.loopCrossfadeDuration,
                    sampleRate: cutMetadata.sampleRate, duration: cutMetadata.duration)
            }
            _ = try await effects.process(sourceURL: cut, destinationURL: output, settings: input.effects,
                expectedDuration: input.selection.duration, profile: .wav24)
            destination = output
        }
        let result: AudioMetadata
        if mode == .original { result = cutMetadata }
        else { result = try await metadata.metadata(for: destination) }
        try Task.checkCancellation()
        guard result.hasAudioTrack, result.duration.isFinite, result.duration > 0,
              abs(result.duration - (cutMetadata.duration - offset)) < 0.01 else { throw RingifyError.exportVerificationFailed }
        retained = destination
        return AudioComparisonArtifact(url: destination, duration: result.duration, sourceOffset: offset)
    }
}

@MainActor
final class AudioComparisonViewModel: ObservableObject {
    @Published private(set) var mode: AudioComparisonMode = .processed
    @Published private(set) var isRendering = false
    @Published private(set) var failure: String?
    private let renderer: any AudioComparisonRendering
    let playback: any AudioPlaybackService
    private var input: AudioComparisonInput?
    private var cache: [AudioComparisonMode: AudioComparisonArtifact] = [:]
    private var loaded: AudioComparisonArtifact?
    private var generation = UUID()
    private var pending: Task<Void, Never>?
    private var playAfterRender = false
    private var sourceTime: TimeInterval = 0

    init(renderer: any AudioComparisonRendering, playback: any AudioPlaybackService) {
        self.renderer = renderer; self.playback = playback
    }
    deinit { pending?.cancel() }

    var elapsed: TimeInterval { loaded.map { $0.sourceOffset + playback.currentTime } ?? 0 }

    func updateInput(_ next: AudioComparisonInput) {
        guard input != next else { return }
        let changedProject = input?.projectID != next.projectID || input?.sourceURL != next.sourceURL
        clear()
        input = next
        if changedProject { mode = .processed }
    }

    @discardableResult
    func select(_ next: AudioComparisonMode) -> Task<Void, Never>? {
        guard next != mode else { return nil }
        let shouldPlay = isRendering ? playAfterRender : playback.isPlaying
        sourceTime = loaded.map { $0.sourceOffset + playback.currentTime } ?? sourceTime
        playback.stop(); loaded = nil
        mode = next
        return prepare(play: shouldPlay)
    }

    @discardableResult
    func togglePlayback() -> Task<Void, Never>? {
        if playback.isPlaying { playback.pause(); return nil }
        if let loaded { sourceTime = loaded.sourceOffset + playback.currentTime }
        return prepare(play: true)
    }

    func clear() {
        generation = UUID(); pending?.cancel(); pending = nil
        playback.stop(); loaded = nil
        for artifact in cache.values { try? FileManager.default.removeItem(at: artifact.url) }
        cache.removeAll(); isRendering = false; failure = nil; sourceTime = 0; playAfterRender = false
    }

    private func prepare(play: Bool) -> Task<Void, Never>? {
        guard let input else { return nil }
        generation = UUID(); pending?.cancel(); pending = nil
        failure = nil; playAfterRender = play
        if let artifact = cache[mode] {
            isRendering = false
            activate(artifact, play: play)
            return nil
        }
        let token = generation, requestedMode = mode, renderer = renderer
        isRendering = true
        let task = Task { [weak self] in
            do {
                let artifact = try await renderer.render(input, mode: requestedMode)
                guard let self, !Task.isCancelled, self.generation == token, self.input == input, self.mode == requestedMode else {
                    try? FileManager.default.removeItem(at: artifact.url); return
                }
                self.cache[requestedMode] = artifact
                self.activate(artifact, play: play)
                self.isRendering = false; self.pending = nil
            } catch {
                guard let self, self.generation == token else { return }
                self.failure = error is CancellationError ? nil : error.localizedDescription
                self.isRendering = false; self.pending = nil
            }
        }
        pending = task
        return task
    }

    private func activate(_ artifact: AudioComparisonArtifact, play: Bool) {
        do {
            guard artifact.duration.isFinite, artifact.duration > 0, artifact.sourceOffset.isFinite,
                  artifact.sourceOffset >= 0 else { throw RingifyError.corruptMedia }
            try playback.load(url: artifact.url)
            playback.seek(to: min(max(0, sourceTime - artifact.sourceOffset), max(0, artifact.duration - 0.001)))
            loaded = artifact
            if play { try playback.play(selection: nil, loop: false) }
        } catch {
            playback.stop(); loaded = nil; cache[mode] = nil
            try? FileManager.default.removeItem(at: artifact.url)
            failure = error.localizedDescription
        }
    }
}
