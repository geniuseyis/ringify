import RingifyCore
import SwiftUI

/// Home keeps the original Ringify composition (dark signature card, quick tools,
/// recent projects) on a monochrome, Apple-native base. Violet only marks small
/// highlights: the card's glow, links and the tab bar.
struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var isLoadingProjects = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                signatureCard
                if !model.projects.isEmpty {
                    summary
                }
                quickTools
                recentProjects
            }
            .padding(.horizontal, RingifyTheme.horizontalPadding)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .background(RingifyTheme.background)
        .navigationTitle("Ringify")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.footnote.weight(.bold))
                .foregroundStyle(RingifyTheme.onAction)
                .frame(width: 28, height: 28)
                .background(RingifyTheme.action, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            Text(model.uiText("KİŞİSEL SES STÜDYON", "YOUR PERSONAL AUDIO STUDIO"))
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Signature card

    private var signatureCard: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Text(model.uiText("HER SES BİR BAŞLANGIÇ.", "EVERY SOUND IS A BEGINNING."))
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if !typeSize.isAccessibilitySize {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.45))
                        .accessibilityHidden(true)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(model.uiText("Sesini imzana dönüştür.", "Turn sound into your signature."))
                    .font(.system(.largeTitle, design: .default).weight(.bold))
                    .tracking(-1)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(model.uiText("Bir anı seç. Kendine ait bir ses yarat.", "Choose a moment. Make it sound like you."))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            createButton
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RingifyTheme.heroCanvas
                HomeGridPattern()
                    .foregroundStyle(.white.opacity(0.05))
                // The one place violet is large: a soft glow, never a fill.
                RadialGradient(
                    colors: [RingifyTheme.accent.opacity(0.42), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 260
                )
            }
            .accessibilityHidden(true)
        }
        .clipShape(shape)
        .overlay { shape.strokeBorder(.white.opacity(0.1), lineWidth: 1) }
        .environment(\.colorScheme, .dark)
    }

    private var createButton: some View {
        Button { router.push(.importSource) } label: {
            HStack(spacing: 12) {
                if !typeSize.isAccessibilitySize {
                    Image(systemName: "scissors")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.uiText("Yeni Zil Sesi Oluştur", "Create New Ringtone"))
                        .font(.headline)
                    Text(model.uiText("Video, ses veya mikrofon", "Video, audio or microphone"))
                        .font(.subheadline)
                        .foregroundStyle(.black.opacity(0.6))
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                if !typeSize.isAccessibilitySize {
                    Image(systemName: "arrow.up.right")
                        .font(.body.weight(.semibold))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.black)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(RingifyPressStyle())
        .accessibilityIdentifier("home.create")
    }

    // MARK: - Summary

    /// Real counts from the project store; shown only once there is something to count.
    private var summary: some View {
        let ringtones = model.projects.filter { $0.status == .exported }.count
        let drafts = model.projects.count - ringtones
        return HStack(spacing: 0) {
            summaryItem(value: model.projects.count, title: model.uiText("Proje", "Projects"))
            Divider().frame(height: 32)
            summaryItem(value: ringtones, title: model.uiText("Zil sesi", "Ringtones"))
            Divider().frame(height: 32)
            summaryItem(value: drafts, title: model.uiText("Taslak", "Drafts"))
        }
        .ringifyOutlinedCard(padding: 14)
        .accessibilityElement(children: .combine)
    }

    private func summaryItem(value: Int, title: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick tools

    private var quickTools: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.uiText("Hızlı araçlar", "Quick tools"))
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: toolColumns, spacing: 12) {
                tool(title: model.uiText("Ses Kaydet", "Record"),
                     detail: model.uiText("Mikrofonla yeni ses", "A new take"),
                     icon: "mic", identifier: "home.quick.record") { router.push(.recorder) }
                tool(title: model.localized("conversion.title"),
                     detail: model.uiText("MP4 / MP3 → WAV, M4A", "MP4 / MP3 → WAV, M4A"),
                     icon: "arrow.triangle.2.circlepath", identifier: "home.quick.conversion") { router.push(.conversion) }
                tool(title: model.uiText("Kütüphane", "Library"),
                     detail: model.uiText("Tüm projelerin", "All your projects"),
                     icon: "folder", identifier: "home.quick.library") { router.selectedTab = .library }
                tool(title: model.uiText("Nasıl Ayarlanır?", "Setup Guide"),
                     detail: model.uiText("Zil sesi olarak ata", "Set it as a ringtone"),
                     icon: "bell", identifier: "home.quick.guide") { router.push(.guide) }
            }
        }
    }

    private var toolColumns: [GridItem] {
        typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]
    }

    private func tool(title: String, detail: String, icon: String, identifier: String,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                RingifyIconTile(systemImage: icon, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .ringifyOutlinedCard(padding: 14)
        }
        .buttonStyle(RingifyPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Recent projects

    private var recentProjects: some View {
        VStack(alignment: .leading, spacing: 12) {
            recentHeader
            recentContent
        }
    }

    @ViewBuilder private var recentHeader: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .lastTextBaseline, spacing: 12))
        layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.uiText("KALDIĞIN YERDEN", "PICK UP WHERE YOU LEFT OFF"))
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text("home.recent")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { router.selectedTab = .library } label: {
                Text("common.seeAll")
                    .font(.subheadline.weight(.medium))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("home.projects.all")
        }
    }

    @ViewBuilder private var recentContent: some View {
        if isLoadingProjects && model.projects.isEmpty {
            ProgressView(model.uiText("Projeler yükleniyor…", "Loading projects…"))
                .frame(maxWidth: .infinity, minHeight: 88)
                .ringifyOutlinedCard()
        } else if model.projects.isEmpty {
            emptyProjects
        } else {
            VStack(spacing: 0) {
                ForEach(Array(model.projects.prefix(3).enumerated()), id: \.element.id) { index, project in
                    if index > 0 {
                        Divider().padding(.leading, 56)
                    }
                    projectRow(project)
                }
            }
            .ringifyOutlinedCard(padding: 12)
        }
    }

    private var emptyProjects: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(spacing: 10) {
            RingifyIconTile(systemImage: "music.note", size: 44)
            Text(model.uiText("İlk zil sesini oluştur", "Create your first ringtone"))
                .font(.headline)
            Text(model.uiText("İçe aktardığın sesler ve taslakların burada.", "Your imported sounds and drafts will live here."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .overlay { shape.strokeBorder(RingifyTheme.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 4])) }
        .accessibilityElement(children: .combine)
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
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(RingifyPressStyle())
        .accessibilityHint(model.uiText("Ses Stüdyosu'nda düzenlemeye devam et.", "Continue editing in Audio Studio."))
    }
}


/// Fine grid behind the signature card, drawn once; decoration only.
private struct HomeGridPattern: View {
    var spacing: CGFloat = 22

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .foreground, lineWidth: 0.5)
        }
        .mask {
            LinearGradient(colors: [.black, .clear], startPoint: .topTrailing, endPoint: .bottomLeading)
        }
    }
}
