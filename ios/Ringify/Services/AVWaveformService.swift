@preconcurrency import AVFoundation
import Foundation
import RingifyCore

actor AVWaveformService: WaveformService {
    func samples(for audioURL: URL, sampleCount: Int) async throws -> [Float] {
        guard sampleCount > 0 else { return [] }
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw RingifyError.fileNotFound(audioURL)
        }
        let file = try AVAudioFile(forReading: audioURL)
        let format = file.processingFormat
        let totalFrames = max(1, Int(file.length))
        let framesPerBucket = max(1, Double(totalFrames) / Double(sampleCount))
        let chunkSize: AVAudioFrameCount = 8_192
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkSize) else {
            throw RingifyError.corruptMedia
        }
        var result = Array(repeating: Float.zero, count: sampleCount)
        var globalFrame = 0

        while file.framePosition < file.length {
            try Task.checkCancellation()
            try file.read(into: buffer, frameCount: chunkSize)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
            let channelCount = Int(format.channelCount)
            for frame in 0..<Int(buffer.frameLength) {
                var magnitude: Float = 0
                for channel in 0..<channelCount {
                    magnitude = max(magnitude, abs(channels[channel][frame]))
                }
                let bucket = min(sampleCount - 1, Int(Double(globalFrame) / framesPerBucket))
                result[bucket] = max(result[bucket], magnitude)
                globalFrame += 1
            }
        }
        let peak = result.max() ?? 0
        guard peak > 0 else { return result }
        return result.map { min(1, $0 / peak) }
    }
}
