import XCTest
@testable import RingifyCore

final class ProjectSlotProductTests: XCTestCase {
    func testTwentyStrictDistinctProductIDsAndNextUnownedSlot() throws {
        XCTAssertEqual(ProjectSlotProduct.all.count, 20)
        XCTAssertEqual(Set(ProjectSlotProduct.all.map(\.productID)).count, 20)
        XCTAssertEqual(ProjectSlotProduct.all.first?.productID, "com.ringify.app.project-slot.01")
        XCTAssertEqual(ProjectSlotProduct.all.last?.productID, "com.ringify.app.project-slot.20")
        for invalid in ["com.ringify.app.project-slot.1", "com.ringify.app.project-slot.00", "com.ringify.app.project-slot.21", "com.ringify.app.pro.lifetime", "../01"] {
            XCTAssertNil(ProjectSlotProduct(productID: invalid))
        }
        let first = try XCTUnwrap(ProjectSlotProduct(index: 1)), third = try XCTUnwrap(ProjectSlotProduct(index: 3))
        XCTAssertEqual(ProjectSlotProduct.nextUnowned(in: [first, third])?.index, 2)
        XCTAssertNil(ProjectSlotProduct.nextUnowned(in: Set(ProjectSlotProduct.all)))
        XCTAssertNil(ProjectSlotProduct(index: Int.max)); XCTAssertNil(ProjectSlotProduct(index: -1))
    }
    func testQuotaCountsUniqueOwnershipOnlyWhileProIsActiveAndNeverDeletesProjects() {
        let all = Set(ProjectSlotProduct.all)
        XCTAssertEqual(ProAccessPolicy.projectLimit(hasVerifiedPro: true, purchasedSlots: all), 23)
        XCTAssertEqual(ProAccessPolicy.projectLimit(hasVerifiedPro: false, purchasedSlots: all), 1)
        let first = ProjectSlotProduct.all[0], duplicates: Set<ProjectSlotProduct> = [first, first]
        XCTAssertEqual(ProAccessPolicy.projectLimit(hasVerifiedPro: true, purchasedSlots: duplicates), 4)
        XCTAssertFalse(ProAccessPolicy.canCreateProject(count: 4, hasVerifiedPro: true, purchasedSlots: duplicates))
        XCTAssertTrue(ProAccessPolicy.canCreateProject(count: 3, hasVerifiedPro: true, purchasedSlots: duplicates))
        XCTAssertFalse(ProAccessPolicy.canCreateProject(count: 3, hasVerifiedPro: false, purchasedSlots: duplicates))
        XCTAssertTrue(ProAccessPolicy.canCreateProject(count: 0, hasVerifiedPro: false, purchasedSlots: duplicates))
    }
    func testOnlyCurrentVerifiedNonrevokedNonconsumablesGrantSlots() {
        let product = ProjectSlotProduct.all[0]
        XCTAssertEqual(ProjectSlotProduct.entitlement(productID: product.productID, kind: .nonConsumable,
            verified: true, isCurrent: true, revoked: false, isUpgraded: false), product)
        for flags in [(false, true, false, false), (true, false, false, false), (true, true, true, false), (true, true, false, true)] {
            XCTAssertNil(ProjectSlotProduct.entitlement(productID: product.productID, kind: .nonConsumable,
                verified: flags.0, isCurrent: flags.1, revoked: flags.2, isUpgraded: flags.3))
        }
        for kind in [ProProductKind.autoRenewable, .unsupported] {
            XCTAssertNil(ProjectSlotProduct.entitlement(productID: product.productID, kind: kind,
                verified: true, isCurrent: true, revoked: false, isUpgraded: false))
        }
    }
}
