import Foundation

/// Stateful RBJ/W3C biquads. State is local to each selected render, band and
/// channel; Float32 rounding between stages matches the web studio pipeline.
public struct StudioAudioFilter: Sendable {
    public static let maximumChunkFrames = 32_768
    public let outputChannelCount: Int
    private let inputChannels: Int
    private let mode: StudioChannelMode
    private var bands: [[Biquad]]

    public init(settings: StudioAudioSettings, sampleRate: Double, inputChannels: Int) throws {
        try settings.validate(sampleRate: sampleRate)
        guard (1...2).contains(inputChannels) else { throw RingifyError.corruptMedia }
        self.inputChannels = inputChannels
        self.mode = settings.channelMode
        self.outputChannelCount = settings.channelMode == .mono ? 1 : settings.channelMode == .stereo ? 2 : inputChannels
        var chain: [Biquad] = []
        if settings.highPassHz != 0 { chain.append(Biquad(rate: sampleRate, frequency: settings.highPassHz, kind: .highPass)) }
        for (frequency, gain) in [(120.0, settings.lowGainDB), (1_000.0, settings.midGainDB), (6_000.0, settings.highGainDB)] where gain != 0 {
            chain.append(Biquad(rate: sampleRate, frequency: frequency, kind: .peak, gain: gain))
        }
        if settings.lowPassHz != 0 { chain.append(Biquad(rate: sampleRate, frequency: settings.lowPassHz, kind: .lowPass)) }
        self.bands = Array(repeating: chain, count: outputChannelCount)
    }

    /// Does not mutate caller samples. On failure discard this render's state.
    public mutating func process(_ channels: [[Float]]) throws -> [[Float]] {
        guard channels.count == inputChannels, let count = channels.first?.count,
              count <= Self.maximumChunkFrames,
              channels.allSatisfy({ $0.count == count && $0.allSatisfy(\.isFinite) }) else {
            throw RingifyError.corruptMedia
        }
        var output: [[Float]]
        if mode == .mono, inputChannels == 2 {
            var mono = [Float](repeating: 0, count: count)
            for index in 0..<count { mono[index] = Float((Double(channels[0][index]) + Double(channels[1][index])) / 2) }
            output = [mono]
        } else if mode == .stereo, inputChannels == 1 {
            output = [channels[0], channels[0]]
        } else {
            output = channels
        }
        for channel in 0..<outputChannelCount {
            var chain = bands[channel]
            for stage in chain.indices { try chain[stage].process(&output[channel]) }
            bands[channel] = chain
        }
        return output
    }
}

private struct Biquad: Sendable {
    enum Kind: Equatable { case highPass, lowPass, peak }
    let b0: Double, b1: Double, b2: Double, a1: Double, a2: Double
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    init(rate: Double, frequency: Double, kind: Kind, gain: Double = 0) {
        let omega = 2 * Double.pi * frequency / rate
        let cosine = cos(omega), alpha = sin(omega) / (2 * sqrt(0.5)), amplitude = pow(10, gain / 40)
        let a0 = kind == .peak ? 1 + alpha / amplitude : 1 + alpha
        a1 = -2 * cosine / a0
        a2 = (kind == .peak ? 1 - alpha / amplitude : 1 - alpha) / a0
        b0 = (kind == .peak ? 1 + alpha * amplitude : kind == .lowPass ? (1 - cosine) / 2 : (1 + cosine) / 2) / a0
        b1 = (kind == .peak ? -2 * cosine : kind == .lowPass ? 1 - cosine : -(1 + cosine)) / a0
        b2 = (kind == .peak ? 1 - alpha * amplitude : kind == .lowPass ? (1 - cosine) / 2 : (1 + cosine) / 2) / a0
    }

    mutating func process(_ values: inout [Float]) throws {
        for index in values.indices {
            let x = Double(values[index])
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            let rounded = Float(y)
            guard y.isFinite, rounded.isFinite else { throw RingifyError.corruptMedia }
            values[index] = rounded
            x2 = x1; x1 = x; y2 = y1; y1 = y
        }
    }
}

/// Linked-channel 5ms lookahead / 50ms release. Fixed rings retain at most
/// lookahead+1 frames and peaks (<=961 at192kHz), independent of file duration.
/// process delays emission until future peaks are known; final flush restores
/// exactly the input frame count without leading silence or a time shift.
public struct LinkedPeakLimiter: Sendable {
    public static let maximumChunkFrames = 32_768
    private let channels: Int
    private let capacity: Int
    private let ceiling: Double
    private let release: Double
    private var frames: [[Float]]
    private var peakIndices: [Int64]
    private var peakValues: [Double]
    private var peakHead = 0
    private var peakCount = 0
    private var received: Int64 = 0
    private var emitted: Int64 = 0
    private var gain = 1.0
    private var finalized = false

    public init(sampleRate: Double, ceiling: Double, channelCount: Int) throws {
        guard sampleRate.isFinite, sampleRate > 0, sampleRate <= 192_000,
              ceiling.isFinite, (0.1...0.99).contains(ceiling), (1...2).contains(channelCount) else {
            throw RingifyError.corruptMedia
        }
        self.channels = channelCount
        self.capacity = max(1, Int((sampleRate * 0.005).rounded())) + 1
        self.ceiling = ceiling
        self.release = exp(-1 / (sampleRate * 0.05))
        self.frames = Array(repeating: [Float](repeating: 0, count: capacity), count: channelCount)
        self.peakIndices = [Int64](repeating: 0, count: capacity)
        self.peakValues = [Double](repeating: 0, count: capacity)
    }

    /// Supply one equally sized array per configured channel, including an
    /// empty array per channel for an EOF flush. Calls after final throw.
    public mutating func process(_ input: [[Float]], final: Bool = false) throws -> [[Float]] {
        guard !finalized, input.count == channels, let count = input.first?.count,
              count <= Self.maximumChunkFrames, received <= Int64.max - Int64(count),
              input.allSatisfy({ $0.count == count && $0.allSatisfy(\.isFinite) }) else {
            throw RingifyError.corruptMedia
        }
        var output = Array(repeating: [Float](), count: channels)
        let maximumOutput = count + (final ? Int(received - emitted) : 0)
        for channel in 0..<channels { output[channel].reserveCapacity(maximumOutput) }
        for index in 0..<count {
            let slot = Int(received % Int64(capacity))
            var peak = 0.0
            for channel in 0..<channels {
                let value = input[channel][index]
                frames[channel][slot] = value
                peak = max(peak, abs(Double(value)))
            }
            while peakCount > 0 {
                let last = (peakHead + peakCount - 1) % capacity
                if peakValues[last] > peak { break }
                peakCount -= 1
            }
            let tail = (peakHead + peakCount) % capacity
            peakIndices[tail] = received
            peakValues[tail] = peak
            peakCount += 1
            received += 1
            if received - emitted == Int64(capacity) { emit(into: &output) }
        }
        if final {
            while emitted < received { emit(into: &output) }
            finalized = true
        }
        return output
    }

    private mutating func emit(into output: inout [[Float]]) {
        let peak = peakValues[peakHead]
        let target = peak > ceiling ? ceiling / peak : 1
        gain = min(target, 1 - (1 - gain) * release)
        let slot = Int(emitted % Int64(capacity))
        for channel in 0..<channels { output[channel].append(Float(Double(frames[channel][slot]) * gain)) }
        emitted += 1
        while peakCount > 0, peakIndices[peakHead] < emitted {
            peakHead = (peakHead + 1) % capacity
            peakCount -= 1
        }
    }
}
