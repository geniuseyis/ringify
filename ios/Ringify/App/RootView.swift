import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("ringify.hasCompletedOnboarding") private var completedOnboarding = false
    @State private var isLaunching = true

    var body: some View {
        Group {
            if isLaunching {
                LaunchView()
            } else if !completedOnboarding {
                OnboardingView {
                    completedOnboarding = true
                }
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(isLaunching ? .dark : model.preferredColorScheme)
        .task {
            guard isLaunching else { return }
            #if DEBUG
            if UITestSupport.holdsSplash { return }
            #endif
            do { try await Task.sleep(for: .milliseconds(650)) }
            catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { isLaunching = false }
        }
        .sheet(item: $model.issue, onDismiss: { model.errorMessage = nil }) { issue in
            GlobalIssueSheet(issue: issue, detail: model.errorMessage) {
                model.issue = nil
            }
        }
        .sheet(isPresented: $model.requiresProForProjectLimit) {
            NavigationStack {
                PremiumView(showsProjectLimitNotice: true)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.done") { model.requiresProForProjectLimit = false }
                        }
                    }
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            navigationRoot(for: .home) { HomeView() }
                .tabItem { Label("tab.home", systemImage: "house") }
                .tag(AppTab.home)

            navigationRoot(for: .studio) { AudioEditorView() }
                .tabItem { Label("tab.studio", systemImage: "waveform") }
                .tag(AppTab.studio)

            navigationRoot(for: .library) { LibraryView() }
                .tabItem { Label("tab.library", systemImage: "folder") }
                .tag(AppTab.library)

            navigationRoot(for: .settings) { SettingsView() }
                .tabItem { Label("tab.settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }

    private func navigationRoot<Content: View>(for tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        let root = content()
        return NavigationStack(path: Binding(get: { router.navigationPath(for: tab) },
            set: { router.setNavigationPath($0, for: tab) })) {
            root.modifier(AppNavigationDestination())
        }
        .toolbar(router.path.isEmpty ? .visible : .hidden, for: .tabBar)
    }
}
