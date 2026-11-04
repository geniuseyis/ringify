import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel
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
        .task {
            guard isLaunching else { return }
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeOut(duration: 0.25)) { isLaunching = false }
        }
        .sheet(item: $model.issue, onDismiss: { model.errorMessage = nil }) { issue in
            GlobalIssueSheet(issue: issue, detail: model.errorMessage) {
                model.issue = nil
            }
        }
        .sheet(isPresented: $model.requiresProForProjectLimit) {
            NavigationStack {
                PremiumView()
                    .safeAreaInset(edge: .top) {
                        HStack {
                            Text("premium.limit.title").font(.headline)
                            Spacer()
                            Button("common.done") { model.requiresProForProjectLimit = false }
                        }
                        .padding()
                        .background(.bar)
                    }
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            TabView(selection: $router.selectedTab) {
                HomeView()
                    .tabItem { Label("tab.home", systemImage: "house.fill") }
                    .tag(AppTab.home)

                AudioEditorView()
                    .tabItem { Label("tab.studio", systemImage: "waveform") }
                    .tag(AppTab.studio)

                LibraryView()
                    .tabItem { Label("tab.library", systemImage: "folder") }
                    .tag(AppTab.library)

                SettingsView()
                    .tabItem { Label("tab.settings", systemImage: "gearshape.fill") }
                    .tag(AppTab.settings)
            }
            .tint(RingifyTheme.Studio.accent)
            .modifier(AppNavigationDestination())
        }
    }
}
