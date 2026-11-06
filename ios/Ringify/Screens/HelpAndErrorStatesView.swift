import RingifyCore
import SwiftUI
import UIKit

enum RingifyHelpTopic: String, CaseIterable, Identifiable {
    case create, setRingtone, formats, export, purchases, permissions, importFiles, storage
    var id: String { rawValue }
    static let settingsTopics: [Self] = [.create, .setRingtone, .export, .purchases]
    static let gettingStarted: [Self] = [.create, .setRingtone, .formats]
    static let troubleshooting: [Self] = [.export, .purchases, .permissions, .importFiles, .storage]

    @MainActor func title(_ model: AppModel) -> String {
        switch self {
        case .create: model.uiText("Zil sesi nasıl oluşturulur?", "How do I create a ringtone?")
        case .setRingtone: model.uiText("iPhone'da zil sesi ayarlama", "Set a ringtone on iPhone")
        case .formats: model.uiText("Desteklenen biçimler", "Supported formats")
        case .export: model.uiText("Dışa aktarma sorunları", "Export problems")
        case .purchases: model.uiText("Satın alma ve Pro", "Purchases and Pro")
        case .permissions: model.uiText("Mikrofon ve izinler", "Microphone and permissions")
        case .importFiles: model.uiText("Dosya içe aktarma", "Importing files")
        case .storage: model.uiText("Depolama ve projeler", "Storage and projects")
        }
    }

    var icon: String {
        switch self {
        case .create: "waveform"
        case .setRingtone: "bell"
        case .formats: "doc"
        case .export: "square.and.arrow.up"
        case .purchases: "crown"
        case .permissions: "mic"
        case .importFiles: "folder"
        case .storage: "externaldrive"
        }
    }

    func matches(query: String, localizedTitle: String, locale: Locale) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let keywords: String = switch self {
        case .create: "ringtone zil studio editor kes trim"
        case .setRingtone: "iphone garageband zil ringtone paylaş share"
        case .formats: "mp3 mp4 m4a wav aac codec format biçim"
        case .export: "wav aac m4a export çıktı dışa aktar"
        case .purchases: "pro satın alma purchase restore geri yükle abonelik subscription"
        case .permissions: "mic mikrofon microphone izin permission kayıt record"
        case .importFiles: "dosya file import içe aktar video"
        case .storage: "depolama storage proje project sil delete"
        }
        // Apply locale case conversion before removing the dot from Turkish İ.
        // A simultaneous case/diacritic fold can turn MİKROFON into mıkrofon.
        func normalized(_ text: String) -> String {
            text.lowercased(with: locale).folding(options: .diacriticInsensitive, locale: locale)
        }
        return normalized(localizedTitle + " " + keywords).contains(normalized(needle))
    }
}

enum RingifyHelpCategory: String, CaseIterable, Identifiable {
    case all, files, audio, export, pro
    var id: String { rawValue }
    func includes(_ topic: RingifyHelpTopic) -> Bool {
        switch self {
        case .all: true
        case .files: [RingifyHelpTopic.formats, .importFiles, .storage].contains(topic)
        case .audio: [RingifyHelpTopic.create, .permissions].contains(topic)
        case .export: [RingifyHelpTopic.setRingtone, .export].contains(topic)
        case .pro: topic == .purchases
        }
    }
    @MainActor func title(_ model: AppModel) -> String {
        switch self {
        case .all: model.uiText("Tümü", "All")
        case .files: model.uiText("Dosya", "File")
        case .audio: model.uiText("Ses", "Audio")
        case .export: model.uiText("Çıktı", "Export")
        case .pro: "Pro"
        }
    }
}

