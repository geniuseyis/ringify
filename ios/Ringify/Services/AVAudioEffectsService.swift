@preconcurrency import AVFoundation
import AudioToolbox
import Foundation
import RingifyCore

actor AVAudioEffectsService: AudioEffectsService {
    func process(sourceURL: URL, destinationURL: URL, settings: AudioEffectSettings, expectedDuration: TimeInterval) async throws -> URL {
        try await process(sourceURL: sourceURL, destinationURL: destinationURL, settings: settings,
            expectedDuration: expectedDuration, profile: .aacStandard)
    }

    func process(
        sourceURL: URL,
        destinationURL: URL,
        settings: AudioEffectSettings,
        expectedDuration: TimeInterval,
        profile: AudioOutputProfile
    ) async throws -> URL {
        try Task.checkCancellation()
        guard sourceURL.isFileURL, destinationURL.isFileURL,
              sourceURL.resolvingSymlinksInPath().standardizedFileURL != destinationURL.resolvingSymlinksInPath().standardizedFileURL,
              !FileManager.default.fileExists(atPath: destinationURL.path),
              destinationURL.pathExtension.lowercased() == profile.format.fileExtension,
              expectedDuration.isFinite, (1...29).contains(expectedDuration) else { throw RingifyError.corruptMedia }
        let input = try AVAudioFile(forReading: sourceURL, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = input.processingFormat
        guard (1...2).contains(format.channelCount), format.sampleRate.isFinite,
              format.sampleRate > 0, format.sampleRate <= 192_000, input.length > 0,
              abs(Double(input.length) / format.sampleRate - expectedDuration) < 0.75 else { throw RingifyError.corruptMedia }
        try settings.studio.validate(sampleRate: format.sampleRate)
        let peak = try scanFilteredPeak(file: input, settings: settings.studio)
        let envelope = try AudioGainEnvelope(peak: Double(peak), settings: settings,
            sampleRate: format.sampleRate, frames: input.length)
        input.framePosition = 0

        var filter = try StudioAudioFilter(settings: settings.studio, sampleRate: format.sampleRate, inputChannels: Int(format.channelCount))
        let channelCount = filter.outputChannelCount
        var crossfade = try LoopCrossfadeProcessor(seconds: settings.loopCrossfadeDuration,
            sampleRate: format.sampleRate, frames: input.length, channelCount: channelCount)
        guard let outputFormat = AVAudioFormat(standardFormatWithSampleRate: format.sampleRate, channels: AVAudioChannelCount(channelCount)) else {
            throw RingifyError.corruptMedia
        }
        var limiter: LinkedPeakLimiter?
        if settings.studio.limiterEnabled {
            limiter = try LinkedPeakLimiter(sampleRate: format.sampleRate, ceiling: settings.studio.ceiling, channelCount: channelCount)
        }

        var outputSettings: [String: Any] = [
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: channelCount
        ]
        if let bitRate = profile.bitRate {
            outputSettings[AVFormatIDKey] = kAudioFormatMPEG4AAC
            outputSettings[AVEncoderBitRateKey] = bitRate
            outputSettings[AVEncoderAudioQualityKey] = AVAudioQuality.high.rawValue
        } else {
            guard let depth = profile.bitDepth else { throw RingifyError.corruptMedia }
            outputSettings[AVFormatIDKey] = kAudioFormatLinearPCM
            outputSettings[AVLinearPCMBitDepthKey] = depth
            outputSettings[AVLinearPCMIsFloatKey] = false
            outputSettings[AVLinearPCMIsBigEndianKey] = false
            outputSettings[AVLinearPCMIsNonInterleaved] = false
        }
        let output = try AVAudioFile(
            forWriting: destinationURL,
            settings: outputSettings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: destinationURL) } }
        let chunkSize: AVAudioFrameCount = 8_192
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkSize) else {
            throw RingifyError.corruptMedia
        }
        var processedFrames: Int64 = 0
        var writtenFrames: Int64 = 0

        while input.framePosition < input.length {
            try Task.checkCancellation()
            try input.read(into: buffer, frameCount: chunkSize)
            guard buffer.frameLength > 0 else { throw RingifyError.exportVerificationFailed }
            var channels = try filter.process(readChannels(buffer))
            for frame in 0..<Int(buffer.frameLength) {
                let absoluteFrame = processedFrames + Int64(frame)
                let gain = envelope.gain(at: absoluteFrame)
                for channel in 0..<channelCount {
                    let value = Float(Double(channels[channel][frame]) * gain)
                    guard value.isFinite else { throw RingifyError.corruptMedia }
                    channels[channel][frame] = value
                }
            }
            let rendered = try limiter?.process(channels) ?? channels
            writtenFrames += try writeChannels(crossfade.process(rendered), to: output, format: outputFormat)
            processedFrames += Int64(buffer.frameLength)
        }
        // Offline lookahead delays writes, not the audio timeline. Flush exactly
        // the remaining frames so the final output retains the original length.
        if var limiter {
            let tail = try limiter.process(Array(repeating: [], count: channelCount), final: true)
            writtenFrames += try writeChannels(crossfade.process(tail), to: output, format: outputFormat)
        }
        try Task.checkCancellation()
        try crossfade.finish()
        guard processedFrames == input.length, writtenFrames == crossfade.outputFrames,
              FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw RingifyError.exportVerificationFailed
        }
        completed = true
        return destinationURL
    }

    private func scanFilteredPeak(file: AVAudioFile, settings: StudioAudioSettings) throws -> Float {
        let format = file.processingFormat
        let chunkSize: AVAudioFrameCount = 8_192
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkSize) else {
            throw RingifyError.corruptMedia
        }
        var peak: Float = 0
        var filter = try StudioAudioFilter(settings: settings, sampleRate: format.sampleRate, inputChannels: Int(format.channelCount))
        var readFrames: Int64 = 0
        while file.framePosition < file.length {
            try Task.checkCancellation()
            try file.read(into: buffer, frameCount: chunkSize)
            guard buffer.frameLength > 0 else { throw RingifyError.exportVerificationFailed }
            let channels = try filter.process(readChannels(buffer))
            for channel in channels {
                for sample in channel {
                    guard sample.isFinite else { throw RingifyError.corruptMedia }
                    peak = max(peak, abs(sample))
                }
            }
            readFrames += Int64(buffer.frameLength)
        }
        guard readFrames == file.length else { throw RingifyError.exportVerificationFailed }
        return peak
    }

    private func readChannels(_ buffer: AVAudioPCMBuffer) throws -> [[Float]] {
        guard let pointers = buffer.floatChannelData else { throw RingifyError.corruptMedia }
        return (0..<Int(buffer.format.channelCount)).map { channel in
            Array(UnsafeBufferPointer(start: pointers[channel], count: Int(buffer.frameLength)))
        }
    }

    private func writeChannels(_ channels: [[Float]], to output: AVAudioFile, format: AVAudioFormat) throws -> Int64 {
        guard channels.count == Int(format.channelCount), let count = channels.first?.count,
              channels.allSatisfy({ $0.count == count }) else { throw RingifyError.corruptMedia }
        guard count > 0 else { return 0 }
        guard count <= 32_768,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
              let pointers = buffer.floatChannelData else { throw RingifyError.corruptMedia }
        buffer.frameLength = AVAudioFrameCount(count)
        for channel in channels.indices {
            for frame in 0..<count {
                let value = channels[channel][frame]
                guard value.isFinite, abs(value) <= 1 else { throw RingifyError.corruptMedia }
                pointers[channel][frame] = value
            }
        }
        try output.write(from: buffer)
        return Int64(count)
    }
}
