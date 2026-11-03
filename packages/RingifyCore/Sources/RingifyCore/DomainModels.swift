import Foundation

public enum MediaSourceKind: String, Codable, CaseIterable, Sendable {
    case photoLibraryVideo
    case audioFile
    case videoFile
    case microphoneRecording
    case authorizedRemoteMedia
}

public struct ImportedMedia: Codable, Equatable, Sendable {
    public let id: UUID
    public let localURL: URL
    public let originalFilename: String
    public let sourceKind: MediaSourceKind
    public let importedAt: Date

    public init(
        id: UUID = UUID(),
        localURL: URL,
        originalFilename: String,
        sourceKind: MediaSourceKind,
        importedAt: Date = .now
    ) {
        self.id = id
        self.localURL = localURL
        self.originalFilename = originalFilename
        self.sourceKind = sourceKind
        self.importedAt = importedAt
    }
}

public struct AudioMetadata: Codable, Equatable, Sendable {
    public let duration: TimeInterval
    public let sampleRate: Double
    public let channelCount: Int
    public let formatDescription: String
    public let hasAudioTrack: Bool

    public init(
        duration: TimeInterval,
        sampleRate: Double,
        channelCount: Int,
        formatDescription: String,
        hasAudioTrack: Bool
    ) {
        self.duration = duration
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.formatDescription = formatDescription
        self.hasAudioTrack = hasAudioTrack
    }
}

public struct EditSelection: Codable, Equatable, Sendable {
    public var start: TimeInterval
    public var end: TimeInterval

    public init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = end
    }

    public var duration: TimeInterval { end - start }
}

public struct AudioEffectSettings: Codable, Equatable, Sendable {
    public var volume: Double
    public var fadeInDuration: TimeInterval
    public var fadeOutDuration: TimeInterval
    public var normalize: Bool
    public var studio: StudioAudioSettings
    public var loopCrossfadeDuration: Double

    public init(
        volume: Double = 1,
        fadeInDuration: TimeInterval = 0,
        fadeOutDuration: TimeInterval = 0,
        normalize: Bool = false,
        studio: StudioAudioSettings = .neutral,
        loopCrossfadeDuration: Double = 0
    ) {
        self.volume = volume
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
        self.normalize = normalize
        self.studio = studio
        self.loopCrossfadeDuration = loopCrossfadeDuration
    }

    public static let neutral = AudioEffectSettings()

    private enum CodingKeys: String, CodingKey {
        case volume, fadeInDuration, fadeOutDuration, normalize, studio, loopCrossfadeDuration
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(volume: try values.decode(Double.self, forKey: .volume),
                  fadeInDuration: try values.decode(Double.self, forKey: .fadeInDuration),
                  fadeOutDuration: try values.decode(Double.self, forKey: .fadeOutDuration),
                  normalize: try values.decode(Bool.self, forKey: .normalize),
                  studio: values.contains(.studio) ? try values.decode(StudioAudioSettings.self, forKey: .studio) : .neutral,
                  loopCrossfadeDuration: values.contains(.loopCrossfadeDuration) ? try values.decode(Double.self, forKey: .loopCrossfadeDuration) : 0)
        try LoopCrossfadeRules.validate(loopCrossfadeDuration)
    }

    public func limitingFades(to selectionDuration: TimeInterval) throws -> Self {
        guard selectionDuration.isFinite, (1...29).contains(selectionDuration),
              fadeInDuration.isFinite, fadeInDuration >= 0,
              fadeOutDuration.isFinite, fadeOutDuration >= 0 else { throw RingifyError.corruptMedia }
        let maximum = min(5, selectionDuration / 2)
        var result = self
        result.fadeInDuration = min(maximum, fadeInDuration)
        result.fadeOutDuration = min(maximum, fadeOutDuration)
        return result
    }
}

public enum ProjectStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case ready
    case exported
}

