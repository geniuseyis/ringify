import Foundation
import RingifyCore
import SwiftUI

struct VoiceRecorderView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var savedURL: URL?
    @State private var isPreparing = false
    @State private var showDiscardConfirmation = false
    @State private var committed = false
    @State private var savedDuration: TimeInterval = 0
    @State private var discardAndLeave = false
    @State private var requestingPermission = false
    @State private var markers: [AudioMarker] = []

    private var recorder: any VoiceRecordingService { model.container.recorder }

    var body: some View {
        // The service exposes live properties rather than ObservableObject.
        // Poll the whole presentation so transport/toolbar match actual state.
        TimelineView(.periodic(from: .now, by: 0.08)) { _ in
            ScrollView {
                VStack(spacing: 26) {
                    VStack(spacing: 22) {
                        HStack(spacing: 8) {
                            Circle().fill(recorder.isRecording ? Color.red : Color.secondary).frame(width: 6, height: 6)
                                .accessibilityHidden(true)
                            Text(statusKey).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        microphoneMeter
                        Text(DurationText.formatted(savedURL == nil ? recorder.currentTime : savedDuration))
                            .font(typeSize.isAccessibilitySize ? .title2.monospacedDigit() : .largeTitle.monospacedDigit())
                            .accessibilityLabel(model.uiText("Kayıt süresi", "Recording duration"))
                            .accessibilityValue(DurationText.formatted(savedURL == nil ? recorder.currentTime : savedDuration))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(RingifyTheme.Studio.surface, in: RoundedRectangle(cornerRadius: RingifyTheme.Studio.cardRadius))
                    controls
                        .disabled(isPreparing || requestingPermission)
                    if savedURL == nil && (recorder.isRecording || recorder.isPaused) {
                        Button(model.uiText("İşaret Ekle", "Add Marker"), systemImage: "bookmark") {
                            let time = recorder.currentTime
                            guard time.isFinite, time >= 0, markers.count < AudioMarkers.maximumCount else { return }
                            markers.append(AudioMarker(time: time, label: model.uiText("İşaret \(markers.count + 1)", "Marker \(markers.count + 1)")))
                        }
                        .frame(minHeight: 44).disabled(isPreparing || markers.count >= AudioMarkers.maximumCount)
                        .sensoryFeedback(.selection, trigger: markers.count)
                    }
                    if !markers.isEmpty {
                        DisclosureGroup(model.uiText("\(markers.count) işaret", "\(markers.count) markers")) {
                            ForEach(markers) { marker in
                                HStack {
                                    Text(marker.label)
                                    Spacer()
                                    Text(DurationText.formatted(marker.time)).monospacedDigit()
                                    Button(role: .destructive) { markers.removeAll { $0.id == marker.id } } label: {
                                        Image(systemName: "trash").frame(width: 44, height: 44)
                                    }.accessibilityLabel(model.uiText("\(marker.label) işaretini sil", "Delete \(marker.label)"))
                                }.disabled(isPreparing)
                            }
                        }.modifier(NativeContentCard())
                    }
                    if requestingPermission {
                        ProgressView(model.uiText("Mikrofon izni bekleniyor…", "Waiting for microphone permission…"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if savedURL != nil {
                        Button(action: useRecording) {
                            HStack(spacing: 10) {
                                if isPreparing { ProgressView().tint(.white) }
                                Text("recorder.use").font(.headline)
                            }
                            .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RingifyTheme.Studio.action)
                        .disabled(isPreparing)
                        .accessibilityIdentifier("recorder.use")
                    }
                }
                .padding(RingifyTheme.horizontalPadding)
            }
            .background(RingifyTheme.Studio.background)
            .ringifyStudioAppearance()
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
        }
        .tint(RingifyTheme.Studio.accent)
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

    private var microphoneMeter: some View {
        let rawPower = recorder.isRecording ? Double(recorder.averagePower) : -80
        let power = rawPower.isFinite ? rawPower : -80
        let normalized = recorder.isRecording ? max(0, min(1, (power + 60) / 60)) : 0
        return VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(RingifyTheme.Studio.accent.opacity(0.18), lineWidth: 1)
                    .frame(width: typeSize.isAccessibilitySize ? 130 : 180, height: typeSize.isAccessibilitySize ? 130 : 180)
                    .scaleEffect(reduceMotion ? 1 : 0.95 + normalized * 0.05)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: normalized)
                Image(systemName: savedURL != nil ? "checkmark" : recorder.isPaused ? "pause.fill" : "mic")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(savedURL != nil ? RingifyTheme.success : RingifyTheme.Studio.accent)
                    .frame(width: 88, height: 88)
                    .background(RingifyTheme.Studio.accent.opacity(0.10), in: Circle())
            }
            .accessibilityHidden(true)
            VStack(spacing: 8) {
                ProgressView(value: normalized)
                    .tint(RingifyTheme.Studio.accent)
                    .accessibilityLabel("recorder.level")
                    .accessibilityValue(recorder.isRecording ? String(format: "%.1f dBFS", power) : model.uiText("Ölçüm yok", "No measurement"))
                HStack {
                    Text("recorder.level")
                    Spacer()
                    Text(recorder.isRecording ? String(format: "%.1f dBFS", power) : "—")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            }
        }
    }

    private var statusKey: LocalizedStringKey {
        if savedURL != nil { return "recorder.ready" }
        if recorder.isRecording { return "recorder.recording" }
        if recorder.isPaused { return "recorder.paused" }
        return "recorder.idle"
    }

    @ViewBuilder private var controls: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 18))
            : AnyLayout(HStackLayout(spacing: 22))
        layout {
            if savedURL == nil {
                if recorder.isRecording {
                    Button { model.container.recorder.pause() } label: {
                        controlLabel(model.uiText("Duraklat", "Pause"), icon: "pause.fill", color: RingifyTheme.Studio.action)
                    }
                    .accessibilityIdentifier("recorder.pause")
                    Button(action: finishRecording) {
                        controlLabel(model.uiText("Kaydı bitir", "Finish recording"), icon: "stop.fill", color: .red)
                    }
                    .accessibilityIdentifier("recorder.stop")
                } else if recorder.isPaused {
                    Button {
                        do { try model.container.recorder.resume() } catch { model.present(error) }
                    } label: {
                        controlLabel(model.uiText("Devam et", "Resume"), icon: "play.fill", color: RingifyTheme.Studio.action)
                    }
                    .accessibilityIdentifier("recorder.resume")
                    Button(action: finishRecording) {
                        controlLabel(model.uiText("Kaydı bitir", "Finish recording"), icon: "stop.fill", color: .red)
                    }
                    .accessibilityIdentifier("recorder.stop")
                } else {
                    Button(action: beginRecording) {
                        controlLabel(model.uiText("Kaydı başlat", "Start recording"), icon: "mic.fill", color: .red)
                    }
                    .accessibilityIdentifier("recorder.start")
                }
            } else if let savedURL {
                Button {
                    do {
                        try model.container.playback.load(url: savedURL)
                        if model.container.playback.isPlaying {
                            model.container.playback.pause()
                        } else {
                            try model.container.playback.play(selection: nil, loop: false)
                        }
                    } catch { model.present(error) }
                } label: {
                    controlLabel(model.uiText(model.container.playback.isPlaying ? "Duraklat" : "Kaydı dinle", model.container.playback.isPlaying ? "Pause" : "Listen back"), icon: model.container.playback.isPlaying ? "pause.fill" : "play.fill", color: RingifyTheme.Studio.action)
                }
                .accessibilityIdentifier("recorder.preview")
            }
        }
        .buttonStyle(.plain)
    }

    private func controlLabel(_ title: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Circle().fill(color).frame(width: 64, height: 64)
                .overlay(Image(systemName: icon).font(.system(size: 23, weight: .semibold)).foregroundStyle(.white))
                .accessibilityHidden(true)
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 64, minHeight: 88)
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
