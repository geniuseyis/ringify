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
            Section {
                Button { showImporter = true } label: {
                    Label {
                        if let url = viewModel.sourceURL { Text(url.lastPathComponent) }
                        else { Text("conversion.choose") }
                    } icon: { Image(systemName: "doc.badge.arrow.up") }
                        .frame(minHeight: 44)
                }
                .disabled(viewModel.isWorking)
            } footer: { Text("conversion.limits") }
            Section("conversion.output") {
                TextField("conversion.filename", text: $viewModel.filename)
                    .disabled(viewModel.isWorking || viewModel.result != nil)
                Picker("conversion.format", selection: $viewModel.format) {
                    Text("WAV / PCM 16-bit").tag(AudioConversionFormat.wav)
                    Text("M4A / AAC").tag(AudioConversionFormat.m4a)
                }
                .disabled(viewModel.isWorking || viewModel.result != nil)
            }
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
                    ShareLink(item: result.url) { Label("conversion.share", systemImage: "square.and.arrow.up") }
                        .frame(minHeight: 44)
                } header: { Text("conversion.ready") } footer: { Text("conversion.saveHint") }
            } else {
                Section {
                    Button("conversion.start") { viewModel.start() }
                        .disabled(viewModel.sourceURL == nil || viewModel.filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .frame(minHeight: 44)
                }
            }
        }
        .ringifyStudioAppearance()
        .navigationTitle("conversion.title")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.mpeg4Movie, .mp3]) { result in
            do { viewModel.select(try result.get()) }
            catch { viewModel.error = error.localizedDescription }
        }
        .alert("conversion.failed", isPresented: Binding(get: { viewModel.error != nil }, set: { if !$0 { viewModel.error = nil } })) {
            Button("common.done") { viewModel.error = nil }
        } message: { Text(viewModel.error ?? "") }
        .onDisappear { viewModel.dispose() }
    }
}
