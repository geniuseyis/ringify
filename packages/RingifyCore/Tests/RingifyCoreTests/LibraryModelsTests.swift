import Foundation
import XCTest
@testable import RingifyCore

private actor LegacyLibraryAdapter: ProjectStorageService {
    func projects() async throws -> [RingtoneProject] { [] }
    func project(id: UUID) async throws -> RingtoneProject? { nil }
    func save(_ project: RingtoneProject) async throws {}
    func delete(id: UUID) async throws {}
    func deleteAll() async throws {}
}

final class LibraryModelsTests: XCTestCase {
    private let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    private func project(id: UUID? = nil, name: String = "Tone", duration: Double = 3,
                         favorite: Bool = false, collections: Set<UUID> = [], status: ProjectStatus = .draft,
                         created: Double = 10, updated: Double = 20) -> RingtoneProject {
        RingtoneProject(id: id ?? UUID(), name: name, sourceFilename: "source.wav",
            sourceURL: URL(fileURLWithPath: "/tmp/source.wav"), sourceKind: .audioFile,
            sourceDuration: 8, selection: EditSelection(start: 0, end: duration), status: status,
            createdAt: Date(timeIntervalSinceReferenceDate: created), updatedAt: Date(timeIntervalSinceReferenceDate: updated),
            library: ProjectLibraryMetadata(favorite: favorite, collectionIDs: collections))
    }

