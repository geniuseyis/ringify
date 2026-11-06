import RingifyCore
import SwiftUI

struct LibraryCollectionFilterPicker: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selection: LibraryCollectionFilter

    var body: some View {
        Picker(model.uiText("Koleksiyon", "Collection"), selection: $selection) {
            Text(model.uiText("Tüm koleksiyonlar", "All collections")).tag(LibraryCollectionFilter.all)
            Text(model.uiText("Koleksiyonsuz", "Unfiled")).tag(LibraryCollectionFilter.unfiled)
            ForEach(model.collections) { collection in
                Text(collection.name).tag(LibraryCollectionFilter.collection(collection.id))
            }
        }
        .pickerStyle(.menu).frame(minHeight: 44)
        .accessibilityIdentifier("library.collection.filter")
    }
}

struct LibraryOrganizationView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Binding var preferences: LibraryPreferences

    var body: some View {
        Form {
            Section {
                Picker(model.uiText("Durum", "Status"), selection: $preferences.status) {
                    ForEach(LibraryStatusFilter.allCases) { Text($0.title(model)).tag($0) }
                }
                Toggle(model.uiText("Yalnız favoriler", "Favorites only"), isOn: $preferences.favoritesOnly)
                LibraryCollectionFilterPicker(selection: $preferences.collection)
            } header: {
                Text(model.uiText("Göster", "Show")).textCase(nil)
            }
            Section {
                Picker(model.uiText("Sırala", "Sort"), selection: $preferences.sort) {
                    ForEach(LibrarySortOrder.allCases) { Text($0.title(model)).tag($0) }
                }.pickerStyle(.inline)
            } header: {
                Text(model.uiText("Sıralama", "Sort order")).textCase(nil)
            }
            Section {
                NavigationLink { LibraryExportHistoryView() } label: {
                    SettingsNavigationRow(title: model.uiText("Dışa aktarma geçmişi", "Export history"), icon: "clock.arrow.circlepath")
                }
                NavigationLink { LibraryCollectionsView() } label: {
                    SettingsNavigationRow(title: model.uiText("Koleksiyonları yönet", "Manage collections"), icon: "folder",
                        value: model.collections.count.formatted())
                }
                NavigationLink { SettingsStorageView() } label: {
                    SettingsNavigationRow(title: model.localized("settings.storage"), icon: "externaldrive",
                        value: model.uiText("\(model.projects.count) proje", "\(model.projects.count) projects"))
                }
            }
        }
        .navigationTitle(model.uiText("Kütüphane Düzeni", "Library Organization"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { dismiss() } } }
    }
}

struct LibraryCollectionAssignmentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    let projectID: UUID

    private var project: RingtoneProject? { model.projects.first { $0.id == projectID } }

    var body: some View {
        NavigationStack {
            List {
                if let project {
                    Section {
                        ForEach(model.collections) { collection in
                            let included = project.library.collectionIDs.contains(collection.id)
                            Toggle(collection.name, isOn: Binding(get: { included }, set: { selected in
                                Task {
                                    await model.updateProjectLibrary(projectIDs: [projectID],
                                        change: selected ? .addToCollection(collection.id) : .removeFromCollection(collection.id))
                                }
                            }))
                            .frame(minHeight: 44)
                            .disabled(model.isLibraryWorking || (!included && !purchases.isPro))
                        }
                        if model.collections.isEmpty {
                            Text(model.uiText("Henüz koleksiyon yok.", "No collections yet.")).foregroundStyle(.secondary)
                        }
                        if !project.library.collectionIDs.isEmpty {
                            Button(model.uiText("Tüm koleksiyonlardan çıkar", "Remove from all collections"), role: .destructive) {
                                Task { await model.updateProjectLibrary(projectIDs: [projectID], change: .clearCollections) }
                            }.frame(minHeight: 44).disabled(model.isLibraryWorking)
                        }
                    } header: {
                        Text(verbatim: project.name).textCase(nil)
                    }
                    if purchases.isPro {
                        Button(model.uiText("Yeni Koleksiyon", "New Collection"), systemImage: "folder.badge.plus") { showEditor = true }
                            .frame(minHeight: 44).disabled(model.isLibraryWorking)
                    } else {
                        NavigationLink { PremiumView() } label: {
                            Label(model.uiText("Koleksiyon araçları · Pro", "Collection tools · Pro"), systemImage: "crown")
                                .frame(minHeight: 44)
                        }
                    }
                } else {
                    ContentUnavailableView(model.uiText("Proje bulunamadı", "Project not found"), systemImage: "folder.badge.questionmark")
                }
            }
            .navigationTitle(model.uiText("Koleksiyonlar", "Collections"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { dismiss() } } }
            .sheet(isPresented: $showEditor) { LibraryCollectionEditor() }
        }
        .interactiveDismissDisabled(model.isLibraryWorking)
    }
}

