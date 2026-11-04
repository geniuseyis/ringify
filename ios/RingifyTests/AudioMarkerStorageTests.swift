import Foundation
import RingifyCore
import XCTest
@testable import Ringify

@MainActor
final class AudioMarkerStorageTests: XCTestCase {
    func testMarkersRoundTripAndSurviveStaleContentSavesWithoutChangingExport() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let stores: [any ProjectStorageService] = [InMemoryProjectStorageService(),
            try SwiftDataProjectStorageService(inMemory: true, directories: AppDirectories(root: root))]
        let original = RingtoneProject(name: "Tone", sourceFilename: "source.wav", sourceURL: URL(fileURLWithPath: "/source.wav"),
            sourceKind: .audioFile, sourceDuration: 3, selection: EditSelection(start: 0, end: 3),
            exportedURL: URL(fileURLWithPath: "/original.m4a"))
        let markers = [AudioMarker(time: 1, label: "Start")]
        for storage in stores {
            try await storage.save(original)
            _ = try await storage.updateMarkers(projectID: original.id, markers: markers)
            var stale = original; stale.effects.volume = 0.5
            try await storage.save(stale)
            let restored = try await storage.project(id: original.id)
            XCTAssertEqual(restored?.markers, markers)
            XCTAssertEqual(restored?.effects.volume, 0.5)
            XCTAssertEqual(restored?.exportedURL, original.exportedURL)
            do {
                _ = try await storage.updateMarkers(projectID: original.id, markers: [AudioMarker(time: .nan, label: "Invalid")])
                XCTFail("Invalid data must not overwrite markers")
            } catch { XCTAssertNotNil(error as? RingifyError) }
            let retained = try await storage.project(id: original.id)
            XCTAssertEqual(retained?.markers, markers)
        }
    }
}
