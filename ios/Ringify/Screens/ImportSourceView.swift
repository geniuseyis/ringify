import Foundation
import PhotosUI
import RingifyCore
import SwiftUI
import UniformTypeIdentifiers

/// Source picker in the original card-grid layout, rebuilt on monochrome tiles
/// with hairline borders: one featured Photos card, then files, then record/convert.
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
                VStack(alignment: .leading, spacing: 24) {
                    intro
                    fileSection
                    createSection
                    librarySection
                    privacyNote
                }
                .padding(.horizontal, RingifyTheme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(RingifyTheme.background)
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

    // MARK: - Content

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.uiText("Bir ses ekle", "Add a sound"))
                .font(.largeTitle.weight(.bold))
                .tracking(-0.6)
                .accessibilityAddTraits(.isHeader)
            Text("import.subtitle")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var fileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(model.uiText("DOSYA SEÇ", "CHOOSE A FILE"))
            PhotosPicker(selection: $photoSelection, matching: .videos) {
                ImportSourceCard(title: Text("import.photos"), detail: Text("import.photos.detail"),
                                 systemImage: "photo.on.rectangle.angled", isFeatured: true)
            }
            .buttonStyle(RingifyPressStyle())
            .accessibilityIdentifier("import.photos")
            LazyVGrid(columns: columns, spacing: 12) {
                Button { showAudioImporter = true } label: {
                    ImportSourceCard(title: Text("import.audio"), detail: Text("import.audio.detail"), systemImage: "doc")
                }
                .buttonStyle(RingifyPressStyle())
                .accessibilityIdentifier("import.audio")
                Button { showVideoImporter = true } label: {
                    ImportSourceCard(title: Text("import.video"), detail: Text("import.video.detail"), systemImage: "film")
                }
                .buttonStyle(RingifyPressStyle())
                .accessibilityIdentifier("import.video")
            }
        }
    }

    private var createSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(model.uiText("KAYDET VE DÖNÜŞTÜR", "RECORD AND CONVERT"))
            LazyVGrid(columns: columns, spacing: 12) {
                Button { router.push(.recorder) } label: {
                    ImportSourceCard(title: Text("import.microphone"), detail: Text("import.microphone.detail"),
                                     systemImage: "mic", navigates: true)
                }
                .buttonStyle(RingifyPressStyle())
                .accessibilityIdentifier("import.microphone")
                Button { router.push(.conversion) } label: {
                    ImportSourceCard(title: Text("conversion.title"), detail: Text("conversion.detail"),
                                     systemImage: "arrow.left.arrow.right", navigates: true)
                }
                .buttonStyle(RingifyPressStyle())
                .accessibilityIdentifier("import.conversion")
            }
        }
    }

    private var librarySection: some View {
        Button {
            router.popToRoot()
            router.selectedTab = .library
        } label: {
            RingifyRow(Text("tab.library"),
                       subtitle: Text(model.uiText("Kayıtlı bir projeden devam et", "Continue a saved project")),
                       systemImage: "folder", showsChevron: true)
                .ringifyOutlinedCard(padding: 14)
        }
        .buttonStyle(RingifyPressStyle())
        .accessibilityIdentifier("import.library")
    }

    private var privacyNote: some View {
        Label {
            Text("import.privacy")
        } icon: {
            Image(systemName: "lock.shield")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }

    private var columns: [GridItem] {
        typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]
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

/// A media source as a card: monochrome icon tile, title and detail. The featured
/// card spans the width and lays out horizontally.
private struct ImportSourceCard: View {
    let title: Text
    let detail: Text
    let systemImage: String
    var isFeatured = false
    var navigates = false

    var body: some View {
        Group {
            if isFeatured {
                HStack(spacing: 14) {
                    RingifyIconTile(systemImage: systemImage, size: 48)
                    texts.frame(maxWidth: .infinity, alignment: .leading)
                    trailingGlyph
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        RingifyIconTile(systemImage: systemImage, size: 40)
                        Spacer(minLength: 8)
                        trailingGlyph
                    }
                    texts
                }
                .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            }
        }
        .ringifyOutlinedCard(padding: 16)
        .accessibilityElement(children: .combine)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 4) {
            title.font(.headline).foregroundStyle(.primary)
            detail.font(.footnote).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var trailingGlyph: some View {
        Image(systemName: navigates ? "chevron.forward" : "arrow.up.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

