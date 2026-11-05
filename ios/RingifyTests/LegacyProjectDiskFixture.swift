import Foundation
import RingifyCore
import SwiftData

/// Representative pre-Studio schema: the original scalar project fields,
/// without optional effects/library/marker/loop metadata or later entities.
/// This is generated test data, not a claimed copy of a released user store.
enum LegacyProjectDiskFixture: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [StoredProject.self] }

    @Model final class StoredProject {
        @Attribute(.unique) var id: UUID
        var name: String
        var sourceFilename: String
        var sourcePath: String
        var sourceKindRaw: String
        var sourceDuration: Double
        var selectionStart: Double
        var selectionEnd: Double
        var volume: Double
        var fadeInDuration: Double
        var fadeOutDuration: Double
        var normalize: Bool
        var waveformSamples: [Float]
        var statusRaw: String
        var createdAt: Date
        var updatedAt: Date
        var exportedPath: String?

        init(_ project: RingtoneProject) {
            id = project.id; name = project.name
            sourceFilename = project.sourceFilename; sourcePath = project.sourceURL.path
            sourceKindRaw = project.sourceKind.rawValue; sourceDuration = project.sourceDuration
            selectionStart = project.selection.start; selectionEnd = project.selection.end
            volume = project.effects.volume; fadeInDuration = project.effects.fadeInDuration
            fadeOutDuration = project.effects.fadeOutDuration; normalize = project.effects.normalize
            waveformSamples = project.waveformSamples; statusRaw = project.status.rawValue
            createdAt = project.createdAt; updatedAt = project.updatedAt
            exportedPath = project.exportedURL?.path
        }
    }

    @MainActor static func write(_ project: RingtoneProject, to url: URL) throws {
        let schema = Schema(versionedSchema: Self.self)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        context.insert(StoredProject(project))
        try context.save()
    }
}
