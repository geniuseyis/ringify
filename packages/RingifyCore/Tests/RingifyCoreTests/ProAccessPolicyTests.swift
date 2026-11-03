import XCTest
@testable import RingifyCore

final class ProAccessPolicyTests: XCTestCase {
    func testCatalogRetainsLifetimeIdentifierAndFourDistinctPlans() {
        XCTAssertEqual(ProPlan.lifetime.productID, "com.ringify.app.pro.lifetime")
        XCTAssertEqual(Set(ProPlan.allCases.map(\.productID)).count, 4)
        XCTAssertFalse(ProPlan.lifetime.isSubscription)
        XCTAssertNil(ProPlan(productID: "unknown"))
    }
    func testNormalAndVerifiedProNewProjectQuotas() {
        XCTAssertEqual(ProAccessPolicy.normalProjectLimit, 1)
        XCTAssertEqual(ProAccessPolicy.proProjectLimit, 3)
        XCTAssertTrue(ProAccessPolicy.canCreateProject(count: 0, hasVerifiedPro: false))
        XCTAssertFalse(ProAccessPolicy.canCreateProject(count: 1, hasVerifiedPro: false))
        XCTAssertFalse(ProAccessPolicy.canCreateProject(count: 2, hasVerifiedPro: false))
        XCTAssertFalse(ProAccessPolicy.canCreateProject(count: 3, hasVerifiedPro: false))
        XCTAssertTrue(ProAccessPolicy.canCreateProject(count: 0, hasVerifiedPro: true))
        XCTAssertTrue(ProAccessPolicy.canCreateProject(count: 1, hasVerifiedPro: true))
        XCTAssertTrue(ProAccessPolicy.canCreateProject(count: 2, hasVerifiedPro: true))
        XCTAssertFalse(ProAccessPolicy.canCreateProject(count: 3, hasVerifiedPro: true))
        XCTAssertFalse(ProAccessPolicy.canCreateProject(count: 100, hasVerifiedPro: true))
        for hasVerifiedPro in [false, true] {
            XCTAssertFalse(ProAccessPolicy.canCreateProject(count: -1, hasVerifiedPro: hasVerifiedPro))
            XCTAssertFalse(ProAccessPolicy.canCreateProject(count: Int.max, hasVerifiedPro: hasVerifiedPro))
        }
    }
    func testNormalizationPreservesPriorWorkButRequiresProForNewEnable() {
        XCTAssertTrue(ProAccessPolicy.canChangeNormalization(current: true, next: true, hasVerifiedPro: false))
        XCTAssertTrue(ProAccessPolicy.canChangeNormalization(current: true, next: false, hasVerifiedPro: false))
        XCTAssertFalse(ProAccessPolicy.canChangeNormalization(current: false, next: true, hasVerifiedPro: false))
        XCTAssertTrue(ProAccessPolicy.canChangeNormalization(current: false, next: true, hasVerifiedPro: true))
    }
    func testRecognizedVerifiedCurrentProductTypesOnly() {
        for plan in ProPlan.allCases {
            XCTAssertEqual(ProAccessPolicy.entitledPlan(productID: plan.productID,
                kind: plan.isSubscription ? .autoRenewable : .nonConsumable,
                verified: true, isCurrentEntitlement: true, revoked: false, isUpgraded: false), plan)
        }
        XCTAssertNil(ProAccessPolicy.entitledPlan(productID: ProPlan.lifetime.productID,
            kind: .autoRenewable, verified: true, isCurrentEntitlement: true, revoked: false, isUpgraded: false))
    }
    func testUnverifiedRevokedUpgradedAndStaleTransactionsNeverAuthorize() {
        for flags in [(false, true, false, false), (true, false, false, false),
                      (true, true, true, false), (true, true, false, true)] {
            XCTAssertNil(ProAccessPolicy.entitledPlan(productID: ProPlan.yearly.productID,
                kind: .autoRenewable, verified: flags.0, isCurrentEntitlement: flags.1,
                revoked: flags.2, isUpgraded: flags.3))
        }
    }
    func testAuthoritativeCurrentSubscriptionAllowsStoreKitGracePeriod() {
        // There is deliberately no independent expiration-date gate: StoreKit
        // currentEntitlements decides whether grace access is still current.
        XCTAssertEqual(ProAccessPolicy.entitledPlan(productID: ProPlan.monthly.productID,
            kind: .autoRenewable, verified: true, isCurrentEntitlement: true,
            revoked: false, isUpgraded: false), .monthly)
        XCTAssertNil(ProAccessPolicy.entitledPlan(productID: ProPlan.monthly.productID,
            kind: .autoRenewable, verified: true, isCurrentEntitlement: false,
            revoked: false, isUpgraded: false))
    }
}
