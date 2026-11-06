import Foundation
import PhotosUI
import RingifyCore
import SwiftUI
import UniformTypeIdentifiers

struct ImportSourceView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @State private var showAudioImporter = false
    @State private var showVideoImporter = false
    @State private var photoSelection: PhotosPickerItem?

    var body: some View {
        ZStack {
            List {
                fileSection
                recordSection
                moreSection
            }
            .listStyle(.insetGrouped)
            .disabled(model.isWorking)
            .accessibilityHidden(model.isWorking)
            if model.isWorking {
                workingOverlay
            }
        }
        .navigationTitle("import.title")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showAudioImporter, allowedContentTypes: [.audio]) { result in
            handleFileResult(result, kind: .audioFile)
        }
        .fileImporter(isPresented: $showVideoImporter, allowedContentTypes: [.movie, .video]) { result in
            handleFileResult(result, kind: .videoFile)
        }
        .onChange(of: photoSelection) { _, newValue in
            guard let newValue else { return }
            Task {
                defer { photoSelection = nil }
                do {
                    guard let transfer = try await newValue.loadTransferable(type: PhotoVideoTransfer.self) else {
                        throw RingifyError.corruptMedia
                    }
                    defer { try? FileManager.default.removeItem(at: transfer.url) }
                    if await model.prepareMedia(from: transfer.url, kind: .photoLibraryVideo) {
                        router.push(.editor)
                    }
                } catch {
                    model.present(error)
                }
            }
        }
    }

    private var fileSection: some View {
        Section {
            PhotosPicker(selection: $photoSelection, matching: .videos) {
                RingifyRow(Text("import.photos"), subtitle: Text("import.photos.detail"), systemImage: "photo.on.rectangle.angled")
            }
            .accessibilityIdentifier("import.photos")
            Button { showAudioImporter = true } label: {
                RingifyRow(Text("import.audio"), subtitle: Text("import.audio.detail"), systemImage: "doc")
            }
            .accessibilityIdentifier("import.audio")
            Button { showVideoImporter = true } label: {
                RingifyRow(Text("import.video"), subtitle: Text("import.video.detail"), systemImage: "film")
            }
            .accessibilityIdentifier("import.video")
        } header: {
            Text(model.uiText("Dosya Seç", "Choose a File")).textCase(nil)
        }
    }

    private var recordSection: some View {
        Section {
            Button { router.push(.recorder) } label: {
                RingifyRow(Text("import.microphone"), subtitle: Text("import.microphone.detail"),
                           systemImage: "mic", showsChevron: true)
            }
            .accessibilityIdentifier("import.microphone")
        } header: {
            Text(model.uiText("Kaydet", "Record")).textCase(nil)
        }
    }

    private var moreSection: some View {
        Section {
            Button { router.push(.conversion) } label: {
                RingifyRow(Text("conversion.title"), subtitle: Text("conversion.detail"),
                           systemImage: "arrow.left.arrow.right", showsChevron: true)
            }
            .accessibilityIdentifier("import.conversion")
            Button {
                router.popToRoot()
                router.selectedTab = .library
            } label: {
                RingifyRow(Text("tab.library"), subtitle: Text("home.recent"), systemImage: "folder", showsChevron: true)
            }
            .accessibilityIdentifier("import.library")
        } header: {
            Text(model.uiText("Diğer", "More")).textCase(nil)
        }
    }

    private var workingOverlay: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text("import.processing")
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: RingifyTheme.cardRadius, style: .continuous))
        .padding(RingifyTheme.horizontalPadding)
        .accessibilityElement(children: .combine)
    }

    private func handleFileResult(_ result: Result<URL, Error>, kind: MediaSourceKind) {
        Task {
            do {
                let url = try result.get()
                if await model.prepareMedia(from: url, kind: kind) {
                    router.push(.editor)
                }
            } catch {
                model.present(error)
            }
        }
    }
}
