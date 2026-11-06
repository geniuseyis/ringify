import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 76
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
        Page(id: 2, icon: "bell.badge", title: "onboarding.use.title", message: "onboarding.use.message")
    ]

    @State private var page = 0
    let completion: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("common.skip", action: completion)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("onboarding.skip")
            }
            .padding(.horizontal, RingifyTheme.horizontalPadding)

            TabView(selection: $page) {
                ForEach(pages) { item in
                    pageContent(item).tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 8) {
                pageIndicator
                RingifyPrimaryButton(title: page == pages.count - 1 ? "common.getStarted" : "common.next") {
                    if page == pages.count - 1 { completion() } else { selectPage(page + 1) }
                }
                .accessibilityIdentifier("onboarding.continue")
            }
            .padding(.horizontal, RingifyTheme.horizontalPadding)
            .padding(.bottom, 12)
        }
        .background(RingifyTheme.background)
        .onChange(of: page) { _, next in focusedPage = next }
    }

    private func pageContent(_ item: Page) -> some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                    Image(systemName: item.icon)
                        .font(.system(size: symbolSize))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    VStack(spacing: 12) {
                        Text(item.title)
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($focusedPage, equals: item.id)
                        Text(item.message)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 0) {
            ForEach(pages) { item in
                Button { selectPage(item.id) } label: {
                    Circle()
                        .fill(item.id == page ? RingifyTheme.accent : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.uiText("\(item.id + 1). sayfa", "Page \(item.id + 1)"))
                .accessibilityAddTraits(item.id == page ? .isSelected : [])
                .accessibilityIdentifier("onboarding.page.\(item.id)")
            }
        }
    }

    private func selectPage(_ next: Int) {
        guard pages.indices.contains(next) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { page = next }
    }
}
