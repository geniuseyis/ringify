import RingifyCore
import SwiftUI

struct GlobalIssueSheet: View {
    @EnvironmentObject private var router: AppRouter
    let issue: RingifyIssue
    let detail: String?
    let dismiss: () -> Void

    var body: some View {
        ScrollView {
          VStack(spacing: 22) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(color)
            Text(LocalizedStringKey("issue.\(issue.rawValue).title"))
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(LocalizedStringKey("issue.\(issue.rawValue).message"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RingifyTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            }
            Text(LocalizedStringKey("issue.\(issue.rawValue).action"))
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("settings.help", systemImage: "questionmark.circle") {
                dismiss()
                router.push(.help)
            }
            .frame(minHeight: 44)
            .buttonStyle(.bordered)
            RingifyPrimaryButton(title: "common.done", action: dismiss)
          }
          .padding(RingifyTheme.horizontalPadding)
        }
        .presentationDetents([.medium, .large])
    }

    private var icon: String {
        switch issue {
        case .storageFailed: "externaldrive.badge.exclamationmark"
        case .unsupportedFile, .corruptFile, .fileNotFound: "doc.badge.exclamationmark"
        case .missingAudioTrack: "speaker.slash.fill"
        case .permissionDenied: "hand.raised.fill"
        case .insufficientStorage: "externaldrive.badge.exclamationmark"
        case .exportFailed: "square.and.arrow.up.trianglebadge.exclamationmark"
        case .cancelled: "xmark.circle"
        case .noSavedProject: "music.note.list"
        case .purchaseFailed: "creditcard.trianglebadge.exclamationmark"
        }
    }

    private var color: Color {
        switch issue {
        case .cancelled, .noSavedProject: .secondary
        case .permissionDenied, .insufficientStorage: RingifyTheme.warning
        default: RingifyTheme.danger
        }
    }
}
