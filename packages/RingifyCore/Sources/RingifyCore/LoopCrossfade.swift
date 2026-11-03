import Foundation

public enum LoopCrossfadeRules {
    public static func validate(_ seconds: Double) throws {
        guard seconds.isFinite, seconds == 0 || (0.005...0.25).contains(seconds) else { throw RingifyError.corruptMedia }
    }
    public static func overlapFrames(seconds: Double, sampleRate: Double, frames: Int64) throws -> Int64 {
        try validate(seconds)
        guard sampleRate.isFinite, sampleRate > 0, sampleRate <= 192_000, frames > 0 else { throw RingifyError.corruptMedia }
        guard seconds > 0 else { return 0 }
        let overlap = min(Int64((seconds * sampleRate).rounded()), frames / 4)
        guard overlap >= 2 else { throw RingifyError.corruptMedia }
        return overlap
    }
    public static func sourceOffset(seconds: Double, sampleRate: Double, duration: Double) throws -> Double {
        guard sampleRate.isFinite, sampleRate > 0, sampleRate <= 192_000, duration.isFinite, (1...29).contains(duration) else {
            throw RingifyError.corruptMedia
        }
        return Double(try overlapFrames(seconds: seconds, sampleRate: sampleRate,
            frames: Int64((duration * sampleRate).rounded()))) / sampleRate
    }
}

/// Streaming linear endpoint overlap. Emits the middle, then a tail/head blend.
/// Output length is input-overlap; both joins follow original adjacent samples.
/// Retains only the first overlap frames (<=48000/channel), not the whole clip.
public struct LoopCrossfadeProcessor: Sendable {
    public let outputFrames: Int64
    private let inputFrames: Int64
    private let channels: Int
    private let overlap: Int
    private var head: [[Float]]
    private var received: Int64 = 0

    public init(seconds: Double, sampleRate: Double, frames: Int64, channelCount: Int) throws {
        guard (1...2).contains(channelCount) else { throw RingifyError.corruptMedia }
        let overlap = try LoopCrossfadeRules.overlapFrames(seconds: seconds, sampleRate: sampleRate, frames: frames)
        self.inputFrames = frames; self.outputFrames = frames - overlap
        self.overlap = Int(overlap); self.channels = channelCount
        head = Array(repeating: [Float](repeating: 0, count: Int(overlap)), count: channelCount)
    }
    public mutating func process(_ input: [[Float]]) throws -> [[Float]] {
        guard input.count == channels, let count = input.first?.count, count <= 32_768,
              Int64(count) <= inputFrames - received,
              input.allSatisfy({ $0.count == count && $0.allSatisfy(\.isFinite) }) else { throw RingifyError.corruptMedia }
        if overlap == 0 { received += Int64(count); return input }
        var output = Array(repeating: [Float](), count: channels)
        for frame in 0..<count {
            let position = received + Int64(frame)
            if position < Int64(overlap) {
                for channel in 0..<channels { head[channel][Int(position)] = input[channel][frame] }
            } else if position < inputFrames - Int64(overlap) {
                for channel in 0..<channels { output[channel].append(input[channel][frame]) }
            } else {
                let index = Int(position - (inputFrames - Int64(overlap)))
                let blend = Double(index) / Double(overlap - 1)
                for channel in 0..<channels {
                    let sample = Float(Double(input[channel][frame]) * (1 - blend) + Double(head[channel][index]) * blend)
                    guard sample.isFinite else { throw RingifyError.corruptMedia }
                    output[channel].append(sample)
                }
            }
        }
        received += Int64(count)
        return output
    }
    public func finish() throws {
        guard received == inputFrames else { throw RingifyError.exportVerificationFailed }
    }
}
