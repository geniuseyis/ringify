import Foundation
import RingifyCore
import SwiftUI

extension LibraryStatusFilter {
    @MainActor func title(_ model: AppModel) -> String {
        switch self {
        case .all: model.uiText("Tümü", "All")
        case .drafts: model.uiText("Taslaklar", "Drafts")
        case .ready: model.uiText("Zil Sesleri", "Ringtones")
        }
    }

}

extension LibrarySortOrder {
    @MainActor func title(_ model: AppModel) -> String {
        switch self {
        case .recentlyEdited: model.uiText("Son düzenlenenler", "Recently edited")
        case .newest: model.uiText("En yeni", "Newest")
        case .name: model.uiText("Ad · A–Z", "Name · A–Z")
        case .duration: model.uiText("Süre · kısa önce", "Duration · shortest first")
        }
    }

}

struct LibraryView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var query = ""
    @AppStorage("ringify.library.preferences") private var preferencesData = Data()
    @AppStorage("ringify.library.grid") private var gridLayout = false
    @State private var showOrganization = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var pendingDeleteIDs: [UUID] = []
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var projectToRename: RingtoneProject?
    @State private var projectToOrganize: RingtoneProject?
    @State private var showBatchOrganization = false

    private var preferences: LibraryPreferences {
        (try? JSONDecoder().decode(LibraryPreferences.self, from: preferencesData)) ?? LibraryPreferences()
    }

    private var visibleProjects: [RingtoneProject] {
        LibraryQueryUseCase()(model.projects, query: query, preferences: preferences,
            locale: Locale(identifier: model.settings.language.rawValue))
    }

    var body: some View {
        List {
            Section {
                librarySummary
                    .listRowBackground(Color.clear)
                filterPicker
                    .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                    .listRowBackground(Color.clear)
                libraryToolbar
                    .listRowBackground(Color.clear)
            }
            Section {
                if model.isWorking && model.projects.isEmpty {
                    RingifyLoadingView().frame(minHeight: 220)
                } else if visibleProjects.isEmpty {
                    emptyState
                } else if gridLayout && !isSelecting {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top),
                        count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                        ForEach(visibleProjects) { project in
                            projectRow(project)
                                .buttonStyle(.plain)
                                .padding(12)
                                .background(RingifyTheme.Studio.surface, in: RoundedRectangle(cornerRadius: 20))
                                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(RingifyTheme.Studio.border).allowsHitTesting(false) }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(visibleProjects) { project in
                        projectRow(project)
                            .swipeActions(edge: .trailing) {
                                if !isSelecting {
                                    Button(role: .destructive) { confirmDeletion([project.id]) } label: {
                                        Label("library.delete", systemImage: "trash")
                                    }
                                    Button { projectToRename = project } label: {
                                        Label("library.rename", systemImage: "pencil")
                                    }.tint(RingifyTheme.accent)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if !isSelecting {
                                    Button { toggleFavorite(project) } label: {
                                        Label(project.library.favorite ? model.uiText("Favoriden çıkar", "Remove favorite") : model.uiText("Favoriye ekle", "Add favorite"),
                                            systemImage: project.library.favorite ? "star.slash" : "star")
                                    }
                                    .tint(RingifyTheme.accent).disabled(model.isLibraryWorking)
                                }
                            }
                    }
                }
            } header: {
                HStack {
                    Text(preferences.sort.title(model)).textCase(nil)
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .ringifyStudioAppearance()
        .searchable(text: $query, prompt: "library.search")
        .navigationTitle(model.uiText("Kütüphane", "Library"))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isSelecting {
                    Button("common.done") { endSelection() }.disabled(isDeleting || model.isLibraryWorking)
                } else {
                    Menu {
                        Button { showOrganization = true } label: {
                            Label(model.uiText("Filtrele ve sırala", "Filter and sort"), systemImage: "line.3.horizontal.decrease")
                        }
                        Button {
                            if purchases.isPro { isSelecting = true }
                            else { router.push(.premium) }
                        } label: {
                            Label(model.uiText("Projeleri seç", "Select projects"), systemImage: "checkmark.circle")
                        }.disabled(model.projects.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(model.uiText("Kütüphane seçenekleri", "Library options"))
                    Button { router.push(.importSource) } label: {
                        Image(systemName: "plus").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("home.create")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting { selectionBar }
        }
        .task { if await model.reloadLibrary() { reconcileCollectionFilter() } }
        .onChange(of: model.collections.map(\.id)) { _, _ in reconcileCollectionFilter() }
        .onChange(of: model.projects.map(\.id)) { _, projectIDs in
            selectedIDs.formIntersection(Set(projectIDs))
        }
        .onChange(of: purchases.isPro) { _, active in
            if !active { endSelection(); showDeleteConfirmation = false; pendingDeleteIDs = [] }
        }
        .sheet(isPresented: $showOrganization) {
            NavigationStack {
                LibraryOrganizationView(preferences: Binding(get: { preferences }, set: { savePreferences($0) }))
                    .ringifyStudioAppearance()
            }
        }
        .sheet(item: $projectToRename) { project in
            RenameProjectSheet(project: project) { await model.renameProject(project, to: $0) }
                .environment(\.ringifyVisualStyle, .classic)
                .tint(RingifyTheme.AppleV2.accent)
        }
        .sheet(item: $projectToOrganize) { project in
            LibraryCollectionAssignmentView(projectID: project.id)
                .environment(\.ringifyVisualStyle, .classic)
                .tint(RingifyTheme.AppleV2.accent)
        }
        .sheet(isPresented: $showBatchOrganization) {
            LibraryBatchOrganizationView(projectIDs: selectedIDs)
                .environment(\.ringifyVisualStyle, .classic)
                .tint(RingifyTheme.AppleV2.accent)
        }
        .confirmationDialog(model.uiText("Seçilen projeler silinsin mi?", "Delete the selected projects?"),
            isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(model.uiText("\(pendingDeleteIDs.count) Projeyi Sil", pendingDeleteIDs.count == 1 ? "Delete 1 Project" : "Delete \(pendingDeleteIDs.count) Projects"), role: .destructive) {
                let projectIDs = pendingDeleteIDs
                let wasSelecting = isSelecting
                isDeleting = true
                Task {
                    var failures: Set<UUID> = []
                    for id in projectIDs {
                        if !(await model.deleteProject(id: id)) { failures.insert(id) }
                    }
                    isDeleting = false
                    pendingDeleteIDs = []
                    if failures.isEmpty { endSelection() }
                    else if wasSelecting && purchases.isPro { selectedIDs = failures }
                }
            }
            Button("common.cancel", role: .cancel) { pendingDeleteIDs = [] }
        } message: {
            Text(model.uiText("Projeler ve onlara ait yerel dosyalar kaldırılır. Bu işlem geri alınamaz.",
                "Projects and their local files will be removed. This cannot be undone."))
        }
    }

    private var librarySummary: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.uiText("\(model.projects.count) proje", "\(model.projects.count) projects"))
                    .font(.subheadline.weight(.semibold))
                Text(model.uiText("\(model.projects.filter { $0.status == .draft }.count) taslak · \(model.projects.filter { $0.status == .exported }.count) hazır",
                    "\(model.projects.filter { $0.status == .draft }.count) drafts · \(model.projects.filter { $0.status == .exported }.count) exported"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Button { gridLayout.toggle() } label: {
                Image(systemName: gridLayout ? "list.bullet" : "square.grid.2x2")
                    .frame(width: 44, height: 44)
                    .background(RingifyTheme.Studio.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(RingifyTheme.Studio.border) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.uiText("Görünümü değiştir", "Change layout"))
            .accessibilityValue(gridLayout ? model.uiText("Izgara", "Grid") : model.uiText("Liste", "List"))
            .accessibilityIdentifier("library.layout")
        }
    }

    private var libraryToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { libraryToolbarButtons }
            VStack(alignment: .leading, spacing: 10) { libraryToolbarButtons }
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder private var libraryToolbarButtons: some View {
        Button { preferenceBinding(\.favoritesOnly).wrappedValue = !preferences.favoritesOnly } label: {
            Label(model.uiText("Favoriler \(model.projects.filter { $0.library.favorite }.count)", "Favorites \(model.projects.filter { $0.library.favorite }.count)"), systemImage: "star")
                .font(.subheadline).frame(minHeight: 44)
        }
        .accessibilityAddTraits(preferences.favoritesOnly ? [.isSelected] : [])
        .tint(preferences.favoritesOnly ? RingifyTheme.Studio.accent : RingifyTheme.Studio.secondary)
        .accessibilityIdentifier("library.favorites.filter")
        Button { showOrganization = true } label: {
            Label(model.uiText("Koleksiyonlar", "Collections"), systemImage: "folder")
                .font(.subheadline).frame(minHeight: 44)
        }
        .accessibilityIdentifier("library.collections")
        Button { showOrganization = true } label: {
            Image(systemName: "arrow.up.arrow.down").frame(width: 44, height: 44)
        }
        .accessibilityLabel(model.uiText("Filtrele ve sırala", "Filter and sort"))
        .accessibilityIdentifier("library.sort")
    }

    @ViewBuilder private var filterPicker: some View {
        if typeSize.isAccessibilitySize {
            Picker(model.uiText("Göster", "Show"), selection: preferenceBinding(\.status)) { filterOptions }
                .pickerStyle(.menu)
        } else {
            Picker(model.uiText("Göster", "Show"), selection: preferenceBinding(\.status)) { filterOptions }
                .pickerStyle(.segmented)
        }
    }

    private var filterOptions: some View {
        ForEach([LibraryStatusFilter.all, .ready, .drafts]) { option in Text(option.title(model)).tag(option) }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(model.projects.isEmpty ? model.localized("library.empty.title") : model.localized("library.noResults.title"),
                systemImage: model.projects.isEmpty ? "music.note.list" : "magnifyingglass")
        } description: {
            Text(model.projects.isEmpty ? model.localized("library.empty.message") :
                model.uiText("Başka bir ad ara veya durum filtresini değiştir.", "Try another name or change the status filter."))
        } actions: {
            if model.projects.isEmpty {
                Button("home.create") { router.push(.importSource) }
                    .buttonStyle(.borderedProminent).tint(RingifyTheme.accent)
            } else {
                Button(model.uiText("Aramayı ve filtreyi temizle", "Clear search and filter")) {
                    query = ""
                    var next = preferences
                    next.status = .all
                    next.favoritesOnly = false
                    next.collection = .all
                    savePreferences(next)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(minHeight: 240)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder private func projectRow(_ project: RingtoneProject) -> some View {
        if isSelecting {
            Button {
                if selectedIDs.contains(project.id) { selectedIDs.remove(project.id) }
                else { selectedIDs.insert(project.id) }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selectedIDs.contains(project.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIDs.contains(project.id) ? RingifyTheme.accent : Color.secondary)
                        .font(.title3).accessibilityHidden(true)
                    LibraryProjectLabel(project: project)
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selectedIDs.contains(project.id) ? [.isSelected] : [])
        } else {
            HStack(spacing: 4) {
                NavigationLink {
                    LibraryProjectDetailView(projectID: project.id)
                        .environment(\.ringifyVisualStyle, .classic)
                        .tint(RingifyTheme.AppleV2.accent)
                } label: {
                    LibraryProjectLabel(project: project, compact: gridLayout)
                }
                Menu {
                    Button("library.edit", systemImage: "scissors") { open(project, at: .editor) }
                    Button("library.rename", systemImage: "pencil") { projectToRename = project }
                    Button(model.uiText("Çoğalt", "Duplicate"), systemImage: "plus.square.on.square") {
                        Task { await model.duplicateProject(id: project.id) }
                    }.disabled(model.isLibraryWorking || model.isWorking)
                    Button(project.library.favorite ? model.uiText("Favoriden çıkar", "Remove favorite") : model.uiText("Favoriye ekle", "Add favorite"), systemImage: "star") {
                        toggleFavorite(project)
                    }.disabled(model.isLibraryWorking)
                    Button(model.uiText("Koleksiyonlar", "Collections"), systemImage: "folder") { projectToOrganize = project }
                    if let exportedURL = project.exportedURL {
                        ShareLink(item: exportedURL) { Label("library.share", systemImage: "square.and.arrow.up") }
                    }
                    Button("library.delete", systemImage: "trash", role: .destructive) { confirmDeletion([project.id]) }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(model.uiText("\(project.name) seçenekleri", "Options for \(project.name)"))
            }
        }
    }

    private var selectionBar: some View {
        HStack {
            Text(model.uiText("\(selectedIDs.count) seçili", "\(selectedIDs.count) selected")).font(.subheadline)
            Spacer()
            if isDeleting { ProgressView() }
            Button { showBatchOrganization = true } label: {
                Label(model.uiText("Düzenle", "Organize"), systemImage: "folder").frame(minHeight: 44)
            }
            .disabled(selectedIDs.isEmpty || isDeleting || model.isLibraryWorking)
            Button(role: .destructive) { confirmDeletion(Array(selectedIDs)) } label: {
                Label("library.delete", systemImage: "trash").frame(minHeight: 44)
            }
            .disabled(selectedIDs.isEmpty || isDeleting || model.isWorking || model.isLibraryWorking)
        }
        .padding(.horizontal, RingifyTheme.horizontalPadding)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func open(_ project: RingtoneProject, at route: AppRoute) {
        if model.loadProject(project) { router.push(route) }
    }

    private func toggleFavorite(_ project: RingtoneProject) {
        if !project.library.favorite && !purchases.isPro { router.push(.premium); return }
        Task { await model.updateProjectLibrary(projectIDs: [project.id], change: .favorite(!project.library.favorite)) }
    }

    private func preferenceBinding<Value>(_ key: WritableKeyPath<LibraryPreferences, Value>) -> Binding<Value> {
        Binding(get: { preferences[keyPath: key] }, set: { value in
            var next = preferences
            next[keyPath: key] = value
            savePreferences(next)
        })
    }

    private func savePreferences(_ preferences: LibraryPreferences) {
        do { preferencesData = try JSONEncoder().encode(preferences) }
        catch { model.present(RingifyError.storageUnavailable(reason: error.localizedDescription)) }
    }

    private func reconcileCollectionFilter() {
        if case .collection(let id) = preferences.collection, !model.collections.contains(where: { $0.id == id }) {
            var next = preferences
            next.collection = .all
            savePreferences(next)
        }
    }

    private func confirmDeletion(_ ids: [UUID]) {
        guard !isDeleting, !model.isLibraryWorking else { return }
        pendingDeleteIDs = ids
        showDeleteConfirmation = true
    }

    private func endSelection() {
        isSelecting = false
        selectedIDs = []
    }
}

private struct LibraryProjectLabel: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.ringifyVisualStyle) private var visualStyle
    let project: RingtoneProject
    var compact = false

    private var thumbnail: [Float] {
        let values = project.waveformSamples
        let count = min(24, values.count)
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            values[(index * values.count / count)..<((index + 1) * values.count / count)]
                .reduce(Float.zero) { peak, value in value.isFinite ? max(peak, abs(value)) : peak }
        }
    }

    var body: some View {
        let layout = compact
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Group {
                if thumbnail.isEmpty {
                    Image(systemName: project.status == .exported ? "bell.fill" : "waveform")
                        .font(.title3).foregroundStyle(visualStyle.accent)
                } else {
                    WaveformView(samples: thumbnail, tint: visualStyle.accent).padding(6)
                }
            }
                .frame(width: 44, height: 44)
                .background(visualStyle.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(project.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    .lineLimit(2)
                if project.library.favorite {
                    Label(model.uiText("Favori", "Favorite"), systemImage: "star.fill")
                        .font(.caption).foregroundStyle(RingifyTheme.accent)
                }
                if !project.library.collectionIDs.isEmpty {
                    Text(model.collections.filter { project.library.collectionIDs.contains($0.id) }.map(\.name).joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 5) { metadata }
                    VStack(alignment: .leading, spacing: 3) { metadata }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder private var metadata: some View {
        Text(DurationText.formatted(project.selection.duration))
        Text(project.status == .exported ? model.uiText("Zil sesi", "Ringtone") : model.uiText("Taslak", "Draft"))
    }
}

private struct LibraryProjectDetailView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var projectToRename: RingtoneProject?
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showPreview = false
    @State private var showEditor = false
    @State private var showCollections = false
    let projectID: UUID

    private var project: RingtoneProject? { model.projects.first { $0.id == projectID } }

    var body: some View {
        Group {
            if let project {
                List {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: project.status == .exported ? "bell.fill" : "waveform")
                                .font(.largeTitle).foregroundStyle(RingifyTheme.accent)
                                .frame(width: 72, height: 72)
                                .background(RingifyTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
                            Text(project.name).font(.title2.bold()).multilineTextAlignment(.center)
                            Text(project.status == .exported ? model.uiText("Hazır zil sesi", "Ready ringtone") : model.uiText("Taslak proje", "Draft project"))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    Section {
                        Button {
                            if model.loadProject(project) { showPreview = true }
                        } label: {
                            Label("preview.title", systemImage: "play.circle").frame(minHeight: 44)
                        }
                        Button {
                            if model.loadProject(project) { showEditor = true }
                        } label: {
                            Label("preview.reedit", systemImage: "scissors").frame(minHeight: 44)
                        }
                        if let exportedURL = project.exportedURL {
                            ShareLink(item: exportedURL) { Label("library.share", systemImage: "square.and.arrow.up").frame(minHeight: 44) }
                        }
                    }
                    Section(model.uiText("Proje bilgileri", "Project information")) {
                        NavigationLink { LibraryExportHistoryView(projectID: projectID) } label: {
                            Label(model.uiText("Dışa aktarma geçmişi", "Export history"), systemImage: "clock.arrow.circlepath")
                        }.frame(minHeight: 44)
                        LabeledContent(model.uiText("Seçim", "Selection"), value: DurationText.formatted(project.selection.duration))
                        LabeledContent(model.uiText("Kaynak", "Source"), value: project.sourceFilename)
                        LabeledContent(model.uiText("Son düzenleme", "Last edited")) { Text(project.updatedAt, style: .date) }
                    }
                    Section(model.uiText("Düzen", "Organization")) {
                        if project.library.favorite || purchases.isPro {
                            Button(project.library.favorite ? model.uiText("Favoriden çıkar", "Remove favorite") : model.uiText("Favoriye ekle", "Add favorite"), systemImage: "star") {
                                Task { await model.updateProjectLibrary(projectIDs: [projectID], change: .favorite(!project.library.favorite)) }
                            }.frame(minHeight: 44).disabled(model.isLibraryWorking)
                        } else {
                            NavigationLink { PremiumView() } label: {
                                Label(model.uiText("Favoriye ekle · Pro", "Add favorite · Pro"), systemImage: "star")
                                    .frame(minHeight: 44)
                            }
                        }
                        Button(model.uiText("Koleksiyonlar", "Collections"), systemImage: "folder") { showCollections = true }
                            .frame(minHeight: 44).disabled(model.isLibraryWorking)
                    }
                    Section {
                        Button(model.uiText("Çoğalt", "Duplicate"), systemImage: "plus.square.on.square") {
                            Task { await model.duplicateProject(id: projectID) }
                        }.frame(minHeight: 44).disabled(model.isLibraryWorking || model.isWorking)
                        Button("library.rename", systemImage: "pencil") { projectToRename = project }.frame(minHeight: 44)
                        Button("library.delete", systemImage: "trash", role: .destructive) { showDeleteConfirmation = true }
                            .frame(minHeight: 44).disabled(isDeleting || model.isWorking)
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                RingifyEmptyState(icon: "music.note.list", title: "issue.noSavedProject.title", message: "issue.noSavedProject.message")
            }
        }
        .navigationTitle(model.uiText("Proje Ayrıntıları", "Project Details"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showPreview) { RingtonePreviewView() }
        .navigationDestination(isPresented: $showEditor) { AudioEditorView() }
        .sheet(item: $projectToRename) { project in
            RenameProjectSheet(project: project) { await model.renameProject(project, to: $0) }
        }
        .sheet(isPresented: $showCollections) { LibraryCollectionAssignmentView(projectID: projectID) }
        .confirmationDialog("library.delete.confirm", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("library.delete", role: .destructive) {
                isDeleting = true
                Task {
                    await model.deleteProject(id: projectID)
                    isDeleting = false
                    if project == nil { dismiss() }
                }
            }
            Button("common.cancel", role: .cancel) {}
        }
    }

}

private struct RenameProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let project: RingtoneProject
    let onSave: (String) async -> Bool
    @State private var name: String
    @State private var isSaving = false
    @State private var saveFailed = false

    init(project: RingtoneProject, onSave: @escaping (String) async -> Bool) {
        self.project = project
        self.onSave = onSave
        _name = State(initialValue: project.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("library.rename.placeholder", text: $name)
                if saveFailed { Text("issue.storageFailed.message").foregroundStyle(RingifyTheme.danger) }
            }
            .navigationTitle("library.rename")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        isSaving = true
                        saveFailed = false
                        Task {
                            if await onSave(name) { dismiss() } else { saveFailed = true }
                            isSaving = false
                        }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
        .presentationDetents([.medium, .large])
    }
}
