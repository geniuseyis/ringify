import RingifyCore
import SwiftUI

// Presentation copy follows the app's existing, persisted language preference.
extension AppModel {
    func uiText(_ turkish: String, _ english: String) -> String {
        settings.language == .turkish ? turkish : english
    }
}

/// A plain tinted symbol, a title and an optional trailing value. The enclosing
/// NavigationLink draws the chevron, so a row without one simply shows information.
struct SettingsNavigationRow: View {
    let title: String
    let icon: String
    var value: String? = nil
    var tint: Color? = nil

    var body: some View {
        HStack(spacing: 8) {
            Label {
                Text(title)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                symbol
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                Text(value)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var symbol: some View {
        if let tint {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
        } else {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        }
    }
}

struct RingifyPrivacyView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section {
                Label(model.uiText("Dosyaların bu aygıtta", "Your files stay on this device"), systemImage: "iphone")
                    .font(.headline)
                Text("settings.privacy.summary").foregroundStyle(.secondary)
            }
            Section(model.uiText("Satın alımlar", "Purchases")) {
                Text("premium.privacy.body").foregroundStyle(.secondary)
            }
            Section(model.uiText("İzinler", "Permissions")) {
                Text(model.uiText(
                    "Mikrofon izni kayıt başlatıldığında istenir. Fotoğraflar ve Dosyalar için sistem seçicilerini kullanırsın.",
                    "Microphone permission is requested when you start recording. Photos and Files use the system pickers."))
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RingifyTermsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section(model.uiText("Kullanım", "Use")) {
                Text(model.uiText(
                    "Yalnızca kullanma iznin olan sesleri ve videoları içe aktar. Kaynak dosyan değiştirilmez; düzenlemeler Ringify'ın yerel kopyası üzerinde yapılır.",
                    "Import audio and video you have permission to use. Your source file is unchanged; edits use Ringify's local copy."))
            }
            Section(model.uiText("App Store satın alımları", "App Store purchases")) {
                Text("premium.terms").foregroundStyle(.secondary)
                if let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    Link(destination: terms) {
                        Label("premium.eula", systemImage: "arrow.up.right.square").frame(minHeight: 44)
                    }
                }
            }
            Section {
                NavigationLink { RingifyPrivacyView() } label: {
                    SettingsNavigationRow(title: model.localized("settings.privacy"), icon: "hand.raised")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(model.uiText("Kullanım Koşulları", "Terms of Use"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
