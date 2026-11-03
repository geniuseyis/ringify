import XCTest
@testable import RingifyCore

final class AudioConversionTests: XCTestCase {
    func testAllowsFullDurationBeyondRingtoneLimit() throws {
        try AudioConversionRules().validateAudio(duration: 120, sampleRate: 48_000, channels: 2)
        try AudioConversionRules().validateAudio(duration: 1_800, sampleRate: 44_100, channels: 1)
    }
    func testRejectsInvalidMetadata() {
        for duration in [Double.nan, .infinity, 0, -1, 1_801] {
            XCTAssertThrowsError(try AudioConversionRules().validateAudio(duration: duration, sampleRate: 48_000, channels: 2))
        }
        XCTAssertThrowsError(try AudioConversionRules().validateAudio(duration: 30, sampleRate: .nan, channels: 2))
        XCTAssertThrowsError(try AudioConversionRules().validateAudio(duration: 30, sampleRate: 48_000, channels: 6))
    }
    func testAcceptsOnlyLocalBoundedMP3AndMP4() throws {
        let rules = AudioConversionRules()
        try rules.validateSource(url: URL(fileURLWithPath: "/media/TONE.MP3"), byteCount: 100)
        try rules.validateSource(url: URL(fileURLWithPath: "/media/video.mp4"), byteCount: AudioConversionRules.maximumBytes)
        XCTAssertThrowsError(try rules.validateSource(url: URL(string: "https://example.com/video.mp4")!, byteCount: 100))
        XCTAssertThrowsError(try rules.validateSource(url: URL(fileURLWithPath: "/media/tone.wav"), byteCount: 100))
        for bytes in [Int64(0), -1, AudioConversionRules.maximumBytes + 1] {
            XCTAssertThrowsError(try rules.validateSource(url: URL(fileURLWithPath: "/media/tone.mp3"), byteCount: bytes))
        }
    }
}