private struct CollectionEditorRequest: Identifiable {
    let id = UUID()
    let collection: ProjectCollection?
}

struct LibraryCollectionsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var editor: CollectionEditorRequest?
    @State private var pendingDelete: ProjectCollection?
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            if model.collections.isEmpty {
                ContentUnavailableView(model.uiText("Henüz koleksiyon yok", "No collections yet"), systemImage: "folder")
            }
            ForEach(model.collections) { collection in
                HStack {
                    Label(collection.name, systemImage: "folder")
                    Spacer()
                    Text(model.projects.filter { $0.library.collectionIDs.contains(collection.id) }.count.formatted())
                        .foregroundStyle(.secondary)
                    Menu {
                        Button(model.uiText("Yeniden Adlandır", "Rename"), systemImage: "pencil") {
                            editor = CollectionEditorRequest(collection: collection)
                        }.disabled(!purchases.isPro)
                        Button(model.uiText("Koleksiyonu Sil", "Delete Collection"), systemImage: "trash", role: .destructive) {
                            pendingDelete = collection
                            showDeleteConfirmation = true
                        }
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                    .accessibilityLabel(model.uiText("\(collection.name) seçenekleri", "Options for \(collection.name)"))
                    .disabled(model.isLibraryWorking)
                }
            }
            if purchases.isPro {
                Button(model.uiText("Yeni Koleksiyon", "New Collection"), systemImage: "folder.badge.plus") {
                    editor = CollectionEditorRequest(collection: nil)
                }.frame(minHeight: 44).disabled(model.isLibraryWorking)
            } else {
                NavigationLink { PremiumView() } label: {
                    Label(model.uiText("Koleksiyon araçları · Pro", "Collection tools · Pro"), systemImage: "crown")
                }.frame(minHeight: 44)
            }
        }
        .navigationTitle(model.uiText("Koleksiyonlar", "Collections"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { LibraryCollectionEditor(collection: $0.collection) }
        .confirmationDialog(model.uiText("Koleksiyon silinsin mi?", "Delete collection?"),
            isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(model.uiText("Koleksiyonu Sil", "Delete Collection"), role: .destructive) {
                guard let pendingDelete else { return }
                Task { await model.deleteCollection(id: pendingDelete.id); self.pendingDelete = nil }
            }
            Button("common.cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(model.uiText("Projeler ve ses dosyaları korunur.", "Projects and audio files are kept."))
        }
    }
}

private struct LibraryCollectionEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let collection: ProjectCollection?
    @State private var name: String
    @State private var isSaving = false
    @State private var failed = false

    init(collection: ProjectCollection? = nil) {
        self.collection = collection
        _name = State(initialValue: collection?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(model.uiText("Koleksiyon adı", "Collection name"), text: $name)
                    .textInputAutocapitalization(.words).disabled(isSaving)
                if failed {
                    Text(model.uiText("Kaydedilemedi. Adı kontrol edip tekrar deneyin.", "Could not save. Check the name and try again."))
                        .foregroundStyle(RingifyTheme.danger)
                }
            }
            .navigationTitle(collection == nil ? model.uiText("Yeni Koleksiyon", "New Collection") : model.uiText("Koleksiyonu Düzenle", "Edit Collection"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        isSaving = true
                        failed = false
                        Task {
                            if await model.saveCollection(id: collection?.id, name: name) { dismiss() }
                            else { failed = true }
                            isSaving = false
                        }
                    }
                    .disabled(isSaving || (try? ProjectCollection.validatedName(name)) == nil)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .presentationDetents([.medium, .large])
    }
}
