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
                    .font(.largeTitle)
                    .foregroundStyle(color)
                issueText("title")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                issueText("message")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RingifyTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                issueText("action")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("settings.help", systemImage: "questionmark.circle") {
                    dismiss()
                    router.push(.help)
                }
                .frame(minHeight: 44)
                .ringifySecondaryAction()
            }
            .padding(RingifyTheme.horizontalPadding)
        }
        .ringifyBottomBar {
            RingifyPrimaryButton(title: "common.done", action: dismiss)
        }
        .presentationDetents([.medium, .large])
    }

    // The key must reach LocalizedStringKey as a String. As an interpolated literal,
    // Swift would look up "issue.%@.title" and the sheet would show the raw key.
    private func issueText(_ part: String) -> Text {
        let key = "issue.\(issue.rawValue).\(part)"
        return Text(LocalizedStringKey(key))
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
