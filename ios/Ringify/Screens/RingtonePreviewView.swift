import Foundation
import RingifyCore
import SwiftUI

struct RingtonePreviewView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @State private var previewURL: URL?
    @State private var isRendering = false
    @State private var renderGeneration = UUID()
    @State private var renderAttempt = 0
    @State private var hasAttemptedRender = false
    @State private var hasPlayedPreview = false
    @State private var renderedSourceOffset: TimeInterval = 0

    var body: some View {
        Group {
            if let project = model.currentProject {
                ScrollView {
                    VStack(spacing: 22) {
                        VStack(spacing: 12) {
                            Image(systemName: "bell.badge")
                                .font(.largeTitle)
                                .foregroundStyle(RingifyTheme.Studio.accent)
                                .frame(width: 80, height: 80)
                                .background(RingifyTheme.Studio.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 22))
                                .accessibilityHidden(true)
                            Text(project.name).font(.title2.bold())
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                            Text(project.sourceFilename).font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                            VStack(spacing: 16) {
                                NativeSelectionWaveform(project: project, elapsed: hasPlayedPreview ? renderedSourceOffset + model.container.playback.currentTime : 0)
                                Text(DurationText.formatted(hasPlayedPreview ? min(project.selection.duration, model.container.playback.currentTime) : 0)
                                     + " / " + DurationText.formatted(project.selection.duration))
                                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                                Button {
                                    togglePlayback()
                                    if model.container.playback.isPlaying { hasPlayedPreview = true }
                                } label: {
                                    ZStack {
                                        Circle().fill(Color.primary).frame(width: 72, height: 72)
                                        Image(systemName: model.container.playback.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.title2.bold()).foregroundStyle(RingifyTheme.Studio.surface)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isRendering || previewURL == nil)
                                .opacity(previewURL == nil ? 0.42 : 1)
                                .accessibilityLabel(model.container.playback.isPlaying ? "common.pause" : "common.play")
                                .accessibilityIdentifier("preview.playback")
                            }
                            .modifier(NativeContentCard())
                        }
                        if isRendering || !hasAttemptedRender {
                            ProgressView("effects.rendering")
                        } else if previewURL == nil {
                            VStack(spacing: 12) {
                                Label(model.uiText("Ön izleme hazırlanamadı.", "The preview could not be prepared."), systemImage: "exclamationmark.circle")
                                    .foregroundStyle(.secondary)
                                Button(model.uiText("Tekrar Dene", "Try Again")) { renderAttempt += 1 }
                                    .frame(minHeight: 44)
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("preview.retry")
                            }
                            .modifier(NativeContentCard())
                        }
                        VStack(spacing: 14) {
                            NativeMetadataRow(title: model.uiText("Süre", "Duration"), value: DurationText.formatted(project.selection.duration))
                            Divider()
                            NativeMetadataRow(title: model.uiText("Çıktı biçimi", "Output format"), value: "M4A · AAC")
                            Divider()
                            NativeMetadataRow(title: model.uiText("Ses seviyesi", "Volume"), value: (project.effects.volume * 100).formatted(.number.precision(.fractionLength(0))) + "%")
                            if project.effects.normalize {
                                Divider()
                                NativeMetadataRow(title: model.uiText("Normalize", "Normalize"), value: model.uiText("Açık", "On"))
                            }
                        }
                        .modifier(NativeContentCard())
                        NativePrimaryAction(title: "preview.export", icon: "square.and.arrow.up", disabled: previewURL == nil || isRendering) { router.push(.export) }
                            .accessibilityIdentifier("preview.export")
                        Button("preview.reedit", systemImage: "scissors") { router.push(.editor) }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("preview.reedit")
                    }
                    .padding(RingifyTheme.horizontalPadding)
                }
                .task(id: "\(project.id.uuidString):\(project.updatedAt.timeIntervalSince1970):\(renderAttempt)") {
                    hasAttemptedRender = true
                    await renderPreview(project)
                }
            } else {
                RingifyEmptyState(icon: "music.note", title: "preview.empty.title", message: "preview.empty.message",
                    actionTitle: "home.create", action: { router.push(.importSource) })
            }
        }
        .background(RingifyTheme.Studio.background)
        .tint(RingifyTheme.Studio.accent)
        .ringifyStudioAppearance()
        .navigationTitle("preview.title")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: previewURL) { _, _ in hasPlayedPreview = false }
        .onDisappear { cleanup() }
    }

    private func renderPreview(_ project: RingtoneProject) async {
        cleanup()
        let generation = UUID()
        renderGeneration = generation
        isRendering = true
        defer { if renderGeneration == generation { isRendering = false } }
        let trimmed = model.container.directories.temporaryURL(extension: "caf")
        let processed = model.container.directories.temporaryURL(extension: "m4a")
        defer { try? FileManager.default.removeItem(at: trimmed) }
        do {
            var sourceOffset: TimeInterval = 0
            if project.effects.loopCrossfadeDuration > 0 {
                let metadata = try await model.container.metadata.metadata(for: project.sourceURL)
                sourceOffset = try LoopCrossfadeRules.sourceOffset(seconds: project.effects.loopCrossfadeDuration,
                    sampleRate: metadata.sampleRate, duration: project.selection.duration)
            }
            _ = try await model.container.trim.trimPCM(sourceURL: project.sourceURL, selection: project.selection, destinationURL: trimmed)
            _ = try await model.container.effects.process(
                sourceURL: trimmed,
                destinationURL: processed,
                settings: project.effects,
                expectedDuration: project.selection.duration
            )
            try Task.checkCancellation()
            guard renderGeneration == generation, model.currentProject?.id == project.id else {
                try? FileManager.default.removeItem(at: processed)
                return
            }
            previewURL = processed
            renderedSourceOffset = sourceOffset
        } catch is CancellationError {
            try? FileManager.default.removeItem(at: processed)
        } catch {
            try? FileManager.default.removeItem(at: processed)
            if renderGeneration == generation { model.present(error) }
        }
    }

    private func togglePlayback() {
        guard let previewURL else { return }
        do {
            if model.container.playback.isPlaying {
                model.container.playback.pause()
            } else {
                try model.container.playback.load(url: previewURL)
                try model.container.playback.play(selection: nil, loop: false)
            }
        } catch { model.present(error) }
    }

    private func cleanup() {
        renderGeneration = UUID()
        isRendering = false
        model.container.playback.stop()
        if let previewURL { try? FileManager.default.removeItem(at: previewURL) }
        previewURL = nil
        renderedSourceOffset = 0
    }
}
