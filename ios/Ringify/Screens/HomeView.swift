import RingifyCore
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var isLoadingProjects = true

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                header
                signatureCard
                quickAccess
                recentProjects
            }
            .padding(.horizontal, RingifyTheme.horizontalPadding)
            .padding(.bottom, 32)
        }
        .background(RingifyTheme.Studio.background)
        .ringifyStudioAppearance()
        .navigationTitle("Ringify")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.push(.premium) } label: {
                    Image(systemName: "crown")
                        .foregroundStyle(RingifyTheme.Studio.accent)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("home.pro")
                .accessibilityIdentifier("home.pro")
            }
        }
        .task {
            isLoadingProjects = true
            await model.reloadProjects()
            isLoadingProjects = false
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.title)
                .foregroundStyle(RingifyTheme.Studio.accent)
                .accessibilityHidden(true)
            Text(model.uiText("KİŞİSEL SES STÜDYON", "YOUR PERSONAL AUDIO STUDIO"))
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button { router.selectedTab = .settings } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(RingifyTheme.Studio.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("tab.settings")
            .accessibilityIdentifier("home.settings")
        }
        .padding(.top, 8)
    }

    // Decorative brand artwork is a symbol, never a fabricated media waveform.
    private var signatureCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Text(model.uiText("HER SES BİR BAŞLANGIÇ.", "EVERY SOUND IS A BEGINNING."))
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if !typeSize.isAccessibilitySize {
                    Image(systemName: "waveform")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.55))
                        .accessibilityHidden(true)
                }
            }
            Text(model.uiText("Sesini imzana dönüştür.", "Turn sound into your signature."))
                .font(.largeTitle.bold())
                .tracking(-0.8)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(model.uiText("Bir anı seç. Kendine ait bir ses yarat.", "Choose a moment. Make it sound like you."))
                .font(.body)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            createCard
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RingifyTheme.Studio.canvas
                LinearGradient(colors: [RingifyTheme.Studio.wave.opacity(0.08), .clear], startPoint: .topTrailing, endPoint: .bottomLeading)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(RingifyTheme.Studio.canvasBorder, lineWidth: 1)
        }
    }

    private var createCard: some View {
        Button { router.push(.importSource) } label: {
            HStack(spacing: 12) {
                if !typeSize.isAccessibilitySize {
                    Image(systemName: "scissors")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(RingifyTheme.Studio.accent)
                        .frame(width: 40, height: 40)
                        .background(RingifyTheme.Studio.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.uiText("Yeni Zil Sesi Oluştur", "Create New Ringtone"))
                        .font(.headline)
                    Text(model.uiText("Video, ses veya mikrofon", "Video, audio or microphone"))
                        .font(.caption)
                        .foregroundStyle(.black.opacity(0.68))
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                if !typeSize.isAccessibilitySize {
                    Image(systemName: "arrow.up.right")
                        .font(.body.weight(.semibold))
                        .accessibilityHidden(true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .foregroundStyle(.black)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.create")
    }

    @ViewBuilder private var recentProjects: some View {
        VStack(alignment: .leading, spacing: 12) {
            let headingLayout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            headingLayout {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.uiText("KALDIĞIN YERDEN", "PICK UP WHERE YOU LEFT OFF"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("home.recent").font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                }
                if !typeSize.isAccessibilitySize { Spacer() }
                Button { router.selectedTab = .library } label: {
                    Label("common.seeAll", systemImage: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityIdentifier("home.projects.all")
            }
            if isLoadingProjects && model.projects.isEmpty {
                ProgressView(model.uiText("Projeler yükleniyor…", "Loading projects…"))
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if model.projects.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "music.note.house")
                        .font(.title2)
                        .foregroundStyle(RingifyTheme.Studio.accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.uiText("İlk zil sesini oluştur", "Create your first ringtone"))
                            .font(.headline)
                        Text(model.uiText("İçe aktardığın sesler ve taslakların burada.", "Your imported sounds and drafts will live here."))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .ringifyCard()
            } else {
                ForEach(model.projects.prefix(3)) { project in
                    Button {
                        if model.loadProject(project) { router.selectedTab = .studio }
                    } label: {
                        ProjectRow(project: project)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(model.uiText("Ses Stüdyosu'nda düzenlemeye devam et.", "Continue editing in Audio Studio."))
                }
            }
        }
    }

    private var quickAccess: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.uiText("Hızlı araçlar", "Quick tools"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 1 : 3), spacing: 8) {
                quickButton(model.uiText("Ses Kaydet", "Record"), icon: "mic", identifier: "home.quick.record") {
                    router.push(.recorder)
                }
                quickButton(model.uiText("Kütüphane", "Library"), icon: "folder", identifier: "home.quick.library") {
                    router.selectedTab = .library
                }
                quickButton(model.uiText("Nasıl Ayarlanır?", "Setup Guide"), icon: "checkmark.shield", identifier: "home.quick.guide") {
                    router.push(.guide)
                }
            }
        }
    }

    private func quickButton(_ title: String, icon: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(RingifyTheme.Studio.accent)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(RingifyTheme.Studio.surface, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

struct ProjectRow: View {
    let project: RingtoneProject
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(RingifyTheme.Studio.accent.opacity(0.12))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "waveform").foregroundStyle(RingifyTheme.Studio.accent))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(project.updatedAt, style: .relative)
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            Divider()
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .accessibilityHidden(true)
                DurationText(seconds: project.selection.duration)
            }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .ringifyCard()
        .accessibilityElement(children: .combine)
    }
}
