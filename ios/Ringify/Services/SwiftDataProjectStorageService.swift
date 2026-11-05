import Foundation
import RingifyCore
import SwiftData

@Model
final class StoredProject {
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
    // Additive optional metadata: pre-Studio records retain all original fields.
    var studioSettingsData: Data? = nil
    var libraryMetadataData: Data? = nil
    var markerData: Data? = nil
    var loopCrossfadeDuration: Double? = nil
    var waveformSamples: [Float]
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date
    var exportedPath: String?

    init(project: RingtoneProject) throws {
        try project.effects.studio.validate()
        try LoopCrossfadeRules.validate(project.effects.loopCrossfadeDuration)
        let studioData = project.effects.studio.isNeutral ? nil : try JSONEncoder().encode(project.effects.studio)
        try project.library.validate()
        let libraryData = project.library == .empty ? nil : try JSONEncoder().encode(project.library)
        let markers = try AudioMarkers.validated(project.markers, sourceDuration: project.sourceDuration)
        let encodedMarkers = markers.isEmpty ? nil : try JSONEncoder().encode(markers)
        id = project.id
        name = project.name
        sourceFilename = project.sourceFilename
        sourcePath = project.sourceURL.path
        sourceKindRaw = project.sourceKind.rawValue
        sourceDuration = project.sourceDuration
        selectionStart = project.selection.start
        selectionEnd = project.selection.end
        volume = project.effects.volume
        fadeInDuration = project.effects.fadeInDuration
        fadeOutDuration = project.effects.fadeOutDuration
        normalize = project.effects.normalize
        studioSettingsData = studioData
        libraryMetadataData = libraryData
        markerData = encodedMarkers
        loopCrossfadeDuration = project.effects.loopCrossfadeDuration == 0 ? nil : project.effects.loopCrossfadeDuration
        waveformSamples = project.waveformSamples
        statusRaw = project.status.rawValue
        createdAt = project.createdAt
        updatedAt = project.updatedAt
        exportedPath = project.exportedURL?.path
    }

    func update(from project: RingtoneProject) throws {
        // Encode before mutating persisted metadata so invalid settings cannot
        // leave a half-updated object in the current transaction.
        try project.effects.studio.validate()
        try LoopCrossfadeRules.validate(project.effects.loopCrossfadeDuration)
        try project.library.validate()
        let existingMarkers = try markerData.map { try JSONDecoder().decode([AudioMarker].self, from: $0) } ?? []
        _ = try AudioMarkers.validated(existingMarkers, sourceDuration: project.sourceDuration)
        let studioData = project.effects.studio.isNeutral ? nil : try JSONEncoder().encode(project.effects.studio)
        name = project.name
        sourceFilename = project.sourceFilename
        sourcePath = project.sourceURL.path
        sourceKindRaw = project.sourceKind.rawValue
        sourceDuration = project.sourceDuration
        selectionStart = project.selection.start
        selectionEnd = project.selection.end
        volume = project.effects.volume
        fadeInDuration = project.effects.fadeInDuration
        fadeOutDuration = project.effects.fadeOutDuration
        normalize = project.effects.normalize
        studioSettingsData = studioData
        loopCrossfadeDuration = project.effects.loopCrossfadeDuration == 0 ? nil : project.effects.loopCrossfadeDuration
        // Organization has its own transaction. A queued content snapshot must
        // not overwrite a newer favorite or collection assignment.
        waveformSamples = project.waveformSamples
        statusRaw = project.status.rawValue
        updatedAt = project.updatedAt
        exportedPath = project.exportedURL?.path
    }

