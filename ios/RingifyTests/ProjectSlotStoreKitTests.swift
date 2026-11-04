import Foundation
import RingifyCore
import StoreKitTest
import XCTest
@testable import Ringify

/// Must run serially: SKTestSession has one global test environment.
/// Source only on Windows; these tests require an Xcode-hosted iOS test run.
@MainActor
final class ProjectSlotStoreKitTests: XCTestCase {
    func testExistingWeeklyProCannotClearPendingLifetimeDuringRefreshReloadOrRestore() async throws {
        let session = try session(); defer { session.clearTransactions(); session.resetToDefaultState() }
        let manager = PurchaseManager(startObservingTransactions: false)
        try session.buyProduct(productIdentifier: ProPlan.weekly.productID)
        try await wait(manager, until: { manager.verifiedPlans.contains(.weekly) })
        await manager.loadProducts(); session.askToBuyEnabled = true
        await manager.purchase(.lifetime)
        XCTAssertEqual(manager.pendingPlan, .lifetime)
        XCTAssertEqual(manager.state, .pending)
        await manager.refreshEntitlements()
        XCTAssertTrue(manager.isPro)
        XCTAssertFalse(manager.hasLifetime)
        XCTAssertEqual(manager.pendingPlan, .lifetime)
        XCTAssertEqual(manager.state, .pending)
        await manager.loadProducts()
        XCTAssertEqual(manager.pendingPlan, .lifetime)
        XCTAssertEqual(manager.state, .pending)
        let transactions = session.allTransactions().count
        await manager.purchaseNextSlot()
        XCTAssertEqual(session.allTransactions().count, transactions)
        await manager.restorePurchases()
        XCTAssertEqual(manager.pendingPlan, .lifetime)
        XCTAssertEqual(manager.state, .pending)
    }

    func testOwningFirstSlotCannotFulfillPendingSecondSlotUntilItsApproval() async throws {
        let session = try session(); defer { session.clearTransactions(); session.resetToDefaultState() }
        let manager = PurchaseManager(startObservingTransactions: false)
        let first = ProjectSlotProduct.all[0], second = ProjectSlotProduct.all[1]
        try session.buyProduct(productIdentifier: ProPlan.lifetime.productID)
        try session.buyProduct(productIdentifier: first.productID)
        try await wait(manager, until: { manager.isPro && manager.verifiedSlots.contains(first) })
        await manager.loadProducts(); session.askToBuyEnabled = true
        await manager.purchaseNextSlot()
        await manager.refreshEntitlements()
        XCTAssertEqual(manager.pendingSlot, second)
        XCTAssertEqual(manager.slotState, .pending)
        XCTAssertEqual(manager.state, .pending)
        XCTAssertEqual(manager.projectLimit, 4)
        await manager.restorePurchases()
        XCTAssertEqual(manager.pendingSlot, second)
        XCTAssertEqual(manager.state, .pending)
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == second.productID })
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        try await wait(manager, until: { manager.verifiedSlots.contains(second) })
        XCTAssertNil(manager.pendingSlot)
        XCTAssertEqual(manager.projectLimit, 5)
        XCTAssertEqual(manager.state, .purchased)
    }

    private func session() throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Ringify", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState(); session.clearTransactions(); session.disableDialogs = true; session.storefront = "TUR"
        return session
    }
    private func wait(_ manager: PurchaseManager, until predicate: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while ContinuousClock.now < deadline {
            await manager.refreshEntitlements()
            if predicate() { return }; try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("StoreKit entitlement did not converge"); throw RingifyError.corruptMedia
    }
    // The synchronous test API supports the project's iOS 17.0 baseline.
    // Replace with buyProduct(identifier:options:) after its SDK availability is verified.
    func testPurchaseAndFreshManagerRestoreUniqueSlotWithoutLocalCounter() async throws {
        let session = try session(); defer { session.clearTransactions(); session.resetToDefaultState() }
        let manager = PurchaseManager(startObservingTransactions: false)
        await manager.purchaseNextSlot()
        XCTAssertEqual(manager.verifiedSlots.count, 0); XCTAssertEqual(manager.projectLimit, 1)
        try session.buyProduct(productIdentifier: ProPlan.lifetime.productID)
        try await wait(manager, until: { manager.isPro })
        await manager.loadProducts()
        XCTAssertEqual(manager.slotProducts.count, 20)
        await manager.purchaseNextSlot()
        try await wait(manager, until: { manager.verifiedSlots.count == 1 })
        XCTAssertEqual(manager.projectLimit, 4); XCTAssertEqual(manager.nextSlot?.index, 2)
        await manager.refreshEntitlements(); XCTAssertEqual(manager.projectLimit, 4)
        let fresh = PurchaseManager(startObservingTransactions: false)
        await fresh.restorePurchases()
        try await wait(fresh, until: { fresh.verifiedSlots.count == 1 && fresh.isPro })
        XCTAssertEqual(fresh.projectLimit, 4)
    }
    func testRefundRemovesSlotAndReoffersSameIndex() async throws {
        let session = try session(); defer { session.clearTransactions(); session.resetToDefaultState() }
        let slot = ProjectSlotProduct.all[0], manager = PurchaseManager(startObservingTransactions: false)
        try session.buyProduct(productIdentifier: ProPlan.lifetime.productID)
        try session.buyProduct(productIdentifier: slot.productID)
        try await wait(manager, until: { manager.isPro && manager.verifiedSlots.count == 1 })
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == slot.productID })
        try session.refundTransaction(identifier: transaction.identifier)
        try await wait(manager, until: { manager.verifiedSlots.isEmpty })
        XCTAssertEqual(manager.projectLimit, 3); XCTAssertEqual(manager.nextSlot, slot)
    }
    func testProRevocationRetainsSlotOwnershipButRestoresNormalCreationLimit() async throws {
        let session = try session(); defer { session.clearTransactions(); session.resetToDefaultState() }
        let manager = PurchaseManager(startObservingTransactions: false)
        try session.buyProduct(productIdentifier: ProPlan.lifetime.productID)
        try session.buyProduct(productIdentifier: ProjectSlotProduct.all[0].productID)
        try await wait(manager, until: { manager.isPro && manager.verifiedSlots.count == 1 })
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == ProPlan.lifetime.productID })
        try session.refundTransaction(identifier: transaction.identifier)
        try await wait(manager, until: { !manager.isPro })
        XCTAssertEqual(manager.verifiedSlots.count, 1); XCTAssertEqual(manager.projectLimit, 1)
    }
    func testAskToBuyPendingCannotIncreaseCapacityUntilVerifiedApproval() async throws {
        let session = try session(); defer { session.clearTransactions(); session.resetToDefaultState() }
        let manager = PurchaseManager(startObservingTransactions: false), slot = ProjectSlotProduct.all[0]
        try session.buyProduct(productIdentifier: ProPlan.lifetime.productID)
        try await wait(manager, until: { manager.isPro })
        await manager.loadProducts(); session.askToBuyEnabled = true
        await manager.purchaseNextSlot()
        XCTAssertEqual(manager.slotState, .pending); XCTAssertEqual(manager.projectLimit, 3)
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == slot.productID })
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        try await wait(manager, until: { manager.verifiedSlots.contains(slot) })
        XCTAssertEqual(manager.projectLimit, 4); XCTAssertNil(manager.pendingSlot)
    }
}
