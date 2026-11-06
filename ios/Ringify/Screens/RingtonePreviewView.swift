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
                previewList(project)
                    .task(id: "\(project.id.uuidString):\(project.updatedAt.timeIntervalSince1970):\(renderAttempt)") {
                        hasAttemptedRender = true
                        await renderPreview(project)
                    }
                    .onChange(of: previewURL) { _, _ in hasPlayedPreview = false }
                    .onDisappear { cleanup() }
            } else {
                RingifyEmptyState(icon: "music.note", title: "preview.empty.title", message: "preview.empty.message",
                    actionTitle: "home.create", action: { router.push(.importSource) })
                    .background(RingifyTheme.background)
            }
        }
        .navigationTitle("preview.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func previewList(_ project: RingtoneProject) -> some View {
        List {
            playbackSection(project)
            renderStatusSection
            detailsSection(project)
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.push(.editor) } label: {
                    Label("preview.reedit", systemImage: "scissors")
                }
                .accessibilityIdentifier("preview.reedit")
            }
        }
        .ringifyBottomBar {
            RingifyPrimaryButton(title: "preview.export", systemImage: "square.and.arrow.up",
                                 isDisabled: previewURL == nil || isRendering) { router.push(.export) }
                .accessibilityIdentifier("preview.export")
        }
    }

    private func playbackSection(_ project: RingtoneProject) -> some View {
        Section {
            VStack(spacing: 16) {
                Text(verbatim: project.name)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                // Playback isn't observable, so the timeline also keeps the button's
                // symbol and label current when the audio ends by itself.
                TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                    playbackControls(project)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func playbackControls(_ project: RingtoneProject) -> some View {
        let isPlaying = model.container.playback.isPlaying
        return VStack(spacing: 16) {
            NativeSelectionWaveform(project: project, elapsed: hasPlayedPreview ? renderedSourceOffset + model.container.playback.currentTime : 0)
            Text(DurationText.formatted(hasPlayedPreview ? min(project.selection.duration, model.container.playback.currentTime) : 0)
                 + " / " + DurationText.formatted(project.selection.duration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            RingifyCircleButton(title: model.localized(isPlaying ? "common.pause" : "common.play"),
                                systemImage: isPlaying ? "pause.fill" : "play.fill",
                                emphasis: .prominent,
                                diameter: 64) {
                togglePlayback()
                if model.container.playback.isPlaying { hasPlayedPreview = true }
            }
            .disabled(isRendering || previewURL == nil)
            .accessibilityIdentifier("preview.playback")
        }
    }

    @ViewBuilder private var renderStatusSection: some View {
        if isRendering || !hasAttemptedRender {
            Section {
                // List reuses this row's cell, and a reused spinner can stop drawing.
                // A new identity per render keeps it visible after returning to this screen.
                ProgressView("effects.rendering")
                    .frame(maxWidth: .infinity)
                    .id(renderGeneration)
            }
        } else if previewURL == nil {
            Section {
                Label(model.uiText("Ön izleme hazırlanamadı.", "The preview could not be prepared."), systemImage: "exclamationmark.circle")
                    .foregroundStyle(.secondary)
                Button { renderAttempt += 1 } label: {
                    Text(model.uiText("Tekrar Dene", "Try Again"))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("preview.retry")
            }
        }
    }

    private func detailsSection(_ project: RingtoneProject) -> some View {
        Section {
            NativeMetadataRow(title: model.uiText("Süre", "Duration"), value: DurationText.formatted(project.selection.duration))
            NativeMetadataRow(title: model.uiText("Çıktı biçimi", "Output format"), value: "M4A · AAC")
            NativeMetadataRow(title: model.uiText("Ses seviyesi", "Volume"), value: (project.effects.volume * 100).formatted(.number.precision(.fractionLength(0))) + "%")
            if project.effects.normalize {
                NativeMetadataRow(title: model.uiText("Normalize", "Normalize"), value: model.uiText("Açık", "On"))
            }
            NativeMetadataRow(title: model.uiText("Kaynak", "Source"), value: project.sourceFilename)
        }
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
