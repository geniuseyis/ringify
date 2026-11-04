@preconcurrency import AVFoundation
import AudioToolbox
import CoreMedia
import Foundation
import RingifyCore

// Full-file conversion is deliberately separate from the 1–29 second ringtone use case.
// AVAssetReader decodes to an owned PCM scratch file; AVAudioFile streams the second
// pass with one global anti-clipping gain. No lossy intermediate or source mutation.
actor AVAudioConversionService: AudioConversionService {
    private let root: URL
    private var ownedResults: Set<URL> = []
    init(root: URL = FileManager.default.temporaryDirectory.appendingPathComponent("RingifyConversions", isDirectory: true)) {
        self.root = root
    }

    func convert(sourceURL: URL, format: AudioConversionFormat, filename: String) async throws -> ConvertedAudio {
        try Task.checkCancellation()
        guard sourceURL.isFileURL else { throw RingifyError.unauthorizedRemoteHost }
        let access = sourceURL.startAccessingSecurityScopedResource()
        defer { if access { sourceURL.stopAccessingSecurityScopedResource() } }
        let values = try sourceURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw RingifyError.corruptMedia }
        try AudioConversionRules().validateSource(url: sourceURL, byteCount: Int64(values.fileSize ?? 0))
        switch RingtoneRules().validate(filename: filename) {
        case .failure(let issue): throw RingifyError.invalidFilename(issue)
        case .success: break
        }
        let handle = try FileHandle(forReadingFrom: sourceURL)
        let header = try handle.read(upToCount: 16) ?? Data()
        try handle.close()
        let bytes = [UInt8](header)
        let mp3 = bytes.count >= 3 && (Array(bytes.prefix(3)) == [73, 68, 51] || (bytes[0] == 255 && bytes[1] & 224 == 224))
        let mp4 = bytes.count >= 12 && String(bytes: bytes[4..<8], encoding: .ascii) == "ftyp"
        guard (sourceURL.pathExtension.lowercased() == "mp3" ? mp3 : mp4) else { throw RingifyError.corruptMedia }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let workspace = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: false)
        do {
            let staged = workspace.appendingPathComponent("source").appendingPathExtension(sourceURL.pathExtension.lowercased())
            try FileManager.default.copyItem(at: sourceURL, to: staged)
            let asset = AVURLAsset(url: staged)
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else { throw RingifyError.missingAudioTrack }
            let range = try await track.load(.timeRange)
            let descriptions = try await track.load(.formatDescriptions)
            guard let description = descriptions.first,
                  let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee else { throw RingifyError.corruptMedia }
            try AudioConversionRules().validateAudio(duration: range.duration.seconds, sampleRate: basic.mSampleRate, channels: Int(basic.mChannelsPerFrame))
            let required = Int64(range.duration.seconds * 48_000 * Double(basic.mChannelsPerFrame) * 6) + 20_000_000
            let capacity = try workspace.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let available = capacity.volumeAvailableCapacityForImportantUsage, available < required { throw RingifyError.insufficientStorage(requiredBytes: required) }
            let raw = workspace.appendingPathComponent("decoded.caf")
            try decode(track: track, range: range, channels: basic.mChannelsPerFrame, destination: raw)
            let output = workspace.appendingPathComponent(RingtoneRules().safeFilename(from: filename)).appendingPathExtension(format.rawValue)
            try encode(source: raw, destination: output, format: format)
            try Task.checkCancellation()
            let metadata = try await AVAudioMetadataService().metadata(for: output)
            let size = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 44, metadata.hasAudioTrack, metadata.duration.isFinite,
                  abs(metadata.duration - range.duration.seconds) < 0.75,
                  metadata.channelCount == Int(basic.mChannelsPerFrame),
                  (format == .wav ? metadata.formatDescription == "lpcm" : metadata.formatDescription == "aac") else {
                throw RingifyError.exportVerificationFailed
            }
            try FileManager.default.removeItem(at: raw)
            try FileManager.default.removeItem(at: staged)
            ownedResults.insert(output)
            return ConvertedAudio(url: output, duration: metadata.duration, byteCount: Int64(size))
        } catch {
            // Cleanup failures are surfaced; no journal or user-owned source is touched.
            try FileManager.default.removeItem(at: workspace)
            throw error
        }
    }

    func discard(_ result: ConvertedAudio) async throws {
        guard ownedResults.contains(result.url) else { return }
        try FileManager.default.removeItem(at: result.url.deletingLastPathComponent())
        ownedResults.remove(result.url)
    }

    private func decode(track: AVAssetTrack, range: CMTimeRange, channels: AVAudioChannelCount, destination: URL) throws {
        let composition = AVMutableComposition()
        guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw RingifyError.corruptMedia }
        try audioTrack.insertTimeRange(range, of: track, at: .zero)
        let reader = try AVAssetReader(asset: composition)
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: Int(channels), AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false]
        let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: settings)
        guard reader.canAdd(output), let pcmFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: channels, interleaved: true) else { throw RingifyError.corruptMedia }
        reader.add(output)
        let sink = try AVAudioFile(forWriting: destination, settings: pcmFormat.settings, commonFormat: .pcmFormatFloat32, interleaved: true)
        guard reader.startReading() else { throw reader.error ?? RingifyError.corruptMedia }
        defer { if reader.status == .reading { reader.cancelReading() } }
        var total: Int64 = 0
        while let sample = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            let frames = CMSampleBufferGetNumSamples(sample)
            guard frames > 0, frames <= 131_072, let data = CMSampleBufferGetDataBuffer(sample),
                  CMBlockBufferGetDataLength(data) == frames * Int(channels) * 4,
                  let pcm = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: AVAudioFrameCount(frames)),
                  let pointer = pcm.mutableAudioBufferList.pointee.mBuffers.mData else { throw RingifyError.corruptMedia }
            pcm.frameLength = AVAudioFrameCount(frames)
            guard CMBlockBufferCopyDataBytes(data, atOffset: 0, dataLength: frames * Int(channels) * 4, destination: pointer) == noErr else { throw RingifyError.corruptMedia }
            total += Int64(frames)
            guard Double(total) / 48_000 <= AudioConversionRules.maximumDuration + 0.1 else { throw RingifyError.corruptMedia }
            try sink.write(from: pcm)
        }
        guard reader.status == .completed, total > 0 else { throw reader.error ?? RingifyError.corruptMedia }
    }

    private func encode(source: URL, destination: URL, format: AudioConversionFormat) throws {
        let input = try AVAudioFile(forReading: source, commonFormat: .pcmFormatFloat32, interleaved: false)
        let pcmFormat = input.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: 8_192) else { throw RingifyError.corruptMedia }
        var peak: Float = 0
        while input.framePosition < input.length {
            try Task.checkCancellation(); try input.read(into: buffer)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { throw RingifyError.corruptMedia }
            for channel in 0..<Int(pcmFormat.channelCount) { for frame in 0..<Int(buffer.frameLength) {
                let value = channels[channel][frame]
                guard value.isFinite else { throw RingifyError.corruptMedia }
                peak = max(peak, abs(value))
            } }
        }
        input.framePosition = 0
        let gain: Float = peak > 0 ? min(1, 0.99 / peak) : 1
        var settings: [String: Any] = [AVSampleRateKey: pcmFormat.sampleRate, AVNumberOfChannelsKey: Int(pcmFormat.channelCount)]
        if format == .wav {
            settings[AVFormatIDKey] = kAudioFormatLinearPCM; settings[AVLinearPCMBitDepthKey] = 16
            settings[AVLinearPCMIsFloatKey] = false; settings[AVLinearPCMIsBigEndianKey] = false; settings[AVLinearPCMIsNonInterleaved] = false
        } else {
            settings[AVFormatIDKey] = kAudioFormatMPEG4AAC; settings[AVEncoderBitRateKey] = 192_000; settings[AVEncoderAudioQualityKey] = AVAudioQuality.high.rawValue
        }
        let output = try AVAudioFile(forWriting: destination, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        while input.framePosition < input.length {
            try Task.checkCancellation(); try input.read(into: buffer)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { throw RingifyError.corruptMedia }
            for channel in 0..<Int(pcmFormat.channelCount) { for frame in 0..<Int(buffer.frameLength) { channels[channel][frame] *= gain } }
            try output.write(from: buffer)
        }
    }
}
