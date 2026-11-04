import Foundation
import RingifyCore
import SwiftUI

struct AudioEditorView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .caption2) private var waveformInset: CGFloat = 24
    @State private var selection = EditSelection(start: 0, end: 1)
    @State private var zoom = 1.0
    @GestureState private var pinchStartZoom: Double? = nil
    @State private var editingFeedback = false
    @State private var loadedProjectID: UUID?
    @State private var loopPlayback = false
    @State private var hasLoadedPlayback = false
    @State private var history = EditorHistory(
        initial: EditorSnapshot(selection: EditSelection(start: 0, end: 1), effects: .neutral)
    )

    var body: some View {
        Group {
            if let project = model.currentProject {
                studio(project)
            } else {
                emptyStudio
            }
        }
        .background(RingifyTheme.Studio.background)
        .tint(RingifyTheme.Studio.accent)
        .ringifyStudioAppearance()
        .navigationTitle(model.uiText("Ses Stüdyosu", "Audio Studio"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.currentProject != nil {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("editor.undo", systemImage: "arrow.uturn.backward", action: undo)
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(!history.canUndo)
                        .accessibilityIdentifier("studio.undo")
                    Button("editor.redo", systemImage: "arrow.uturn.forward", action: redo)
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(!history.canRedo)
                        .accessibilityIdentifier("studio.redo")
                }
            }
        }
        .onAppear { resetFromProject() }
        .onChange(of: model.currentProject?.id) { _, _ in resetFromProject() }
        .onChange(of: selection) { _, _ in stopPlayback() }
        .onChange(of: loopPlayback) { _, _ in refreshLoopPlayback() }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            _ = persistSelection()
            if model.container.playback.isPlaying { model.container.playback.pause() }
        }
        .onDisappear { _ = persistSelection(); stopPlayback() }
        .sensoryFeedback(.selection, trigger: editingFeedback)
    }

    @ViewBuilder private func studio(_ project: RingtoneProject) -> some View {
        if typeSize.isAccessibilitySize {
            // Keep transport reachable at large Dynamic Type; a fixed footer
            // must not consume the entire available editor viewport.
            ScrollView {
                VStack(spacing: 20) {
                    workspace(project)
                    playbackControls(project)
                }
                .padding(RingifyTheme.horizontalPadding)
            }
        } else {
            ScrollView {
                workspace(project)
                    .padding(RingifyTheme.horizontalPadding)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                playbackControls(project)
                    .padding(.horizontal, RingifyTheme.horizontalPadding)
                    .padding(.vertical, 14)
                    .background(RingifyTheme.Studio.background)
                    .overlay(alignment: .top) { Divider() }
            }
        }
    }

    private var emptyStudio: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "waveform")
                    .font(.largeTitle)
                    .foregroundStyle(RingifyTheme.Studio.accent)
                    .padding(20)
                    .background(RingifyTheme.Studio.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityHidden(true)
                VStack(spacing: 10) {
                    Text(model.uiText("Stüdyon hazır", "Your studio is ready"))
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(model.uiText("Düzenlemek için bir ses ekle veya kayıtlı projeni aç.", "Add audio to edit, or open one of your saved projects."))
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                Button { router.push(.importSource) } label: {
                    Label(model.uiText("Ses ekle", "Add audio"), systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(RingifyTheme.Studio.action)
                .accessibilityIdentifier("studio.import")
                Button { router.selectedTab = .library } label: {
                    Label(model.uiText("Kütüphaneyi aç", "Open library"), systemImage: "folder")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("studio.library")
            }
            .padding(RingifyTheme.horizontalPadding)
            .padding(.top, 36)
        }
    }

    private func workspace(_ project: RingtoneProject) -> some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundStyle(RingifyTheme.Studio.accent)
                    .frame(width: 44, height: 44)
                    .background(RingifyTheme.Studio.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(project.name).font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(project.sourceFilename).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                    Text(DurationText.formatted(project.sourceDuration))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            waveformEditor(project)
            timeSummary
            editingTools(project)
            AudioProjectMarkersPanel(project: project, currentTime: { playhead }) { marker in
                do {
                    selection = try AudioMarkers.selection(for: marker, sourceDuration: project.sourceDuration, preferredDuration: selection.duration)
                    commitSelection()
                } catch { model.present(error) }
            }
            AudioSegmentSuggestionsPanel(project: project, service: model.container.segments) { next in
                selection = next
                commitSelection()
            }
            if !isSelectionValid(project) {
                Label("editor.durationRule", systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var timeSummary: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
        return layout {
            selectionMetric(model.uiText("Başlangıç", "Start"), seconds: selection.start)
            selectionMetric(model.uiText("Seçili bölüm", "Selection"), seconds: selection.duration, emphasized: true)
            selectionMetric(model.uiText("Bitiş", "End"), seconds: selection.end)
        }
        .modifier(StudioSurface())
    }

    private func selectionMetric(_ title: String, seconds: TimeInterval, emphasized: Bool = false) -> some View {
        VStack(alignment: typeSize.isAccessibilitySize ? .leading : .center, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(DurationText.formatted(seconds)).font(.headline.monospacedDigit())
                .foregroundStyle(emphasized ? RingifyTheme.Studio.accent : Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: typeSize.isAccessibilitySize ? .leading : .center)
        .accessibilityElement(children: .combine)
    }

    private var rulerIntervals: Int { typeSize.isAccessibilitySize ? 1 : (typeSize >= .xLarge ? 2 : 4) }

    private func waveformEditor(_ project: RingtoneProject) -> some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            GeometryReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        EditorTimelineRuler(duration: project.sourceDuration, inset: waveformInset, intervals: rulerIntervals)
                            .frame(height: 30)
                        EditorWaveformSelectionView(
                            samples: project.waveformSamples,
                            duration: project.sourceDuration,
                            selection: $selection,
                            playhead: playhead,
                            inset: waveformInset,
                            intervals: rulerIntervals,
                            onEditingEnded: { commitSelection(for: project.id) }
                        )
                        .frame(height: 200)
                    }
                    .frame(width: max(proxy.size.width, proxy.size.width * zoom))
                }
                .simultaneousGesture(
                    MagnifyGesture()
                        .updating($pinchStartZoom) { _, origin, _ in
                            // GestureState also resets when the system cancels
                            // a gesture, rather than only on normal completion.
                            if origin == nil { origin = zoom }
                        }
                        .onChanged { value in
                            zoom = StudioZoomRules.proposed(start: pinchStartZoom ?? zoom,
                                magnification: Double(value.magnification))
                        }
                        .onEnded { value in
                            if let origin = pinchStartZoom {
                                zoom = StudioZoomRules.proposed(start: origin,
                                    magnification: Double(value.magnification))
                            }
                        }
                )
            }
            .frame(height: 230)
        }
        .padding(.vertical, 14)
        .background(RingifyTheme.Studio.canvas, in: RoundedRectangle(cornerRadius: RingifyTheme.Studio.cardRadius))
        .overlay { RoundedRectangle(cornerRadius: RingifyTheme.Studio.cardRadius).strokeBorder(RingifyTheme.Studio.canvasBorder) }
        .id(project.id)
    }

    private func playbackControls(_ project: RingtoneProject) -> some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            VStack(spacing: 12) {
                Text(DurationText.formatted(max(0, playhead - selection.start)) + " / " + DurationText.formatted(selection.duration))
                    .font(.headline.monospacedDigit())
                    .accessibilityLabel(model.uiText("Oynatma süresi", "Playback time"))
                    .accessibilityValue(DurationText.formatted(max(0, playhead - selection.start)) + " / " + DurationText.formatted(selection.duration))
                HStack(spacing: 24) {
                    Toggle(isOn: $loopPlayback) {
                        Label("editor.loop", systemImage: "repeat")
                    }
                    .toggleStyle(.button)
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("studio.loop")
                    Button { togglePlayback(project) } label: {
                        Image(systemName: model.container.playback.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2.weight(.semibold))
                            .frame(width: 60, height: 60)
                            .foregroundStyle(RingifyTheme.Studio.surface)
                            .background(Color.primary, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(model.uiText(model.container.playback.isPlaying ? "Duraklat" : "Oynat", model.container.playback.isPlaying ? "Pause" : "Play"))
                    .accessibilityIdentifier("studio.playback")
                    .disabled(!isSelectionValid(project))
                    Button { stopPlayback() } label: {
                        Image(systemName: "stop.fill")
                            .font(.body)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(model.uiText("Durdur", "Stop"))
                    .accessibilityIdentifier("studio.stop")
                }
                Button {
                    if persistSelection() {
                        router.push(.effects)
                    }
                } label: {
                    Label("editor.continue", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(RingifyTheme.Studio.action)
                .disabled(!isSelectionValid(project))
                .accessibilityIdentifier("studio.continue")
            }
        }
    }

    private func editingTools(_ project: RingtoneProject) -> some View {
        VStack(spacing: 8) {
            HStack {
                Label(model.uiText("Kes", "Trim"), systemImage: "scissors").font(.subheadline.weight(.semibold))
                Spacer()
                Button("editor.reset", systemImage: "arrow.counterclockwise") { resetSelection(project) }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("studio.reset")
            }
            HStack(spacing: 12) {
                Image(systemName: "minus.magnifyingglass").accessibilityHidden(true)
                Slider(value: $zoom, in: StudioZoomRules.range)
                    .frame(minHeight: 44)
                    .accessibilityLabel("editor.zoom")
                    .accessibilityIdentifier("studio.zoom")
                Image(systemName: "plus.magnifyingglass").accessibilityHidden(true)
            }
        }
        .modifier(StudioSurface())
    }

    private var playhead: TimeInterval {
        guard hasLoadedPlayback else { return selection.start }
        return min(selection.end, max(selection.start, model.container.playback.currentTime))
    }

    private func isSelectionValid(_ project: RingtoneProject) -> Bool {
        if case .success = RingtoneRules().validate(selection: selection, sourceDuration: project.sourceDuration) { return true }
        return false
    }

    private func togglePlayback(_ project: RingtoneProject) {
        do {
            if model.container.playback.isPlaying {
                model.container.playback.pause()
            } else {
                try model.container.playback.load(url: project.sourceURL)
                try model.container.playback.play(selection: selection, loop: loopPlayback)
                hasLoadedPlayback = true
            }
        } catch { model.present(error) }
    }

    private func stopPlayback() {
        model.container.playback.stop()
        hasLoadedPlayback = false
    }

    private func refreshLoopPlayback() {
        guard hasLoadedPlayback, model.container.playback.isPlaying else { return }
        do {
            // Apply the selected loop state to the existing player immediately;
            // the service retains its current position inside this selection.
            try model.container.playback.play(selection: selection, loop: loopPlayback)
        } catch {
            stopPlayback()
            model.present(error)
        }
    }

    private func undo() {
        guard let projectID = loadedProjectID, model.currentProject?.id == projectID else { return }
        if let snapshot = history.undo() {
            selection = snapshot.selection
            _ = persistSelection()
            editingFeedback.toggle()
        }
    }

    private func redo() {
        guard let projectID = loadedProjectID, model.currentProject?.id == projectID else { return }
        if let snapshot = history.redo() {
            selection = snapshot.selection
            _ = persistSelection()
            editingFeedback.toggle()
        }
    }

    private func resetSelection(_ project: RingtoneProject) {
        let reset = RingtoneRules().clampedSelection(
            start: 0,
            end: min(project.sourceDuration, RingtoneRules.maximumDuration),
            sourceDuration: project.sourceDuration
        )
        guard loadedProjectID == project.id,
            StudioSelectionPersistence.commit(reset, expectedProjectID: project.id, model: model) else { return }
        if selection != reset { editingFeedback.toggle() }
        history.commit(EditorSnapshot(selection: reset, effects: project.effects))
        selection = reset
    }

    private func resetFromProject() {
        hasLoadedPlayback = false
        zoom = StudioZoomRules.range.lowerBound
        loadedProjectID = model.currentProject?.id
        guard let project = model.currentProject else { return }
        selection = project.selection
        history.reset(to: EditorSnapshot(selection: project.selection, effects: project.effects))
    }

    private func persistSelection() -> Bool {
        guard let projectID = loadedProjectID else { return false }
        return StudioSelectionPersistence.commit(selection, expectedProjectID: projectID, model: model)
    }

    private func commitSelection(for projectID: UUID) {
        guard loadedProjectID == projectID, persistSelection() else { return }
        let effects = model.currentProject?.effects ?? .neutral
        if history.current.selection != selection { editingFeedback.toggle() }
        history.commit(EditorSnapshot(selection: selection, effects: effects))
    }
}

private struct StudioSurface: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(14)
            .background(RingifyTheme.Studio.surface, in: RoundedRectangle(cornerRadius: RingifyTheme.Studio.cardRadius))
    }
}

