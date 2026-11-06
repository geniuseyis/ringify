import RingifyCore
import SwiftUI

struct LibraryBatchOrganizationView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var failed = false
    let projectIDs: Set<UUID>

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    action(model.uiText("Favorilere ekle", "Add favorites"), icon: "star", change: .favorite(true))
                    action(model.uiText("Favorilerden çıkar", "Remove favorites"), icon: "star.slash", change: .favorite(false))
                } header: {
                    Text(model.uiText("\(projectIDs.count) proje seçili", "\(projectIDs.count) projects selected")).textCase(nil)
                }
                if !model.collections.isEmpty {
                    Section {
                        ForEach(model.collections) { group in action(group.name, icon: "folder.badge.plus", change: .addToCollection(group.id)) }
                    } header: {
                        Text(model.uiText("Koleksiyona ekle", "Add to collection")).textCase(nil)
                    }
                    Section {
                        ForEach(model.collections) { group in action(group.name, icon: "folder.badge.minus", change: .removeFromCollection(group.id)) }
                    } header: {
                        Text(model.uiText("Koleksiyondan çıkar", "Remove from collection")).textCase(nil)
                    }
                }
                if model.isLibraryWorking { ProgressView("common.processing") }
                if failed {
                    Text(model.uiText("Değişiklik kaydedilemedi. Seçimin korundu; tekrar deneyebilirsin.",
                        "The change could not be saved. Your selection is kept; try again."))
                        .foregroundStyle(RingifyTheme.danger)
                }
            }
            .navigationTitle(model.uiText("Toplu Düzenle", "Batch Organization"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("common.done") { dismiss() }.disabled(model.isLibraryWorking) } }
            .onChange(of: purchases.isPro) { _, active in if !active { dismiss() } }
        }
        .interactiveDismissDisabled(model.isLibraryWorking)
    }

    private func action(_ title: String, icon: String, change: LibraryMetadataChange) -> some View {
        Button(title, systemImage: icon) {
            failed = false
            Task {
                if await model.updateProjectLibrary(projectIDs: projectIDs, change: change) { dismiss() }
                else { failed = true }
            }
        }
        .frame(minHeight: 44)
        .disabled(model.isLibraryWorking || projectIDs.isEmpty || !purchases.isPro)
    }
}
