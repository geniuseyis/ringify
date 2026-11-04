@preconcurrency import AVFoundation
import Foundation
import RingifyCore

actor AVAudioSegmentSuggestionsService: AudioSegmentSuggesting {
    func suggest(sourceURL: URL, duration: AudioSegmentDuration) async throws -> [AudioSegmentSuggestion] {
        try Task.checkCancellation()
        guard sourceURL.isFileURL else { throw RingifyError.corruptMedia }
        let file = try AVAudioFile(forReading: sourceURL, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat
        var accumulator = try AudioSegmentAccumulator(sampleRate: format.sampleRate, channelCount: Int(format.channelCount),
            frameCount: file.length, duration: duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8_192) else { throw RingifyError.corruptMedia }
        while file.framePosition < file.length {
            try Task.checkCancellation()
            try file.read(into: buffer, frameCount: AVAudioFrameCount(min(8_192, file.length - file.framePosition)))
            guard buffer.frameLength > 0, let values = buffer.floatChannelData else { throw RingifyError.corruptMedia }
            try accumulator.append((0..<Int(format.channelCount)).map {
                Array(UnsafeBufferPointer(start: values[$0], count: Int(buffer.frameLength)))
            })
        }
        try Task.checkCancellation()
        return try accumulator.finish()
    }
}
