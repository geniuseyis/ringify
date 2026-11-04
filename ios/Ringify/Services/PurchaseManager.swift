import Foundation
import Combine
import RingifyCore
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    enum State: Equatable {
        case idle, loading, purchasing, pending, purchased
        case failed(String)
    }

    // Preserve the original non-consumable ID for existing lifetime owners.
    static let proProductID = ProPlan.lifetime.productID
    @Published private(set) var products: [Product] = []
    @Published private(set) var verifiedPlans: Set<ProPlan> = []
    @Published private(set) var state: State = .idle
    @Published private(set) var isBusy = false
    @Published private(set) var pendingPlan: ProPlan?
    @Published private(set) var slotProducts: [Product] = []
    @Published private(set) var verifiedSlots: Set<ProjectSlotProduct> = []
    @Published private(set) var pendingSlot: ProjectSlotProduct?
    @Published private(set) var slotState: State = .idle
    var isPro: Bool { !verifiedPlans.isEmpty }
    var hasLifetime: Bool { verifiedPlans.contains(.lifetime) }
    var proProduct: Product? { product(for: .lifetime) }
    var projectLimit: Int { ProAccessPolicy.projectLimit(hasVerifiedPro: isPro, purchasedSlots: verifiedSlots) }
    var nextSlot: ProjectSlotProduct? { ProjectSlotProduct.nextUnowned(in: verifiedSlots) }
    private var settledState: State {
        pendingPlan != nil || pendingSlot != nil ? .pending : isPro ? .purchased : .idle
    }
    private var updateTask: Task<Void, Never>?
    private var bootstrapTask: Task<Void, Never>?
    private var refreshGeneration = 0

    init(startObservingTransactions: Bool = true) {
        guard startObservingTransactions else { return }
        updateTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled, let self else { return }
                guard case .verified(let transaction) = result else { continue }
                let plan = ProPlan(productID: transaction.productID), slot = ProjectSlotProduct(productID: transaction.productID)
                guard plan.map({ self.kind(transaction.productType) == ($0.isSubscription ? .autoRenewable : .nonConsumable) }) == true
                    || (slot != nil && transaction.productType == .nonConsumable) else { continue }
                await transaction.finish()
                // A transaction update alone is not proof that this requested
                // product is in the authoritative current entitlement snapshot.
                await self.refreshEntitlements()
            }
        }
        bootstrapTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshEntitlements()
            await self.loadProducts()
        }
    }
    deinit { updateTask?.cancel(); bootstrapTask?.cancel() }

    func product(for plan: ProPlan) -> Product? { products.first { $0.id == plan.productID } }
    func product(for slot: ProjectSlotProduct) -> Product? { slotProducts.first { $0.id == slot.productID } }

    func loadProducts() async {
        guard !isBusy else { return }
        isBusy = true
        state = .loading
        defer { isBusy = false }
        do {
            let fetched = try await Product.products(for: ProPlan.allCases.map(\.productID) + ProjectSlotProduct.all.map(\.productID))
            guard !Task.isCancelled else { state = .idle; return }
            products = ProPlan.allCases.compactMap { plan in
                fetched.first { $0.id == plan.productID && matches($0, plan: plan) }
            }
            slotProducts = ProjectSlotProduct.all.compactMap { slot in
                fetched.first { $0.id == slot.productID && $0.type == .nonConsumable }
            }
            state = settledState
        } catch { state = .failed(error.localizedDescription) }
    }

    func purchasePro() async { await purchase(.lifetime) }

    func purchase(_ plan: ProPlan) async {
        guard !isBusy, pendingPlan == nil, pendingSlot == nil else { return }
        guard !hasLifetime else { state = .purchased; return }
        guard let product = product(for: plan), matches(product, plan: plan) else {
            state = .failed("premium.store.unavailable")
            return
        }
        isBusy = true
        state = .purchasing
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                let transaction: Transaction
                switch result {
                case .verified(let value): transaction = value
                case .unverified(_, let error): throw error
                }
                guard transaction.productID == plan.productID,
                      kind(transaction.productType) == (plan.isSubscription ? .autoRenewable : .nonConsumable),
                      transaction.revocationDate == nil, !transaction.isUpgraded else {
                    state = .failed("premium.store.verificationFailed")
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
                // Purchase success alone is not proof that current access exists.
                pendingPlan = verifiedPlans.contains(plan) ? nil : plan
                state = settledState
            case .pending:
                pendingPlan = plan
                state = .pending
            case .userCancelled:
                state = settledState
            @unknown default:
                state = .failed("premium.store.unknown")
            }
        } catch { state = .failed(error.localizedDescription) }
    }

    func purchaseNextSlot() async {
        guard !isBusy, pendingPlan == nil, pendingSlot == nil else { return }
        guard isPro else { slotState = .failed("premium.slot.requiresPro"); return }
        guard let slot = nextSlot else { slotState = .failed("premium.slot.full"); return }
        guard let product = product(for: slot), product.type == .nonConsumable else {
            slotState = .failed("premium.store.unavailable"); return
        }
        isBusy = true; slotState = .purchasing
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                let transaction: Transaction
                switch result {
                case .verified(let value): transaction = value
                case .unverified(_, let error): throw error
                }
                guard transaction.productID == slot.productID, transaction.productType == .nonConsumable,
                      transaction.revocationDate == nil, !transaction.isUpgraded else {
                    slotState = .failed("premium.store.verificationFailed"); return
                }
                await transaction.finish()
                await refreshEntitlements()
                // Approval may arrive after Pro expires: preserve ownership,
                // but projectLimit still remains Normal until Pro is active.
                pendingSlot = verifiedSlots.contains(slot) ? nil : slot
                slotState = pendingSlot == nil ? .purchased : .pending
                state = settledState
            case .pending: pendingSlot = slot; slotState = .pending; state = settledState
            case .userCancelled: slotState = .idle; state = settledState
            @unknown default: slotState = .failed("premium.store.unknown")
            }
        } catch { slotState = .failed(error.localizedDescription) }
    }

    func restorePurchases() async {
        guard !isBusy else { return }
        isBusy = true
        state = .loading
        defer { isBusy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if let pendingPlan, verifiedPlans.contains(pendingPlan) { self.pendingPlan = nil }
            if let pendingSlot, verifiedSlots.contains(pendingSlot) { self.pendingSlot = nil }
            state = pendingPlan != nil || pendingSlot != nil ? .pending :
                isPro ? .purchased : verifiedSlots.isEmpty ? .failed("premium.store.nothingToRestore") : .idle
            slotState = self.pendingSlot != nil ? .pending : verifiedSlots.isEmpty ? .idle : .purchased
        } catch { state = .failed(error.localizedDescription) }
    }

    func refreshEntitlements() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        var current: Set<ProPlan> = []
        var slots: Set<ProjectSlotProduct> = []
        for await result in Transaction.currentEntitlements {
            guard !Task.isCancelled else { return }
            guard case .verified(let transaction) = result else { continue }
            if let plan = ProAccessPolicy.entitledPlan(
                productID: transaction.productID, kind: kind(transaction.productType),
                verified: true, isCurrentEntitlement: true,
                revoked: transaction.revocationDate != nil, isUpgraded: transaction.isUpgraded
            ) { current.insert(plan) }
            if let slot = ProjectSlotProduct.entitlement(productID: transaction.productID, kind: kind(transaction.productType),
                verified: true, isCurrent: true, revoked: transaction.revocationDate != nil, isUpgraded: transaction.isUpgraded) {
                slots.insert(slot)
            }
        }
        guard !Task.isCancelled, generation == refreshGeneration else { return }
        verifiedPlans = current
        verifiedSlots = slots
        if let pendingPlan, current.contains(pendingPlan) { self.pendingPlan = nil }
        if let pendingSlot, slots.contains(pendingSlot) { self.pendingSlot = nil }
        if !isBusy {
            if pendingPlan != nil || pendingSlot != nil || isPro || state == .purchased || state == .pending {
                state = settledState
            }
            if pendingSlot != nil { slotState = .pending }
            else if !slots.isEmpty { slotState = .purchased }
            else if slotState == .purchased { slotState = .idle }
        }
    }

    private func kind(_ type: Product.ProductType) -> ProProductKind {
        switch type {
        case .autoRenewable: .autoRenewable
        case .nonConsumable: .nonConsumable
        default: .unsupported
        }
    }
    private func matches(_ product: Product, plan: ProPlan) -> Bool {
        if plan == .lifetime { return product.type == .nonConsumable }
        guard product.type == .autoRenewable, let period = product.subscription?.subscriptionPeriod,
              period.value == 1 else { return false }
        switch plan {
        case .weekly: return period.unit == .week
        case .monthly: return period.unit == .month
        case .yearly: return period.unit == .year
        case .lifetime: return false
        }
    }
}
