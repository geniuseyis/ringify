import Foundation

public enum AudioOutputProfile: String, Codable, CaseIterable, Identifiable, Sendable {
    case aacStandard, aacHigh, wav16, wav24
    public var id: String { rawValue }
    public var format: ExportFormat { self == .wav16 || self == .wav24 ? .wavPCM : .m4aAAC }
    public var bitDepth: Int? { self == .wav16 ? 16 : self == .wav24 ? 24 : nil }
    public var bitRate: Int? { self == .aacStandard ? 192_000 : self == .aacHigh ? 256_000 : nil }
    public var requiresPro: Bool { self == .aacHigh || self == .wav24 }
}
