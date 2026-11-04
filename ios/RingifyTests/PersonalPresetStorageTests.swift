import Foundation
import RingifyCore
import XCTest
@testable import Ringify

@MainActor
final class PersonalPresetStorageTests: XCTestCase {
    func testSaveRenameDeleteAndFullResetRoundTripInBothAdapters() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let stores: [any ProjectStorageService] = [InMemoryProjectStorageService(),
            try SwiftDataProjectStorageService(inMemory: true, directories: AppDirectories(root: root))]
        for storage in stores {
            var preset = UserAudioPreset(name: "Voice", effects: AudioEffectSettings(volume: 0.8, studio: StudioAudioPreset.warm.settings))
            try await storage.saveAudioPreset(preset)
            let initial = try await storage.audioPresets()
            XCTAssertEqual(initial, [preset])
            preset.name = "Renamed"
            try await storage.saveAudioPreset(preset)
            let renamed = try await storage.audioPresets()
            XCTAssertEqual(renamed, [preset])
            try await storage.deleteAudioPreset(id: preset.id)
            let empty = try await storage.audioPresets()
            XCTAssertTrue(empty.isEmpty)
            try await storage.saveAudioPreset(preset)
            try await storage.deleteAll()
            let cleared = try await storage.audioPresets()
            XCTAssertTrue(cleared.isEmpty)
        }
    }
    func testDuplicateNamesAndInvalidSettingsDoNotOverwriteTheSavedPreset() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = try SwiftDataProjectStorageService(inMemory: true, directories: AppDirectories(root: root))
        let original = UserAudioPreset(name: "Voice", effects: .neutral)
        try await storage.saveAudioPreset(original)
        for invalid in [UserAudioPreset(name: "voice", effects: .neutral),
                        UserAudioPreset(id: original.id, name: "Voice", effects: AudioEffectSettings(volume: .nan), createdAt: original.createdAt)] {
            do { try await storage.saveAudioPreset(invalid); XCTFail("Must reject duplicate/invalid preset") }
            catch { XCTAssertNotNil(error as? RingifyError) }
        }
        let restored = try await storage.audioPresets()
        XCTAssertEqual(restored, [original])
    }
}
