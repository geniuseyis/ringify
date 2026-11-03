import Foundation

public enum AudioConversionFormat: String, CaseIterable, Codable, Hashable, Sendable { case wav, m4a }
public struct ConvertedAudio: Sendable, Equatable {
    public let url: URL
    public let duration: TimeInterval
    public let byteCount: Int64
    public init(url: URL, duration: TimeInterval, byteCount: Int64) {
        self.url = url; self.duration = duration; self.byteCount = byteCount
    }
}
public protocol AudioConversionService: Sendable {
    func convert(sourceURL: URL, format: AudioConversionFormat, filename: String) async throws -> ConvertedAudio
    func discard(_ result: ConvertedAudio) async throws
}
public struct AudioConversionRules: Sendable {
    public static let maximumBytes: Int64 = 512 * 1024 * 1024
    public static let maximumDuration: TimeInterval = 30 * 60
    public init() {}
    public func validateSource(url: URL, byteCount: Int64) throws {
        guard url.isFileURL, ["mp3", "mp4"].contains(url.pathExtension.lowercased()) else {
            throw RingifyError.unsupportedFile(extension: url.pathExtension)
        }
        guard byteCount > 0, byteCount <= Self.maximumBytes else { throw RingifyError.corruptMedia }
    }
    public func validateAudio(duration: TimeInterval, sampleRate: Double, channels: Int) throws {
        guard duration.isFinite, duration > 0, duration <= Self.maximumDuration,
              sampleRate.isFinite, (8_000...96_000).contains(sampleRate), (1...2).contains(channels) else {
            throw RingifyError.corruptMedia
        }
    }
}
