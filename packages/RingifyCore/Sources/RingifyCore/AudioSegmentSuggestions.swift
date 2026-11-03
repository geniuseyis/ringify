import Foundation

public enum AudioSegmentDuration: Int, CaseIterable, Sendable { case short = 15, medium = 20, ringtone = 29 }
public struct AudioSegmentSuggestion: Equatable, Sendable {
    public let selection: EditSelection
    public let rmsDbFS: Double
    public init(selection: EditSelection, rmsDbFS: Double) { self.selection = selection; self.rmsDbFS = rmsDbFS }
}
public protocol AudioSegmentSuggesting: Sendable {
    func suggest(sourceURL: URL, duration: AudioSegmentDuration) async throws -> [AudioSegmentSuggestion]
}

/// Exact frame-energy ranking on the web's 50ms grid. Stores <=2402 candidate
/// sums, never source PCM. No AI/speech inference. Same 120s/48MiB input bounds.
public struct AudioSegmentAccumulator: Sendable {
    private struct Candidate: Sendable { let first: Int64; var startEnergy: Double = 0; var power: Double = 0 }
    private let rate: Double
    private let channels: Int
    private let expected: Int64
    private let span: Int64
    private var candidates: [Candidate]
    private var frames: Int64 = 0
    private var energy: Double = 0
    private var startIndex = 0
    private var endIndex = 0
    private var finished = false

    public init(sampleRate: Double, channelCount: Int, frameCount: Int64, duration: AudioSegmentDuration) throws {
        guard sampleRate.isFinite, (8_000...192_000).contains(sampleRate), (1...2).contains(channelCount),
              frameCount > 0, frameCount <= Int64(48 * 1024 * 1024 / 4 / channelCount),
              Double(frameCount) / sampleRate <= 120 else { throw RingifyError.corruptMedia }
        rate = sampleRate; channels = channelCount; expected = frameCount
        span = min(frameCount, Int64((Double(duration.rawValue) * sampleRate).rounded()))
        let step = max(1, Int64((sampleRate * 0.05).rounded())), last = frameCount - span
        candidates = stride(from: Int64(0), through: last, by: step).map { Candidate(first: $0) }
        if candidates.last?.first != last { candidates.append(Candidate(first: last)) }
    }
    public mutating func append(_ input: [[Float]]) throws {
        guard !finished, input.count == channels, let count = input.first?.count, (1...32_768).contains(count),
              Int64(count) <= expected - frames,
              input.allSatisfy({ $0.count == count && $0.allSatisfy(\.isFinite) }) else { throw RingifyError.corruptMedia }
        for frame in 0..<count {
            if startIndex < candidates.count, candidates[startIndex].first == frames {
                candidates[startIndex].startEnergy = energy; startIndex += 1
            }
            for channel in input { let value = Double(channel[frame]); energy += value * value }
            frames += 1
            if endIndex < candidates.count, candidates[endIndex].first + span == frames {
                let power = (energy - candidates[endIndex].startEnergy) / (Double(span) * Double(channels))
                guard power.isFinite else { throw RingifyError.corruptMedia }
                candidates[endIndex].power = max(0, power); endIndex += 1
            }
        }
    }
    public mutating func finish() throws -> [AudioSegmentSuggestion] {
        guard !finished, frames == expected, endIndex == candidates.count else { throw RingifyError.corruptMedia }
        finished = true
        guard Double(frames) / rate >= 1 else { return [] }
        let ranked = candidates.filter { $0.power >= pow(10, -45.0 / 10) }.sorted {
            $0.power == $1.power ? $0.first < $1.first : $0.power > $1.power
        }
        var chosen: [Candidate] = []
        for item in ranked where chosen.allSatisfy({ item.first + span <= $0.first || item.first >= $0.first + span }) {
            chosen.append(item); if chosen.count == 3 { break }
        }
        return chosen.map { AudioSegmentSuggestion(selection: EditSelection(start: Double($0.first) / rate,
            end: Double($0.first + span) / rate), rmsDbFS: 10 * log10($0.power)) }
    }
}
