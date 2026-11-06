import Foundation
import RingifyCore
import SwiftUI

struct AudioEffectsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var effects = AudioEffectSettings.neutral
    var body: some View {
        Group {
            if let project = model.currentProject {
                effectsList(project: project)
            } else {
                RingifyEmptyState(icon: "slider.horizontal.3", title: "editor.empty.title", message: "editor.empty.message",
                    actionTitle: "home.create", action: { router.push(.importSource) })
            }
        }
        .navigationTitle("effects.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.currentProject != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("effects.reset", systemImage: "arrow.counterclockwise") {
                        effects = .neutral
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("effects.reset")
                }
            }
        }
        .onAppear { effects = model.currentProject?.effects ?? .neutral }
        .onChange(of: model.currentProject?.id) { _, _ in
            effects = model.currentProject?.effects ?? .neutral
        }
    }

    private func effectsList(project: RingtoneProject) -> some View {
        List {
            Section {
                AudioComparisonPanel(project: project, effects: effects, container: model.container)
            }
            if isSelectionValid(project) {
                audioSection(project: project)
                processingSection
            } else {
                Section {
                    Label("editor.durationRule", systemImage: "exclamationmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(RingifyTheme.danger)
                }
            }
            Section {
                AdvancedEffectsPanel(project: project, effects: $effects)
            }
            Section {
                PersonalAudioPresetsPanel(project: project, effects: $effects)
            }
            Section {
                analysisPanel(project: project)
            }
        }
        .listStyle(.insetGrouped)
        .ringifyBottomBar {
            RingifyPrimaryButton(title: LocalizedStringKey(model.uiText("Ön İzle", "Preview")), isDisabled: !isSelectionValid(project)) {
                if model.updateCurrentProject({ $0.effects = effects }) {
                    router.push(.ringtonePreview)
                }
            }
            .accessibilityIdentifier("effects.continue")
        }
    }

    private func analysisPanel(project: RingtoneProject) -> some View {
        AudioAnalysisPanel(project: project, service: model.container.analysis) { selection in
            do {
                let nextEffects = try effects.limitingFades(to: selection.duration)
                effects = nextEffects
                model.updateCurrentProject {
                    $0.selection = selection
                    $0.effects = nextEffects
                }
            } catch { model.present(error) }
        }
    }

    private func isSelectionValid(_ project: RingtoneProject) -> Bool {
        if case .success = RingtoneRules().validate(selection: project.selection, sourceDuration: project.sourceDuration) { return true }
        return false
    }

    private func audioSection(project: RingtoneProject) -> some View {
        Section {
            sliderRow("effects.volume", icon: "speaker.wave.2.fill", value: $effects.volume, range: 0...1.5,
                      display: (effects.volume * 100).formatted(.number.precision(.fractionLength(0))) + "%", identifier: "effects.volume")
            sliderRow("effects.fadeIn", icon: "chart.line.uptrend.xyaxis", value: $effects.fadeInDuration, range: 0...min(5, project.selection.duration / 2),
                      display: seconds(effects.fadeInDuration), identifier: "effects.fadeIn")
            sliderRow("effects.fadeOut", icon: "chart.line.downtrend.xyaxis", value: $effects.fadeOutDuration, range: 0...min(5, project.selection.duration / 2),
                      display: seconds(effects.fadeOutDuration), identifier: "effects.fadeOut")
        } header: {
            Text(model.uiText("Ses", "Audio")).textCase(nil)
        }
    }

    private var processingSection: some View {
        Section {
            normalizeToggle
            Toggle(model.uiText("Pürüzsüz loop", "Smooth loop"), isOn: Binding(
                get: { effects.loopCrossfadeDuration > 0 }, set: { effects.loopCrossfadeDuration = $0 ? 0.03 : 0 }))
            if effects.loopCrossfadeDuration > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    NativeMetadataRow(title: model.uiText("Uç geçişi", "Edge overlap"), value: (effects.loopCrossfadeDuration * 1000).formatted(.number.precision(.fractionLength(0))) + " ms")
                    Slider(value: $effects.loopCrossfadeDuration, in: 0.005...0.25, step: 0.005)
                        .frame(minHeight: 44)
                        .accessibilityLabel(model.uiText("Döngü uç geçişi", "Loop edge overlap"))
                        .accessibilityValue((effects.loopCrossfadeDuration * 1000).formatted(.number.precision(.fractionLength(0))) + " ms")
                }
            }
        }
    }

    private var normalizeToggle: some View {
        Toggle(isOn: Binding(get: { effects.normalize }, set: { next in
            guard ProAccessPolicy.canChangeNormalization(current: effects.normalize,
                next: next, hasVerifiedPro: purchases.isPro) else {
                model.updateCurrentProject { $0.effects = effects }
                router.push(.premium)
                return
            }
            effects.normalize = next
        })) {
            VStack(alignment: .leading, spacing: 2) {
                Label("effects.normalize", systemImage: "waveform.path.ecg")
                if !purchases.isPro {
                    Text("Ringify Pro").font(.caption).foregroundStyle(RingifyTheme.violet)
                }
            }
        }
        .accessibilityIdentifier("effects.normalize")
    }

    private func seconds(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1))) + model.uiText(" sn", " s")
    }

    private func sliderRow(
        _ title: LocalizedStringKey,
        icon: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        display: String,
        identifier: String
    ) -> some View {
        VStack(spacing: 10) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
            layout {
                Label(title, systemImage: icon)
                if !typeSize.isAccessibilitySize { Spacer() }
                Text(display)
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .frame(minHeight: 44)
                .accessibilityLabel(title)
                .accessibilityValue(display)
                .accessibilityIdentifier(identifier)
        }
        .padding(.vertical, 4)
    }

}
