import Foundation

public struct ValidateSelectionUseCase: Sendable {
    private let rules: RingtoneRules

    public init(rules: RingtoneRules = RingtoneRules()) {
        self.rules = rules
    }

    public func callAsFunction(_ selection: EditSelection, sourceDuration: TimeInterval) throws -> EditSelection {
        switch rules.validate(selection: selection, sourceDuration: sourceDuration) {
        case .success(let selection): return selection
        case .failure(let error): throw RingifyError.invalidSelection(error)
        }
    }
}

public struct CreateProjectUseCase: Sendable {
    private let rules: RingtoneRules

    public init(rules: RingtoneRules = RingtoneRules()) {
        self.rules = rules
    }

    public func callAsFunction(media: ImportedMedia, metadata: AudioMetadata) throws -> RingtoneProject {
        guard metadata.hasAudioTrack else { throw RingifyError.missingAudioTrack }
        guard metadata.duration.isFinite, metadata.duration >= RingtoneRules.minimumDuration else {
            throw RingifyError.corruptMedia
        }
        let selection = rules.clampedSelection(
            start: 0,
            end: min(metadata.duration, RingtoneRules.maximumDuration),
            sourceDuration: metadata.duration
        )
        let baseName = (media.originalFilename as NSString).deletingPathExtension
        let name = rules.safeFilename(from: baseName)
        return RingtoneProject(
            name: name,
            sourceFilename: media.originalFilename,
            sourceURL: media.localURL,
            sourceKind: media.sourceKind,
            sourceDuration: metadata.duration,
            selection: selection
        )
    }
}

public struct SearchProjectsUseCase: Sendable {
    public init() {}

    public func callAsFunction(_ projects: [RingtoneProject], query: String) -> [RingtoneProject] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = trimmed.isEmpty
            ? projects
            : projects.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed)
                    || $0.sourceFilename.localizedCaseInsensitiveContains(trimmed)
            }
        return matches.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.name < rhs.name }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}
