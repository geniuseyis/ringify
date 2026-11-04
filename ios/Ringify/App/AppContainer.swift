import Foundation
import RingifyCore

@MainActor
struct AppContainer {
    let mediaImport: any MediaImportService
    let authorizedMediaImport: any AuthorizedMediaImportService
    let metadata: any AudioMetadataService
    let extraction: any AudioExtractionService
    let waveform: any WaveformService
    let playback: any AudioPlaybackService
    let trim: any AudioTrimService
    let effects: any AudioEffectsService
    let export: any AudioExportService
    let storage: any ProjectStorageService
    let recorder: any VoiceRecordingService
    let purchases: PurchaseManager
    let directories: AppDirectories
    var conversion: any AudioConversionService = AVAudioConversionService()
    var analysis: any AudioSignalAnalyzing = AVAudioSignalAnalysisService()
    var segments: any AudioSegmentSuggesting = AVAudioSegmentSuggestionsService()
    var initialStorageError: String? = nil

    static func live() throws -> AppContainer {
        let directories = AppDirectories()
        let mediaImport = SecureMediaImportService(directories: directories)
        let metadata = AVAudioMetadataService()
        let extraction = AVAudioExtractionService()
        let waveform = AVWaveformService()
        let trim = AVAudioTrimService()
        let effects = AVAudioEffectsService()
        let export = AVAudioExportService(
            directories: directories,
            trimService: trim,
            effectsService: effects,
            metadataService: metadata
        )
        return AppContainer(
            mediaImport: mediaImport,
            authorizedMediaImport: RestrictedAuthorizedMediaImportService(importService: mediaImport),
            metadata: metadata,
            extraction: extraction,
            waveform: waveform,
            playback: AVAudioPlaybackService(),
            trim: trim,
            effects: effects,
            export: export,
            storage: try SwiftDataProjectStorageService(),
            recorder: AVVoiceRecordingService(),
            purchases: PurchaseManager(),
            directories: directories
        )
    }

    static func resilient() -> AppContainer {
        do {
            return try live()
        } catch {
            let directories = AppDirectories()
            let mediaImport = SecureMediaImportService(directories: directories)
            let metadata = AVAudioMetadataService()
            let trim = AVAudioTrimService()
            let effects = AVAudioEffectsService()
            return AppContainer(
                mediaImport: mediaImport,
                authorizedMediaImport: RestrictedAuthorizedMediaImportService(importService: mediaImport),
                metadata: metadata,
                extraction: AVAudioExtractionService(),
                waveform: AVWaveformService(),
                playback: AVAudioPlaybackService(),
                trim: trim,
                effects: effects,
                export: AVAudioExportService(
                    directories: directories,
                    trimService: trim,
                    effectsService: effects,
                    metadataService: metadata
                ),
                storage: UnavailableProjectStorageService(reason: error.localizedDescription),
                recorder: AVVoiceRecordingService(),
                purchases: PurchaseManager(),
                directories: directories,
                initialStorageError: error.localizedDescription
            )
        }
    }
}
