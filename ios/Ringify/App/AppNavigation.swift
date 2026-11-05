import Foundation
import SwiftUI

enum AppTab: Hashable {
    case home
    case studio
    case library
    case settings
}

enum AppRoute: Hashable {
    case importSource
    case conversion
    case recorder
    case editor
    case effects
    case ringtonePreview
    case export
    case guide
    case premium
    case help
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var selectedTab: AppTab = .home {
        didSet { if oldValue != selectedTab { path.removeAll() } }
    }

    func push(_ route: AppRoute) { path.append(route) }
    func popToRoot() { path.removeAll() }
    func navigationPath(for tab: AppTab) -> [AppRoute] { selectedTab == tab ? path : [] }
    func setNavigationPath(_ value: [AppRoute], for tab: AppTab) {
        guard selectedTab == tab else { return }
        path = value
    }
}

struct AppNavigationDestination: ViewModifier {
    @EnvironmentObject private var model: AppModel
    func body(content: Content) -> some View {
        content.navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .importSource: ImportSourceView()
            case .conversion: AudioConversionView(service: model.container.conversion)
            case .recorder: VoiceRecorderView()
            case .editor: AudioEditorView()
            case .effects: AudioEffectsView()
            case .ringtonePreview: RingtonePreviewView()
            case .export: ExportView()
            case .guide: RingtoneGuideView()
            case .premium: PremiumView()
            case .help: HelpAndErrorStatesView()
            }
        }
    }
}
