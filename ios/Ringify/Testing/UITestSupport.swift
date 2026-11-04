#if DEBUG
import AVFoundation
import Foundation
import RingifyCore

/// Only the Debug UI-test process can select this isolated composition root.
/// Real import, waveform, playback, DSP and export services remain in use.
@MainActor enum UITestSupport {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-RingifyUITesting")
            && ProcessInfo.processInfo.environment["RINGIFY_UI_TESTING"] == "1"
    }
    static var holdsSplash: Bool {
        isEnabled && ProcessInfo.processInfo.environment["RINGIFY_UI_HOLD_SPLASH"] == "1"
    }

    static func makeModel() throws -> AppModel {
        let environment = ProcessInfo.processInfo.environment
        let name = "com.ringify.ui-tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name),
              let appearance = AppearancePreference(rawValue: environment["RINGIFY_UI_THEME"] ?? "light") else {
            throw RingifyError.corruptMedia
        }
        defaults.set(environment["RINGIFY_UI_ONBOARDING"] != "1", forKey: "ringify.hasCompletedOnboarding")
        defaults.set(try JSONEncoder().encode(UserSettings(appearance: appearance, language: .turkish)), forKey: "ringify.settings")
        let directories = AppDirectories(root: FileManager.default.temporaryDirectory
            .appendingPathComponent("RingifyUITests-\(UUID().uuidString)", isDirectory: true))
        try directories.prepare()
        let media = SecureMediaImportService(directories: directories)
        let metadata = AVAudioMetadataService(), trim = AVAudioTrimService(), effects = AVAudioEffectsService()
        let container = AppContainer(mediaImport: media,
            authorizedMediaImport: RestrictedAuthorizedMediaImportService(importService: media),
            metadata: metadata, extraction: AVAudioExtractionService(), waveform: AVWaveformService(),
            playback: AVAudioPlaybackService(), trim: trim, effects: effects,
            export: AVAudioExportService(directories: directories, trimService: trim, effectsService: effects, metadataService: metadata),
            storage: try SwiftDataProjectStorageService(inMemory: true, directories: directories),
            recorder: AVVoiceRecordingService(), purchases: PurchaseManager(startObservingTransactions: false), directories: directories)
        return AppModel(container: container, defaults: defaults)
    }

    static func prepareFixtureIfNeeded(_ model: AppModel) async {
        guard isEnabled, ProcessInfo.processInfo.environment["RINGIFY_UI_FIXTURE"] == "1",
              !model.preferenceStore.bool(forKey: "ui.fixture.prepared") else { return }
        model.preferenceStore.set(true, forKey: "ui.fixture.prepared")
        let source = model.container.directories.root.appendingPathComponent("Ringify Native Fixture.wav")
        defer { try? FileManager.default.removeItem(at: source) }
        do {
            try await UITestPCMFixture().write(to: source)
            _ = await model.prepareMedia(from: source, kind: .audioFile)
        } catch { model.present(error) }
    }
}

/// Deterministic audio, not a synthetic UI waveform. Bounded writes off MainActor.
private actor UITestPCMFixture {
    func write(to url: URL) throws {
        let rate = 48_000.0, frames = 883_200
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8_192),
              let samples = buffer.floatChannelData?[0] else { throw RingifyError.corruptMedia }
        let writer = try FinalizedPCMWriter(url: url, settings: format.settings)
        for first in stride(from: 0, to: frames, by: 8_192) {
            try Task.checkCancellation()
            let count = min(8_192, frames - first)
            buffer.frameLength = AVAudioFrameCount(count)
            for index in 0..<count {
                let time = Double(first + index) / rate
                let envelope = 0.65 + 0.35 * cos(2 * .pi * time / 1.3)
                samples[index] = Float((sin(2 * .pi * 220 * time) * 0.22 + sin(2 * .pi * 440 * time) * 0.08) * envelope)
            }
            try writer.write(from: buffer)
        }
        writer.finish()
    }
}
#endif
