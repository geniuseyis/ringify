import RingifyCore
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var isLoadingProjects = true

    var body: some View {
        List {
            createSection
            quickAccess
            recentProjects
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Ringify")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.push(.premium) } label: {
                    Label("home.pro", systemImage: "crown")
                }
                .accessibilityIdentifier("home.pro")
            }
        }
        .task {
            isLoadingProjects = true
            await model.reloadProjects()
            isLoadingProjects = false
        }
    }

    // MARK: - Create

    private var createSection: some View {
        Section {
            Button { router.push(.importSource) } label: {
                createCard
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.create")
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var createCard: some View {
        HStack(spacing: 12) {
            if !typeSize.isAccessibilitySize {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.uiText("Yeni Zil Sesi Oluştur", "Create New Ringtone"))
                    .font(.headline)
                Text(model.uiText("Video, ses veya mikrofon", "Video, audio or microphone"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            if !typeSize.isAccessibilitySize {
                Image(systemName: "chevron.forward")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RingifyTheme.action.gradient, in: cardShape)
        .contentShape(cardShape)
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: RingifyTheme.cardRadius, style: .continuous)
    }

    // MARK: - Quick access

    private var quickAccess: some View {
        Section {
            quickRow(Text(model.uiText("Ses Kaydet", "Record")), icon: "mic", identifier: "home.quick.record") {
                router.push(.recorder)
            }
            quickRow(Text("conversion.title"), icon: "arrow.triangle.2.circlepath", identifier: "home.quick.conversion") {
                router.push(.conversion)
            }
            quickRow(Text(model.uiText("Nasıl Ayarlanır?", "Setup Guide")), icon: "bell", identifier: "home.quick.guide") {
                router.push(.guide)
            }
        } header: {
            Text("home.quickAccess")
                .accessibilityAddTraits(.isHeader)
                .textCase(nil)
        }
    }

    // A default Button in a List keeps the system row highlight but tints its label,
    // and the row's hierarchical .primary would inherit that tint. Color.primary keeps
    // the title neutral; only the symbol carries the accent.
    private func quickRow(_ title: Text, icon: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RingifyRow(title, systemImage: icon, showsChevron: true)
                .foregroundStyle(Color.primary)
        }
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Recent projects

    private var recentProjects: some View {
        Section {
            recentRows
        } header: {
            recentHeader
        }
    }

    @ViewBuilder private var recentHeader: some View {
        let headingLayout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        headingLayout {
            Text("home.recent")
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { router.selectedTab = .library } label: {
                Text("common.seeAll")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("home.projects.all")
        }
        .textCase(nil)
    }

    @ViewBuilder private var recentRows: some View {
        if isLoadingProjects && model.projects.isEmpty {
            ProgressView(model.uiText("Projeler yükleniyor…", "Loading projects…"))
                .frame(maxWidth: .infinity, minHeight: 44)
        } else if model.projects.isEmpty {
            RingifyRow(
                Text(model.uiText("İlk zil sesini oluştur", "Create your first ringtone")),
                subtitle: Text(model.uiText("İçe aktardığın sesler ve taslakların burada.", "Your imported sounds and drafts will live here.")),
                systemImage: "music.note.house"
            )
            .accessibilityElement(children: .combine)
        } else {
            ForEach(model.projects.prefix(3)) { project in
                projectRow(project)
            }
        }
    }

    private func projectRow(_ project: RingtoneProject) -> some View {
        Button {
            if model.loadProject(project) { router.selectedTab = .studio }
        } label: {
            HStack(spacing: 8) {
                RingifyProjectLabel(project: project)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.primary)
        }
        .accessibilityHint(model.uiText("Ses Stüdyosu'nda düzenlemeye devam et.", "Continue editing in Audio Studio."))
    }
}
