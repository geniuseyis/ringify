import Foundation
import RingifyCore
import SwiftUI

struct VoiceRecorderView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize: CGFloat = 64
    @State private var savedURL: URL?
    @State private var isPreparing = false
    @State private var showDiscardConfirmation = false
    @State private var committed = false
    @State private var savedDuration: TimeInterval = 0
    @State private var discardAndLeave = false
    @State private var requestingPermission = false
    @State private var markers: [AudioMarker] = []
    /// Measured input levels, oldest first, normalized to 0...1. Only real readings.
    @State private var levels: [Double] = []

    private static let maximumLevels = 120

    private var recorder: any VoiceRecordingService { model.container.recorder }

    var body: some View {
        // The service exposes live properties rather than ObservableObject.
        // Poll the whole presentation so transport/toolbar match actual state.
        TimelineView(.periodic(from: .now, by: 0.08)) { context in
            ScrollView {
                VStack(spacing: 24) {
                    statusRow
                    timer
                    levelHistory
                    if !markers.isEmpty {
                        markerList
                    }
                    if requestingPermission {
                        ProgressView(model.uiText("Mikrofon izni bekleniyor…", "Waiting for microphone permission…"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(RingifyTheme.horizontalPadding)
            }
            .background(RingifyTheme.background)
            .ringifyBottomBar { bottomBar }
            .navigationTitle("recorder.title")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if recorder.isRecording || recorder.isPaused || savedURL != nil {
                            discardAndLeave = true
                            showDiscardConfirmation = true
                        } else { dismiss() }
                    } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(model.uiText("Geri", "Back"))
                    .accessibilityIdentifier("recorder.back")
                    .disabled(isPreparing || requestingPermission)
                }
                if recorder.isRecording || recorder.isPaused || savedURL != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            discardAndLeave = false
                            showDiscardConfirmation = true
                        } label: {
                            Image(systemName: "trash").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("recorder.discard")
                        .accessibilityIdentifier("recorder.discard")
                        .disabled(isPreparing || requestingPermission)
                    }
                }
            }
            .onChange(of: recorder.isRecording || recorder.isPaused) { _, active in
                if active { requestingPermission = false }
            }
            .onChange(of: context.date) { _, _ in appendLevel() }
            // Idle again after a discard or a used recording: the next recording
            // starts from an empty history.
            .onChange(of: isIdle) { _, idle in
                if idle { levels = [] }
            }
        }
        .onAppear {
            // An imported recording has already been copied into project storage
            // and its scratch URL consumed. Returning must not offer that URL.
            if committed {
                savedURL = nil
                savedDuration = 0
                committed = false
                markers = []
            }
        }
        .onChange(of: model.issue) { _, issue in
            if issue != nil { requestingPermission = false }
        }
        .confirmationDialog("recorder.discard.title", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
            Button("recorder.discard", role: .destructive) {
                model.container.playback.stop()
                model.container.recorder.discard()
                if let savedURL { try? FileManager.default.removeItem(at: savedURL) }
                savedURL = nil
                savedDuration = 0
                markers = []
                if discardAndLeave { dismiss() }
            }
            Button("common.cancel", role: .cancel) { discardAndLeave = false }
        }
        .onDisappear {
            model.container.playback.stop()
            if !committed {
                model.container.recorder.discard()
                if let savedURL { try? FileManager.default.removeItem(at: savedURL) }
            }
        }
    }

    // MARK: - Content

    private var isActive: Bool { savedURL == nil && (recorder.isRecording || recorder.isPaused) }
    private var isIdle: Bool { savedURL == nil && !recorder.isRecording && !recorder.isPaused }

    private var statusRow: some View {
        HStack(spacing: 8) {
            if recorder.isRecording {
                Circle().fill(RingifyTheme.record).frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
            Text(statusKey).font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    private var timer: some View {
        Text(DurationText.formatted(savedURL == nil ? recorder.currentTime : savedDuration))
            .font(.system(size: timerSize, weight: .light).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(model.uiText("Kayıt süresi", "Recording duration"))
            .accessibilityValue(DurationText.formatted(savedURL == nil ? recorder.currentTime : savedDuration))
    }

    /// Current input power in dBFS, or nil when nothing is being measured.
    private var currentPower: Double? {
        guard recorder.isRecording else { return nil }
        let rawPower = Double(recorder.averagePower)
        return rawPower.isFinite ? rawPower : -80
    }

    private var levelHistory: some View {
        RecorderLevelHistory(levels: levels)
            .frame(height: 88)
            .frame(maxWidth: .infinity)
            .ringifyCard()
            .accessibilityElement()
            .accessibilityLabel("recorder.level")
            .accessibilityValue(currentPower.map { String(format: "%.1f dBFS", $0) } ?? model.uiText("Ölçüm yok", "No measurement"))
    }

    private var markerList: some View {
        DisclosureGroup(model.uiText("\(markers.count) işaret", "\(markers.count) markers")) {
            ForEach(markers) { marker in
                HStack {
                    Text(marker.label)
                    Spacer()
                    Text(DurationText.formatted(marker.time)).monospacedDigit()
                    Button(role: .destructive) { markers.removeAll { $0.id == marker.id } } label: {
                        Image(systemName: "trash").frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(model.uiText("\(marker.label) işaretini sil", "Delete \(marker.label)"))
                }.disabled(isPreparing)
            }
        }
        .ringifyCard()
    }

    private var statusKey: LocalizedStringKey {
        if savedURL != nil { return "recorder.ready" }
        if recorder.isRecording { return "recorder.recording" }
        if recorder.isPaused { return "recorder.paused" }
        return "recorder.idle"
    }

    private func appendLevel() {
        guard let power = currentPower else { return }
        levels.append(max(0, min(1, (power + 60) / 60)))
        if levels.count > Self.maximumLevels {
            levels.removeFirst(levels.count - Self.maximumLevels)
        }
    }

    // MARK: - Controls

    @ViewBuilder private var bottomBar: some View {
        if let savedURL {
            previewButton(savedURL)
                .disabled(isPreparing || requestingPermission)
            RingifyPrimaryButton(title: "recorder.use", isLoading: isPreparing) { useRecording() }
                .accessibilityIdentifier("recorder.use")
        } else {
            transport
                .disabled(isPreparing || requestingPermission)
        }
    }

    /// Three equal zones so the record button stays centered.
    private var transport: some View {
        HStack(spacing: 0) {
            pauseResumeButton
                .frame(maxWidth: .infinity)
            RecorderRecordButton(
                isActive: isActive,
                title: isActive
                    ? model.uiText("Kaydı bitir", "Finish recording")
                    : model.uiText("Kaydı başlat", "Start recording"),
                action: { if isActive { finishRecording() } else { beginRecording() } }
            )
            .accessibilityIdentifier(isActive ? "recorder.stop" : "recorder.start")
            markerButton
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var pauseResumeButton: some View {
        if savedURL == nil && recorder.isRecording {
            RingifyCircleButton(title: model.uiText("Duraklat", "Pause"), systemImage: "pause.fill") {
                model.container.recorder.pause()
            }
            .accessibilityIdentifier("recorder.pause")
        } else if savedURL == nil && recorder.isPaused {
            RingifyCircleButton(title: model.uiText("Devam et", "Resume"), systemImage: "play.fill") {
                do { try model.container.recorder.resume() } catch { model.present(error) }
            }
            .accessibilityIdentifier("recorder.resume")
        } else {
            Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
        }
    }

    @ViewBuilder private var markerButton: some View {
        if isActive {
            RingifyCircleButton(title: model.uiText("İşaret Ekle", "Add Marker"), systemImage: "bookmark") {
                let time = recorder.currentTime
                guard time.isFinite, time >= 0, markers.count < AudioMarkers.maximumCount else { return }
                markers.append(AudioMarker(time: time, label: model.uiText("İşaret \(markers.count + 1)", "Marker \(markers.count + 1)")))
            }
            .disabled(isPreparing || markers.count >= AudioMarkers.maximumCount)
            .sensoryFeedback(.selection, trigger: markers.count)
        } else {
            Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
        }
    }

    private func previewButton(_ savedURL: URL) -> some View {
        let isPlaying = model.container.playback.isPlaying
        return RingifyCircleButton(
            title: model.uiText(isPlaying ? "Duraklat" : "Kaydı dinle", isPlaying ? "Pause" : "Listen back"),
            systemImage: isPlaying ? "pause.fill" : "play.fill",
            emphasis: .prominent,
            diameter: 72
        ) {
            do {
                try model.container.playback.load(url: savedURL)
                if model.container.playback.isPlaying {
                    model.container.playback.pause()
                } else {
                    try model.container.playback.play(selection: nil, loop: false)
                }
            } catch { model.present(error) }
        }
        .accessibilityIdentifier("recorder.preview")
    }

    private func finishRecording() {
        savedDuration = recorder.currentTime
        savedURL = model.container.recorder.stop()
    }

    private func beginRecording() {
        guard !requestingPermission, !isPreparing else { return }
        requestingPermission = true
        startRecording()
    }

    private func startRecording() {
        Task {
            guard await recorder.requestPermission() else {
                model.issue = .permissionDenied
                return
            }
            do {
                try model.container.directories.prepare()
                let url = model.container.directories.uniqueURL(
                    in: model.container.directories.recordings,
                    filename: "Recording",
                    extension: "m4a"
                )
                try recorder.startRecording(to: url)
            } catch { model.present(error) }
        }
    }

    private func useRecording() {
        guard let savedURL else { return }
        isPreparing = true
        Task {
            defer { isPreparing = false }
            if await model.prepareMedia(from: savedURL, kind: .microphoneRecording, markers: markers) {
                committed = true
                try? FileManager.default.removeItem(at: savedURL)
                router.push(.editor)
            }
        }
    }
}

/// Voice Memos style record control: an outer ring with a red disc that becomes
/// a rounded square while recording.
private struct RecorderRecordButton: View {
    let isActive: Bool
    let title: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(Color.primary, lineWidth: 3)
                RoundedRectangle(cornerRadius: isActive ? 6 : 30, style: .circular)
                    .fill(RingifyTheme.record)
                    .frame(width: isActive ? 28 : 60, height: isActive ? 28 : 60)
            }
            .frame(width: 72, height: 72)
            .contentShape(Circle())
            .opacity(isEnabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}