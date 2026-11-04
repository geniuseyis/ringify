import Foundation
import UIKit
import XCTest
@testable import Ringify

@MainActor final class BundleResourcesTests: XCTestCase {
    func testAppBundlesLocalizationsAssetsAndPrivacyButNotStoreKitFixture() throws {
        for language in ["tr", "en"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: language, withExtension: "lproj"))
            let localized = try XCTUnwrap(Bundle(url: url))
            let title = localized.localizedString(forKey: "tab.home", value: nil, table: nil)
            XCTAssertFalse(title.isEmpty)
            XCTAssertNotEqual(title, "tab.home")
        }
        XCTAssertNotNil(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        XCTAssertNotNil(UIColor(named: "AccentColor", in: .main, compatibleWith: nil))
        XCTAssertNil(Bundle.main.url(forResource: "Ringify", withExtension: "storekit"))
        XCTAssertNotNil(Bundle(for: Self.self).url(forResource: "Ringify", withExtension: "storekit"))
    }
}
