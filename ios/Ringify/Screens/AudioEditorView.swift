import Foundation
import RingifyCore
import SwiftUI

struct AudioEditorView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .caption2) private var rulerHeight: CGFloat = 16
    // The inline layout at accessibility sizes grows its round controls so the
    // scaled symbols stay inside them. The bottom bar keeps 56 and 44.
    @ScaledMetric(relativeTo: .title2) private var inlinePlayDiameter: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var inlineControlDiameter: CGFloat = 44
    @State private var selection = EditSelection(start: 0, end: 1)
    @State private var zoom = 1.0
    @GestureState private var pinchStartZoom: Double? = nil
    @State private var editingFeedback = false
    @State private var loadedProjectID: UUID?
    @State private var loopPlayback = false
    @State private var hasLoadedPlayback = false
    @State private var showMarkers = false
    @State private var showSuggestions = false
    @State private var history = EditorHistory(
        initial: EditorSnapshot(selection: EditSelection(start: 0, end: 1), effects: .neutral)
    )

    var body: some View {
        screen
            .onAppear { resetFromProject() }
            // A panel belongs to one project. Closing it here also stops a stale
            // flag from reopening the sheet for the next project.
            .onChange(of: model.currentProject?.id) { _, _ in resetFromProject(); closePanels() }
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

    private var screen: some View {
        Group {
            if let project = model.currentProject {
                studio(project)
            } else {
                emptyStudio
            }
        }
        .background(RingifyTheme.background)
        .navigationTitle(model.currentProject?.name ?? model.uiText("Ses Stüdyosu", "Audio Studio"))
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
        .sheet(isPresented: $showMarkers) { markersSheet }
        .sheet(isPresented: $showSuggestions) { suggestionsSheet }
    }

    @ViewBuilder private func studio(_ project: RingtoneProject) -> some View {
        if typeSize.isAccessibilitySize {
            // Keep transport reachable at large Dynamic Type; a fixed footer
            // must not consume the entire available editor viewport.
            ScrollView {
                VStack(spacing: 20) {
                    workspace(project)
                    inlinePlaybackControls(project)
                }
                .padding(RingifyTheme.horizontalPadding)
            }
        } else {
            ScrollView {
                workspace(project)
                    .padding(RingifyTheme.horizontalPadding)
            }
            .ringifyBottomBar {
                transportBar(project)
                continueButton(project)
            }
        }
    }

    // MARK: - Empty state

    @ViewBuilder private var emptyStudio: some View {
        if typeSize.isAccessibilitySize {
            ScrollView { emptyStudioContent }
        } else {
            emptyStudioContent
        }
    }

    private var emptyStudioContent: some View {
        ContentUnavailableView {
            Label(model.uiText("Stüdyon hazır", "Your studio is ready"), systemImage: "waveform")
                .accessibilityAddTraits(.isHeader)
        } description: {
            Text(model.uiText("Düzenlemek için bir ses ekle veya kayıtlı projeni aç.", "Add audio to edit, or open one of your saved projects."))
        } actions: {
            Button { router.push(.importSource) } label: {
                Label(model.uiText("Ses ekle", "Add audio"), systemImage: "plus")
            }
            .ringifyPrimaryAction()
            .accessibilityIdentifier("studio.import")
            Button { router.selectedTab = .library } label: {
                Label(model.uiText("Kütüphaneyi aç", "Open library"), systemImage: "folder")
            }
            .ringifySecondaryAction()
            .accessibilityIdentifier("studio.library")
        }
    }

    // MARK: - Workspace

    private func workspace(_ project: RingtoneProject) -> some View {
        VStack(spacing: 16) {
            waveformCard(project)
            if !isSelectionValid(project) {
                durationRuleNotice
            }
            zoomControl
            supportActions(project)
        }
    }

    // The scroller runs edge to edge inside the card so a handle at the very
    // start or end keeps its full 44 pt target. Everything else takes the margin.
    private func waveformCard(_ project: RingtoneProject) -> some View {
        VStack(spacing: 16) {
            waveformEditor(project)
            Divider()
                .padding(.horizontal, RingifyTheme.horizontalPadding)
            timeSummary
                .padding(.horizontal, RingifyTheme.horizontalPadding)
        }
        .padding(.vertical, RingifyTheme.horizontalPadding)
        .ringifyCard(padding: 0)
    }

    private var durationRuleNotice: some View {
        Label {
            Text("editor.durationRule")
        } icon: {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(RingifyTheme.warning)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeSummary: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        return layout {
            selectionMetric(model.uiText("Başlangıç", "Start"), seconds: selection.start)
            selectionMetric(model.uiText("Seçili bölüm", "Selection"), seconds: selection.duration, emphasized: true)
            selectionMetric(model.uiText("Bitiş", "End"), seconds: selection.end)
        }
    }

    private func selectionMetric(_ title: String, seconds: TimeInterval, emphasized: Bool = false) -> some View {
        VStack(alignment: typeSize.isAccessibilitySize ? .leading : .center, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(DurationText.formatted(seconds)).font(.headline.monospacedDigit())
                .foregroundStyle(emphasized ? RingifyTheme.accent : Color.primary)
        }
        .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .center)
        .frame(maxWidth: .infinity, alignment: typeSize.isAccessibilitySize ? .leading : .center)
        .accessibilityElement(children: .combine)
    }

    private var rulerIntervals: Int { typeSize.isAccessibilitySize ? 1 : (typeSize >= .xLarge ? 2 : 4) }

    private func waveformEditor(_ project: RingtoneProject) -> some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            GeometryReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: EditorWaveformMetrics.rulerSpacing) {
                        EditorTimelineRuler(duration: project.sourceDuration, inset: EditorWaveformMetrics.laneInset, intervals: rulerIntervals)
                            .frame(height: rulerHeight)
                        EditorWaveformSelectionView(
                            samples: project.waveformSamples,
                            duration: project.sourceDuration,
                            selection: $selection,
                            playhead: playhead,
                            inset: EditorWaveformMetrics.laneInset,
                            onEditingEnded: { commitSelection(for: project.id) }
                        )
                        .frame(height: EditorWaveformMetrics.laneHeight)
                    }
                    .frame(width: max(proxy.size.width, proxy.size.width * zoom))
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
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
            .frame(height: rulerHeight + EditorWaveformMetrics.rulerSpacing + EditorWaveformMetrics.laneHeight)
        }
        .id(project.id)
    }

    private var zoomControl: some View {
        HStack(spacing: 12) {
            Image(systemName: "minus.magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Slider(value: $zoom, in: StudioZoomRules.range)
                .frame(minHeight: 44)
                .accessibilityLabel("editor.zoom")
                .accessibilityIdentifier("studio.zoom")
            Image(systemName: "plus.magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Reset, markers, suggestions

    // ViewThatFits compares single-line widths, so the row only appears when all
    // three titles fit whole. Otherwise they stack and may wrap.
    private func supportActions(_ project: RingtoneProject) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                resetAction(project, fillsWidth: false).fixedSize()
                Spacer(minLength: 8)
                markersAction(project, fillsWidth: false).fixedSize()
                Spacer(minLength: 8)
                suggestionsAction(fillsWidth: false).fixedSize()
            }
            VStack(spacing: 8) {
                resetAction(project, fillsWidth: true)
                markersAction(project, fillsWidth: true)
                suggestionsAction(fillsWidth: true)
            }
        }
    }

    private func resetAction(_ project: RingtoneProject, fillsWidth: Bool) -> some View {
        supportButton(Text("editor.reset"), fillsWidth: fillsWidth) { resetSelection(project) }
            .accessibilityIdentifier("studio.reset")
    }

    private func markersAction(_ project: RingtoneProject, fillsWidth: Bool) -> some View {
        supportButton(Text(model.uiText("İşaretler · \(project.markers.count)", "Markers · \(project.markers.count)")),
            fillsWidth: fillsWidth) { showMarkers = true }
            .accessibilityIdentifier("studio.markers")
    }

    private func suggestionsAction(fillsWidth: Bool) -> some View {
        supportButton(Text(model.uiText("Öneriler", "Suggestions")), fillsWidth: fillsWidth) { showSuggestions = true }
            .accessibilityIdentifier("studio.suggestions")
    }

    private func supportButton(_ title: Text, fillsWidth: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            title
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
        }
        .ringifySecondaryAction()
    }

    private var markersSheet: some View {
        panelSheet(title: model.uiText("İşaretler", "Markers")) {
            if let project = model.currentProject {
                AudioProjectMarkersPanel(project: project, currentTime: { playhead }) { marker in
                    guard loadedProjectID == project.id, model.currentProject?.id == project.id else { return }
                    do {
                        selection = try AudioMarkers.selection(for: marker, sourceDuration: project.sourceDuration, preferredDuration: selection.duration)
                        commitSelection(for: project.id)
                    } catch { model.present(error) }
                }
            }
        }
    }

    private var suggestionsSheet: some View {
        panelSheet(title: model.uiText("Öneriler", "Suggestions")) {
            if let project = model.currentProject {
                AudioSegmentSuggestionsPanel(project: project, service: model.container.segments) { next in
                    guard loadedProjectID == project.id, model.currentProject?.id == project.id else { return }
                    selection = next
                    commitSelection(for: project.id)
                }
            }
        }
    }

    private func panelSheet<Panel: View>(title: String, @ViewBuilder panel: () -> Panel) -> some View {
        let content = panel()
        return NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.done") { closePanels() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }

    private func closePanels() {
        showMarkers = false
        showSuggestions = false
    }

    // MARK: - Transport

    // Three equal zones keep play on the screen's center line whatever the time
    // text needs. The periods above and here poll because playback is not observable.
    private func transportBar(_ project: RingtoneProject) -> some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            HStack(spacing: 0) {
                playbackTime
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                playButton(project, diameter: 56)
                    .frame(maxWidth: .infinity)
                HStack(spacing: 8) {
                    loopButton(diameter: 44)
                    stopButton(diameter: 44)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func inlinePlaybackControls(_ project: RingtoneProject) -> some View {
        VStack(spacing: 12) {
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                VStack(spacing: 12) {
                    playbackTime
                        .font(.headline.monospacedDigit())
                        .multilineTextAlignment(.center)
                    HStack(spacing: 24) {
                        loopButton(diameter: min(80, inlineControlDiameter))
                        playButton(project, diameter: min(96, inlinePlayDiameter))
                        stopButton(diameter: min(80, inlineControlDiameter))
                    }
                }
            }
            continueButton(project)
        }
    }

    private var playbackTime: some View {
        Text(DurationText.formatted(max(0, playhead - selection.start)) + " / " + DurationText.formatted(selection.duration))
            .accessibilityLabel(model.uiText("Oynatma süresi", "Playback time"))
            .accessibilityValue(DurationText.formatted(max(0, playhead - selection.start)) + " / " + DurationText.formatted(selection.duration))
    }

    private func playButton(_ project: RingtoneProject, diameter: CGFloat) -> some View {
        RingifyCircleButton(
            title: model.uiText(model.container.playback.isPlaying ? "Duraklat" : "Oynat", model.container.playback.isPlaying ? "Pause" : "Play"),
            systemImage: model.container.playback.isPlaying ? "pause.fill" : "play.fill",
            emphasis: .prominent,
            diameter: diameter
        ) { togglePlayback(project) }
        .accessibilityIdentifier("studio.playback")
        .disabled(!isSelectionValid(project))
    }

    private func loopButton(diameter: CGFloat) -> some View {
        RingifyCircleButton(
            title: model.localized("editor.loop"),
            systemImage: "repeat",
            diameter: diameter,
            isSelected: loopPlayback
        ) { loopPlayback.toggle() }
        .accessibilityIdentifier("studio.loop")
    }

    private func stopButton(diameter: CGFloat) -> some View {
        RingifyCircleButton(title: model.uiText("Durdur", "Stop"), systemImage: "stop.fill", diameter: diameter) { stopPlayback() }
            .accessibilityIdentifier("studio.stop")
    }

    private func continueButton(_ project: RingtoneProject) -> some View {
        RingifyPrimaryButton(title: "editor.continue", systemImage: "slider.horizontal.3", isDisabled: !isSelectionValid(project)) {
            if persistSelection() {
                router.push(.effects)
            }
        }
        .accessibilityIdentifier("studio.continue")
    }

    // MARK: - Editing logic

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

// MARK: - Waveform editor

private enum EditorWaveformMetrics {
    static let laneHeight: CGFloat = 200
    static let laneCornerRadius: CGFloat = 6
    static let rulerSpacing: CGFloat = 8
    static let frameEdge: CGFloat = 2.5
    static let handleWidth: CGFloat = 14
    static let handleCornerRadius: CGFloat = 6
    static let minimumTargetWidth: CGFloat = 44
    /// Card margin plus handle width, so a handle's outer edge lines up with the
    /// divider and the summary, and its 44 pt target stays inside the scroller.
    static let laneInset: CGFloat = RingifyTheme.horizontalPadding + handleWidth
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


private struct StudioSurface: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(14)
            .background(RingifyTheme.Studio.surface, in: RoundedRectangle(cornerRadius: RingifyTheme.Studio.cardRadius))
    }
}