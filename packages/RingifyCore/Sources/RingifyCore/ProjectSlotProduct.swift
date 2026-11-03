import Foundation

/// Individually restorable non-consumables; never a local credit balance.
public struct ProjectSlotProduct: Hashable, Identifiable, Sendable {
    public static let maximumCount = 20
    public static let all = (1...maximumCount).compactMap { Self(index: $0) }
    public let index: Int
    public var id: String { productID }
    public var productID: String { "com.ringify.app.project-slot." + String(format: "%02d", index) }
    public init?(index: Int) {
        guard (1...Self.maximumCount).contains(index) else { return nil }; self.index = index
    }
    public init?(productID: String) {
        guard let value = Self.all.first(where: { $0.productID == productID }) else { return nil }; self = value
    }
    public static func nextUnowned(in owned: Set<Self>) -> Self? { all.first { !owned.contains($0) } }
    public static func entitlement(productID: String, kind: ProProductKind, verified: Bool,
                                   isCurrent: Bool, revoked: Bool, isUpgraded: Bool) -> Self? {
        guard verified, isCurrent, kind == .nonConsumable, !revoked, !isUpgraded else { return nil }
        return Self(productID: productID)
    }
}
