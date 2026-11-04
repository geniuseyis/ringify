import Foundation
import RingifyCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var purchases: PurchaseManager

    var body: some View {
        List {
            Section(model.uiText("Hesap", "Account")) {
                NavigationLink { PremiumView() } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "crown.fill")
                            .font(.title2).foregroundStyle(RingifyTheme.Studio.accent)
                            .frame(width: 48, height: 48)
                            .background(RingifyTheme.Studio.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ringify Pro").font(.headline)
                            Text(purchases.hasLifetime ? model.localized("premium.lifetime.active") :
                                (purchases.isPro ? model.uiText("Pro etkin", "Pro active") : model.uiText("Normal sürüm · 1 proje", "Normal plan · 1 project")))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                }
                NavigationLink { AccountDetailView() } label: {
                    SettingsNavigationRow(title: model.uiText("Hesap ve lisans", "Account and license"), icon: "checkmark.shield")
                }
                NavigationLink { PurchaseSupportView() } label: {
                    SettingsNavigationRow(title: model.uiText("Satın alımlar ve geri yükleme", "Purchases and restore"), icon: "arrow.clockwise")
                }
            }
            Section(model.uiText("Genel", "General")) {
                NavigationLink { AppearanceSettingsView() } label: {
                    SettingsNavigationRow(title: model.localized("settings.appearance"), icon: "circle.lefthalf.filled",
                        value: model.localized("settings.appearance.\(model.settings.appearance.rawValue)"))
                }
                NavigationLink { LanguageSettingsView() } label: {
                    SettingsNavigationRow(title: model.localized("settings.language"), icon: "globe",
                        value: model.settings.language == .turkish ? "Türkçe" : "English")
                }
            }
            Section(model.uiText("Ses ve dosyalar", "Audio and files")) {
                NavigationLink { ExportPreferencesView() } label: {
                    SettingsNavigationRow(title: model.localized("settings.export"), icon: "waveform", value: "M4A")
                }
                NavigationLink { SettingsStorageView() } label: {
                    SettingsNavigationRow(title: model.localized("settings.storage"), icon: "externaldrive",
                        value: model.uiText("\(model.projects.count) proje", model.projects.count == 1 ? "1 project" : "\(model.projects.count) projects"))
                }
            }
            Section(model.uiText("Gizlilik ve uygulama", "Privacy and app")) {
                NavigationLink { RingifyPrivacyView() } label: {
                    SettingsNavigationRow(title: model.localized("settings.privacy"), icon: "hand.raised")
                }
                NavigationLink { RingifyTermsView() } label: {
                    SettingsNavigationRow(title: model.uiText("Kullanım Koşulları", "Terms of Use"), icon: "doc.text")
                }
                LabeledContent("settings.version", value: ringifyAppVersion).frame(minHeight: 44)
            }
            Section(model.uiText("Yardım ve destek", "Help and support")) {
                ForEach(RingifyHelpTopic.settingsTopics) { topic in
                    NavigationLink { HelpTopicDetailView(topic: topic) } label: {
                        SettingsNavigationRow(title: topic.title(model), icon: topic.icon)
                    }
                }
                NavigationLink { HelpAndErrorStatesView() } label: {
                    SettingsNavigationRow(title: model.uiText("Destek ve geri bildirim", "Support and feedback"), icon: "lifepreserver")
                }
            }
        }
        .listStyle(.insetGrouped)
        .ringifyStudioAppearance()
        .navigationTitle("settings.title")
        .task {
            await model.reloadProjects()
            await purchases.refreshEntitlements()
        }
    }
}

