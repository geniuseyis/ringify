import RingifyCore
import SwiftUI
import UniformTypeIdentifiers

struct AudioConversionView: View {
    @StateObject private var viewModel: AudioConversionViewModel
    @State private var showImporter = false
    init(service: any AudioConversionService) {
        _viewModel = StateObject(wrappedValue: AudioConversionViewModel(service: service))
    }
    var body: some View {
        Form {
            sourceSection
            outputSection
            if viewModel.isWorking {
                Section {
                    ProgressView("conversion.working")
                    Button("common.cancel", role: .cancel) { viewModel.cancel() }
                }
            } else if let result = viewModel.result {
                Section {
                    Text(result.url.lastPathComponent).textSelection(.enabled)
                    Text(result.duration.formatted(.number.precision(.fractionLength(1))) + " s · " + ByteCountFormatter.string(fromByteCount: result.byteCount, countStyle: .file))
                        .font(.subheadline).foregroundStyle(.secondary)
                } header: { Text("conversion.ready").textCase(nil) } footer: { Text("conversion.saveHint") }
            }
        }
        .navigationTitle("conversion.title")
        .navigationBarTitleDisplayMode(.inline)
        .ringifyBottomBar { bottomBar }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.mpeg4Movie, .mp3]) { result in
            do { viewModel.select(try result.get()) }
            catch { viewModel.error = error.localizedDescription }
        }
        .alert("conversion.failed", isPresented: Binding(get: { viewModel.error != nil }, set: { if !$0 { viewModel.error = nil } })) {
            Button("common.done") { viewModel.error = nil }
        } message: { Text(viewModel.error ?? "") }
        .onDisappear { viewModel.dispose() }
    }

    private var sourceSection: some View {
        Section {
            Button { showImporter = true } label: {
                RingifyRow(sourceTitle, systemImage: "doc.badge.arrow.up")
            }
            .disabled(viewModel.isWorking)
            .accessibilityIdentifier("conversion.choose")
        } footer: { Text("conversion.limits") }
    }

    private var sourceTitle: Text {
        if let url = viewModel.sourceURL { return Text(url.lastPathComponent) }
        return Text("conversion.choose")
    }

    private var outputSection: some View {
        Section {
            TextField("conversion.filename", text: $viewModel.filename)
                .disabled(viewModel.isWorking || viewModel.result != nil)
                .accessibilityIdentifier("conversion.filename")
            Picker("conversion.format", selection: $viewModel.format) {
                Text("WAV / PCM 16-bit").tag(AudioConversionFormat.wav)
                Text("M4A / AAC").tag(AudioConversionFormat.m4a)
            }
            .disabled(viewModel.isWorking || viewModel.result != nil)
            .accessibilityIdentifier("conversion.format")
        } header: { Text("conversion.output").textCase(nil) }
    }

    // One primary action per state: convert before a result exists, share after.
    @ViewBuilder private var bottomBar: some View {
        if let result = viewModel.result {
            ShareLink(item: result.url) {
                Label("conversion.share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .ringifyPrimaryAction()
            .accessibilityIdentifier("conversion.share")
        } else if !viewModel.isWorking {
            RingifyPrimaryButton(
                title: "conversion.start",
                systemImage: "arrow.left.arrow.right",
                isDisabled: viewModel.sourceURL == nil || viewModel.filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) { viewModel.start() }
            .accessibilityIdentifier("conversion.start")
        }
    }
}
