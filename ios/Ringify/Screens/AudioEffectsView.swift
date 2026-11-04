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
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        NativeProjectIdentity(project: project)
                        AudioComparisonPanel(project: project, effects: effects, container: model.container)
                        if isSelectionValid(project) {
                            effectControls(project: project)
                        } else {
                            Label("editor.durationRule", systemImage: "exclamationmark.circle")
                                .font(.subheadline).foregroundStyle(.red)
                        }
                        AdvancedEffectsPanel(project: project, effects: $effects)
                        PersonalAudioPresetsPanel(project: project, effects: $effects)
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
                        NativePrimaryAction(title: LocalizedStringKey(model.uiText("Ön İzle", "Preview")), disabled: !isSelectionValid(project)) {
                            if model.updateCurrentProject({ $0.effects = effects }) {
                                router.push(.ringtonePreview)
                            }
                        }
                        .accessibilityIdentifier("effects.continue")
                    }
                    .padding(RingifyTheme.horizontalPadding)
                }
            } else {
                RingifyEmptyState(icon: "slider.horizontal.3", title: "editor.empty.title", message: "editor.empty.message",
                    actionTitle: "home.create", action: { router.push(.importSource) })
            }
        }
        .background(RingifyTheme.Studio.background)
        .tint(RingifyTheme.Studio.accent)
        .ringifyStudioAppearance()
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

    private func isSelectionValid(_ project: RingtoneProject) -> Bool {
        if case .success = RingtoneRules().validate(selection: project.selection, sourceDuration: project.sourceDuration) { return true }
        return false
    }

    private func effectControls(project: RingtoneProject) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(model.uiText("Ses", "Audio")).font(.headline).accessibilityAddTraits(.isHeader)
            sliderRow("effects.volume", icon: "speaker.wave.2.fill", value: $effects.volume, range: 0...1.5,
                      display: (effects.volume * 100).formatted(.number.precision(.fractionLength(0))) + "%", identifier: "effects.volume")
                .modifier(NativeContentCard())
            Text(model.uiText("Geçişler", "Fades")).font(.headline).accessibilityAddTraits(.isHeader)
            VStack(spacing: 18) {
                sliderRow("effects.fadeIn", icon: "chart.line.uptrend.xyaxis", value: $effects.fadeInDuration, range: 0...min(5, project.selection.duration / 2),
                          display: seconds(effects.fadeInDuration), identifier: "effects.fadeIn")
                Divider()
                sliderRow("effects.fadeOut", icon: "chart.line.downtrend.xyaxis", value: $effects.fadeOutDuration, range: 0...min(5, project.selection.duration / 2),
                          display: seconds(effects.fadeOutDuration), identifier: "effects.fadeOut")
            }
            .modifier(NativeContentCard())
            Toggle(isOn: Binding(get: { effects.normalize }, set: { next in
                guard ProAccessPolicy.canChangeNormalization(current: effects.normalize,
                    next: next, hasVerifiedPro: purchases.isPro) else {
                    model.updateCurrentProject { $0.effects = effects }
                    router.push(.premium)
                    return
                }
                effects.normalize = next
            })) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("effects.normalize", systemImage: "waveform.path.ecg")
                    if !purchases.isPro { Text("Ringify Pro").font(.caption).foregroundStyle(RingifyTheme.Studio.accent) }
                }
            }
            .frame(minHeight: 44)
            .modifier(NativeContentCard())
            .accessibilityIdentifier("effects.normalize")
            VStack(alignment: .leading, spacing: 12) {
                Toggle(model.uiText("Pürüzsüz loop", "Smooth loop"), isOn: Binding(
                    get: { effects.loopCrossfadeDuration > 0 }, set: { effects.loopCrossfadeDuration = $0 ? 0.03 : 0 }))
                    .frame(minHeight: 44)
                if effects.loopCrossfadeDuration > 0 {
                    NativeMetadataRow(title: model.uiText("Uç geçişi", "Edge overlap"), value: (effects.loopCrossfadeDuration * 1000).formatted(.number.precision(.fractionLength(0))) + " ms")
                    Slider(value: $effects.loopCrossfadeDuration, in: 0.005...0.25, step: 0.005)
                        .frame(minHeight: 44)
                        .accessibilityLabel(model.uiText("Döngü uç geçişi", "Loop edge overlap"))
                        .accessibilityValue((effects.loopCrossfadeDuration * 1000).formatted(.number.precision(.fractionLength(0))) + " ms")
                }
            }.modifier(NativeContentCard())
        }
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
    }

}
