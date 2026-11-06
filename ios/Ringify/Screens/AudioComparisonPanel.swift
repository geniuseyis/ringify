import RingifyCore
import SwiftUI

struct AudioComparisonPanel: View {
    let project: RingtoneProject
    let effects: AudioEffectSettings
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @StateObject private var comparison: AudioComparisonViewModel

    init(project: RingtoneProject, effects: AudioEffectSettings, container: AppContainer) {
        self.project = project; self.effects = effects
        _comparison = StateObject(wrappedValue: AudioComparisonViewModel(renderer: AudioComparisonRenderer(
            trim: container.trim, effects: container.effects, metadata: container.metadata, directories: container.directories),
            playback: container.playback))
    }

    private var input: AudioComparisonInput { AudioComparisonInput(project: project, effects: effects) }

    // One List row. Its buttons carry explicit styles, so a tap on the row
    // fires only the control under the finger.
    var body: some View {
        VStack(spacing: 14) {
            Group {
                if typeSize.isAccessibilitySize { modePicker.pickerStyle(.menu) }
                else { modePicker.pickerStyle(.segmented) }
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("effects.comparison")
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                VStack(spacing: 14) {
                    NativeSelectionWaveform(project: project, elapsed: comparison.elapsed)
                    if comparison.isRendering {
                        ProgressView("effects.rendering")
                        Button(model.uiText("İptal", "Cancel")) { comparison.clear() }
                            .buttonStyle(.borderless)
                            .frame(minHeight: 44)
                    } else {
                        Button { comparison.togglePlayback() } label: {
                            Label(comparison.playback.isPlaying ? LocalizedStringKey("common.pause") : LocalizedStringKey("effects.preview"),
                                  systemImage: comparison.playback.isPlaying ? "pause.fill" : "play.fill")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .disabled((try? ValidateSelectionUseCase()(project.selection, sourceDuration: project.sourceDuration)) == nil)
                        .accessibilityIdentifier("effects.listen")
                    }
                }
            }
            if let failure = comparison.failure {
                Text(failure).font(.footnote).foregroundStyle(RingifyTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("effects.comparison.error")
            }
        }
        .padding(.vertical, 6)
        .onAppear { comparison.updateInput(input) }
        .onChange(of: input) { _, next in comparison.updateInput(next) }
        .onDisappear { comparison.clear() }
    }

    private var modePicker: some View {
        Picker(model.uiText("Karşılaştır", "Compare"), selection: Binding(get: { comparison.mode }, set: { comparison.select($0) })) {
            Text(model.uiText("Orijinal", "Original")).tag(AudioComparisonMode.original)
            Text(model.uiText("İşlenmiş", "Processed")).tag(AudioComparisonMode.processed)
        }
    }
}
