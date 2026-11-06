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
            controlsSection
            projectsSection
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "library.search")
        .navigationTitle(model.uiText("Kütüphane", "Library"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelecting {
                selectionBar
                    .background(.bar)
                    .overlay(alignment: .top) { Divider() }
            }
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
            }
        }
        .sheet(item: $projectToRename) { project in
            RenameProjectSheet(project: project) { await model.renameProject(project, to: $0) }
        }
        .sheet(item: $projectToOrganize) { project in
            LibraryCollectionAssignmentView(projectID: project.id)
        }
        .sheet(isPresented: $showBatchOrganization) {
            LibraryBatchOrganizationView(projectIDs: selectedIDs)
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

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
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

    // MARK: Controls

    private var controlsSection: some View {
        Section {
            filterPicker
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            filterChips
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    private var favoriteCount: Int { model.projects.filter { $0.library.favorite }.count }

    /// Favorites, collections, sort and layout stay visible on the list (user decision):
    /// one line of small capsules that scrolls sideways instead of breaking words.
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                favoritesChip
                collectionsChip
                sortChip
                layoutChip
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .padding(.vertical, 8)
        }
    }

    private var favoritesChip: some View {
        Button { preferenceBinding(\.favoritesOnly).wrappedValue = !preferences.favoritesOnly } label: {
            Label(model.uiText("Favoriler · \(favoriteCount)", "Favorites · \(favoriteCount)"),
                systemImage: preferences.favoritesOnly ? "star.fill" : "star")
                .lineLimit(1)
                .fixedSize()
                .modifier(LibraryChipHitArea())
        }
        // Selected state only: an explicit tint fills the active capsule; the others keep the system look.
        .tint(preferences.favoritesOnly ? RingifyTheme.accent : nil)
        .accessibilityAddTraits(preferences.favoritesOnly ? [.isSelected] : [])
        .accessibilityIdentifier("library.favorites.filter")
    }

    private var collectionsChip: some View {
        Button { showOrganization = true } label: {
            Label(model.uiText("Koleksiyonlar", "Collections"), systemImage: "folder")
                .lineLimit(1)
                .fixedSize()
                .modifier(LibraryChipHitArea())
        }
        .accessibilityIdentifier("library.collections")
    }

    private var sortChip: some View {
        Button { showOrganization = true } label: {
            Label(preferences.sort.title(model), systemImage: "arrow.up.arrow.down")
                .lineLimit(1)
                .fixedSize()
                .modifier(LibraryChipHitArea())
        }
        .accessibilityLabel(model.uiText("Filtrele ve sırala", "Filter and sort"))
        .accessibilityValue(preferences.sort.title(model))
        .accessibilityIdentifier("library.sort")
    }

    private var layoutChip: some View {
        Button { gridLayout.toggle() } label: {
            Image(systemName: gridLayout ? "list.bullet" : "square.grid.2x2")
                .fixedSize()
                .modifier(LibraryChipHitArea())
        }
        .accessibilityLabel(model.uiText("Görünümü değiştir", "Change layout"))
        .accessibilityValue(gridLayout ? model.uiText("Izgara", "Grid") : model.uiText("Liste", "List"))
        .accessibilityIdentifier("library.layout")
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

    // MARK: Projects

    private var projectsSection: some View {
        Section {
            projectsContent
        } header: {
            projectsHeader
        }
    }

    @ViewBuilder private var projectsContent: some View {
        if model.isWorking && model.projects.isEmpty {
            RingifyLoadingView().frame(minHeight: 220)
                .listRowBackground(Color.clear)
        } else if visibleProjects.isEmpty {
            emptyState
        } else if gridLayout && !isSelecting {
            projectGrid
        } else {
            projectList
        }
    }

    private var projectList: some View {
        ForEach(visibleProjects) { project in
            projectRow(project)
                .swipeActions(edge: .trailing) {
                    if !isSelecting {
                        Button(role: .destructive) { confirmDeletion([project.id]) } label: {
                            Label("library.delete", systemImage: "trash")
                        }
                        Button { projectToRename = project } label: {
                            Label("library.rename", systemImage: "pencil")
                        }
                    }
                }
                .swipeActions(edge: .leading) {
                    if !isSelecting {
                        Button { toggleFavorite(project) } label: {
                            Label(project.library.favorite ? model.uiText("Favoriden çıkar", "Remove favorite") : model.uiText("Favoriye ekle", "Add favorite"),
                                systemImage: project.library.favorite ? "star.slash" : "star")
                        }
                        .tint(RingifyTheme.action).disabled(model.isLibraryWorking)
                    }
                }
        }
    }

    private var projectCountText: String {
        model.uiText("\(model.projects.count) proje", "\(model.projects.count) projects")
    }

    private var statusCountText: String {
        let drafts = model.projects.filter { $0.status == .draft }.count
        let exported = model.projects.filter { $0.status == .exported }.count
        return model.uiText("\(drafts) taslak · \(exported) hazır", "\(drafts) drafts · \(exported) exported")
    }

    /// Sort order on the left, the project counter on the right; the draft and
    /// exported breakdown joins the line only when it fits.
    private var projectsHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(preferences.sort.title(model)).lineLimit(1)
                Spacer(minLength: 8)
                Text(projectCountText).lineLimit(1)
                Text(statusCountText).lineLimit(1).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(preferences.sort.title(model)).lineLimit(1)
                Spacer(minLength: 8)
                Text(projectCountText).lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(preferences.sort.title(model))
                Text(projectCountText)
                Text(statusCountText).foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }

    private var projectGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
            count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
            ForEach(visibleProjects) { project in
                NavigationLink {
                    LibraryProjectDetailView(projectID: project.id)
                } label: {
                    LibraryGridProjectLabel(project: project)
                        .ringifyCard(padding: 12)
                        .contentShape(.contextMenuPreview,
                            RoundedRectangle(cornerRadius: RingifyTheme.cardRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .contextMenu { projectActions(project) }
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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
                    .ringifyPrimaryAction()
            } else {
                Button(model.uiText("Aramayı ve filtreyi temizle", "Clear search and filter")) {
                    query = ""
                    var next = preferences
                    next.status = .all
                    next.favoritesOnly = false
                    next.collection = .all
                    savePreferences(next)
                }
                .ringifySecondaryAction()
            }
        }
        .frame(minHeight: 240)
        .listRowBackground(Color.clear)
    }

    private func collectionNames(_ project: RingtoneProject) -> String {
        model.collections.filter { project.library.collectionIDs.contains($0.id) }.map(\.name).joined(separator: ", ")
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
                    RingifyProjectLabel(project: project, detail: collectionNames(project))
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selectedIDs.contains(project.id) ? [.isSelected] : [])
        } else {
            NavigationLink {
                LibraryProjectDetailView(projectID: project.id)
            } label: {
                RingifyProjectLabel(project: project, detail: collectionNames(project))
            }
            .contextMenu { projectActions(project) }
        }
    }

    /// The actions the row's former "…" menu offered, unchanged, now in the context menu.
    @ViewBuilder private func projectActions(_ project: RingtoneProject) -> some View {
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

/// Small capsules stay compact visually but keep a 44 pt tall touch target.
private struct LibraryChipHitArea: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .padding(.vertical, -8)
    }
}