    func domainModel() throws -> RingtoneProject {
        try LoopCrossfadeRules.validate(loopCrossfadeDuration ?? 0)
        let library = try libraryMetadataData.map { try JSONDecoder().decode(ProjectLibraryMetadata.self, from: $0) } ?? .empty
        let markers = try markerData.map { try JSONDecoder().decode([AudioMarker].self, from: $0) } ?? []
        let validMarkers = try AudioMarkers.validated(markers, sourceDuration: sourceDuration)
        let studio: StudioAudioSettings
        if let studioSettingsData {
            studio = try JSONDecoder().decode(StudioAudioSettings.self, from: studioSettingsData)
        } else {
            studio = .neutral
        }
        return RingtoneProject(
            id: id,
            name: name,
            sourceFilename: sourceFilename,
            sourceURL: URL(fileURLWithPath: sourcePath),
            sourceKind: MediaSourceKind(rawValue: sourceKindRaw) ?? .audioFile,
            sourceDuration: sourceDuration,
            selection: EditSelection(start: selectionStart, end: selectionEnd),
            effects: AudioEffectSettings(
                volume: volume,
                fadeInDuration: fadeInDuration,
                fadeOutDuration: fadeOutDuration,
                normalize: normalize,
                studio: studio,
                loopCrossfadeDuration: loopCrossfadeDuration ?? 0
            ),
            waveformSamples: waveformSamples,
            status: ProjectStatus(rawValue: statusRaw) ?? .draft,
            createdAt: createdAt,
            updatedAt: updatedAt,
            exportedURL: exportedPath.map(URL.init(fileURLWithPath:)),
            library: library,
            markers: validMarkers
        )
    }
}

@Model
final class StoredProjectCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    init(_ collection: ProjectCollection) throws {
        try collection.validate()
        id = collection.id
        name = collection.name
        createdAt = collection.createdAt
    }

    func domainModel() throws -> ProjectCollection {
        let value = ProjectCollection(id: id, name: name, createdAt: createdAt)
        try value.validate()
        return value
    }
}

@Model
final class StoredExportRecord {
    @Attribute(.unique) var id: UUID
    var projectID: UUID
    var payload: Data

    init(_ record: ProjectExportRecord) throws {
        try record.validate()
        id = record.id; projectID = record.projectID
        payload = try JSONEncoder().encode(record)
    }

    func domainModel() throws -> ProjectExportRecord {
        let record = try JSONDecoder().decode(ProjectExportRecord.self, from: payload)
        try record.validate()
        guard record.id == id, record.projectID == projectID else { throw RingifyError.corruptMedia }
        return record
    }
}

@Model
final class StoredAudioPreset {
    @Attribute(.unique) var id: UUID
    var payload: Data
    init(_ preset: UserAudioPreset) throws {
        try preset.validate(); id = preset.id; payload = try JSONEncoder().encode(preset)
    }
    func domainModel() throws -> UserAudioPreset {
        let preset = try JSONDecoder().decode(UserAudioPreset.self, from: payload)
        try preset.validate()
        guard preset.id == id else { throw RingifyError.corruptMedia }
        return preset
    }
}

