import Foundation
import RingifyCore
import SwiftUI

struct ExportView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var filename = ""
    @State private var profile: AudioOutputProfile = .aacStandard
    @State private var exportTask: Task<Void, Never>?

    var body: some View {
        // ZStack, not Group: each state has its own Form so that only states with an
        // action get the bottom bar. Group would pass onDisappear to whichever Form is
        // showing, and leaving the filename form would cancel the export it just started.
        ZStack {
            if let project = model.currentProject {
                stateContent(project)
            } else {
                RingifyEmptyState(icon: "square.and.arrow.up", title: "preview.empty.title", message: "preview.empty.message",
                    actionTitle: "home.create", action: { router.push(.importSource) })
                    .background(RingifyTheme.background)
            }
        }
        .navigationTitle("export.title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if filename.isEmpty { filename = model.currentProject?.name ?? "Ringify" }
        }
        .onChange(of: model.currentProject?.id) { _, _ in
            exportTask?.cancel()
            filename = model.currentProject?.name ?? ""
            profile = .aacStandard
        }
        .onDisappear { exportTask?.cancel() }
    }

    @ViewBuilder private func stateContent(_ project: RingtoneProject) -> some View {
        if model.isWorking {
            Form { progressSection }
        } else if let exported = model.exportedRingtone {
            Form { successSections(exported) }
                .ringifyBottomBar { shareAction(exported) }
        } else {
            Form { formSections(project) }
                .ringifyBottomBar {
                    RingifyPrimaryButton(title: "export.action", systemImage: "square.and.arrow.up",
                                         isDisabled: !isFilenameValid) { startExport() }
                        .accessibilityIdentifier("export.create")
                }
        }
    }

    private var isFilenameValid: Bool {
        if case .success = RingtoneRules().validate(filename: filename) { return true }
        return false
    }

    @ViewBuilder private func formSections(_ project: RingtoneProject) -> some View {
        Section {
            TextField("export.filename.placeholder", text: $filename)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .frame(minHeight: 44)
                .accessibilityLabel("export.filename")
                .accessibilityIdentifier("export.filename")
            if !isFilenameValid {
                Text(model.uiText("Geçerli bir dosya adı gir (en fazla 80 karakter).", "Enter a valid filename (up to 80 characters)."))
                    .font(.footnote)
                    .foregroundStyle(RingifyTheme.danger)
            }
        } header: {
            Text("export.filename")
                .accessibilityAddTraits(.isHeader)
                .textCase(nil)
        }
        Section {
            profilePicker
            NativeMetadataRow(title: model.uiText("Seçili süre", "Selection duration"), value: DurationText.formatted(project.selection.duration))
        }
    }

    private var profilePicker: some View {
        Picker(model.uiText("Çıktı kalitesi", "Output quality"), selection: Binding(get: { profile }, set: { next in
            if next.requiresPro && !purchases.isPro { router.push(.premium) }
            else { profile = next }
        })) {
            Text("M4A · 192 kbps").tag(AudioOutputProfile.aacStandard)
            Text("M4A · 256 kbps · Pro").tag(AudioOutputProfile.aacHigh)
            Text("WAV · 16-bit").tag(AudioOutputProfile.wav16)
            Text("WAV · 24-bit · Pro").tag(AudioOutputProfile.wav24)
        }
        .pickerStyle(.menu)
        .frame(minHeight: 44)
        .accessibilityIdentifier("export.profile")
    }

    private var progressSection: some View {
        Section {
            VStack(spacing: 16) {
                // The service reports stages, not a continuously measured encoder
                // percentage. Keep the indicator indeterminate instead of inventing one.
                ProgressView().controlSize(.large)
                Text(progressTitle).font(.headline).multilineTextAlignment(.center)
                if canCancel {
                    Button(role: .destructive) { exportTask?.cancel() } label: {
                        Text("export.cancel")
                            .multilineTextAlignment(.center)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("export.cancel")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder private func successSections(_ result: ExportedRingtone) -> some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(RingifyTheme.success)
                    .accessibilityHidden(true)
                Text("export.success.title")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(result.url.lastPathComponent)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        Section {
            NativeMetadataRow(title: model.uiText("Süre", "Duration"), value: DurationText.formatted(result.duration))
            NativeMetadataRow(title: model.uiText("Dosya boyutu", "File size"), value: ByteCountFormatter.string(fromByteCount: result.byteCount, countStyle: .file))
        }
        Section {
            Button { model.prepareAnotherExport() } label: {
                RingifyRow(Text(model.uiText("Başka Biçimde Dışa Aktar", "Export Another Format")), systemImage: "arrow.triangle.2.circlepath")
            }
            Button { router.push(.guide) } label: {
                RingifyRow(Text("export.guide"), systemImage: "iphone.radiowaves.left.and.right", showsChevron: true)
            }
            .accessibilityIdentifier("export.guide")
        }
    }

    private func shareAction(_ result: ExportedRingtone) -> some View {
        ShareLink(item: result.url) {
            Label("export.share", systemImage: "square.and.arrow.up")
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .ringifyPrimaryAction()
        .accessibilityIdentifier("export.share")
    }

    private var canCancel: Bool {
        if case .completed = model.exportProgress { return false }
        return true
    }

    private var progressTitle: LocalizedStringKey {
        switch model.exportProgress {
        case .preparing: "export.preparing"
        case .processing(_): "export.processing"
        case .verifying: "export.verifying"
        case .completed(_): LocalizedStringKey(model.uiText("Kaydediliyor…", "Saving…"))
        case nil: "common.processing"
        }
    }

    private func startExport() {
        exportTask = Task { await model.exportCurrentProject(filename: filename, profile: profile) }
    }
}
