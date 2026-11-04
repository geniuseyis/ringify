@preconcurrency import AVFoundation
import Foundation
import RingifyCore

actor AVAudioSignalAnalysisService: AudioSignalAnalyzing {
    func analyze(sourceURL: URL, selection: EditSelection) async throws -> AudioSignalAnalysis {
        try Task.checkCancellation()
        guard sourceURL.isFileURL else { throw RingifyError.corruptMedia }
        let file = try AVAudioFile(forReading: sourceURL)
        let format = file.processingFormat
        guard format.sampleRate.isFinite, (8_000...192_000).contains(format.sampleRate),
              (1...2).contains(format.channelCount), file.length > 0 else { throw RingifyError.corruptMedia }
        _ = try ValidateSelectionUseCase()(selection, sourceDuration: Double(file.length) / format.sampleRate)
        let first = AVAudioFramePosition((selection.start * format.sampleRate).rounded())
        let last = min(file.length, AVAudioFramePosition((selection.end * format.sampleRate).rounded()))
        var accumulator = try AudioSignalAccumulator(sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount), frameCount: last - first,
            sourceStart: Double(first) / format.sampleRate)
        let capacity: AVAudioFrameCount = 8_192
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw RingifyError.corruptMedia
        }
        file.framePosition = first
        while file.framePosition < last {
            try Task.checkCancellation()
            let count = AVAudioFrameCount(min(Int64(capacity), last - file.framePosition))
            try file.read(into: buffer, frameCount: count)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else {
                throw RingifyError.corruptMedia
            }
            // Only this bounded chunk is copied; the full source never enters an array.
            let samples = (0..<Int(format.channelCount)).map { channel in
                Array(UnsafeBufferPointer(start: channels[channel], count: Int(buffer.frameLength)))
            }
            try accumulator.append(samples)
        }
        try Task.checkCancellation()
        return try accumulator.finish()
    }
}