/// Compact grid cell: real waveform thumbnail, name, and duration with status.
private struct LibraryGridProjectLabel: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    let project: RingtoneProject

    private var summary: String {
        let status = project.status == .exported
            ? model.uiText("Zil sesi", "Ringtone")
            : model.uiText("Taslak", "Draft")
        return DurationText.formatted(project.selection.duration) + " · " + status
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                RingifyWaveformThumbnail(samples: project.waveformSamples)
                Spacer(minLength: 0)
                if project.library.favorite {
                    Image(systemName: "star.fill")
                        .font(.footnote)
                        .foregroundStyle(.yellow)
                        .accessibilityLabel(model.uiText("Favori", "Favorite"))
                }
            }
            Text(project.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                .multilineTextAlignment(.leading)
            Text(summary)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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
                    summarySection(project)
                    actionsSection(project)
                    informationSection(project)
                    organizationSection(project)
                    manageSection(project)
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

    private func summarySection(_ project: RingtoneProject) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                NativeSelectionWaveform(project: project, height: 64)
                Text(project.name)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text(project.status == .exported ? model.uiText("Hazır zil sesi", "Ready ringtone") : model.uiText("Taslak proje", "Draft project"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
        }
    }

    private func actionsSection(_ project: RingtoneProject) -> some View {
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
    }

    private func informationSection(_ project: RingtoneProject) -> some View {
        Section {
            NavigationLink { LibraryExportHistoryView(projectID: projectID) } label: {
                Label(model.uiText("Dışa aktarma geçmişi", "Export history"), systemImage: "clock.arrow.circlepath")
            }.frame(minHeight: 44)
            LabeledContent(model.uiText("Seçim", "Selection"), value: DurationText.formatted(project.selection.duration))
            LabeledContent(model.uiText("Kaynak", "Source"), value: project.sourceFilename)
            LabeledContent(model.uiText("Son düzenleme", "Last edited")) { Text(project.updatedAt, style: .date) }
        } header: {
            Text(model.uiText("Proje bilgileri", "Project information")).textCase(nil)
        }
    }

    private func organizationSection(_ project: RingtoneProject) -> some View {
        Section {
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
        } header: {
            Text(model.uiText("Düzen", "Organization")).textCase(nil)
        }
    }

    private func manageSection(_ project: RingtoneProject) -> some View {
        Section {
            Button(model.uiText("Çoğalt", "Duplicate"), systemImage: "plus.square.on.square") {
                Task { await model.duplicateProject(id: projectID) }
            }.frame(minHeight: 44).disabled(model.isLibraryWorking || model.isWorking)
            Button("library.rename", systemImage: "pencil") { projectToRename = project }.frame(minHeight: 44)
            Button("library.delete", systemImage: "trash", role: .destructive) { showDeleteConfirmation = true }
                .frame(minHeight: 44).disabled(isDeleting || model.isWorking)
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
