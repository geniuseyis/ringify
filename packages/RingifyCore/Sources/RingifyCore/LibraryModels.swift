import Foundation

/// Organization is independent of the project's editable audio and export identity.
public struct ProjectLibraryMetadata: Codable, Equatable, Sendable {
    public var favorite: Bool
    public var collectionIDs: Set<UUID>

    public init(favorite: Bool = false, collectionIDs: Set<UUID> = []) {
        self.favorite = favorite
        self.collectionIDs = collectionIDs
    }

    public static let empty = ProjectLibraryMetadata()

    public func validate() throws {
        guard collectionIDs.count <= 128 else { throw RingifyError.corruptMedia }
    }

    private enum CodingKeys: String, CodingKey { case favorite, collectionIDs }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let identifiers = try values.decode([UUID].self, forKey: .collectionIDs)
        let unique = Set(identifiers)
        guard identifiers.count == unique.count else { throw RingifyError.corruptMedia }
        self.init(favorite: try values.decode(Bool.self, forKey: .favorite), collectionIDs: unique)
        try validate()
    }

    public func encode(to encoder: any Encoder) throws {
        try validate()
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(favorite, forKey: .favorite)
        try values.encode(collectionIDs.sorted { $0.uuidString < $1.uuidString }, forKey: .collectionIDs)
    }
}

public struct ProjectCollection: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public let createdAt: Date

    public init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    public static func validatedName(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RingifyError.invalidFilename(.empty) }
        guard trimmed.count <= 60 else { throw RingifyError.invalidFilename(.tooLong(maximum: 60)) }
        guard !trimmed.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            throw RingifyError.invalidFilename(.reservedName)
        }
        return trimmed
    }

    public func validate() throws {
        guard try Self.validatedName(name) == name else { throw RingifyError.invalidFilename(.reservedName) }
        guard createdAt.timeIntervalSinceReferenceDate.isFinite else { throw RingifyError.corruptMedia }
    }

    private enum CodingKeys: String, CodingKey { case id, name, createdAt }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try values.decode(UUID.self, forKey: .id),
                  name: try values.decode(String.self, forKey: .name),
                  createdAt: try values.decode(Date.self, forKey: .createdAt))
        try validate()
    }
}

public enum LibraryMetadataChange: Equatable, Sendable {
    case favorite(Bool)
    case addToCollection(UUID)
    case removeFromCollection(UUID)
    case clearCollections

    public func applying(to current: ProjectLibraryMetadata) throws -> ProjectLibraryMetadata {
        try current.validate()
        var result = current
        switch self {
        case .favorite(let favorite): result.favorite = favorite
        case .addToCollection(let id): result.collectionIDs.insert(id)
        case .removeFromCollection(let id): result.collectionIDs.remove(id)
        case .clearCollections: result.collectionIDs.removeAll()
        }
        try result.validate()
        return result
    }
}

public enum LibraryAccessPolicy {
    /// Existing organization survives entitlement expiry; removal remains available.
    public static func canApply(change: LibraryMetadataChange, current: ProjectLibraryMetadata, hasVerifiedPro: Bool) -> Bool {
        guard let next = try? change.applying(to: current) else { return false }
        if next == current || hasVerifiedPro { return true }
        switch change {
        case .favorite(let favorite): return !favorite
        case .addToCollection: return false
        case .removeFromCollection, .clearCollections: return true
        }
    }
}

public enum LibraryStatusFilter: String, Codable, CaseIterable, Identifiable, Sendable {
    case all, drafts, ready
    public var id: String { rawValue }
}

public enum LibrarySortOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    case recentlyEdited, newest, name, duration
    public var id: String { rawValue }
}

public enum LibraryCollectionFilter: Codable, Equatable, Hashable, Sendable {
    case all
    case unfiled
    case collection(UUID)
}

public struct LibraryPreferences: Codable, Equatable, Sendable {
    public var status: LibraryStatusFilter
    public var sort: LibrarySortOrder
    public var favoritesOnly: Bool
    public var collection: LibraryCollectionFilter

    public init(status: LibraryStatusFilter = .all, sort: LibrarySortOrder = .recentlyEdited,
                favoritesOnly: Bool = false, collection: LibraryCollectionFilter = .all) {
        self.status = status
        self.sort = sort
        self.favoritesOnly = favoritesOnly
        self.collection = collection
    }
}

public struct LibraryQueryUseCase: Sendable {
    public init() {}

    /// Invalid durations remain discoverable for recovery and sort after valid durations.
    public func callAsFunction(_ projects: [RingtoneProject], query: String,
                               preferences: LibraryPreferences, locale: Locale = .current) -> [RingtoneProject] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return projects.filter { project in
            if !text.isEmpty && ![project.name, project.sourceFilename].contains(where: {
                $0.range(of: text, options: [.caseInsensitive, .diacriticInsensitive], locale: locale) != nil
            }) { return false }
            if preferences.favoritesOnly && !project.library.favorite { return false }
            switch preferences.status {
            case .all: break
            case .drafts: if project.status == .exported { return false }
            case .ready: if project.status != .exported { return false }
            }
            switch preferences.collection {
            case .all: break
            case .unfiled: if !project.library.collectionIDs.isEmpty { return false }
            case .collection(let id): if !project.library.collectionIDs.contains(id) { return false }
            }
            return true
        }.sorted { lhs, rhs in
            let order: ComparisonResult
            switch preferences.sort {
            case .recentlyEdited:
                order = compare(lhs.updatedAt.timeIntervalSinceReferenceDate, rhs.updatedAt.timeIntervalSinceReferenceDate, ascending: false)
            case .newest:
                order = compare(lhs.createdAt.timeIntervalSinceReferenceDate, rhs.createdAt.timeIntervalSinceReferenceDate, ascending: false)
            case .name:
                order = lhs.name.compare(rhs.name, options: [.caseInsensitive, .diacriticInsensitive, .numeric], locale: locale)
            case .duration:
                order = compare(lhs.selection.duration, rhs.selection.duration, ascending: true, rejectNegative: true)
            }
            return order == .orderedSame ? lhs.id.uuidString < rhs.id.uuidString : order == .orderedAscending
        }
    }

    private func compare(_ lhs: Double, _ rhs: Double, ascending: Bool, rejectNegative: Bool = false) -> ComparisonResult {
        let lhsValid = lhs.isFinite && (!rejectNegative || lhs >= 0)
        let rhsValid = rhs.isFinite && (!rejectNegative || rhs >= 0)
        if lhsValid != rhsValid { return lhsValid ? .orderedAscending : .orderedDescending }
        guard lhsValid, lhs != rhs else { return .orderedSame }
        return (ascending ? lhs < rhs : lhs > rhs) ? .orderedAscending : .orderedDescending
    }
}