public struct RingtoneProject: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var sourceFilename: String
    public var sourceURL: URL
    public var sourceKind: MediaSourceKind
    public var sourceDuration: TimeInterval
    public var selection: EditSelection
    public var effects: AudioEffectSettings
    public var waveformSamples: [Float]
    public var status: ProjectStatus
    public let createdAt: Date
    public var updatedAt: Date
    public var exportedURL: URL?
    public var library: ProjectLibraryMetadata
    public var markers: [AudioMarker]

    public init(
        id: UUID = UUID(),
        name: String,
        sourceFilename: String,
        sourceURL: URL,
        sourceKind: MediaSourceKind,
        sourceDuration: TimeInterval,
        selection: EditSelection,
        effects: AudioEffectSettings = .neutral,
        waveformSamples: [Float] = [],
        status: ProjectStatus = .draft,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        exportedURL: URL? = nil,
        library: ProjectLibraryMetadata = .empty,
        markers: [AudioMarker] = []
    ) {
        self.id = id
        self.name = name
        self.sourceFilename = sourceFilename
        self.sourceURL = sourceURL
        self.sourceKind = sourceKind
        self.sourceDuration = sourceDuration
        self.selection = selection
        self.effects = effects
        self.waveformSamples = waveformSamples
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.exportedURL = exportedURL
        self.library = library
        self.markers = markers
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, sourceFilename, sourceURL, sourceKind, sourceDuration, selection, effects
        case waveformSamples, status, createdAt, updatedAt, exportedURL, library, markers
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try values.decode(UUID.self, forKey: .id),
                  name: try values.decode(String.self, forKey: .name),
                  sourceFilename: try values.decode(String.self, forKey: .sourceFilename),
                  sourceURL: try values.decode(URL.self, forKey: .sourceURL),
                  sourceKind: try values.decode(MediaSourceKind.self, forKey: .sourceKind),
                  sourceDuration: try values.decode(TimeInterval.self, forKey: .sourceDuration),
                  selection: try values.decode(EditSelection.self, forKey: .selection),
                  effects: try values.decode(AudioEffectSettings.self, forKey: .effects),
                  waveformSamples: try values.decode([Float].self, forKey: .waveformSamples),
                  status: try values.decode(ProjectStatus.self, forKey: .status),
                  createdAt: try values.decode(Date.self, forKey: .createdAt),
                  updatedAt: try values.decode(Date.self, forKey: .updatedAt),
                  exportedURL: try values.decodeIfPresent(URL.self, forKey: .exportedURL),
                  library: values.contains(.library) ? try values.decode(ProjectLibraryMetadata.self, forKey: .library) : .empty,
                  markers: values.contains(.markers) ? try values.decode([AudioMarker].self, forKey: .markers) : [])
        markers = try AudioMarkers.validated(markers, sourceDuration: sourceDuration)
    }

    public mutating func rename(to newName: String, now: Date = .now) {
        name = newName
        updatedAt = now
    }

    public mutating func markExported(to url: URL, now: Date = .now) {
        exportedURL = url
        status = .exported
        updatedAt = now
    }
}

public enum ExportFormat: String, Codable, CaseIterable, Sendable {
    case m4aAAC
    case wavPCM

    public var fileExtension: String { self == .m4aAAC ? "m4a" : "wav" }
}

public struct ExportRequest: Codable, Equatable, Sendable {
    public let projectID: UUID
    public let sourceURL: URL
    public let filename: String
    public let selection: EditSelection
    public let effects: AudioEffectSettings
    public let format: ExportFormat
    public let profile: AudioOutputProfile

    public init(
        projectID: UUID,
        sourceURL: URL,
        filename: String,
        selection: EditSelection,
        effects: AudioEffectSettings,
        format: ExportFormat = .m4aAAC,
        profile: AudioOutputProfile? = nil
    ) {
        self.projectID = projectID
        self.sourceURL = sourceURL
        self.filename = filename
        self.selection = selection
        self.effects = effects
        self.profile = profile ?? (format == .wavPCM ? .wav16 : .aacStandard)
        self.format = self.profile.format
    }

    private enum CodingKeys: String, CodingKey { case projectID, sourceURL, filename, selection, effects, format, profile }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let format = try values.decode(ExportFormat.self, forKey: .format)
        let profile = values.contains(.profile) ? try values.decode(AudioOutputProfile.self, forKey: .profile) :
            (format == .wavPCM ? AudioOutputProfile.wav16 : .aacStandard)
        guard profile.format == format else { throw RingifyError.corruptMedia }
        self.init(projectID: try values.decode(UUID.self, forKey: .projectID), sourceURL: try values.decode(URL.self, forKey: .sourceURL),
            filename: try values.decode(String.self, forKey: .filename), selection: try values.decode(EditSelection.self, forKey: .selection),
            effects: try values.decode(AudioEffectSettings.self, forKey: .effects), format: format, profile: profile)
    }
}

public struct ExportedRingtone: Codable, Equatable, Sendable {
    public let url: URL
    public let duration: TimeInterval
    public let byteCount: Int64
    public let createdAt: Date

    public init(url: URL, duration: TimeInterval, byteCount: Int64, createdAt: Date = .now) {
        self.url = url
        self.duration = duration
        self.byteCount = byteCount
        self.createdAt = createdAt
    }
}

public enum ExportProgress: Equatable, Sendable {
    case preparing
    case processing(Double)
    case verifying
    case completed(ExportedRingtone)
}

public enum AppearancePreference: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case turkish = "tr"
    case english = "en"
}

public struct UserSettings: Codable, Equatable, Sendable {
    public var appearance: AppearancePreference
    public var language: AppLanguage
    public var defaultExportFormat: ExportFormat

    public init(
        appearance: AppearancePreference = .system,
        language: AppLanguage = .turkish,
        defaultExportFormat: ExportFormat = .m4aAAC
    ) {
        self.appearance = appearance
        self.language = language
        self.defaultExportFormat = defaultExportFormat
    }
}

public enum RingifyIssue: String, Codable, CaseIterable, Identifiable, Sendable {
    case storageFailed
    case unsupportedFile
    case missingAudioTrack
    case corruptFile
    case permissionDenied
    case insufficientStorage
    case exportFailed
    case cancelled
    case noSavedProject
    case purchaseFailed
    case fileNotFound

    public var id: String { rawValue }
}
