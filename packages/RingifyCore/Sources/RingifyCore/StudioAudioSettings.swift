import Foundation

public enum StudioChannelMode: String, Codable, CaseIterable, Sendable {
    case original, mono, stereo
}

public struct StudioAudioSettings: Codable, Equatable, Sendable {
    public var lowGainDB: Double
    public var midGainDB: Double
    public var highGainDB: Double
    public var highPassHz: Double
    public var lowPassHz: Double
    public var channelMode: StudioChannelMode
    public var limiterEnabled: Bool
    public var ceiling: Double

    public init(lowGainDB: Double = 0, midGainDB: Double = 0, highGainDB: Double = 0,
                highPassHz: Double = 0, lowPassHz: Double = 0,
                channelMode: StudioChannelMode = .original, limiterEnabled: Bool = false,
                ceiling: Double = 0.99) {
        self.lowGainDB = lowGainDB
        self.midGainDB = midGainDB
        self.highGainDB = highGainDB
        self.highPassHz = highPassHz
        self.lowPassHz = lowPassHz
        self.channelMode = channelMode
        self.limiterEnabled = limiterEnabled
        self.ceiling = ceiling
    }

    public static let neutral = StudioAudioSettings()
    public var isNeutral: Bool { self == .neutral }

    public func validate(sampleRate: Double? = nil) throws {
        let gains = [lowGainDB, midGainDB, highGainDB]
        let cutoffs = [highPassHz, lowPassHz]
        guard gains.allSatisfy({ $0.isFinite && abs($0) <= 12 }),
              cutoffs.allSatisfy({ $0.isFinite && ($0 == 0 || (20...20_000).contains($0)) }),
              ceiling.isFinite, (0.1...0.99).contains(ceiling),
              highPassHz == 0 || lowPassHz == 0 || highPassHz < lowPassHz else {
            throw RingifyError.corruptMedia
        }
        if let sampleRate {
            guard sampleRate.isFinite, sampleRate > 0, sampleRate <= 192_000,
                  cutoffs.allSatisfy({ $0 == 0 || $0 < sampleRate / 2 }),
                  zip(gains, [120.0, 1_000.0, 6_000.0]).allSatisfy({ $0.0 == 0 || $0.1 < sampleRate / 2 }) else {
                throw RingifyError.corruptMedia
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case lowGainDB, midGainDB, highGainDB, highPassHz, lowPassHz, channelMode, limiterEnabled, ceiling
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(lowGainDB: try values.decode(Double.self, forKey: .lowGainDB),
                  midGainDB: try values.decode(Double.self, forKey: .midGainDB),
                  highGainDB: try values.decode(Double.self, forKey: .highGainDB),
                  highPassHz: try values.decode(Double.self, forKey: .highPassHz),
                  lowPassHz: try values.decode(Double.self, forKey: .lowPassHz),
                  channelMode: try values.decode(StudioChannelMode.self, forKey: .channelMode),
                  limiterEnabled: try values.decode(Bool.self, forKey: .limiterEnabled),
                  ceiling: try values.decode(Double.self, forKey: .ceiling))
        try validate()
    }
}

public enum StudioAudioPreset: String, CaseIterable, Identifiable, Sendable {
    case neutral, warm, clear, telephone
    public var id: String { rawValue }
    public var settings: StudioAudioSettings {
        switch self {
        case .neutral: .neutral
        case .warm: StudioAudioSettings(lowGainDB: 3, highGainDB: -2)
        case .clear: StudioAudioSettings(lowGainDB: -2, midGainDB: 2, highGainDB: 2, highPassHz: 80)
        case .telephone: StudioAudioSettings(highPassHz: 300, lowPassHz: 3_400, channelMode: .mono)
        }
    }
}
