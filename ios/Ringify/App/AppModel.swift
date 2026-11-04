import Foundation
import RingifyCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    let container: AppContainer

    @Published var currentProject: RingtoneProject? {
        didSet {
            if exportState.invalidate(for: currentProject) { exportProgress = nil }
        }
    }
    @Published var projects: [RingtoneProject] = []
    @Published private(set) var collections: [ProjectCollection] = []
    @Published private(set) var exportHistory: [ProjectExportRecord] = []
    @Published private(set) var audioPresets: [UserAudioPreset] = []
    @Published private(set) var isPresetWorking = false
    @Published private(set) var isLibraryWorking = false
    @Published private(set) var exportState = ProjectExportState()
    var exportedRingtone: ExportedRingtone? { exportState.result }
    @Published var exportProgress: ExportProgress?
    @Published var issue: RingifyIssue?
    @Published var errorMessage: String?
    @Published var isWorking = false
    @Published var requiresProForProjectLimit = false
    @Published var settings: UserSettings {
        didSet { persistSettings() }
    }
    private var pendingWrite: Task<Void, Error>?
    private var libraryRevision = UUID()
    private var libraryReadToken = UUID()
    private var presetReadToken = UUID()
    private var deletingIDs: Set<UUID> = []

    init(container: AppContainer) {
        self.container = container
        if let data = UserDefaults.standard.data(forKey: "ringify.settings"),
           let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
            settings = decoded
        } else {
            settings = UserSettings()
        }
        if let detail = container.initialStorageError {
            issue = .storageFailed
            errorMessage = detail
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch settings.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    func localized(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: settings.language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }

    @discardableResult
    func prepareMedia(from sourceURL: URL, kind: MediaSourceKind, markers: [AudioMarker] = []) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        defer { isWorking = false }
        var importedFiles: [URL] = []
        var committed = false
        defer {
            if !committed {
                do {
                    let files = ManagedFileDeletion(roots: [container.directories.imports],
                        trash: container.directories.root.appendingPathComponent("PendingDeletion"))
                    try files.commit(files.stage(candidates: importedFiles, retaining: []))
                } catch { presentStorage(error) }
            }
        }
        do {
            let savedProjects = try await container.storage.projects()
            projects = savedProjects
            if savedProjects.count >= ProAccessPolicy.normalProjectLimit {
                await container.purchases.refreshEntitlements()
            }
            guard ProAccessPolicy.canCreateProject(count: savedProjects.count, hasVerifiedPro: container.purchases.isPro,
                purchasedSlots: container.purchases.verifiedSlots) else {
                requiresProForProjectLimit = true
                return false
            }
            exportState.reset()
            exportProgress = nil
            let imported = try await container.mediaImport.importMedia(from: sourceURL, kind: kind)
            importedFiles.append(imported.localURL)
            var editorMedia = imported
            var mediaMetadata = try await container.metadata.metadata(for: imported.localURL)
            guard mediaMetadata.hasAudioTrack else { throw RingifyError.missingAudioTrack }
            guard mediaMetadata.duration.isFinite, mediaMetadata.duration >= RingtoneRules.minimumDuration,
                  mediaMetadata.duration <= 30 * 60, (1...2).contains(mediaMetadata.channelCount) else {
                throw RingifyError.corruptMedia
            }

            if kind == .videoFile || kind == .photoLibraryVideo {
                try container.directories.prepare()
                let sourceName = (imported.originalFilename as NSString).deletingPathExtension
                let audioURL = container.directories.uniqueURL(
                    in: container.directories.imports,
                    filename: "\(sourceName)-audio",
                    extension: "m4a"
                )
                importedFiles.append(audioURL)
                let extractedURL = try await container.extraction.extractAudio(
                    from: imported.localURL,
                    to: audioURL
                )
                editorMedia = ImportedMedia(
                    localURL: extractedURL,
                    originalFilename: imported.originalFilename,
                    sourceKind: kind,
                    importedAt: imported.importedAt
                )
                mediaMetadata = try await container.metadata.metadata(for: extractedURL)
            }

            var project = try CreateProjectUseCase()(media: editorMedia, metadata: mediaMetadata)
            project.markers = try AudioMarkers.fittingRecording(markers, sourceDuration: project.sourceDuration)
            project.waveformSamples = try await container.waveform.samples(
                for: editorMedia.localURL,
                sampleCount: 240
            )
            do {
                try await scheduleWrite {
                    let saved = try await self.container.storage.projects()
                    try self.validateProjectCapacity(count: saved.count)
                    try await self.container.storage.save(project)
                }.value
            } catch {
                if let known = error as? RingifyError, case .purchaseFailed = known { present(error) }
                else { presentStorage(error) }
                return false
            }
            committed = true
            currentProject = project
            // The project references extracted audio, not the original video copy.
            if editorMedia.localURL != imported.localURL {
                do { try FileManager.default.removeItem(at: imported.localURL) }
                catch { presentStorage(error) }
            }
            await reloadProjects()
            return true
        } catch {
            present(error)
            return false
        }
    }

    /// True means accepted and queued; durable storage can still fail and is reported separately.
    @discardableResult
    func updateCurrentProject(_ update: (inout RingtoneProject) -> Void) -> Bool {
        guard var project = currentProject, !deletingIDs.contains(project.id) else { return false }
        let priorNormalization = project.effects.normalize
        let priorStudio = project.effects.studio
        let priorLibrary = project.library
        let priorMarkers = project.markers
        update(&project)
        // Content edits cannot bypass the dedicated organization transaction.
        project.library = priorLibrary
        project.markers = priorMarkers
        do { try project.effects.studio.validate(); try LoopCrossfadeRules.validate(project.effects.loopCrossfadeDuration) }
        catch { present(error); return false }
        guard ProAccessPolicy.canChangeNormalization(current: priorNormalization,
            next: project.effects.normalize, hasVerifiedPro: container.purchases.isPro) else {
            present(RingifyError.purchaseFailed(reason: localized("premium.normalize.required")))
            return false
        }
        guard ProAccessPolicy.canChangeStudioEffects(current: priorStudio,
            next: project.effects.studio, hasVerifiedPro: container.purchases.isPro) else {
            present(RingifyError.purchaseFailed(reason: localized("premium.studio.required")))
            return false
        }
        container.playback.stop()
        project.exportedURL = nil
        project.status = .draft
        project.updatedAt = .now
        currentProject = project
        let snapshot = project
        let write = scheduleWrite { try await self.container.storage.save(snapshot) }
        Task {
            do { try await write.value; await reloadProjects() }
            catch { presentStorage(error) }
        }
        return true
    }

    func reloadProjects() async {
        _ = await pendingWrite?.result
        let revision = libraryRevision
        do {
            let saved = try await container.storage.projects()
            guard revision == libraryRevision else { return }
            projects = saved
        } catch {
            presentStorage(error)
        }
    }

    @discardableResult
    func reloadLibrary() async -> Bool {
        let token = UUID()
        libraryReadToken = token
        _ = await pendingWrite?.result
        let revision = libraryRevision
        do {
            let saved = try await container.storage.projects()
            let groups = try await container.storage.collections()
            let history = try await container.storage.exportHistory(projectID: nil)
            guard token == libraryReadToken, revision == libraryRevision else { return false }
            projects = saved
            collections = groups
            exportHistory = history
            if let active = currentProject, let stored = saved.first(where: { $0.id == active.id }) {
                mergeLibraryMetadata([stored])
            }
            return true
        } catch { presentStorage(error); return false }
    }

    func updateProjectLibrary(projectIDs: Set<UUID>, change: LibraryMetadataChange) async -> Bool {
        guard !isLibraryWorking, !projectIDs.isEmpty else { return false }
        isLibraryWorking = true
        defer { isLibraryWorking = false }
        do {
            try await scheduleWrite {
                guard projectIDs.isDisjoint(with: self.deletingIDs) else { throw RingifyError.projectNotFound }
                // Read after preceding content writes, and check current verified
                // access inside the same serial queue used by save and deletion.
                let saved = try await self.container.storage.projects().filter { projectIDs.contains($0.id) }
                guard saved.count == projectIDs.count else { throw RingifyError.projectNotFound }
                guard projectIDs.count == 1 || self.container.purchases.isPro else {
                    throw RingifyError.purchaseFailed(reason: self.uiText("Toplu düzenleme için Ringify Pro gerekir.",
                        "Ringify Pro is required for batch organization."))
                }
                guard saved.allSatisfy({ LibraryAccessPolicy.canApply(change: change, current: $0.library,
                    hasVerifiedPro: self.container.purchases.isPro) }) else {
                    throw RingifyError.purchaseFailed(reason: self.uiText("Yeni favori ve koleksiyon üyelikleri için Ringify Pro gerekir.",
                        "Ringify Pro is required for new favorites and collection memberships."))
                }
                let updated = try await self.container.storage.updateLibraryMetadata(projectIDs: projectIDs, change: change)
                self.mergeLibraryMetadata(updated)
            }.value
            await reloadLibrary()
            return true
        } catch {
            if case RingifyError.purchaseFailed = error { present(error) }
            else { presentStorage(error) }
            return false
        }
    }

    func saveCollection(id: UUID? = nil, name: String) async -> Bool {
        guard !isLibraryWorking else { return false }
        isLibraryWorking = true
        defer { isLibraryWorking = false }
        do {
            let valid = try ProjectCollection.validatedName(name)
            try await scheduleWrite {
                guard self.container.purchases.isPro else {
                    throw RingifyError.purchaseFailed(reason: self.uiText("Koleksiyon oluşturmak ve yeniden adlandırmak için Ringify Pro gerekir.",
                        "Ringify Pro is required to create and rename collections."))
                }
                let collection: ProjectCollection
                if let id {
                    guard let saved = try await self.container.storage.collections().first(where: { $0.id == id }) else {
                        throw RingifyError.projectNotFound
                    }
                    collection = ProjectCollection(id: saved.id, name: valid, createdAt: saved.createdAt)
                } else { collection = ProjectCollection(name: valid) }
                try await self.container.storage.saveCollection(collection)
            }.value
            await reloadLibrary()
            return true
        } catch {
            if case RingifyError.purchaseFailed = error { present(error) }
            else { presentStorage(error) }
            return false
        }
    }

    func deleteCollection(id: UUID) async -> Bool {
        guard !isLibraryWorking else { return false }
        isLibraryWorking = true
        defer { isLibraryWorking = false }
        do {
            try await scheduleWrite { try await self.container.storage.deleteCollection(id: id) }.value
            await reloadLibrary()
            return true
        } catch { presentStorage(error); return false }
    }

    func duplicateProject(id: UUID) async -> Bool {
        guard !isLibraryWorking, !isWorking else { return false }
        isLibraryWorking = true
        defer { isLibraryWorking = false }
        do {
            try await scheduleWrite {
                guard !self.deletingIDs.contains(id) else { throw RingifyError.projectNotFound }
                let projects = try await self.container.storage.projects()
                guard let original = projects.first(where: { $0.id == id }) else { throw RingifyError.projectNotFound }
                try self.validateProjectCapacity(count: projects.count)
                let source = original.sourceURL.standardizedFileURL.resolvingSymlinksInPath()
                let roots = [self.container.directories.imports, self.container.directories.recordings]
                    .map { $0.standardizedFileURL.resolvingSymlinksInPath().pathComponents }
                guard original.sourceURL.isFileURL, roots.contains(where: {
                    source.pathComponents.count > $0.count && source.pathComponents.starts(with: $0)
                }), FileManager.default.fileExists(atPath: source.path),
                   try source.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
                    throw RingifyError.fileNotFound(original.sourceURL)
                }
                let name = RingtoneRules().safeFilename(from: original.name + self.uiText(" kopya", " copy"))
                let duplicate = try DuplicateProjectUseCase()(original, name: name)
                try await self.container.storage.save(duplicate)
            }.value
            await reloadLibrary()
            return true
        } catch {
            if let known = error as? RingifyError {
                switch known {
                case .purchaseFailed, .fileNotFound, .invalidSelection, .corruptMedia: present(error)
                default: presentStorage(error)
                }
            } else { presentStorage(error) }
            return false
        }
    }

    private func validateProjectCapacity(count: Int) throws {
        guard ProAccessPolicy.canCreateProject(count: count, hasVerifiedPro: container.purchases.isPro,
            purchasedSlots: container.purchases.verifiedSlots) else {
            requiresProForProjectLimit = !container.purchases.isPro
            let limit = container.purchases.projectLimit
            throw RingifyError.purchaseFailed(reason: uiText("Bu planın \(limit) proje sınırına ulaştın.",
                "You have reached this plan's limit of \(limit) projects."))
        }
    }

    private func mergeLibraryMetadata(_ saved: [RingtoneProject]) {
        libraryRevision = UUID()
        let metadata = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, ($0.library, $0.markers)) })
        projects = projects.map { project in
            var next = project
            if let (library, markers) = metadata[project.id] { next.library = library; next.markers = markers }
            return next
        }
        if var active = currentProject, let (library, markers) = metadata[active.id] {
            active.library = library
            active.markers = markers
            currentProject = active
        }
    }

    func deleteExport(_ record: ProjectExportRecord) async -> Bool {
        guard !isLibraryWorking, !isWorking else { return false }
        isLibraryWorking = true
        defer { isLibraryWorking = false }
        do {
            try await scheduleWrite {
                try await self.container.storage.deleteExport(id: record.id)
                if self.exportedRingtone?.url == record.output.url { self.exportState.reset(); self.exportProgress = nil }
                if var active = self.currentProject, active.id == record.projectID, active.exportedURL == record.output.url {
                    active.exportedURL = nil; active.status = .draft
                    self.currentProject = active
                }
            }.value
            await reloadLibrary()
            return true
        } catch { presentStorage(error); return false }
    }

    func updateProjectMarkers(id: UUID, markers: [AudioMarker]) async -> Bool {
        guard !isLibraryWorking else { return false }
        isLibraryWorking = true
        defer { isLibraryWorking = false }
        do {
            try await scheduleWrite {
                guard !self.deletingIDs.contains(id) else { throw RingifyError.projectNotFound }
                let saved = try await self.container.storage.updateMarkers(projectID: id, markers: markers)
                self.mergeLibraryMetadata([saved])
            }.value
            await reloadLibrary()
            return true
        } catch { presentStorage(error); return false }
    }

    @discardableResult func reloadAudioPresets() async -> Bool {
        let token = UUID()
        presetReadToken = token
        _ = await pendingWrite?.result
        let revision = libraryRevision
        do {
            let saved = try await container.storage.audioPresets()
            guard token == presetReadToken, revision == libraryRevision else { return false }
            audioPresets = saved
            return true
        } catch { presentStorage(error); return false }
    }

    func saveAudioPreset(id: UUID? = nil, name: String, effects: AudioEffectSettings) async -> Bool {
        guard !isPresetWorking else { return false }
        isPresetWorking = true
        defer { isPresetWorking = false }
        do {
            let validName = try ProjectCollection.validatedName(name)
            try await scheduleWrite {
                let preset: UserAudioPreset
                if let id {
                    guard let prior = try await self.container.storage.audioPresets().first(where: { $0.id == id }) else { throw RingifyError.projectNotFound }
                    preset = UserAudioPreset(id: id, name: validName, effects: effects, createdAt: prior.createdAt, updatedAt: .now)
                } else { preset = UserAudioPreset(name: validName, effects: effects) }
                try await self.container.storage.saveAudioPreset(preset)
            }.value
            await reloadAudioPresets()
            return true
        } catch { presentStorage(error); return false }
    }

    func deleteAudioPreset(id: UUID) async -> Bool {
        guard !isPresetWorking else { return false }
        isPresetWorking = true
        defer { isPresetWorking = false }
        do {
            try await scheduleWrite { try await self.container.storage.deleteAudioPreset(id: id) }.value
            await reloadAudioPresets()
            return true
        } catch { presentStorage(error); return false }
    }

    @discardableResult func loadProject(_ project: RingtoneProject) -> Bool {
        container.playback.stop()
        exportState.reset()
        exportProgress = nil
        guard FileManager.default.fileExists(atPath: project.sourceURL.path) else {
            currentProject = nil
            issue = .fileNotFound
            return false
        }
        currentProject = project
        return true
    }

    @discardableResult func deleteProject(id: UUID) async -> Bool {
        deletingIDs.insert(id)
        defer { deletingIDs.remove(id) }
        container.playback.stop()
        do {
            try await scheduleWrite { try await self.container.storage.delete(id: id) }.value
            if currentProject?.id == id { currentProject = nil }
            exportHistory.removeAll { $0.projectID == id }
            await reloadProjects()
            return true
        } catch {
            presentStorage(error)
            return false
        }
    }

    func renameProject(_ project: RingtoneProject, to name: String) async -> Bool {
        guard !deletingIDs.contains(project.id) else { return false }
        do {
            let valid = try RingtoneRules().validate(filename: name).get()
            var updated = project
            updated.rename(to: valid)
            let snapshot = updated
            try await scheduleWrite { try await self.container.storage.save(snapshot) }.value
            if var active = currentProject, active.id == project.id {
                active.name = updated.name
                active.updatedAt = updated.updatedAt
                currentProject = active
            }
            await reloadProjects()
            return true
        } catch { presentStorage(error); return false }
    }

    func deleteAllProjects() async {
        container.playback.stop()
        deletingIDs.formUnion(projects.map(\.id))
        defer { deletingIDs.removeAll() }
        do {
            try await scheduleWrite { try await self.container.storage.deleteAll() }.value
            currentProject = nil
            projects = []
            collections = []
            exportHistory = []
            audioPresets = []
        } catch { presentStorage(error) }
    }

    @discardableResult private func scheduleWrite(_ operation: @escaping @MainActor () async throws -> Void) -> Task<Void, Error> {
        libraryRevision = UUID()
        let previous = pendingWrite
        let task = Task {
            // Each caller reports its own error. A failed write must not prevent
            // later retries or deletions from reaching the persistent store.
            _ = await previous?.result
            try await operation()
        }
        pendingWrite = task
        return task
    }

    private func presentStorage(_ error: Error) {
        issue = .storageFailed
        errorMessage = error.localizedDescription
    }

    func waitForPendingWrites() async throws { try await pendingWrite?.value }

    func prepareAnotherExport() {
        guard !isWorking else { return }
        exportState.reset()
        exportProgress = nil
    }

    func exportCurrentProject(filename: String, profile: AudioOutputProfile = .aacStandard) async {
        guard !isWorking else { return }
        guard !profile.requiresPro || container.purchases.isPro else {
            present(RingifyError.purchaseFailed(reason: uiText("Bu dışa aktarma kalitesi için Ringify Pro gerekir.",
                "Ringify Pro is required for this export quality.")))
            return
        }
        guard let project = currentProject else {
            issue = .noSavedProject
            return
        }
        isWorking = true
        let token = exportState.begin(for: project)
        defer { isWorking = false }
        let request = ExportRequest(
            projectID: project.id,
            sourceURL: project.sourceURL,
            filename: filename,
            selection: project.selection,
            effects: project.effects,
            profile: profile
        )
        do {
            for try await event in container.export.export(request) {
                guard exportState.accepts(currentProject, token: token) else {
                    if case .completed(let result) = event { await discardUnreferencedExport(result.url) }
                    return
                }
                exportProgress = event
                if case .completed(let result) = event {
                    var updated = project
                    updated.markExported(to: result.url, now: result.createdAt)
                    let snapshot = updated
                    do {
                        try await scheduleWrite {
                            guard self.exportState.accepts(self.currentProject, token: token) else { return }
                            guard !profile.requiresPro || self.container.purchases.isPro else {
                                throw RingifyError.purchaseFailed(reason: self.uiText("Pro erişimi sona erdi. Standart kaliteyle tekrar deneyebilirsin.",
                                    "Pro access ended. Try again using standard quality."))
                            }
                            try await self.container.storage.commitExport(project: snapshot, output: result, profile: profile)
                        }.value
                    } catch {
                        await discardUnreferencedExport(result.url)
                        if let known = error as? RingifyError, case .purchaseFailed = known { present(error) }
                        else { presentStorage(error) }
                        return
                    }
                    guard exportState.accepts(currentProject, token: token) else {
                        await discardUnreferencedExport(result.url)
                        return
                    }
                    // Organization may have changed while the audio was rendering.
                    if let active = currentProject { updated.library = active.library; updated.markers = active.markers }
                    currentProject = updated
                    exportState.complete(result, for: currentProject, token: token)
                    await reloadLibrary()
                }
            }
        } catch is CancellationError {
            issue = .cancelled
        } catch {
            present(error)
        }
    }

    func present(_ error: Error) {
        errorMessage = error is RingifyError ? nil : error.localizedDescription
        guard let ringifyError = error as? RingifyError else {
            issue = .exportFailed
            return
        }
        switch ringifyError {
        case .storageUnavailable(let reason): issue = .storageFailed; errorMessage = reason
        case .unsupportedFile(_): issue = .unsupportedFile
        case .missingAudioTrack: issue = .missingAudioTrack
        case .corruptMedia: issue = .corruptFile
        case .permissionDenied: issue = .permissionDenied
        case .insufficientStorage(_): issue = .insufficientStorage
        case .cancelled: issue = .cancelled
        case .fileNotFound(_): issue = .fileNotFound
        case .purchaseFailed(let reason): issue = .purchaseFailed; errorMessage = reason
        default: issue = .exportFailed
        }
    }

    private func discardUnreferencedExport(_ url: URL) async {
        do {
            let saved = try await container.storage.projects()
            let history = try await container.storage.exportHistory(projectID: nil)
            let referenced = saved.flatMap { [$0.sourceURL] + [$0.exportedURL].compactMap { $0 } } + history.map { $0.output.url }
            let deletion = ManagedFileDeletion(roots: [container.directories.exports],
                trash: container.directories.root.appendingPathComponent("PendingDeletion"))
            try deletion.commit(deletion.stage(candidates: [url], retaining: referenced))
        } catch { presentStorage(error) }
    }

    private func persistSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: "ringify.settings")
        } catch { presentStorage(error) }
    }
}