    private func projectJSON(_ project: RingtoneProject) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(project)) as? [String: Any])
    }

    func testLegacyProjectWithoutLibraryPreservesAdvancedAudioAndAllOriginalFields() throws {
        var original = project(id: first)
        original.effects = AudioEffectSettings(volume: 0.7, fadeInDuration: 0.2, normalize: true,
            studio: StudioAudioPreset.telephone.settings)
        original.exportedURL = URL(fileURLWithPath: "/tmp/finished.m4a")
        original.waveformSamples = [0.2, 0.7]
        var json = try projectJSON(original)
        json.removeValue(forKey: "library")
        let decoded = try JSONDecoder().decode(RingtoneProject.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.library, .empty)
    }

    func testPresentNullPartialOrMalformedLibraryNeverFallsBackToEmpty() throws {
        let original = project()
        let payloads: [Any] = [NSNull(), ["favorite": true], ["favorite": false, "collectionIDs": ["not-a-uuid"]]]
        for payload in payloads {
            var json = try projectJSON(original)
            json["library"] = payload
            XCTAssertThrowsError(try JSONDecoder().decode(RingtoneProject.self,
                from: JSONSerialization.data(withJSONObject: json)))
        }
    }

    func testMetadataRoundTripHasStableIdentifierOrderAndRejectsDuplicatesOrOversize() throws {
        let metadata = ProjectLibraryMetadata(favorite: true, collectionIDs: [second, first])
        let encoded = try JSONEncoder().encode(metadata)
        XCTAssertEqual(try JSONDecoder().decode(ProjectLibraryMetadata.self, from: encoded), metadata)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(json["collectionIDs"] as? [String], [first.uuidString, second.uuidString])
        let duplicate = Data("{\"favorite\":false,\"collectionIDs\":[\"\(first)\",\"\(first)\"]}".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectLibraryMetadata.self, from: duplicate))
        let excessive = ProjectLibraryMetadata(collectionIDs: Set((0..<129).map { _ in UUID() }))
        XCTAssertThrowsError(try excessive.validate())
        XCTAssertThrowsError(try JSONEncoder().encode(excessive))
    }

    func testCollectionNamesTrimValidateGraphemeLengthAndRejectControls() throws {
        XCTAssertEqual(try ProjectCollection.validatedName("  My Sounds\n"), "My Sounds")
        XCTAssertEqual(try ProjectCollection.validatedName(String(repeating: "🎵", count: 60)).count, 60)
        for invalid in [" \n", String(repeating: "a", count: 61), "Voice\u{0000}Notes", "Voice\nNotes"] {
            XCTAssertThrowsError(try ProjectCollection.validatedName(invalid))
        }
    }

    func testCollectionDecodeRejectsNoncanonicalOrInvalidMetadata() throws {
        let original = ProjectCollection(id: first, name: "Nature", createdAt: Date(timeIntervalSinceReferenceDate: 5))
        XCTAssertEqual(try JSONDecoder().decode(ProjectCollection.self, from: JSONEncoder().encode(original)), original)
        XCTAssertThrowsError(try ProjectCollection(name: " Nature ").validate())
        XCTAssertThrowsError(try ProjectCollection(name: "Nature", createdAt: Date(timeIntervalSinceReferenceDate: .infinity)).validate())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json["name"] = " Nature "
        XCTAssertThrowsError(try JSONDecoder().decode(ProjectCollection.self, from: JSONSerialization.data(withJSONObject: json)))
    }

    func testMetadataChangesPreserveUnrelatedFieldsAndAreIdempotent() throws {
        let original = ProjectLibraryMetadata(favorite: true, collectionIDs: [first])
        let added = try LibraryMetadataChange.addToCollection(second).applying(to: original)
        XCTAssertTrue(added.favorite)
        XCTAssertEqual(added.collectionIDs, [first, second])
        XCTAssertEqual(try LibraryMetadataChange.addToCollection(second).applying(to: added), added)
        let unfavorited = try LibraryMetadataChange.favorite(false).applying(to: added)
        XCTAssertEqual(unfavorited.collectionIDs, added.collectionIDs)
        let removed = try LibraryMetadataChange.removeFromCollection(first).applying(to: unfavorited)
        XCTAssertEqual(removed.collectionIDs, [second])
        XCTAssertEqual(try LibraryMetadataChange.clearCollections.applying(to: original), ProjectLibraryMetadata(favorite: true))
        XCTAssertEqual(original.collectionIDs, [first])
    }

    func testAccessPolicyAllowsPreservationRemovalAndRequiresProForNewOrganization() {
        let saved = ProjectLibraryMetadata(favorite: true, collectionIDs: [first])
        XCTAssertTrue(LibraryAccessPolicy.canApply(change: .favorite(true), current: saved, hasVerifiedPro: false))
        XCTAssertTrue(LibraryAccessPolicy.canApply(change: .favorite(false), current: saved, hasVerifiedPro: false))
        XCTAssertTrue(LibraryAccessPolicy.canApply(change: .addToCollection(first), current: saved, hasVerifiedPro: false))
        XCTAssertTrue(LibraryAccessPolicy.canApply(change: .removeFromCollection(first), current: saved, hasVerifiedPro: false))
        XCTAssertTrue(LibraryAccessPolicy.canApply(change: .clearCollections, current: saved, hasVerifiedPro: false))
        XCTAssertFalse(LibraryAccessPolicy.canApply(change: .favorite(true), current: .empty, hasVerifiedPro: false))
        XCTAssertFalse(LibraryAccessPolicy.canApply(change: .addToCollection(second), current: saved, hasVerifiedPro: false))
        XCTAssertTrue(LibraryAccessPolicy.canApply(change: .addToCollection(second), current: saved, hasVerifiedPro: true))
    }

    func testQueryCombinesStatusFavoriteAndMultipleCollectionMemberships() {
        let match = project(id: first, favorite: true, collections: [first, second], status: .exported)
        let draft = project(id: second, favorite: true, collections: [first])
        let plain = project(favorite: false, collections: [first], status: .exported)
        let preferences = LibraryPreferences(status: .ready, favoritesOnly: true, collection: .collection(second))
        XCTAssertEqual(LibraryQueryUseCase()([draft, plain, match], query: "", preferences: preferences), [match])
        XCTAssertEqual(LibraryQueryUseCase()([draft, match], query: "", preferences: LibraryPreferences(status: .drafts)), [draft])
    }

    func testSearchMatchesNameOrSourceIgnoringCaseDiacriticsAndOuterWhitespace() {
        var named = project(id: first, name: "Café")
        named.sourceFilename = "recording.wav"
        var source = project(id: second, name: "Other")
        source.sourceFilename = "CAFÉ session.m4a"
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(LibraryQueryUseCase()([source, named], query: "  cafe  ", preferences: .init(), locale: locale).map(\.id), [first, second])
        XCTAssertTrue(LibraryQueryUseCase()([named], query: "absent", preferences: .init(), locale: locale).isEmpty)
    }

    func testUnfiledFilterAndStableTiesAcrossEverySort() {
        let a = project(id: first), b = project(id: second)
        let filed = project(collections: [first])
        for sort in LibrarySortOrder.allCases {
            let preferences = LibraryPreferences(sort: sort, collection: .unfiled)
            XCTAssertEqual(LibraryQueryUseCase()([b, filed, a], query: "", preferences: preferences).map(\.id), [first, second])
        }
    }

    func testDurationSortKeepsInvalidProjectsDiscoverableAfterValidOnes() {
        let good = project(duration: 2), later = project(duration: 5)
        let invalid = [project(id: first, duration: .nan), project(id: second, duration: .infinity), project(duration: -1)]
        let result = LibraryQueryUseCase()(invalid + [later, good], query: "", preferences: .init(sort: .duration))
        XCTAssertEqual(Array(result.prefix(2)).map(\.id), [good.id, later.id])
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(Set(result.dropFirst(2).map(\.id)), Set(invalid.map(\.id)))
    }

    func testEachSortUsesItsOwnFieldAndNumericLocalizedNames() {
        let a = project(id: first, name: "Tone 2", duration: 5, created: 30, updated: 10)
        let b = project(id: second, name: "Tone 10", duration: 2, created: 10, updated: 30)
        let query = LibraryQueryUseCase()
        XCTAssertEqual(query([a, b], query: "", preferences: .init(sort: .recentlyEdited)).map(\.id), [second, first])
        XCTAssertEqual(query([a, b], query: "", preferences: .init(sort: .newest)).map(\.id), [first, second])
        XCTAssertEqual(query([b, a], query: "", preferences: .init(sort: .name), locale: Locale(identifier: "en_US")).map(\.id), [first, second])
        XCTAssertEqual(query([a, b], query: "", preferences: .init(sort: .duration)).map(\.id), [second, first])
    }

    func testPreferencesRoundTripAndRejectInvalidEnumValues() throws {
        let original = LibraryPreferences(status: .drafts, sort: .duration, favoritesOnly: true, collection: .collection(first))
        XCTAssertEqual(try JSONDecoder().decode(LibraryPreferences.self, from: JSONEncoder().encode(original)), original)
        XCTAssertEqual(LibraryPreferences(), LibraryPreferences(status: .all, sort: .recentlyEdited, favoritesOnly: false, collection: .all))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json["sort"] = "unexpected"
        XCTAssertThrowsError(try JSONDecoder().decode(LibraryPreferences.self, from: JSONSerialization.data(withJSONObject: json)))
    }

    @MainActor func testLegacyStorageAdaptersFailExplicitlyForUnsupportedOrganization() async {
        let adapter = LegacyLibraryAdapter()
        do { _ = try await adapter.collections(); XCTFail("Expected unsupported storage") }
        catch { XCTAssertNotNil(error as? RingifyError) }
        do { try await adapter.saveCollection(ProjectCollection(name: "Nature")); XCTFail("Expected unsupported storage") }
        catch { XCTAssertNotNil(error as? RingifyError) }
        do { try await adapter.deleteCollection(id: first); XCTFail("Expected unsupported storage") }
        catch { XCTAssertNotNil(error as? RingifyError) }
        do { _ = try await adapter.updateLibraryMetadata(projectIDs: [first], change: .favorite(true)); XCTFail("Expected unsupported storage") }
        catch { XCTAssertNotNil(error as? RingifyError) }
    }
}
