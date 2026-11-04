import RingifyCore
import SwiftUI

struct AdvancedEffectsPanel: View {
    let project: RingtoneProject
    @Binding var effects: AudioEffectSettings
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.locale) private var locale
    @State private var sampleRate: Double?
    @State private var metadataFailed = false
    @State private var parameterError = false
    @State private var retry = 0
    @State private var presetFeedback = 0

    var body: some View {
        Group {
            if purchases.isPro {
                DisclosureGroup(model.uiText("Gelişmiş ses araçları", "Advanced audio tools")) {
                    VStack(alignment: .leading, spacing: 18) {
                        if metadataFailed {
                            Text(model.uiText("Kaynak bilgileri okunamadı.", "Could not read source metadata."))
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button(model.uiText("Tekrar Dene", "Try Again")) { retry += 1 }.frame(minHeight: 44)
                        } else if sampleRate == nil {
                            ProgressView(model.uiText("Kaynak okunuyor…", "Reading source…"))
                        }
                        if parameterError {
                            Text(model.uiText("Bu kaynak için frekanslar geçersiz. Alt kesim üst kesimden küçük ve frekanslar örnekleme hızının yarısından düşük olmalı.",
                                              "Invalid frequencies for this source. High-pass must be below low-pass and frequencies below half the sample rate."))
                                .font(.subheadline).foregroundStyle(.red)
                        }
                        Picker(model.uiText("Ses karakteri", "Preset"), selection: Binding<StudioAudioPreset?>(
                            get: { StudioAudioPreset.allCases.first { $0.settings == effects.studio } },
                            set: { preset in
                                if let preset {
                                    let before = effects.studio
                                    update { $0 = preset.settings }
                                    if effects.studio == preset.settings, effects.studio != before { presetFeedback += 1 }
                                }
                            }
                        )) {
                            Text(model.uiText("Özel", "Custom")).tag(StudioAudioPreset?.none)
                            ForEach(StudioAudioPreset.allCases) { preset in
                                Text(presetTitle(preset)).tag(Optional(preset))
                            }
                        }
                        .pickerStyle(.menu).frame(minHeight: 44).disabled(sampleRate == nil)
                        .accessibilityIdentifier("effects.preset")
                        .sensoryFeedback(.selection, trigger: presetFeedback)
                        equalizerRow(model.uiText("Bas · 120 Hz", "Bass · 120 Hz"), key: \.lowGainDB, frequency: 120)
                        equalizerRow(model.uiText("Orta · 1 kHz", "Mid · 1 kHz"), key: \.midGainDB, frequency: 1_000)
                        equalizerRow(model.uiText("Tiz · 6 kHz", "Treble · 6 kHz"), key: \.highGainDB, frequency: 6_000)
                        cutoffPicker(highPass: true)
                        cutoffPicker(highPass: false)
                        Picker(model.uiText("Kanallar", "Channels"), selection: Binding(get: { effects.studio.channelMode }, set: { next in update { $0.channelMode = next } })) {
                            Text(model.uiText("Kaynağı koru", "Keep source")).tag(StudioChannelMode.original)
                            Text("Mono").tag(StudioChannelMode.mono)
                            Text("Stereo").tag(StudioChannelMode.stereo)
                        }
                        .pickerStyle(.menu).frame(minHeight: 44).disabled(sampleRate == nil)
                        .accessibilityIdentifier("effects.channels")
                        Toggle(model.uiText("Tepe sınırlayıcı", "Peak limiter"), isOn: Binding(get: { effects.studio.limiterEnabled }, set: { next in update { $0.limiterEnabled = next } }))
                            .frame(minHeight: 44).disabled(sampleRate == nil)
                            .accessibilityIdentifier("effects.limiter")
                        if effects.studio.limiterEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                NativeMetadataRow(title: model.uiText("Tepe tavanı", "Peak ceiling"), value: percent(effects.studio.ceiling))
                                Slider(value: numericBinding(\.ceiling), in: 0.1...0.99, step: 0.01)
                                    .frame(minHeight: 44).disabled(sampleRate == nil)
                                    .accessibilityLabel(model.uiText("Tepe tavanı", "Peak ceiling"))
                                    .accessibilityValue(percent(effects.studio.ceiling))
                            }
                        }
                        resetButton
                    }
                    .padding(.top, 14)
                }
                .modifier(NativeContentCard())
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Button { router.push(.premium) } label: {
                        HStack {
                            Label(model.uiText("EQ, filtreler ve preset’ler", "EQ, filters and presets"), systemImage: "slider.horizontal.3")
                            Spacer()
                            Text("Pro").font(.caption.weight(.semibold))
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("effects.advanced.unlock")
                    if !effects.studio.isNeutral { resetButton }
                }
                .modifier(NativeContentCard())
            }
        }
        .task(id: [project.sourceURL.absoluteString, String(purchases.isPro), String(retry)]) {
            sampleRate = nil
            metadataFailed = false
            guard purchases.isPro || !effects.studio.isNeutral else { return }
            do {
                let metadata = try await model.container.metadata.metadata(for: project.sourceURL)
                try Task.checkCancellation()
                guard metadata.sampleRate.isFinite, metadata.sampleRate > 0 else { throw RingifyError.corruptMedia }
                sampleRate = metadata.sampleRate
                do { try effects.studio.validate(sampleRate: metadata.sampleRate); parameterError = false }
                catch { parameterError = true }
            } catch is CancellationError {
            } catch { metadataFailed = true }
        }
        .onChange(of: purchases.isPro) { _, active in
            if !active { effects.studio = model.currentProject?.effects.studio ?? .neutral }
        }
    }

    private var resetButton: some View {
        Button(model.uiText("Gelişmiş ayarları sıfırla", "Reset advanced settings"), systemImage: "arrow.counterclockwise") { update { $0 = .neutral } }
            .frame(minHeight: 44)
            .accessibilityIdentifier("effects.advanced.reset")
    }

    private func update(_ change: (inout StudioAudioSettings) -> Void) {
        var next = effects.studio
        change(&next)
        do { try next.validate() }
        catch { parameterError = true; return }
        guard ProAccessPolicy.canChangeStudioEffects(current: effects.studio, next: next, hasVerifiedPro: purchases.isPro) else {
            router.push(.premium)
            return
        }
        do {
            if !next.isNeutral {
                guard let sampleRate else { parameterError = true; return }
                try next.validate(sampleRate: sampleRate)
            }
            effects.studio = next
            parameterError = false
        } catch { parameterError = true }
    }

    private func numericBinding(_ key: WritableKeyPath<StudioAudioSettings, Double>) -> Binding<Double> {
        Binding(get: { effects.studio[keyPath: key] }, set: { next in update { $0[keyPath: key] = next } })
    }

    private func equalizerRow(_ title: String, key: WritableKeyPath<StudioAudioSettings, Double>, frequency: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NativeMetadataRow(title: title, value: effects.studio[keyPath: key].formatted(.number.precision(.fractionLength(0)).locale(locale)) + " dB")
            Slider(value: numericBinding(key), in: -12...12, step: 1)
                .frame(minHeight: 44)
                .disabled(sampleRate == nil || frequency >= (sampleRate ?? 0) / 2)
                .accessibilityLabel(title)
                .accessibilityValue(effects.studio[keyPath: key].formatted(.number.precision(.fractionLength(0)).locale(locale)) + " dB")
        }
    }

    private func cutoffPicker(highPass: Bool) -> some View {
        let key: WritableKeyPath<StudioAudioSettings, Double> = highPass ? \.highPassHz : \.lowPassHz
        let current = effects.studio[keyPath: key]
        let choices: [Double] = highPass ? [0, 40, 80, 150, 300, 500] : [0, 1_000, 3_400, 6_000, 12_000, 18_000]
        var available = choices.filter { $0 == 0 || $0 < (sampleRate ?? 0) / 2 }
        if current.isFinite, !available.contains(current) { available.append(current) }
        return Picker(highPass ? "High-pass" : "Low-pass", selection: numericBinding(key)) {
            ForEach(available.sorted(), id: \.self) { value in
                Text(value == 0 ? model.uiText("Kapalı", "Off") : value.formatted(.number.locale(locale)) + " Hz").tag(value)
            }
        }
        .pickerStyle(.menu).frame(minHeight: 44).disabled(sampleRate == nil)
    }

    private func percent(_ value: Double) -> String { (value * 100).formatted(.number.precision(.fractionLength(0)).locale(locale)) + "%" }

    private func presetTitle(_ preset: StudioAudioPreset) -> String {
        switch preset {
        case .neutral: model.uiText("Düz", "Flat")
        case .warm: model.uiText("Sıcak", "Warm")
        case .clear: model.uiText("Net", "Clear")
        case .telephone: model.uiText("Telefon", "Telephone")
        }
    }
}
