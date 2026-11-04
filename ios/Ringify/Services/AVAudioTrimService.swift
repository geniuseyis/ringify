@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import RingifyCore

actor AVAudioTrimService: AudioTrimService {
    func trimPCM(sourceURL: URL, selection: EditSelection, destinationURL: URL) async throws -> URL {
        try Task.checkCancellation()
        guard sourceURL.isFileURL, destinationURL.isFileURL,
              sourceURL.standardizedFileURL.resolvingSymlinksInPath() != destinationURL.standardizedFileURL.resolvingSymlinksInPath(),
              destinationURL.pathExtension.lowercased() == "caf",
              !FileManager.default.fileExists(atPath: destinationURL.path) else { throw RingifyError.corruptMedia }
        let input = try AVAudioFile(forReading: sourceURL, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = input.processingFormat
        guard format.sampleRate.isFinite, (8_000...192_000).contains(format.sampleRate),
              (1...2).contains(format.channelCount), input.length > 0,
              Double(input.length) / format.sampleRate <= 1_800 else { throw RingifyError.corruptMedia }
        let actualDuration = Double(input.length) / format.sampleRate
        guard selection.end <= actualDuration + 0.1 else { throw RingifyError.corruptMedia }
        _ = try ValidateSelectionUseCase()(selection, sourceDuration: max(actualDuration, selection.end))
        let first = Int64((selection.start * format.sampleRate).rounded())
        let end = min(input.length, Int64((selection.end * format.sampleRate).rounded()))
        guard first >= 0, end > first, Double(end - first) / format.sampleRate >= 1 - 1 / format.sampleRate else { throw RingifyError.corruptMedia }
        input.framePosition = first
        var fileSettings = format.settings
        fileSettings[AVLinearPCMIsNonInterleaved] = false
        let output = try AVAudioFile(forWriting: destinationURL, settings: fileSettings,
            commonFormat: .pcmFormatFloat32, interleaved: false)
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: destinationURL) } }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8_192) else { throw RingifyError.corruptMedia }
        var remaining = end - first
        while remaining > 0 {
            try Task.checkCancellation()
            try input.read(into: buffer, frameCount: AVAudioFrameCount(min(8_192, remaining)))
            guard buffer.frameLength > 0, let pointers = buffer.floatChannelData else { throw RingifyError.corruptMedia }
            for channel in 0..<Int(format.channelCount) {
                for frame in 0..<Int(buffer.frameLength) where !pointers[channel][frame].isFinite { throw RingifyError.corruptMedia }
            }
            try output.write(from: buffer)
            remaining -= Int64(buffer.frameLength)
        }
        try Task.checkCancellation()
        completed = true
        return destinationURL
    }

    func trim(sourceURL: URL, selection: EditSelection, destinationURL: URL) async throws -> URL {
        try Task.checkCancellation()
        guard sourceURL.isFileURL, destinationURL.isFileURL,
              sourceURL.standardizedFileURL.resolvingSymlinksInPath() != destinationURL.standardizedFileURL.resolvingSymlinksInPath(),
              !FileManager.default.fileExists(atPath: destinationURL.path) else { throw RingifyError.corruptMedia }
        let asset = AVURLAsset(url: sourceURL)
        let sourceDuration = try await asset.load(.duration).seconds
        _ = try ValidateSelectionUseCase()(selection, sourceDuration: sourceDuration)
        guard !(try await asset.loadTracks(withMediaType: .audio)).isEmpty else {
            throw RingifyError.missingAudioTrack
        }
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw RingifyError.exportFailed(reason: "Unable to create trim session")
        }
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: destinationURL) } }
        session.outputURL = destinationURL
        session.outputFileType = .m4a
        session.timeRange = CMTimeRange(
            start: CMTime(seconds: selection.start, preferredTimescale: 600),
            duration: CMTime(seconds: selection.duration, preferredTimescale: 600)
        )
        try await AVFoundationExportSupport.run(session)
        guard FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw RingifyError.exportVerificationFailed
        }
        completed = true
        return destinationURL
    }
}
