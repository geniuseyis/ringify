import Foundation

/// A verified output and the exact edit settings that produced it.
public struct ProjectExportRecord: Codable, Identifiable, Equatable, Sendable {
    public static let maximumRecordsPerProject = 100
    public let id: UUID
    public let projectID: UUID
    public let name: String
    public let sourceDuration: TimeInterval
    public let selection: EditSelection
    public let effects: AudioEffectSettings
    public let output: ExportedRingtone
    public let profile: AudioOutputProfile

    public init(id: UUID = UUID(), project: RingtoneProject, output: ExportedRingtone, profile: AudioOutputProfile) {
        self.id = id; projectID = project.id; name = project.name
        sourceDuration = project.sourceDuration; selection = project.selection; effects = project.effects
        self.output = output; self.profile = profile
    }

    public func validate() throws {
        _ = try ValidateSelectionUseCase()(selection, sourceDuration: sourceDuration)
        try effects.studio.validate()
        try LoopCrossfadeRules.validate(effects.loopCrossfadeDuration)
        guard output.url.isFileURL, output.url.pathExtension.lowercased() == profile.format.fileExtension,
              output.byteCount > 0, output.duration.isFinite, abs(output.duration - selection.duration) < 0.75,
              output.createdAt.timeIntervalSinceReferenceDate.isFinite,
              [effects.volume, effects.fadeInDuration, effects.fadeOutDuration].allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw RingifyError.exportVerificationFailed
        }
    }
}
