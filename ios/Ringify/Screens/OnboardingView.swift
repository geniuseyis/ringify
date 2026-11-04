import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var focusedPage: Int?

    struct Page: Identifiable {
        let id: Int
        let icon: String
        let title: LocalizedStringKey
        let message: LocalizedStringKey
    }

    private let pages = [
        Page(id: 0, icon: "waveform", title: "onboarding.import.title", message: "onboarding.import.message"),
        Page(id: 1, icon: "scissors", title: "onboarding.edit.title", message: "onboarding.edit.message"),
        Page(id: 2, icon: "bell", title: "onboarding.use.title", message: "onboarding.use.message")
    ]

    @State private var page = 0
    let completion: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ringify").font(.title3.bold())
                Spacer()
                Button("common.skip", action: completion)
                    .foregroundStyle(page == 0 ? RingifyTheme.AppleV2.accent : Color.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("onboarding.skip")
            }
            .padding(.horizontal, RingifyTheme.horizontalPadding)
            .padding(.top, 12)

            TabView(selection: $page) {
                ForEach(pages) { item in
                    ScrollView {
                        VStack(spacing: 28) {
                            illustration(item)
                            VStack(spacing: 14) {
                                Text("0\(item.id + 1) / 03")
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                Text(item.title)
                                    .font(.largeTitle.bold())
                                    .accessibilityAddTraits(.isHeader)
                                    .accessibilityFocused($focusedPage, equals: item.id)
                                Text(item.message)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, RingifyTheme.horizontalPadding)
                        .padding(.vertical, typeSize.isAccessibilitySize ? 16 : 32)
                    }
                    .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    ForEach(pages) { item in
                        Button { selectPage(item.id) } label: {
                            Circle().fill(item.id == page ? RingifyTheme.AppleV2.accent : Color.secondary.opacity(0.3))
                                .frame(width: 7, height: 7)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(model.uiText("\(item.id + 1). sayfa", "Page \(item.id + 1)"))
                        .accessibilityAddTraits(item.id == page ? .isSelected : [])
                        .accessibilityIdentifier("onboarding.page.\(item.id)")
                    }
                }
                HStack(spacing: 12) {
                    if page > 0 {
                        Button { selectPage(page - 1) } label: {
                            Image(systemName: "chevron.left").frame(width: 44, height: 52)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(model.uiText("Geri", "Back"))
                    }
                    Button {
                        if page == pages.count - 1 { completion() } else { selectPage(page + 1) }
                    } label: {
                        Text(LocalizedStringKey(page == pages.count - 1 ? "common.getStarted" : "common.next"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RingifyTheme.AppleV2.action)
                    .accessibilityIdentifier("onboarding.continue")
                }
            }
            .padding(.horizontal, RingifyTheme.horizontalPadding)
            .padding(.bottom, 20)
        }
        .background(RingifyTheme.pageBackground)
        .onChange(of: page) { _, next in focusedPage = next }
    }

    private func illustration(_ item: Page) -> some View {
        VStack(spacing: 18) {
            Image(systemName: item.icon)
                .font(.system(size: typeSize.isAccessibilitySize ? 38 : 58, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: typeSize.isAccessibilitySize ? 88 : 140, height: typeSize.isAccessibilitySize ? 88 : 140)
                .background(RingifyTheme.brandGradient, in: Circle())
            HStack(spacing: 20) {
                Image(systemName: item.id == 0 ? "film" : item.id == 1 ? "waveform" : "doc.badge.checkmark")
                if item.id == 0 { Image(systemName: "mic") }
            }
            .font(.title2)
            .foregroundStyle(RingifyTheme.AppleV2.accent)
        }
        .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? 120 : 240)
        .accessibilityHidden(true)
    }

    private func selectPage(_ next: Int) {
        guard pages.indices.contains(next) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { page = next }
    }
}