actor SwiftDataProjectStorageService: ProjectStorageService {
    private let container: ModelContainer
    private let deletion: ManagedFileDeletion
    private let exportRoot: URL

    init(inMemory: Bool = false, directories: AppDirectories? = nil, storeURL: URL? = nil) throws {
        let resolvedDirectories = directories ?? (inMemory ? AppDirectories(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)) : AppDirectories())
        // A caller-owned disk URL enables isolated restart/recovery integration
        // tests. Normal app startup keeps its existing default store location.
        let configuration: ModelConfiguration
        if let storeURL {
            guard !inMemory, storeURL.isFileURL else { throw RingifyError.corruptMedia }
            configuration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        }
        container = try ModelContainer(for: StoredProject.self, StoredProjectCollection.self, StoredExportRecord.self, StoredAudioPreset.self, configurations: configuration)
        exportRoot = resolvedDirectories.exports.standardizedFileURL.resolvingSymlinksInPath()
        deletion = ManagedFileDeletion(roots: [resolvedDirectories.imports, resolvedDirectories.exports, resolvedDirectories.recordings],
            trash: resolvedDirectories.root.appendingPathComponent("PendingDeletion", isDirectory: true))
        let saved = try ModelContext(container).fetch(FetchDescriptor<StoredProject>()).map { try $0.domainModel() }
        let history = try ModelContext(container).fetch(FetchDescriptor<StoredExportRecord>()).map { try $0.domainModel() }
        try deletion.recover(retaining: saved.flatMap { [$0.sourceURL] + [$0.exportedURL].compactMap { $0 } } + history.map { $0.output.url })
    }

    func projects() async throws -> [RingtoneProject] {
        let descriptor = FetchDescriptor<StoredProject>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try ModelContext(container).fetch(descriptor).map { try $0.domainModel() }
    }

    func project(id: UUID) async throws -> RingtoneProject? {
        try ModelContext(container)
            .fetch(FetchDescriptor<StoredProject>())
            .first(where: { $0.id == id })?
            .domainModel()
    }

    func collections() async throws -> [ProjectCollection] {
        try ModelContext(container).fetch(FetchDescriptor<StoredProjectCollection>())
            .map { try $0.domainModel() }.sorted {
                let order = $0.name.localizedStandardCompare($1.name)
                return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
            }
    }

    func audioPresets() async throws -> [UserAudioPreset] {
        try ModelContext(container).fetch(FetchDescriptor<StoredAudioPreset>()).map { try $0.domainModel() }
            .sorted { $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt > $1.updatedAt }
    }
    func updateMarkers(projectID: UUID, markers: [AudioMarker]) async throws -> RingtoneProject {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        guard let row = try context.fetch(FetchDescriptor<StoredProject>()).first(where: { $0.id == projectID }) else { throw RingifyError.projectNotFound }
        var project = try row.domainModel()
        project.markers = try AudioMarkers.validated(markers, sourceDuration: project.sourceDuration)
        row.markerData = project.markers.isEmpty ? nil : try JSONEncoder().encode(project.markers)
        do { try context.save() } catch { context.rollback(); throw error }
        return project
    }
    func saveAudioPreset(_ preset: UserAudioPreset) async throws {
        try preset.validate()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let rows = try context.fetch(FetchDescriptor<StoredAudioPreset>())
        let saved = try rows.map { try $0.domainModel() }
        guard !saved.contains(where: { $0.id != preset.id && $0.name.compare(preset.name,
            options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == .orderedSame }) else {
            throw RingifyError.storageUnavailable(reason: "A preset with this name already exists.")
        }
        if let row = rows.first(where: { $0.id == preset.id }) {
            guard saved.first(where: { $0.id == preset.id })?.createdAt == preset.createdAt else { throw RingifyError.corruptMedia }
            row.payload = try JSONEncoder().encode(preset)
        } else {
            guard rows.count < UserAudioPreset.maximumCount else { throw RingifyError.storageUnavailable(reason: "The personal preset limit has been reached.") }
            context.insert(try StoredAudioPreset(preset))
        }
        do { try context.save() } catch { context.rollback(); throw error }
    }
    func deleteAudioPreset(id: UUID) async throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        if let row = try context.fetch(FetchDescriptor<StoredAudioPreset>()).first(where: { $0.id == id }) { context.delete(row) }
        do { try context.save() } catch { context.rollback(); throw error }
    }

    func saveCollection(_ collection: ProjectCollection) async throws {
        try collection.validate()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let rows = try context.fetch(FetchDescriptor<StoredProjectCollection>())
        guard !rows.contains(where: { $0.id != collection.id &&
            $0.name.compare(collection.name, options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == .orderedSame }) else {
            throw RingifyError.storageUnavailable(reason: "A collection with this name already exists.")
        }
        if let existing = rows.first(where: { $0.id == collection.id }) {
            existing.name = collection.name
        } else {
            guard rows.count < 256 else { throw RingifyError.storageUnavailable(reason: "The collection limit has been reached.") }
            context.insert(try StoredProjectCollection(collection))
        }
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    func updateLibraryMetadata(projectIDs: Set<UUID>, change: LibraryMetadataChange) async throws -> [RingtoneProject] {
        guard !projectIDs.isEmpty else { return [] }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let rows = try context.fetch(FetchDescriptor<StoredProject>()).filter { projectIDs.contains($0.id) }
        guard rows.count == projectIDs.count else { throw RingifyError.projectNotFound }
        if case .addToCollection(let id) = change {
            guard try context.fetch(FetchDescriptor<StoredProjectCollection>()).contains(where: { $0.id == id }) else {
                throw RingifyError.projectNotFound
            }
        }
        // Validate and encode the complete batch before touching managed rows.
        let changes = try rows.map { row -> (StoredProject, Data?, RingtoneProject) in
            var project = try row.domainModel()
            project.library = try change.applying(to: project.library)
            let data = project.library == .empty ? nil : try JSONEncoder().encode(project.library)
            return (row, data, project)
        }
        for (row, data, _) in changes { row.libraryMetadataData = data }
        do { try context.save() }
        catch { context.rollback(); throw error }
        return changes.map { $0.2 }
    }

    func deleteCollection(id: UUID) async throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        guard let collection = try context.fetch(FetchDescriptor<StoredProjectCollection>()).first(where: { $0.id == id }) else { return }
        let rows = try context.fetch(FetchDescriptor<StoredProject>())
        let changes = try rows.map { row -> (StoredProject, Data?) in
            var project = try row.domainModel()
            project.library.collectionIDs.remove(id)
            let data = project.library == .empty ? nil : try JSONEncoder().encode(project.library)
            return (row, data)
        }
        for (row, data) in changes { row.libraryMetadataData = data }
        context.delete(collection)
        do { try context.save() }
        catch { context.rollback(); throw error }
        // Collections own metadata only; no media deletion is scheduled here.
    }

    func save(_ project: RingtoneProject) async throws {
        try saveProject(project, export: nil)
    }

    func exportHistory(projectID: UUID?) async throws -> [ProjectExportRecord] {
        try ModelContext(container).fetch(FetchDescriptor<StoredExportRecord>())
            .filter { projectID == nil || $0.projectID == projectID }
            .map { try $0.domainModel() }.sorted {
                $0.output.createdAt == $1.output.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.output.createdAt > $1.output.createdAt
            }
    }

    func commitExport(project: RingtoneProject, output: ExportedRingtone, profile: AudioOutputProfile) async throws {
        let record = ProjectExportRecord(project: project, output: output, profile: profile)
        try record.validate()
        let resolved = output.url.standardizedFileURL.resolvingSymlinksInPath()
        guard resolved.pathComponents.count > exportRoot.pathComponents.count,
              resolved.pathComponents.starts(with: exportRoot.pathComponents) else { throw RingifyError.exportVerificationFailed }
        let values = try output.url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, Int64(values.fileSize ?? 0) == output.byteCount else {
            throw RingifyError.exportVerificationFailed
        }
        var updated = project
        updated.markExported(to: output.url, now: output.createdAt)
        try saveProject(updated, export: record)
    }

    private func saveProject(_ project: RingtoneProject, export record: ProjectExportRecord?) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let items = try context.fetch(FetchDescriptor<StoredProject>())
        let history = try context.fetch(FetchDescriptor<StoredExportRecord>()).map { try $0.domainModel() }
        if record != nil, !items.contains(where: { $0.id == project.id }) { throw RingifyError.projectNotFound }
        if let record {
            guard history.filter({ $0.projectID == project.id }).count < ProjectExportRecord.maximumRecordsPerProject else {
                throw RingifyError.storageUnavailable(reason: "Export history is full. Remove older exports to continue.")
            }
            guard !history.contains(where: { $0.output.url.standardizedFileURL.resolvingSymlinksInPath() == record.output.url.standardizedFileURL.resolvingSymlinksInPath() }) else {
                throw RingifyError.exportVerificationFailed
            }
            context.insert(try StoredExportRecord(record))
        }
        var obsolete: [URL] = []
        if let existing = items.first(where: { $0.id == project.id }) {
            let previous = try existing.domainModel()
            let nextURLs = [project.sourceURL] + [project.exportedURL].compactMap { $0 }
            obsolete = ([previous.sourceURL] + [previous.exportedURL].compactMap { $0 }).filter { !nextURLs.contains($0) }
            try existing.update(from: project)
        } else {
            if !project.library.collectionIDs.isEmpty {
                let ids = Set(try context.fetch(FetchDescriptor<StoredProjectCollection>()).map(\.id))
                guard project.library.collectionIDs.isSubset(of: ids) else { throw RingifyError.projectNotFound }
            }
            context.insert(try StoredProject(project: project))
        }
        let retained = try items.filter { $0.id != project.id }.map { try $0.domainModel() }.flatMap {
            [$0.sourceURL] + [$0.exportedURL].compactMap { $0 }
        } + [project.sourceURL] + [project.exportedURL].compactMap { $0 } + history.map { $0.output.url }
        let batch = try deletion.stage(candidates: obsolete, retaining: retained)
        do { try context.save() }
        catch {
            context.rollback()
            try deletion.rollback(batch)
            throw error
        }
        try deletion.commit(batch)
    }

    func delete(id: UUID) async throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let items = try context.fetch(FetchDescriptor<StoredProject>())
        let history = try context.fetch(FetchDescriptor<StoredExportRecord>())
        let records = try history.map { try $0.domainModel() }
        if let existing = items.first(where: { $0.id == id }) {
            let target = try existing.domainModel()
            let others = try items.filter { $0.id != id }.map { try $0.domainModel() }
            let candidates = [target.sourceURL] + [target.exportedURL].compactMap { $0 } + records.filter { $0.projectID == id }.map { $0.output.url }
            let referenced = others.flatMap { [$0.sourceURL] + [$0.exportedURL].compactMap { $0 } } + records.filter { $0.projectID != id }.map { $0.output.url }
            let batch = try deletion.stage(candidates: candidates, retaining: referenced)
            context.delete(existing)
            for row in history where row.projectID == id { context.delete(row) }
            do { try context.save() }
            catch {
                context.rollback()
                try deletion.rollback(batch)
                throw error
            }
            try deletion.commit(batch)
        }
    }

    func deleteExport(id: UUID) async throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let rows = try context.fetch(FetchDescriptor<StoredExportRecord>())
        guard let targetRow = rows.first(where: { $0.id == id }) else { return }
        let target = try targetRow.domainModel()
        let projects = try context.fetch(FetchDescriptor<StoredProject>())
        let otherRecords = try rows.filter { $0.id != id }.map { try $0.domainModel() }
        if let project = projects.first(where: { $0.id == target.projectID }), project.exportedPath == target.output.url.path {
            project.exportedPath = nil
            project.statusRaw = ProjectStatus.draft.rawValue
        }
        let retained = try projects.map { try $0.domainModel() }.flatMap { [$0.sourceURL] + [$0.exportedURL].compactMap { $0 } } + otherRecords.map { $0.output.url }
        let batch = try deletion.stage(candidates: [target.output.url], retaining: retained)
        context.delete(targetRow)
        do { try context.save() }
        catch { context.rollback(); try deletion.rollback(batch); throw error }
        try deletion.commit(batch)
    }

    func deleteAll() async throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let items = try context.fetch(FetchDescriptor<StoredProject>())
        let history = try context.fetch(FetchDescriptor<StoredExportRecord>())
        let candidates = try items.map { try $0.domainModel() }.flatMap { [$0.sourceURL] + [$0.exportedURL].compactMap { $0 } } + history.map { try $0.domainModel().output.url }
        let batch = try deletion.stage(candidates: candidates, retaining: [])
        for item in items {
            context.delete(item)
        }
        for collection in try context.fetch(FetchDescriptor<StoredProjectCollection>()) {
            context.delete(collection)
        }
        for record in history { context.delete(record) }
        for preset in try context.fetch(FetchDescriptor<StoredAudioPreset>()) { context.delete(preset) }
        do { try context.save() }
        catch {
            context.rollback()
            try deletion.rollback(batch)
            throw error
        }
        try deletion.commit(batch)
    }
}

