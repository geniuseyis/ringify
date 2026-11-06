import RingifyCore
import SwiftUI

struct AudioSegmentSuggestionsPanel: View {
    let project: RingtoneProject
    let onApply: (EditSelection) -> Void
    @EnvironmentObject private var model: AppModel
    @State private var duration: AudioSegmentDuration = .ringtone
    @StateObject private var suggestions: AudioSegmentsViewModel
    init(project: RingtoneProject, service: any AudioSegmentSuggesting, onApply: @escaping (EditSelection) -> Void) {
        self.project = project; self.onApply = onApply
        _suggestions = StateObject(wrappedValue: AudioSegmentsViewModel(service: service))
    }
    private var input: AudioSegmentsInput { AudioSegmentsInput(project, duration: duration) }
    var body: some View {
        Form {
            scanSection
            if case .ready(let result) = suggestions.state {
                resultsSection(result)
            }
        }
        .onAppear { suggestions.update(input) }
        .onChange(of: input) { _, next in suggestions.update(next) }
        .onDisappear { suggestions.cancel() }
    }

    private var scanSection: some View {
        Section {
            // Menu, not a pushed list: leaving this Form would run its
            // onDisappear, which cancels the scan and discards the results.
            Picker(model.uiText("Hedef süre", "Target duration"), selection: $duration) {
                ForEach(AudioSegmentDuration.allCases, id: \.rawValue) { value in
                    Text("\(value.rawValue) " + model.uiText("saniye", "seconds")).tag(value)
                }
            }
            .pickerStyle(.menu)
            scanControl
            if case .failed = suggestions.state {
                Label {
                    Text(model.uiText("Tarama tamamlanamadı. Kaynağı kontrol edip yeniden dene.",
                        "The scan failed. Check the source and retry."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(RingifyTheme.warning)
                }
            }
        } header: {
            Text(model.uiText("Ses bölümü önerileri", "Audio segment suggestions"))
                .textCase(nil)
        } footer: {
            Text(model.uiText("Kaynak enerjisine göre sıralanır; konuşma veya müzik içeriğini yorumlamaz.",
                "Ranked by source energy, without interpreting speech or music."))
        }
    }

    @ViewBuilder private var scanControl: some View {
        if project.sourceDuration > 120 {
            Text(model.uiText("Bu tarama en fazla 120 saniyelik kaynakları destekler.", "This scan supports sources up to 120 seconds."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if suggestions.state == .running {
            LabeledContent(model.uiText("Kaynak taranıyor…", "Scanning source…")) {
                ProgressView()
            }
            Button(model.uiText("İptal", "Cancel")) { suggestions.cancel() }
        } else {
            Button(model.uiText("Kaynakta bölüm bul", "Find source segments")) { suggestions.start(input) }
        }
    }

    private func resultsSection(_ result: [AudioSegmentSuggestion]) -> some View {
        Section {
            if result.isEmpty {
                Text(model.uiText("Uygun enerjide bölüm bulunamadı.", "No region above the energy threshold was found."))
            }
            ForEach(Array(result.enumerated()), id: \.offset) { index, item in
                Button {
                    guard let current = model.currentProject,
                          let selection = suggestions.selection(at: index, input: AudioSegmentsInput(current, duration: duration)) else { return }
                    onApply(selection)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(DurationText.formatted(item.selection.start)) – \(DurationText.formatted(item.selection.end))")
                            .foregroundStyle(.primary)
                        Text(item.rmsDbFS.formatted(.number.precision(.fractionLength(1))) + " dBFS RMS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
        }
    }
}
