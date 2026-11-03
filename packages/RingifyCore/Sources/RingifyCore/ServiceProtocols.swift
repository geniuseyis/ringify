import Foundation

public protocol MediaImportService: Sendable {
    func importMedia(from sourceURL: URL, kind: MediaSourceKind) async throws -> ImportedMedia
}

/// Imports only media for which the application has an explicit, verifiable right to download.
/// Social-platform page URLs are intentionally outside this contract.
public protocol AuthorizedMediaImportService: Sendable {
    func importAuthorizedMedia(from remoteURL: URL) async throws -> ImportedMedia
}

public protocol AudioMetadataService: Sendable {
    func metadata(for url: URL) async throws -> AudioMetadata
}

public protocol AudioExtractionService: Sendable {
    func extractAudio(from mediaURL: URL, to destinationURL: URL) async throws -> URL
}

public protocol WaveformService: Sendable {
    func samples(for audioURL: URL, sampleCount: Int) async throws -> [Float]
}

@MainActor
public protocol AudioPlaybackService: AnyObject {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    func load(url: URL) throws
    func play(selection: EditSelection?, loop: Bool) throws
    func pause()
    func stop()
    func seek(to time: TimeInterval)
}

public protocol AudioTrimService: Sendable {
    func trim(sourceURL: URL, selection: EditSelection, destinationURL: URL) async throws -> URL
    func trimPCM(sourceURL: URL, selection: EditSelection, destinationURL: URL) async throws -> URL
}

public extension AudioTrimService {
    func trimPCM(sourceURL: URL, selection: EditSelection, destinationURL: URL) async throws -> URL {
        throw RingifyError.exportFailed(reason: "Lossless PCM trimming is unavailable in this adapter.")
    }
}

public protocol AudioEffectsService: Sendable {
    func process(
        sourceURL: URL,
        destinationURL: URL,
        settings: AudioEffectSettings,
        expectedDuration: TimeInterval
    ) async throws -> URL
    func process(sourceURL: URL, destinationURL: URL, settings: AudioEffectSettings,
                 expectedDuration: TimeInterval, profile: AudioOutputProfile) async throws -> URL
}

public extension AudioEffectsService {
    func process(sourceURL: URL, destinationURL: URL, settings: AudioEffectSettings,
                 expectedDuration: TimeInterval, profile: AudioOutputProfile) async throws -> URL {
        guard profile == .aacStandard else { throw RingifyError.exportFailed(reason: "This output profile is unavailable in this adapter.") }
        return try await process(sourceURL: sourceURL, destinationURL: destinationURL, settings: settings, expectedDuration: expectedDuration)
    }
}

public protocol AudioExportService: Sendable {
    func export(_ request: ExportRequest) -> AsyncThrowingStream<ExportProgress, Error>
}

public protocol ProjectStorageService: Sendable {
    func projects() async throws -> [RingtoneProject]
    func project(id: UUID) async throws -> RingtoneProject?
    func save(_ project: RingtoneProject) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
    func collections() async throws -> [ProjectCollection]
    func saveCollection(_ collection: ProjectCollection) async throws
    func deleteCollection(id: UUID) async throws
    func updateLibraryMetadata(projectIDs: Set<UUID>, change: LibraryMetadataChange) async throws -> [RingtoneProject]
    func exportHistory(projectID: UUID?) async throws -> [ProjectExportRecord]
    func commitExport(project: RingtoneProject, output: ExportedRingtone, profile: AudioOutputProfile) async throws
    func deleteExport(id: UUID) async throws
    func audioPresets() async throws -> [UserAudioPreset]
    func saveAudioPreset(_ preset: UserAudioPreset) async throws
    func deleteAudioPreset(id: UUID) async throws
    func updateMarkers(projectID: UUID, markers: [AudioMarker]) async throws -> RingtoneProject
}

/// Older adapters/test doubles remain source compatible without silently claiming
/// support for durable organization. Production adapters must implement these.
public extension ProjectStorageService {
    func updateMarkers(projectID: UUID, markers: [AudioMarker]) async throws -> RingtoneProject { throw RingifyError.storageUnavailable(reason: "Audio markers are unavailable.") }
    func audioPresets() async throws -> [UserAudioPreset] { throw RingifyError.storageUnavailable(reason: "Personal audio presets are unavailable.") }
    func saveAudioPreset(_ preset: UserAudioPreset) async throws { throw RingifyError.storageUnavailable(reason: "Personal audio presets are unavailable.") }
    func deleteAudioPreset(id: UUID) async throws { throw RingifyError.storageUnavailable(reason: "Personal audio presets are unavailable.") }
    func exportHistory(projectID: UUID?) async throws -> [ProjectExportRecord] {
        throw RingifyError.storageUnavailable(reason: "Export history is unavailable.")
    }
    func commitExport(project: RingtoneProject, output: ExportedRingtone, profile: AudioOutputProfile) async throws {
        throw RingifyError.storageUnavailable(reason: "Atomic export recording is unavailable.")
    }
    func deleteExport(id: UUID) async throws {
        throw RingifyError.storageUnavailable(reason: "Export history is unavailable.")
    }
    func collections() async throws -> [ProjectCollection] {
        throw RingifyError.storageUnavailable(reason: "Library organization is unavailable.")
    }
    func saveCollection(_ collection: ProjectCollection) async throws {
        throw RingifyError.storageUnavailable(reason: "Library organization is unavailable.")
    }
    func deleteCollection(id: UUID) async throws {
        throw RingifyError.storageUnavailable(reason: "Library organization is unavailable.")
    }
    func updateLibraryMetadata(projectIDs: Set<UUID>, change: LibraryMetadataChange) async throws -> [RingtoneProject] {
        throw RingifyError.storageUnavailable(reason: "Library organization is unavailable.")
    }
}

@MainActor
public protocol VoiceRecordingService: AnyObject {
    var isRecording: Bool { get }
    var isPaused: Bool { get }
    var currentTime: TimeInterval { get }
    var averagePower: Float { get }
    func requestPermission() async -> Bool
    func startRecording(to url: URL) throws
    func pause()
    func resume() throws
    func stop() -> URL?
    func discard()
}
