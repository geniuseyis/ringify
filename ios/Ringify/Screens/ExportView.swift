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
        Group {
            if let project = model.currentProject {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        NativeProjectIdentity(project: project)
                        if model.isWorking {
                            progressCard
                        } else if let exported = model.exportedRingtone {
                            successCard(exported)
                        } else {
                            exportForm(project)
                        }
                    }
                    .padding(RingifyTheme.horizontalPadding)
                }
            } else {
                RingifyEmptyState(icon: "square.and.arrow.up", title: "preview.empty.title", message: "preview.empty.message",
                    actionTitle: "home.create", action: { router.push(.importSource) })
            }
        }
        .background(RingifyTheme.Studio.background)
        .tint(RingifyTheme.Studio.accent)
        .ringifyStudioAppearance()
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

    private var isFilenameValid: Bool {
        if case .success = RingtoneRules().validate(filename: filename) { return true }
        return false
    }

    private func exportForm(_ project: RingtoneProject) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text("export.filename").font(.headline).accessibilityAddTraits(.isHeader)
                TextField("export.filename.placeholder", text: $filename)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 44)
                    .accessibilityLabel("export.filename")
                    .accessibilityIdentifier("export.filename")
                if !isFilenameValid {
                    Text(model.uiText("Geçerli bir dosya adı gir (en fazla 80 karakter).", "Enter a valid filename (up to 80 characters)."))
                        .font(.footnote).foregroundStyle(.red)
                }
            }
            .modifier(NativeContentCard())
            VStack(spacing: 16) {
                Picker(model.uiText("Çıktı kalitesi", "Output quality"), selection: Binding(get: { profile }, set: { next in
                    if next.requiresPro && !purchases.isPro { router.push(.premium) }
                    else { profile = next }
                })) {
                    Text("M4A · 192 kbps").tag(AudioOutputProfile.aacStandard)
                    Text("M4A · 256 kbps · Pro").tag(AudioOutputProfile.aacHigh)
                    Text("WAV · 16-bit").tag(AudioOutputProfile.wav16)
                    Text("WAV · 24-bit · Pro").tag(AudioOutputProfile.wav24)
                }
                .pickerStyle(.menu).frame(minHeight: 44)
                .accessibilityIdentifier("export.profile")
                Divider()
                NativeMetadataRow(title: model.uiText("Seçili süre", "Selection duration"), value: DurationText.formatted(project.selection.duration))
            }
            .modifier(NativeContentCard())
            NativePrimaryAction(title: "export.action", icon: "square.and.arrow.up", disabled: !isFilenameValid, action: startExport)
                .accessibilityIdentifier("export.create")
        }
    }

    private var progressCard: some View {
        VStack(spacing: 16) {
            // The service reports stages, not a continuously measured encoder
            // percentage. Keep the indicator indeterminate instead of inventing one.
            ProgressView().controlSize(.large)
            Text(progressTitle).font(.headline).multilineTextAlignment(.center)
            if canCancel {
                Button("export.cancel", role: .destructive) { exportTask?.cancel() }
                    .frame(minHeight: 44)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("export.cancel")
            }
        }
        .frame(maxWidth: .infinity)
        .modifier(NativeContentCard())
    }

    private func successCard(_ result: ExportedRingtone) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle).foregroundStyle(RingifyTheme.success)
                .accessibilityHidden(true)
            Text("export.success.title").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text(result.url.lastPathComponent).font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 14) {
                NativeMetadataRow(title: model.uiText("Süre", "Duration"), value: DurationText.formatted(result.duration))
                Divider()
                NativeMetadataRow(title: model.uiText("Dosya boyutu", "File size"), value: ByteCountFormatter.string(fromByteCount: result.byteCount, countStyle: .file))
            }
            .modifier(NativeContentCard())
            ShareLink(item: result.url) {
                Label("export.share", systemImage: "square.and.arrow.up")
                    .multilineTextAlignment(.center)
                    .modifier(NativePrimaryActionLabel())
            }
            .buttonStyle(NativePressButtonStyle())
            .accessibilityIdentifier("export.share")
            Button(model.uiText("Başka Biçimde Dışa Aktar", "Export Another Format"), systemImage: "arrow.triangle.2.circlepath") {
                model.prepareAnotherExport()
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.bordered)
            Button("export.guide", systemImage: "iphone.radiowaves.left.and.right") {
                router.push(.guide)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.bordered)
            .accessibilityIdentifier("export.guide")
        }
        .frame(maxWidth: .infinity)
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
