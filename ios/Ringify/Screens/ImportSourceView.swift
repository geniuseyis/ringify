import Foundation
import PhotosUI
import RingifyCore
import SwiftUI
import UniformTypeIdentifiers

struct ImportSourceView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showAudioImporter = false
    @State private var showVideoImporter = false
    @State private var photoSelection: PhotosPickerItem?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.uiText("Bir ses ekle", "Add a sound"))
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("import.subtitle").foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    LazyVGrid(columns: sourceColumns, spacing: 12) {
                        PhotosPicker(selection: $photoSelection, matching: .videos) {
                            sourceRow(icon: "photo.on.rectangle.angled", title: "import.photos", message: "import.photos.detail")
                        }
                        .accessibilityIdentifier("import.photos")
                        Button { showAudioImporter = true } label: {
                            sourceRow(icon: "doc", title: "import.audio", message: "import.audio.detail")
                        }
                        .accessibilityIdentifier("import.audio")
                        Button { showVideoImporter = true } label: {
                            sourceRow(icon: "film", title: "import.video", message: "import.video.detail")
                        }
                        .accessibilityIdentifier("import.video")
                        Button {
                            router.popToRoot()
                            router.selectedTab = .library
                        } label: {
                            sourceRow(icon: "folder", title: "tab.library", message: "home.recent")
                        }
                        .accessibilityIdentifier("import.library")
                    }
                    .buttonStyle(.plain)
                    LazyVGrid(columns: sourceColumns, spacing: 12) {
                        Button { router.push(.recorder) } label: {
                            sourceRow(icon: "mic", title: "import.microphone", message: "import.microphone.detail")
                        }
                        .accessibilityIdentifier("import.microphone")
                        Button { router.push(.conversion) } label: {
                            sourceRow(icon: "arrow.left.arrow.right", title: "conversion.title", message: "conversion.detail")
                        }
                        .accessibilityIdentifier("import.conversion")
                    }
                    .buttonStyle(.plain)
                }
                .padding(RingifyTheme.horizontalPadding)
            }
            .disabled(model.isWorking)
            .accessibilityHidden(model.isWorking)
            if model.isWorking {
                Color.black.opacity(0.15).ignoresSafeArea()
                VStack(spacing: 18) {
                    ProgressView().controlSize(.large)
                    Text("import.processing")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .background(RingifyTheme.Studio.surface, in: RoundedRectangle(cornerRadius: RingifyTheme.Studio.cardRadius))
                .padding(RingifyTheme.horizontalPadding)
                .accessibilityElement(children: .combine)
            }
        }
        .background(RingifyTheme.Studio.background)
        .ringifyStudioAppearance()
        .navigationTitle("import.title")
        .navigationBarTitleDisplayMode(.inline)
        .tint(RingifyTheme.Studio.accent)
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

    private var sourceColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), alignment: .top), count: typeSize.isAccessibilitySize ? 1 : 2)
    }

    private func sourceRow(icon: String, title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !typeSize.isAccessibilitySize {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(RingifyTheme.Studio.accent)
                        .frame(width: 42, height: 42)
                        .background(RingifyTheme.Studio.soft, in: RoundedRectangle(cornerRadius: 13))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? 120 : 150, alignment: .topLeading)
        .background(RingifyTheme.Studio.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(RingifyTheme.Studio.border).allowsHitTesting(false) }
        .contentShape(Rectangle())
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