private struct AccountDetailView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var purchases: PurchaseManager

    private var capacity: Int {
        purchases.projectLimit
    }

    var body: some View {
        List {
            Section(model.uiText("Durumun", "Your status")) {
                LabeledContent(model.uiText("Üyelik", "Membership"), value: purchases.isPro ? "Ringify Pro" : "Ringify Normal")
                if purchases.hasLifetime {
                    Label("premium.lifetime.active", systemImage: "checkmark.seal.fill").foregroundStyle(RingifyTheme.success)
                }
                ForEach(ProPlan.allCases.filter { purchases.verifiedPlans.contains($0) }) { plan in
                    LabeledContent(model.uiText("Doğrulanan plan", "Verified plan"),
                        value: model.localized("premium.plan.\(plan.rawValue)"))
                }
                LabeledContent(model.uiText("Kayıtlı projeler", "Saved projects"), value: "\(model.projects.count)")
                LabeledContent(model.uiText("Plan kapasitesi", "Plan capacity"), value: "\(capacity)")
                NavigationLink { ProjectCapacityView() } label: {
                    SettingsNavigationRow(title: model.uiText("Proje kapasitesi ve ek yuvalar", "Project capacity and extra slots"), icon: "square.stack")
                }
            }
            Section {
                Text(model.uiText(
                    "Ringify hesabı açman gerekmez. Pro lisansın, App Store'da kullandığın Apple Hesabının doğrulanmış satın alımlarına bağlıdır.",
                    "You do not need a Ringify account. Your Pro license follows verified purchases for the Apple Account you use with the App Store."))
                    .foregroundStyle(.secondary)
                Text("premium.legacy.preserved").font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                NavigationLink { PurchaseSupportView() } label: {
                    SettingsNavigationRow(title: model.uiText("Lisans ve satın alımlar", "License and purchases"), icon: "checkmark.seal")
                }
                NavigationLink { PremiumView() } label: {
                    SettingsNavigationRow(title: model.uiText("Pro planlarını gör", "View Pro plans"), icon: "crown")
                }
            }
        }
        .listStyle(.insetGrouped)
        .ringifyStudioAppearance()
        .navigationTitle(model.uiText("Hesap ve Lisans", "Account and License"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AppearanceSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                Picker("settings.appearance", selection: $model.settings.appearance) {
                    Text("settings.appearance.system").tag(AppearancePreference.system)
                    Text("settings.appearance.light").tag(AppearancePreference.light)
                    Text("settings.appearance.dark").tag(AppearancePreference.dark)
                }
                .pickerStyle(.inline)
            } footer: {
                Text(model.uiText("Sistem seçeneği iPhone'un görünümünü izler.", "System follows your iPhone's appearance."))
            }
        }
        .ringifyStudioAppearance()
        .navigationTitle("settings.appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LanguageSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Picker("settings.language", selection: $model.settings.language) {
                Text("Türkçe").tag(AppLanguage.turkish)
                Text("English").tag(AppLanguage.english)
            }
            .pickerStyle(.inline)
        }
        .ringifyStudioAppearance()
        .navigationTitle("settings.language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ExportPreferencesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section(model.uiText("Zil sesi çıktısı", "Ringtone output")) {
                LabeledContent("settings.export.format", value: "M4A / AAC")
                LabeledContent(model.uiText("Seçim süresi", "Selection length"), value: model.uiText("1–29 saniye", "1–29 seconds"))
                Text(model.uiText("Dosya adını her dışa aktarmada seçersin. Ses seviyesi ve fade ayarları projeye özeldir.",
                    "Choose a file name for each export. Volume and fades are set for each project."))
                    .foregroundStyle(.secondary)
            }
            Section {
                NavigationLink { AudioConversionView(service: model.container.conversion) } label: {
                    SettingsNavigationRow(title: model.localized("conversion.title"), icon: "arrow.triangle.2.circlepath", value: "WAV / M4A")
                }
                NavigationLink { RingtoneGuideView() } label: {
                    SettingsNavigationRow(title: model.localized("guide.title"), icon: "bell")
                }
            }
        }
        .listStyle(.insetGrouped)
        .ringifyStudioAppearance()
        .navigationTitle("settings.export")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingsStorageView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        List {
            Section(model.uiText("Bu iPhone'da", "On this iPhone")) {
                LabeledContent(model.uiText("Kayıtlı projeler", "Saved projects"), value: "\(model.projects.count)")
                LabeledContent(model.uiText("Taslaklar", "Drafts"), value: "\(model.projects.filter { $0.status != .exported }.count)")
                LabeledContent(model.uiText("Hazır zil sesleri", "Ready ringtones"), value: "\(model.projects.filter { $0.status == .exported }.count)")
            }
            Section {
                Text(model.uiText("Projeler, içe aktarılan medya kopyaları ve zil sesi çıktıları uygulamanın yerel alanında tutulur. Tek bir projeyi Kütüphane'den silebilirsin.",
                    "Projects, imported media copies and ringtone exports are kept in the app's local storage. Delete an individual project from Library."))
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("settings.storage.deleteAll", role: .destructive) { showDeleteConfirmation = true }
                    .frame(minHeight: 44).disabled(model.projects.isEmpty || isDeleting || model.isWorking)
                if isDeleting { ProgressView("common.processing") }
            } footer: {
                Text(model.uiText("Bu işlem Ringify içindeki tüm projeleri ve yerel medya kopyalarını kaldırır. Geri alınamaz.",
                    "This removes every Ringify project and its local media copies. It cannot be undone."))
            }
        }
        .listStyle(.insetGrouped)
        .ringifyStudioAppearance()
        .navigationTitle("settings.storage")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.reloadProjects() }
        .confirmationDialog("settings.storage.confirm", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("settings.storage.deleteAll", role: .destructive) {
                isDeleting = true
                Task {
                    await model.deleteAllProjects()
                    isDeleting = false
                }
            }
            Button("common.cancel", role: .cancel) {}
        }
    }
}

var ringifyAppVersion: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    return "\(version) (\(build))"
}
