import RingifyCore
import SwiftUI

private struct PresetEditorRequest: Identifiable {
    let id = UUID()
    let preset: UserAudioPreset?
}

struct PersonalAudioPresetsPanel: View {
    let project: RingtoneProject
    @Binding var effects: AudioEffectSettings
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var router: AppRouter
    @State private var editor: PresetEditorRequest?
    @State private var pendingDelete: UserAudioPreset?
    @State private var showDelete = false
    @State private var loadFailed = false
    @State private var applying = false
    @State private var applyTask: Task<Void, Never>?
    @State private var generation = UUID()

    // The DisclosureGroup is the single root, so the lifecycle modifiers below
    // attach once; its children are direct List rows with native separators.
    var body: some View {
        DisclosureGroup(model.uiText("Kişisel Ses Ayarları", "Personal Audio Presets")) {
            Button(model.uiText("Mevcut ayarları kaydet", "Save current settings"), systemImage: "plus.circle") {
                editor = PresetEditorRequest(preset: nil)
            }.frame(minHeight: 44).disabled(model.isPresetWorking || applying)
            if loadFailed {
                Button(model.uiText("Tekrar Dene", "Try Again")) { Task { loadFailed = !(await model.reloadAudioPresets()) } }
                    .frame(minHeight: 44)
            }
            ForEach(model.audioPresets) { preset in
                presetRow(preset)
            }
            if applying || model.isPresetWorking { ProgressView("common.processing") }
        }
        .task { loadFailed = !(await model.reloadAudioPresets()) }
        .onDisappear { generation = UUID(); applyTask?.cancel(); applying = false }
        .onChange(of: project.id) { _, _ in generation = UUID(); applyTask?.cancel(); applying = false }
        .onChange(of: project.selection) { _, _ in generation = UUID(); applyTask?.cancel(); applying = false }
        .onChange(of: effects) { _, _ in
            if applying { generation = UUID(); applyTask?.cancel(); applying = false }
        }
        .sheet(item: $editor) { request in
            PersonalPresetNameEditor(preset: request.preset, effects: effects)
        }
        .confirmationDialog(model.uiText("Kişisel ayar silinsin mi?", "Delete personal preset?"), isPresented: $showDelete, titleVisibility: .visible) {
            Button(model.uiText("Sil", "Delete"), role: .destructive) {
                guard let preset = pendingDelete else { return }
                Task { if await model.deleteAudioPreset(id: preset.id) { pendingDelete = nil } }
            }
            Button("common.cancel", role: .cancel) { pendingDelete = nil }
        }
    }

    // Two controls in one row: each carries its own explicit style.
    private func presetRow(_ preset: UserAudioPreset) -> some View {
        HStack {
            Button { apply(preset) } label: {
                Text(preset.name)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            Menu {
                Button(model.uiText("Yeniden Adlandır", "Rename"), systemImage: "pencil") { editor = PresetEditorRequest(preset: preset) }
                Button(model.uiText("Sil", "Delete"), systemImage: "trash", role: .destructive) { pendingDelete = preset; showDelete = true }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .accessibilityLabel(model.uiText("\(preset.name) seçenekleri", "Options for \(preset.name)"))
        }.disabled(model.isPresetWorking || applying)
    }

    private func apply(_ preset: UserAudioPreset) {
        let token = UUID()
        generation = token; applying = true
        applyTask?.cancel()
        applyTask = Task {
            defer { if generation == token { applying = false } }
            do {
                let metadata = try await model.container.metadata.metadata(for: project.sourceURL)
                try Task.checkCancellation()
                guard generation == token, model.currentProject?.id == project.id,
                      model.currentProject?.sourceURL == project.sourceURL,
                      model.currentProject?.selection == project.selection else { return }
                let next = try preset.applying(selectionDuration: project.selection.duration, sampleRate: metadata.sampleRate)
                guard ProAccessPolicy.canChangeNormalization(current: effects.normalize, next: next.normalize, hasVerifiedPro: purchases.isPro),
                      ProAccessPolicy.canChangeStudioEffects(current: effects.studio, next: next.studio, hasVerifiedPro: purchases.isPro) else {
                    router.push(.premium); return
                }
                effects = next
            } catch is CancellationError {
            } catch { if generation == token { model.present(error) } }
        }
    }
}

private struct PersonalPresetNameEditor: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let preset: UserAudioPreset?
    let effects: AudioEffectSettings
    @State private var name: String
    @State private var saving = false
    @State private var failed = false
    init(preset: UserAudioPreset?, effects: AudioEffectSettings) {
        self.preset = preset; self.effects = effects
        _name = State(initialValue: preset?.name ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField(model.uiText("Ayar adı", "Preset name"), text: $name).disabled(saving)
                if failed { Text(model.uiText("Kaydedilemedi. Adı kontrol edip tekrar dene.", "Could not save. Check the name and retry.")).foregroundStyle(RingifyTheme.danger) }
            }
            .navigationTitle(model.uiText("Kişisel Ses Ayarı", "Personal Audio Preset"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        saving = true; failed = false
                        Task {
                            if await model.saveAudioPreset(id: preset?.id, name: name, effects: preset?.effects ?? effects) { dismiss() }
                            else { failed = true }
                            saving = false
                        }
                    }.disabled(saving || (try? ProjectCollection.validatedName(name)) == nil)
                }
            }
        }.interactiveDismissDisabled(saving).presentationDetents([.medium, .large])
    }
}
