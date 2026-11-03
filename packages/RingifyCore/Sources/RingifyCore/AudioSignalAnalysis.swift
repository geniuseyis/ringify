import Foundation

public struct AudioSignalAnalysis: Equatable, Sendable {
    public let selection: EditSelection
    public let peakDbFS: Double?
    public let rmsDbFS: Double?
    public let silentRegions: [EditSelection]
    public let suggestion: EditSelection?

    public init(selection: EditSelection, peakDbFS: Double?, rmsDbFS: Double?,
                silentRegions: [EditSelection], suggestion: EditSelection?) {
        self.selection = selection
        self.peakDbFS = peakDbFS
        self.rmsDbFS = rmsDbFS
        self.silentRegions = silentRegions
        self.suggestion = suggestion
    }
}

public protocol AudioSignalAnalyzing: Sendable {
    func analyze(sourceURL: URL, selection: EditSelection) async throws -> AudioSignalAnalysis
}

/// Streaming source PCM statistics. Windows are 50ms; silence is -45dBFS for >=300ms.
/// Values describe source samples, not loudness (LUFS), speech or AI inference.
public struct AudioSignalAccumulator: Sendable {
    private let sampleRate: Double
    private let channelCount: Int
    private let expectedFrames: Int64
    private let sourceStart: TimeInterval
    private let windowFrames: Int
    private var frames: Int64 = 0
    private var peak: Double = 0
    private var totalSquare: Double = 0
    private var windowSquare: Double = 0
    private var windowCount = 0
    private var silenceStart: Int64?
    private var silentRegions: [EditSelection] = []
    private var finished = false

    public init(sampleRate: Double, channelCount: Int, frameCount: Int64, sourceStart: TimeInterval) throws {
        guard sampleRate.isFinite, (8_000...192_000).contains(sampleRate),
              (1...2).contains(channelCount), sourceStart.isFinite, sourceStart >= 0,
              frameCount > 0, Double(frameCount) / sampleRate >= 1,
              Double(frameCount) / sampleRate <= 29 + 1 / sampleRate,
              sourceStart + Double(frameCount) / sampleRate <= 30 * 60 else {
            throw RingifyError.corruptMedia
        }
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.expectedFrames = frameCount
        self.sourceStart = sourceStart
        self.windowFrames = max(1, Int((sampleRate * 0.05).rounded()))
    }

    public mutating func append(_ channels: [[Float]]) throws {
        guard !finished, channels.count == channelCount,
              let count = channels.first?.count, count > 0,
              Int64(count) <= expectedFrames - frames,
              channels.allSatisfy({ $0.count == count && $0.allSatisfy(\.isFinite) }) else {
            throw RingifyError.corruptMedia
        }
        for frame in 0..<count {
            for channel in 0..<channelCount {
                let value = Double(channels[channel][frame])
                peak = max(peak, abs(value))
                windowSquare += value * value
            }
            frames += 1
            windowCount += 1
            if windowCount == windowFrames { closeWindow() }
        }
    }

    public mutating func finish() throws -> AudioSignalAnalysis {
        guard !finished, frames == expectedFrames else { throw RingifyError.corruptMedia }
        if windowCount > 0 { closeWindow() }
        if let silenceStart { addSilence(from: silenceStart, to: frames) }
        finished = true
        let selection = EditSelection(start: sourceStart, end: sourceStart + Double(frames) / sampleRate)
        let first = silentRegions.first
        let last = silentRegions.last
        let start = first.map { $0.start == selection.start ? $0.end : selection.start } ?? selection.start
        let end = last.map { $0.end == selection.end ? $0.start : selection.end } ?? selection.end
        let trimmed = EditSelection(start: start, end: end)
        let suggestion = trimmed.duration >= 1 && trimmed.duration < selection.duration ? trimmed : nil
        return AudioSignalAnalysis(selection: selection,
            peakDbFS: peak > 0 ? 20 * log10(peak) : nil,
            rmsDbFS: totalSquare > 0 ? 10 * log10(totalSquare / (Double(frames) * Double(channelCount))) : nil,
            silentRegions: silentRegions, suggestion: suggestion)
    }

    private mutating func closeWindow() {
        let start = frames - Int64(windowCount)
        let silent = sqrt(windowSquare / (Double(windowCount) * Double(channelCount))) <= pow(10, -45.0 / 20)
        totalSquare += windowSquare
        if silent && silenceStart == nil { silenceStart = start }
        if !silent, let previous = silenceStart {
            addSilence(from: previous, to: start)
            silenceStart = nil
        }
        windowCount = 0
        windowSquare = 0
    }

    private mutating func addSilence(from start: Int64, to end: Int64) {
        if Double(end - start) / sampleRate >= 0.3 - 1e-8 {
            silentRegions.append(EditSelection(start: sourceStart + Double(start) / sampleRate,
                end: sourceStart + Double(end) / sampleRate))
        }
    }
}
