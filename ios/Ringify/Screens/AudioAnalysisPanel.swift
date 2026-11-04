import RingifyCore
import SwiftUI

struct AudioAnalysisPanel: View {
    let project: RingtoneProject
    let onApply: (EditSelection) -> Void
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.locale) private var locale
    @StateObject private var viewModel: AudioAnalysisViewModel

    init(project: RingtoneProject, service: any AudioSignalAnalyzing, onApply: @escaping (EditSelection) -> Void) {
        self.project = project
        self.onApply = onApply
        _viewModel = StateObject(wrappedValue: AudioAnalysisViewModel(service: service))
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 16) {
                if !purchases.isPro {
                    Button("analysis.unlock") { router.push(.premium) }
                        .frame(minHeight: 44)
                } else {
                    Text("analysis.sourceOnly").font(.footnote).foregroundStyle(.secondary)
                    if viewModel.state == .running {
                        ProgressView("analysis.running")
                        Button("analysis.cancel") { viewModel.cancel() }.frame(minHeight: 44)
                    } else {
                        Button("analysis.start") { viewModel.start(project, hasVerifiedPro: purchases.isPro) }
                            .buttonStyle(.bordered).frame(minHeight: 44)
                    }
                    if case .failed = viewModel.state {
                        Text("analysis.failed").foregroundStyle(RingifyTheme.danger)
                    }
                    if case .ready(let result) = viewModel.state {
                        measurement("analysis.peak", value: decibels(result.peakDbFS))
                        measurement("analysis.rms", value: decibels(result.rmsDbFS))
                        measurement("analysis.silence", value: String(result.silentRegions.count))
                        if let selection = result.suggestion {
                            Text("\(DurationText.formatted(selection.start)) – \(DurationText.formatted(selection.end))")
                                .font(.subheadline.monospacedDigit())
                            Button("analysis.applyTrim") {
                                guard let current = model.currentProject,
                                      let suggestion = viewModel.suggestion(for: current, hasVerifiedPro: purchases.isPro) else { return }
                                onApply(suggestion)
                            }
                            .buttonStyle(.bordered).frame(minHeight: 44)
                        } else {
                            Text("analysis.noSuggestion").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            Label("analysis.title", systemImage: "waveform.path.ecg")
        }
        .ringifyCard()
        .onAppear { viewModel.updateInput(project) }
        .onChange(of: AudioAnalysisInput(project)) { _, _ in viewModel.updateInput(project) }
        .onChange(of: purchases.isPro) { _, active in if !active { viewModel.cancel() } }
        .onDisappear { viewModel.cancel() }
    }

    private func decibels(_ value: Double?) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(1)).locale(locale)) + " dBFS" } ?? "−∞ dBFS"
    }

    private func measurement(_ title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }
}