private struct EditorTimelineRuler: View {
    let duration: TimeInterval
    let inset: CGFloat
    let intervals: Int

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width - inset * 2)
            ForEach(0...intervals, id: \.self) { tick in
                let fraction = Double(tick) / Double(intervals)
                Text(DurationText.formatted(max(0, duration.isFinite ? duration : 0) * fraction))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(RingifyTheme.Studio.canvasSecondary)
                    .fixedSize()
                    .position(x: inset + width * CGFloat(fraction), y: 12)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct EditorWaveformSelectionView: View {
    let samples: [Float]
    let duration: TimeInterval
    @Binding var selection: EditSelection
    let playhead: TimeInterval
    let inset: CGFloat
    let intervals: Int
    let onEditingEnded: () -> Void
    @State private var dragStartSelection: TimeInterval?
    @State private var dragEndSelection: TimeInterval?

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width - inset * 2)
            let safeDuration = duration.isFinite && duration > 0 ? duration : 1
            let start = min(safeDuration, max(0, selection.start.isFinite ? selection.start : 0))
            let end = min(safeDuration, max(start, selection.end.isFinite ? selection.end : start))
            let startX = CGFloat(start / safeDuration) * width
            let endX = CGFloat(end / safeDuration) * width
            ZStack(alignment: .leading) {
                ForEach(0...intervals, id: \.self) { tick in
                    Rectangle().fill(Color(uiColor: .separator).opacity(0.35))
                        .frame(width: 1)
                        .offset(x: inset + width * CGFloat(tick) / CGFloat(intervals))
                        .allowsHitTesting(false)
                }
                WaveformView(
                    samples: samples,
                    tint: RingifyTheme.Studio.wave,
                    dimmedTint: RingifyTheme.Studio.outsideWave,
                    selection: (start / safeDuration)...(end / safeDuration)
                )
                .frame(width: width)
                .offset(x: inset)
                Rectangle()
                    .fill(RingifyTheme.Studio.wave.opacity(0.10))
                    .overlay(Rectangle().stroke(RingifyTheme.Studio.wave, lineWidth: 1))
                    .frame(width: max(2, endX - startX))
                    .offset(x: inset + startX)
                    .allowsHitTesting(false)
                Rectangle().fill(RingifyTheme.Studio.canvasText)
                    .frame(width: 2)
                    .offset(x: inset + CGFloat(min(safeDuration, max(0, playhead.isFinite ? playhead : start)) / safeDuration) * width)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                handle
                    .position(x: inset + startX, y: proxy.size.height * (endX - startX < 44 ? 0.25 : 0.5))
                    .gesture(startDrag(width: width))
                    .focusable(interactions: .edit)
                    .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
                        handleKey(press, boundary: .start)
                    }
                    .accessibilityElement()
                    .accessibilityIdentifier("studio.trim.start")
                    .accessibilityLabel("editor.trimStart")
                    .accessibilityValue(DurationText.formatted(selection.start))
                    .accessibilityAdjustableAction { direction in
                        adjust(.start, by: direction == .increment ? 0.1 : -0.1)
                    }
                handle
                    .position(x: inset + endX, y: proxy.size.height * (endX - startX < 44 ? 0.75 : 0.5))
                    .gesture(endDrag(width: width))
                    .focusable(interactions: .edit)
                    .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
                        handleKey(press, boundary: .end)
                    }
                    .accessibilityElement()
                    .accessibilityIdentifier("studio.trim.end")
                    .accessibilityLabel("editor.trimEnd")
                    .accessibilityValue(DurationText.formatted(selection.end))
                    .accessibilityAdjustableAction { direction in
                        adjust(.end, by: direction == .increment ? 0.1 : -0.1)
                    }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("editor.waveform")
        .accessibilityIdentifier("studio.waveform")
        .accessibilityValue("\(DurationText.formatted(selection.start)) – \(DurationText.formatted(selection.end))")
    }

    private func handleKey(_ press: KeyPress, boundary: StudioTrimRules.Boundary) -> KeyPress.Result {
        let backward = press.key == .leftArrow || press.key == .downArrow
        let step = press.modifiers.contains(.shift) ? 1.0 : 0.1
        adjust(boundary, by: backward ? -step : step)
        return .handled
    }

    private func adjust(_ boundary: StudioTrimRules.Boundary, by delta: Double) {
        let next = StudioTrimRules.adjustedSelection(selection, boundary: boundary,
            delta: delta, sourceDuration: duration)
        guard next != selection else { return }
        selection = next
        onEditingEnded()
    }

    private var handle: some View {
        Capsule()
            .fill(RingifyTheme.Studio.canvas)
            .overlay(Capsule().strokeBorder(RingifyTheme.Studio.wave, lineWidth: 2))
            .frame(width: 12, height: 44)
            .frame(width: 44, height: 86)
            .contentShape(Rectangle())
    }

    private func startDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartSelection == nil { dragStartSelection = selection.start }
                let proposed = (dragStartSelection ?? selection.start)
                    + Double(value.translation.width / width) * duration
                selection = StudioTrimRules.adjustedSelection(selection, boundary: .start,
                    delta: proposed - selection.start, sourceDuration: duration)
            }
            .onEnded { _ in
                dragStartSelection = nil
                onEditingEnded()
            }
    }

    private func endDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragEndSelection == nil { dragEndSelection = selection.end }
                let proposed = (dragEndSelection ?? selection.end)
                    + Double(value.translation.width / width) * duration
                selection = StudioTrimRules.adjustedSelection(selection, boundary: .end,
                    delta: proposed - selection.end, sourceDuration: duration)
            }
            .onEnded { _ in
                dragEndSelection = nil
                onEditingEnded()
            }
    }
}
