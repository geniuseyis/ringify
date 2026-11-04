import RingifyCore
import SwiftUI

struct AudioProjectMarkersPanel: View {
    let project: RingtoneProject
    let currentTime: () -> TimeInterval
    let onSelect: (AudioMarker) -> Void
    @EnvironmentObject private var model: AppModel
    @State private var name = ""
    @State private var pendingDelete: AudioMarker?
    @State private var showDelete = false

    var body: some View {
        DisclosureGroup(model.uiText("İşaretler · \(project.markers.count)", "Markers · \(project.markers.count)")) {
            VStack(alignment: .leading, spacing: 12) {
                TextField(model.uiText("İşaret adı (isteğe bağlı)", "Marker label (optional)"), text: $name)
                    .textFieldStyle(.roundedBorder).frame(minHeight: 44)
                Button(model.uiText("Bu Konuma İşaret Ekle", "Mark This Position"), systemImage: "bookmark") {
                    do {
                        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let marker = AudioMarker(time: currentTime(), label: label.isEmpty ? model.uiText("İşaret \(project.markers.count + 1)", "Marker \(project.markers.count + 1)") : label)
                        let next = try AudioMarkers.validated(project.markers + [marker], sourceDuration: project.sourceDuration)
                        Task { if await model.updateProjectMarkers(id: project.id, markers: next) { name = "" } }
                    } catch { model.present(error) }
                }
                .frame(minHeight: 44)
                .disabled(model.isLibraryWorking || project.markers.count >= AudioMarkers.maximumCount)
                ForEach(project.markers) { marker in
                    HStack {
                        Button { onSelect(marker) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(marker.label).fontWeight(.medium)
                                Text(DurationText.formatted(marker.time)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .accessibilityHint(model.uiText("İşareti içeren bölümü seçer.", "Selects the region containing this marker."))
                        Button(role: .destructive) { pendingDelete = marker; showDelete = true } label: {
                            Image(systemName: "trash").frame(width: 44, height: 44)
                        }.accessibilityLabel(model.uiText("\(marker.label) işaretini sil", "Delete \(marker.label)"))
                    }.disabled(model.isLibraryWorking)
                }
            }.padding(.top, 12)
        }
        .modifier(NativeContentCard())
        .confirmationDialog(model.uiText("İşaret silinsin mi?", "Delete marker?"), isPresented: $showDelete, titleVisibility: .visible) {
            Button(model.uiText("Sil", "Delete"), role: .destructive) {
                guard let pendingDelete else { return }
                Task {
                    if await model.updateProjectMarkers(id: project.id, markers: project.markers.filter({ $0.id != pendingDelete.id })) { self.pendingDelete = nil }
                }
            }
            Button("common.cancel", role: .cancel) { pendingDelete = nil }
        }
    }
}
