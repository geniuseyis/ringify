import XCTest
@testable import Ringify

@MainActor final class NavigationRoutingTests: XCTestCase {
    func testOnlySelectedTabReceivesPushedRoutes() {
        let router = AppRouter()
        router.push(.importSource)
        router.push(.recorder)
        XCTAssertEqual(router.navigationPath(for: .home), [.importSource, .recorder])
        for tab in [AppTab.studio, .library, .settings] { XCTAssertTrue(router.navigationPath(for: tab).isEmpty) }
    }

    func testInactiveStackUpdatesCannotEraseOrInjectActiveRoutes() {
        let router = AppRouter()
        router.push(.importSource)
        router.setNavigationPath([], for: .studio)
        router.setNavigationPath([.premium], for: .library)
        XCTAssertEqual(router.path, [.importSource])
    }

    func testActiveStackPopAndRootResetUpdateTheSharedRouter() {
        let router = AppRouter()
        router.selectedTab = .studio
        router.push(.effects)
        router.push(.ringtonePreview)
        router.setNavigationPath([.effects], for: .studio)
        XCTAssertEqual(router.path, [.effects])
        router.popToRoot()
        XCTAssertTrue(router.navigationPath(for: .studio).isEmpty)
    }

    func testTabChangeClearsOldFlowAndLatePopCannotAffectNewFlow() {
        let router = AppRouter()
        router.push(.guide)
        router.selectedTab = .library
        XCTAssertTrue(router.path.isEmpty)
        router.push(.premium)
        router.setNavigationPath([], for: .home)
        XCTAssertEqual(router.path, [.premium])
        router.selectedTab = .library
        XCTAssertEqual(router.path, [.premium], "Reassigning the same tab must retain its current flow")
    }
}
