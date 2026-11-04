@preconcurrency import AVFoundation
import AudioToolbox
import CoreMedia
import Foundation
import RingifyCore

actor AVAudioMetadataService: AudioMetadataService {
    func metadata(for url: URL) async throws -> AudioMetadata {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RingifyError.fileNotFound(url)
        }
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else {
            return AudioMetadata(
                duration: max(0, duration),
                sampleRate: 0,
                channelCount: 0,
                formatDescription: "none",
                hasAudioTrack: false
            )
        }
        let descriptions = try await track.load(.formatDescriptions)
        let basic = descriptions.first.flatMap { description in
            CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee
        }
        let format = descriptions.first.map { fourCharacterCode(CMFormatDescriptionGetMediaSubType($0)) } ?? "audio"
        guard duration.isFinite, duration > 0 else { throw RingifyError.corruptMedia }
        return AudioMetadata(
            duration: duration,
            sampleRate: basic?.mSampleRate ?? 0,
            channelCount: Int(basic?.mChannelsPerFrame ?? 0),
            formatDescription: format,
            hasAudioTrack: true
        )
    }

    private func fourCharacterCode(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xff), UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff), UInt8(code & 0xff)
        ]
        return String(bytes: bytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces) ?? "audio"
    }
}