struct HelpAndErrorStatesView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @State private var query = ""
    @State private var category: RingifyHelpCategory = .all

    private var topics: [RingifyHelpTopic] {
        RingifyHelpTopic.allCases.filter {
            category.includes($0) && $0.matches(query: query, localizedTitle: $0.title(model),
                locale: Locale(identifier: model.settings.language.rawValue))
        }
    }

    var body: some View {
        List {
            shortcutsSection
            topicsSection
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && category == .all {
                troubleshootingSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(model.uiText("Yardım Merkezi", "Help Center"))
        .searchable(text: $query, prompt: model.uiText("Yardımda ara", "Search help"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var shortcutsSection: some View {
        Section {
            quickAction(model.uiText("Dosya ekle", "Add a file"), icon: "square.and.arrow.down") { router.push(.importSource) }
            quickAction(model.uiText("iPhone rehberi", "iPhone guide"), icon: "iphone") { router.push(.guide) }
            quickAction(model.uiText("Projelerim", "My projects"), icon: "folder") {
                router.popToRoot(); router.selectedTab = .library
            }
        } header: {
            Text(model.uiText("Nasıl yardımcı olabiliriz?", "How can we help?")).textCase(nil)
        } footer: {
            Text(model.uiText("Konunu seçerek adımları ve ilgili araçları açabilirsin.",
                "Choose a topic for step-by-step help and the tools you need."))
        }
    }

    private var topicsSection: some View {
        Section {
            Picker(model.uiText("Kategori", "Category"), selection: $category) {
                ForEach(RingifyHelpCategory.allCases) { Text($0.title(model)).tag($0) }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("help.category")
            ForEach(topics) { topic in topicLink(topic) }
            if topics.isEmpty {
                RingifyEmptyState(icon: "magnifyingglass", title: LocalizedStringKey(model.uiText("Sonuç bulunamadı", "No results")),
                    message: LocalizedStringKey(model.uiText("Başka bir konu ara.", "Try another topic.")),
                    actionTitle: LocalizedStringKey(model.uiText("Aramayı temizle", "Clear search")), action: { query = ""; category = .all })
            }
        } header: {
            Text(model.uiText("Yardım konuları", "Help topics")).textCase(nil)
        }
    }

    private var troubleshootingSection: some View {
        Section {
            ForEach(RingifyIssue.allCases) { issue in
                NavigationLink { IssueDetailView(issue: issue) } label: {
                    SettingsNavigationRow(title: model.localized("issue.\(issue.rawValue).title"),
                        icon: issueIcon(issue), tint: issueColor(issue))
                }
            }
        } header: {
            Text("help.states").textCase(nil)
        } footer: {
            Text("help.footer")
        }
    }

    // A default Button in a List keeps the system row highlight but tints its label,
    // and the row's hierarchical .primary would inherit that tint. Color.primary keeps
    // the title neutral; only the symbol carries the accent.
    private func quickAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RingifyRow(Text(title), systemImage: icon, showsChevron: true)
                .foregroundStyle(Color.primary)
        }
        .accessibilityLabel(title)
    }

    private func topicLink(_ topic: RingifyHelpTopic) -> some View {
        NavigationLink { HelpTopicDetailView(topic: topic) } label: {
            SettingsNavigationRow(title: topic.title(model), icon: topic.icon)
        }
    }
}

struct HelpTopicDetailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL
    let topic: RingifyHelpTopic

    var body: some View {
        List {
            content
        }
        .listStyle(.insetGrouped)
        .navigationTitle(topic.title(model))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var content: some View {
        switch topic {
        case .create: createContent
        case .setRingtone: setRingtoneContent
        case .formats: formatsContent
        case .export: exportContent
        case .purchases: purchasesContent
        case .permissions: permissionsContent
        case .importFiles: importFilesContent
        case .storage: storageContent
        }
    }

    @ViewBuilder private var createContent: some View {
        Section {
            instruction("1", title: model.uiText("Sesini ekle", "Add your sound"),
                message: model.uiText("Dosyalar'dan ses, Fotoğraflar'dan video seç veya mikrofonla kaydet.",
                    "Choose audio from Files, video from Photos, or record with the microphone."))
            instruction("2", title: model.uiText("Bölümünü seç", "Choose your section"),
                message: model.uiText("Stüdyo'da 1–29 saniyelik bölümü seç. Ses seviyesini ve fade ayarlarını projene göre düzenle.",
                    "Select 1–29 seconds in Studio. Adjust volume and fades for your project."))
            instruction("3", title: model.uiText("Dışa aktar ve kullan", "Export and use"),
                message: model.uiText("M4A dosyasını oluştur, paylaş ve iPhone rehberindeki adımları izle.",
                    "Create an M4A file, share it, and follow the iPhone guide."))
        } header: {
            Text(model.uiText("Üç adımda zil sesin", "Your ringtone in three steps")).textCase(nil)
        }
        Section { importButton }
    }

    private var setRingtoneContent: some View {
        Section {
            Text("guide.disclaimer").foregroundStyle(.secondary)
            NavigationLink { RingtoneGuideView() } label: {
                SettingsNavigationRow(title: model.uiText("Adım adım iPhone rehberi", "Step-by-step iPhone guide"), icon: "iphone")
            }
        }
    }

    @ViewBuilder private var formatsContent: some View {
        Section {
            LabeledContent(model.uiText("Ses", "Audio"), value: "M4A, MP3")
            Text(model.uiText("Diğer ses ve video biçimleri iPhone'un desteklediği codec'lere bağlıdır. Videoda kullanılabilir bir ses izi bulunmalıdır.",
                "Other audio and video formats depend on codecs supported by your iPhone. Video must contain a usable audio track."))
                .foregroundStyle(.secondary)
            Text(model.uiText("Korumalı veya kullanma iznin olmayan medyayı içe aktarma.",
                "Do not import protected media or media you do not have permission to use."))
                .font(.footnote).foregroundStyle(.secondary)
        } header: {
            Text(model.uiText("İçe aktarma", "Import")).textCase(nil)
        }
        Section {
            LabeledContent(model.uiText("Zil sesi", "Ringtone"), value: "M4A / AAC")
            Text(model.uiText("Ayrı Ses Dönüştür aracı MP4 veya MP3 dosyalarından WAV veya M4A oluşturur.",
                "The separate Convert Audio tool creates WAV or M4A from MP4 or MP3 files."))
                .foregroundStyle(.secondary)
            NavigationLink { AudioConversionView(service: model.container.conversion) } label: {
                Label("conversion.title", systemImage: "arrow.triangle.2.circlepath").frame(minHeight: 44)
            }
        } header: {
            Text(model.uiText("Dışa aktarma", "Export")).textCase(nil)
        }
    }

    @ViewBuilder private var exportContent: some View {
        Section {
            instruction("1", title: model.uiText("Seçim süresi", "Selection length"), message: model.localized("editor.durationRule"))
            instruction("2", title: model.uiText("Kaynak dosya", "Source file"),
                message: model.uiText("Projeyi açıp sesi dinle. Kaynak bulunamıyorsa dosyayı yeniden içe aktar.",
                    "Open the project and preview the sound. If the source is missing, import the file again."))
            instruction("3", title: model.uiText("Boş alan", "Free space"),
                message: model.uiText("iPhone'da çalışma kopyası ve çıktı için yeterli boş alan olduğundan emin ol.",
                    "Make sure your iPhone has free space for a working copy and the export."))
        } header: {
            Text(model.uiText("Önce bunları kontrol et", "Check these first")).textCase(nil)
        }
        Section {
            if model.currentProject != nil {
                NavigationLink { ExportView() } label: {
                    Label(model.uiText("Dışa aktarma ekranını aç", "Open export"), systemImage: "square.and.arrow.up").frame(minHeight: 44)
                }
            } else { importButton }
            NavigationLink { SettingsStorageView() } label: {
                SettingsNavigationRow(title: model.localized("settings.storage"), icon: "externaldrive")
            }
        }
    }

    private var purchasesContent: some View {
        Section {
            Text(model.uiText("Pro görünmüyorsa satın alırken kullandığın Apple Hesabını kontrol et ve satın alımlarını geri yükle. Bekleyen işlemler Apple onayı veya doğrulaması tamamlanınca güncellenir.",
                "If Pro is missing, check the Apple Account used for the purchase and restore purchases. Pending transactions update after Apple approval or verification."))
                .foregroundStyle(.secondary)
            NavigationLink { PurchaseSupportView() } label: {
                SettingsNavigationRow(title: model.uiText("Satın alımlar ve geri yükleme", "Purchases and restore"), icon: "arrow.clockwise")
            }
        }
    }

    @ViewBuilder private var permissionsContent: some View {
        Section {
            Text(model.uiText("Kayıt yapmak için mikrofon izni gerekir. İzni daha önce reddettiysen iPhone Ayarları'nda Ringify için mikrofonu açabilirsin.",
                "Recording requires microphone permission. If you previously denied it, enable the microphone for Ringify in iPhone Settings."))
                .foregroundStyle(.secondary)
            Button { openSettings() } label: {
                Label(model.uiText("iPhone Ayarları'nı aç", "Open iPhone Settings"), systemImage: "gearshape").frame(minHeight: 44)
            }
        } header: {
            Text(model.uiText("Mikrofon erişimi", "Microphone access")).textCase(nil)
        }
        Section {
            Text(model.uiText("Sistem seçicisinde erişebildiğin bir dosyayı veya videoyu seç. Bulut dosyasının aygıtına indirilmesini bekle; ardından tekrar dene.",
                "Choose a file or video available in the system picker. Wait for a cloud file to download to your device, then retry."))
                .foregroundStyle(.secondary)
            importButton
        } header: {
            Text(model.uiText("Dosyalar ve Fotoğraflar", "Files and Photos")).textCase(nil)
        }
    }

    private var importFilesContent: some View {
        Section {
            Text(model.uiText("Dosyanın tam indirildiğini, okunabilir olduğunu ve iOS'un desteklediği bir biçimde olduğunu kontrol et. Video sessizse başka bir kaynak seç.",
                "Check that the file is fully downloaded, readable, and in a format supported by iOS. If a video has no audio, choose another source."))
                .foregroundStyle(.secondary)
            Text(model.uiText("Bozuk dosyayı kaynak uygulamasından yeniden dışa aktarabilirsin. Orijinal dosyan Ringify tarafından değiştirilmez.",
                "You can export a damaged file again from its source app. Ringify does not modify your original file."))
                .foregroundStyle(.secondary)
            importButton
        } header: {
            Text(model.uiText("Dosya açılmıyorsa", "If a file will not open")).textCase(nil)
        }
    }

    private var storageContent: some View {
        Section {
            Text(model.uiText("Kütüphane'den artık kullanmadığın projeleri silebilirsin. Silmek proje yuvasını boşaltır. Tüm yerel verileri silmeden önce saklamak istediğin çıktıları Dosyalar'a kaydet.",
                "Delete projects you no longer need from Library. Deleting frees a project slot. Save exports you want to keep to Files before deleting all local data."))
                .foregroundStyle(.secondary)
            NavigationLink { SettingsStorageView() } label: {
                SettingsNavigationRow(title: model.localized("settings.storage.manage"), icon: "externaldrive")
            }
        }
    }

    private var importButton: some View {
        NavigationLink { ImportSourceView() } label: {
            Label("home.create", systemImage: "plus.circle").frame(minHeight: 44)
        }
    }

    private func instruction(_ number: String, title: String, message: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "\(number).circle.fill")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private struct IssueDetailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL
    let issue: RingifyIssue

    var body: some View {
        List {
            Section {
                Label(model.localized("issue.\(issue.rawValue).title"), systemImage: issueIcon(issue))
                    .font(.headline).foregroundStyle(issueColor(issue))
                Text(model.localized("issue.\(issue.rawValue).message")).foregroundStyle(.secondary)
            }
            Section(model.uiText("Ne yapabilirsin?", "What can you do?")) {
                Text(model.localized("issue.\(issue.rawValue).action")).foregroundStyle(.secondary)
                recoveryAction
            }
        }
        .listStyle(.insetGrouped)
        .ringifyStudioAppearance()
        .navigationTitle(model.localized("issue.\(issue.rawValue).title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var recoveryAction: some View {
        switch issue {
        case .storageFailed, .insufficientStorage:
            NavigationLink { SettingsStorageView() } label: {
                SettingsNavigationRow(title: model.localized("settings.storage.manage"), icon: "externaldrive")
            }
        case .purchaseFailed:
            NavigationLink { PurchaseSupportView() } label: {
                SettingsNavigationRow(title: model.uiText("Satın alma yardımı", "Purchase help"), icon: "creditcard")
            }
        case .permissionDenied:
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Label(model.uiText("iPhone Ayarları'nı aç", "Open iPhone Settings"), systemImage: "gearshape").frame(minHeight: 44)
            }
        case .exportFailed:
            NavigationLink { HelpTopicDetailView(topic: .export) } label: {
                SettingsNavigationRow(title: model.uiText("Dışa aktarma yardımını aç", "Open export help"), icon: "square.and.arrow.up")
            }
        default:
            NavigationLink { ImportSourceView() } label: {
                Label(model.uiText("Kaynak seç", "Choose a source"), systemImage: "folder").frame(minHeight: 44)
            }
        }
    }
}

private func issueIcon(_ issue: RingifyIssue) -> String {
    switch issue {
    case .storageFailed, .insufficientStorage: "externaldrive.badge.exclamationmark"
    case .unsupportedFile, .corruptFile, .fileNotFound: "doc.badge.exclamationmark"
    case .missingAudioTrack: "speaker.slash.fill"
    case .permissionDenied: "hand.raised.fill"
    case .exportFailed: "square.and.arrow.up.trianglebadge.exclamationmark"
    case .cancelled: "xmark.circle"
    case .noSavedProject: "music.note.list"
    case .purchaseFailed: "creditcard.trianglebadge.exclamationmark"
    }
}

private func issueColor(_ issue: RingifyIssue) -> Color {
    switch issue {
    case .cancelled, .noSavedProject: .secondary
    case .permissionDenied, .insufficientStorage: RingifyTheme.warning
    default: RingifyTheme.danger
    }
}
