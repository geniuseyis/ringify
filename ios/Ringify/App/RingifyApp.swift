import SwiftUI

@main
struct RingifyApp: App {
    @StateObject private var model: AppModel
    @StateObject private var router = AppRouter()

    init() {
        _model = StateObject(wrappedValue: AppModel(container: AppContainer.resilient()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(router)
                .environmentObject(model.container.purchases)
                .environment(\.locale, Locale(identifier: model.settings.language.rawValue))
                .preferredColorScheme(model.preferredColorScheme)
                .tint(RingifyTheme.accent)
        }
    }
}
