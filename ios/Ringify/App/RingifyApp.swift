import SwiftUI

@main
struct RingifyApp: App {
    @StateObject private var model: AppModel
    @StateObject private var router = AppRouter()

    init() {
        #if DEBUG
        if UITestSupport.isEnabled {
            do { _model = StateObject(wrappedValue: try UITestSupport.makeModel()) }
            catch { fatalError("Isolated UI test setup failed: \(error)") }
            return
        }
        #endif
        _model = StateObject(wrappedValue: AppModel(container: AppContainer.resilient()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .defaultAppStorage(model.preferenceStore)
                .environmentObject(model)
                .environmentObject(router)
                .environmentObject(model.container.purchases)
                .environment(\.locale, Locale(identifier: model.settings.language.rawValue))
                .preferredColorScheme(model.preferredColorScheme)
                .tint(RingifyTheme.accent)
                .task {
                    #if DEBUG
                    await UITestSupport.prepareFixtureIfNeeded(model)
                    #endif
                }
        }
    }
}
