import Foundation

/// Independent edits share immutable source media; storage reference tracking
/// keeps that source alive until its last project is deleted.
public struct DuplicateProjectUseCase: Sendable {
    public init() {}

    public func callAsFunction(_ original: RingtoneProject, name: String,
                               id: UUID = UUID(), now: Date = .now) throws -> RingtoneProject {
        guard id != original.id, now.timeIntervalSinceReferenceDate.isFinite else { throw RingifyError.corruptMedia }
        _ = try ValidateSelectionUseCase()(original.selection, sourceDuration: original.sourceDuration)
        try original.effects.studio.validate()
        try LoopCrossfadeRules.validate(original.effects.loopCrossfadeDuration)
        guard [original.effects.volume, original.effects.fadeInDuration, original.effects.fadeOutDuration]
            .allSatisfy({ $0.isFinite && $0 >= 0 }) else { throw RingifyError.corruptMedia }
        try original.library.validate()
        _ = try AudioMarkers.validated(original.markers, sourceDuration: original.sourceDuration)
        let validName = try RingtoneRules().validate(filename: name).get()
        return RingtoneProject(id: id, name: validName, sourceFilename: original.sourceFilename,
            sourceURL: original.sourceURL, sourceKind: original.sourceKind, sourceDuration: original.sourceDuration,
            selection: original.selection, effects: original.effects, waveformSamples: original.waveformSamples,
            status: .draft, createdAt: now, updatedAt: now, exportedURL: nil, library: original.library, markers: original.markers)
    }
}