actor InMemoryProjectStorageService: ProjectStorageService {
    private var values: [UUID: RingtoneProject] = [:]
    private var groups: [UUID: ProjectCollection] = [:]
    private var history: [UUID: ProjectExportRecord] = [:]
    private var presets: [UUID: UserAudioPreset] = [:]

    func projects() async throws -> [RingtoneProject] {
        values.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func project(id: UUID) async throws -> RingtoneProject? { values[id] }
    func save(_ project: RingtoneProject) async throws {
        try project.library.validate()
        _ = try AudioMarkers.validated(values[project.id]?.markers ?? project.markers, sourceDuration: project.sourceDuration)
        var saved = project
        if let current = values[project.id] { saved.library = current.library; saved.markers = current.markers }
        else if !project.library.collectionIDs.isSubset(of: Set(groups.keys)) { throw RingifyError.projectNotFound }
        values[project.id] = saved
    }
    func delete(id: UUID) async throws {
        values[id] = nil
        history = history.filter { $0.value.projectID != id }
    }
    func deleteAll() async throws { values.removeAll(); groups.removeAll(); history.removeAll(); presets.removeAll() }
    func audioPresets() async throws -> [UserAudioPreset] {
        presets.values.sorted { $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt > $1.updatedAt }
    }
    func saveAudioPreset(_ preset: UserAudioPreset) async throws {
        try preset.validate()
        guard !presets.values.contains(where: { $0.id != preset.id && $0.name.compare(preset.name,
            options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == .orderedSame }) else {
            throw RingifyError.storageUnavailable(reason: "A preset with this name already exists.")
        }
        guard presets[preset.id] != nil || presets.count < UserAudioPreset.maximumCount else {
            throw RingifyError.storageUnavailable(reason: "The personal preset limit has been reached.")
        }
        if let prior = presets[preset.id], prior.createdAt != preset.createdAt { throw RingifyError.corruptMedia }
        presets[preset.id] = preset
    }
    func deleteAudioPreset(id: UUID) async throws { presets[id] = nil }
    func updateMarkers(projectID: UUID, markers: [AudioMarker]) async throws -> RingtoneProject {
        guard var project = values[projectID] else { throw RingifyError.projectNotFound }
        project.markers = try AudioMarkers.validated(markers, sourceDuration: project.sourceDuration)
        values[projectID] = project
        return project
    }
    func exportHistory(projectID: UUID?) async throws -> [ProjectExportRecord] {
        history.values.filter { projectID == nil || $0.projectID == projectID }.sorted {
            $0.output.createdAt == $1.output.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.output.createdAt > $1.output.createdAt
        }
    }
    func commitExport(project: RingtoneProject, output: ExportedRingtone, profile: AudioOutputProfile) async throws {
        guard let existing = values[project.id] else { throw RingifyError.projectNotFound }
        let record = ProjectExportRecord(project: project, output: output, profile: profile)
        try record.validate()
        guard history.values.filter({ $0.projectID == project.id }).count < ProjectExportRecord.maximumRecordsPerProject else {
            throw RingifyError.storageUnavailable(reason: "Export history is full. Remove older exports to continue.")
        }
        guard !history.values.contains(where: { $0.output.url == output.url }) else { throw RingifyError.exportVerificationFailed }
        var saved = project
        saved.library = existing.library
        saved.markers = existing.markers
        saved.markExported(to: output.url, now: output.createdAt)
        values[project.id] = saved
        history[record.id] = record
    }
    func deleteExport(id: UUID) async throws {
        guard let record = history.removeValue(forKey: id) else { return }
        if var project = values[record.projectID], project.exportedURL == record.output.url {
            project.exportedURL = nil; project.status = .draft
            values[project.id] = project
        }
    }
    func collections() async throws -> [ProjectCollection] {
        groups.values.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
        }
    }
    func saveCollection(_ collection: ProjectCollection) async throws {
        try collection.validate()
        guard !groups.values.contains(where: { $0.id != collection.id &&
            $0.name.compare(collection.name, options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == .orderedSame }) else {
            throw RingifyError.storageUnavailable(reason: "A collection with this name already exists.")
        }
        guard groups[collection.id] != nil || groups.count < 256 else {
            throw RingifyError.storageUnavailable(reason: "The collection limit has been reached.")
        }
        let createdAt = groups[collection.id]?.createdAt ?? collection.createdAt
        groups[collection.id] = ProjectCollection(id: collection.id, name: collection.name, createdAt: createdAt)
    }
    func updateLibraryMetadata(projectIDs: Set<UUID>, change: LibraryMetadataChange) async throws -> [RingtoneProject] {
        guard !projectIDs.isEmpty else { return [] }
        if case .addToCollection(let id) = change, groups[id] == nil { throw RingifyError.projectNotFound }
        let updates = try projectIDs.map { id -> RingtoneProject in
            guard var project = values[id] else { throw RingifyError.projectNotFound }
            project.library = try change.applying(to: project.library)
            return project
        }
        for project in updates { values[project.id] = project }
        return updates
    }
    func deleteCollection(id: UUID) async throws {
        groups[id] = nil
        for projectID in Array(values.keys) { values[projectID]?.library.collectionIDs.remove(id) }
    }
}

/// Startup remains usable, but no write may masquerade as durable storage.
actor UnavailableProjectStorageService: ProjectStorageService {
    let reason: String
    init(reason: String) { self.reason = reason }
    func projects() async throws -> [RingtoneProject] { throw RingifyError.storageUnavailable(reason: reason) }
    func project(id: UUID) async throws -> RingtoneProject? { throw RingifyError.storageUnavailable(reason: reason) }
    func save(_ project: RingtoneProject) async throws { throw RingifyError.storageUnavailable(reason: reason) }
    func delete(id: UUID) async throws { throw RingifyError.storageUnavailable(reason: reason) }
    func deleteAll() async throws { throw RingifyError.storageUnavailable(reason: reason) }
}
