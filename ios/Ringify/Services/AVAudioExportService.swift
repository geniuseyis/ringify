import Foundation
import RingifyCore
@preconcurrency import AVFoundation
import AudioToolbox

actor AVAudioExportService: AudioExportService {
    private let directories: AppDirectories
    private let trimService: any AudioTrimService
    private let effectsService: any AudioEffectsService
    private let metadataService: any AudioMetadataService

    init(
        directories: AppDirectories,
        trimService: any AudioTrimService,
        effectsService: any AudioEffectsService,
        metadataService: any AudioMetadataService
    ) {
        self.directories = directories
        self.trimService = trimService
        self.effectsService = effectsService
        self.metadataService = metadataService
    }

    nonisolated func export(_ request: ExportRequest) -> AsyncThrowingStream<ExportProgress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.perform(request, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func perform(
        _ request: ExportRequest,
        continuation: AsyncThrowingStream<ExportProgress, Error>.Continuation
    ) async throws {
        continuation.yield(.preparing)
        try Task.checkCancellation()
        let sourceMetadata = try await metadataService.metadata(for: request.sourceURL)
        guard sourceMetadata.hasAudioTrack else { throw RingifyError.missingAudioTrack }
        guard sourceMetadata.sampleRate.isFinite, (8_000...192_000).contains(sourceMetadata.sampleRate),
              (1...2).contains(sourceMetadata.channelCount), sourceMetadata.duration <= 1_800 else { throw RingifyError.corruptMedia }
        _ = try ValidateSelectionUseCase()(request.selection, sourceDuration: sourceMetadata.duration)
        switch RingtoneRules().validate(filename: request.filename) {
        case .failure(let error): throw RingifyError.invalidFilename(error)
        case .success: break
        }

        try directories.prepare()
        let outputChannels = request.effects.studio.channelMode == .mono ? 1 : request.effects.studio.channelMode == .stereo ? 2 : sourceMetadata.channelCount
        let estimate = Int64(ceil(request.selection.duration * sourceMetadata.sampleRate * Double((sourceMetadata.channelCount + outputChannels) * 4))) + 20_000_000
        if let available = try directories.exports.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage,
           available < estimate { throw RingifyError.insufficientStorage(requiredBytes: estimate) }
        let trimmedURL = directories.temporaryURL(extension: "caf")
        defer { try? FileManager.default.removeItem(at: trimmedURL) }
        _ = try await trimService.trimPCM(
            sourceURL: request.sourceURL,
            selection: request.selection,
            destinationURL: trimmedURL
        )
        let trimmedFrames = try AVAudioFile(forReading: trimmedURL).length
        continuation.yield(.processing(0.5))
        try Task.checkCancellation()

        let destination = directories.uniqueURL(
            in: directories.exports,
            filename: request.filename,
            extension: request.format.fileExtension
        )
        var shouldKeepDestination = false
        defer {
            if !shouldKeepDestination { try? FileManager.default.removeItem(at: destination) }
        }
        do {
            _ = try await effectsService.process(
                sourceURL: trimmedURL,
                destinationURL: destination,
                settings: request.effects,
                expectedDuration: request.selection.duration,
                profile: request.profile
            )
        } catch {
            throw error
        }

        try Task.checkCancellation()
        continuation.yield(.verifying)
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let resultMetadata = try await metadataService.metadata(for: destination)
        let sourceFrames = trimmedFrames
        let overlapFrames = try LoopCrossfadeRules.overlapFrames(seconds: request.effects.loopCrossfadeDuration, sampleRate: sourceMetadata.sampleRate, frames: sourceFrames)
        let renderedDuration = Double(sourceFrames - overlapFrames) / sourceMetadata.sampleRate
        let durationDifference = abs(resultMetadata.duration - renderedDuration)
        let outputFile = try AVAudioFile(forReading: destination)
        let description = outputFile.fileFormat.streamDescription.pointee
        let channels = request.effects.studio.channelMode == .mono ? 1 :
            request.effects.studio.channelMode == .stereo ? 2 : sourceMetadata.channelCount
        guard bytes > 0, resultMetadata.hasAudioTrack, durationDifference < 0.75,
              resultMetadata.channelCount == channels,
              abs(resultMetadata.sampleRate - sourceMetadata.sampleRate) < 1,
              description.mFormatID == (request.profile.bitDepth == nil ? kAudioFormatMPEG4AAC : kAudioFormatLinearPCM) else {
            throw RingifyError.exportVerificationFailed
        }
        if let depth = request.profile.bitDepth {
            guard description.mBitsPerChannel == UInt32(depth), description.mFormatFlags & kAudioFormatFlagIsFloat == 0,
                  abs(Double(outputFile.length) / outputFile.processingFormat.sampleRate - renderedDuration) <= 2 / sourceMetadata.sampleRate,
                  bytes > Int64(outputFile.length) * Int64(channels * depth / 8) else {
                throw RingifyError.exportVerificationFailed
            }
        }
        shouldKeepDestination = true
        continuation.yield(.completed(ExportedRingtone(
            url: destination,
            duration: resultMetadata.duration,
            byteCount: bytes
        )))
    }
}
