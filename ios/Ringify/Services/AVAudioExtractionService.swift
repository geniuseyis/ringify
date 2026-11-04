@preconcurrency import AVFoundation
import Foundation
import RingifyCore

actor AVAudioExtractionService: AudioExtractionService {
    func extractAudio(from mediaURL: URL, to destinationURL: URL) async throws -> URL {
        try Task.checkCancellation()
        let asset = AVURLAsset(url: mediaURL)
        guard !(try await asset.loadTracks(withMediaType: .audio)).isEmpty else {
            throw RingifyError.missingAudioTrack
        }
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw RingifyError.exportFailed(reason: "Unable to create audio extraction session")
        }
        try? FileManager.default.removeItem(at: destinationURL)
        session.outputURL = destinationURL
        session.outputFileType = .m4a
        session.shouldOptimizeForNetworkUse = false
        try await AVFoundationExportSupport.run(session)
        guard FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw RingifyError.exportVerificationFailed
        }
        return destinationURL
    }
}
