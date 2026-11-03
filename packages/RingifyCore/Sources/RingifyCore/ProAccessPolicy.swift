import Foundation

public enum ProPlan: String, CaseIterable, Identifiable, Hashable, Sendable {
    case weekly, monthly, yearly, lifetime
    public var id: String { rawValue }
    public var productID: String { "com.ringify.app.pro.\(rawValue)" }
    public var isSubscription: Bool { self != .lifetime }
    public init?(productID: String) {
        guard let plan = Self.allCases.first(where: { $0.productID == productID }) else { return nil }
        self = plan
    }
}

public enum ProProductKind: Equatable, Sendable { case autoRenewable, nonConsumable, unsupported }

public enum ProAccessPolicy {
    public static let normalProjectLimit = 1
    public static let proProjectLimit = 3

    public static func projectLimit(hasVerifiedPro: Bool, purchasedSlots: Set<ProjectSlotProduct> = []) -> Int {
        hasVerifiedPro ? proProjectLimit + purchasedSlots.count : normalProjectLimit
    }

    public static func canCreateProject(count: Int, hasVerifiedPro: Bool, purchasedSlots: Set<ProjectSlotProduct> = []) -> Bool {
        count >= 0 && count < projectLimit(hasVerifiedPro: hasVerifiedPro, purchasedSlots: purchasedSlots)
    }

    public static func canChangeNormalization(current: Bool, next: Bool, hasVerifiedPro: Bool) -> Bool {
        !next || current || hasVerifiedPro
    }

    public static func canChangeStudioEffects(current: StudioAudioSettings, next: StudioAudioSettings, hasVerifiedPro: Bool) -> Bool {
        guard (try? next.validate()) != nil else { return false }
        return next.isNeutral || next == current || hasVerifiedPro
    }

    // Call only for verified snapshots from StoreKit's currentEntitlements.
    // That sequence includes Billing Grace Period. A past expirationDate alone
    // must not reject a subscription that StoreKit still considers current.
    public static func entitledPlan(productID: String, kind: ProProductKind,
                                    verified: Bool, isCurrentEntitlement: Bool,
                                    revoked: Bool, isUpgraded: Bool) -> ProPlan? {
        guard verified, isCurrentEntitlement, !revoked, !isUpgraded,
              let plan = ProPlan(productID: productID) else { return nil }
        switch (plan, kind) {
        case (.lifetime, .nonConsumable): return plan
        case (.weekly, .autoRenewable), (.monthly, .autoRenewable), (.yearly, .autoRenewable): return plan
        default: return nil
        }
    }
}
