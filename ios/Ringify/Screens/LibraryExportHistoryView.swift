import RingifyCore
import SwiftUI

struct LibraryExportHistoryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pendingDelete: ProjectExportRecord?
    @State private var showConfirmation = false
    var projectID: UUID? = nil

    private var records: [ProjectExportRecord] {
        model.exportHistory.filter { projectID == nil || $0.projectID == projectID }
    }

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView(model.uiText("Henüz dışa aktarma yok", "No exports yet"), systemImage: "clock.arrow.circlepath")
            }
            ForEach(records) { record in
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.output.url.lastPathComponent).font(.headline).lineLimit(2)
                    Text(record.name).font(.subheadline).foregroundStyle(.secondary)
                    Text(record.output.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                    Text(DurationText.formatted(record.output.duration) + " · " +
                         ByteCountFormatter.string(fromByteCount: record.output.byteCount, countStyle: .file))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    HStack {
                        if FileManager.default.fileExists(atPath: record.output.url.path) {
                            ShareLink(item: record.output.url) {
                                Label(model.uiText("Paylaş", "Share"), systemImage: "square.and.arrow.up").frame(minHeight: 44)
                            }
                        } else {
                            Label(model.uiText("Dosya bulunamadı", "File not found"), systemImage: "exclamationmark.circle")
                                .font(.caption).foregroundStyle(RingifyTheme.danger)
                        }
                        Spacer()
                        Button(role: .destructive) { pendingDelete = record; showConfirmation = true } label: {
                            Image(systemName: "trash").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(model.uiText("\(record.output.url.lastPathComponent) çıktısını sil", "Delete export \(record.output.url.lastPathComponent)"))
                        .disabled(model.isLibraryWorking || model.isWorking)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle(model.uiText("Dışa Aktarma Geçmişi", "Export History"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.reloadLibrary() }
        .confirmationDialog(model.uiText("Çıktı dosyası silinsin mi?", "Delete output file?"),
            isPresented: $showConfirmation, titleVisibility: .visible) {
            Button(model.uiText("Çıktıyı Sil", "Delete Export"), role: .destructive) {
                guard let record = pendingDelete else { return }
                Task { if await model.deleteExport(record) { pendingDelete = nil } }
            }
            Button("common.cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(model.uiText("Kaynak ses ve düzenleme ayarları korunur.", "Source audio and edit settings are kept."))
        }
    }
}
