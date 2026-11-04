@preconcurrency import AVFoundation
import Foundation
import RingifyCore

@MainActor
final class AVVoiceRecordingService: NSObject, VoiceRecordingService, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    var isRecording: Bool { recorder?.isRecording == true }
    var isPaused: Bool { recorder != nil && recorder?.isRecording == false }
    var currentTime: TimeInterval { recorder?.currentTime ?? 0 }
    var averagePower: Float {
        recorder?.updateMeters()
        return recorder?.averagePower(forChannel: 0) ?? -80
    }

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func startRecording(to url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128_000
        ]
        try? FileManager.default.removeItem(at: url)
        let newRecorder = try AVAudioRecorder(url: url, settings: settings)
        newRecorder.delegate = self
        newRecorder.isMeteringEnabled = true
        guard newRecorder.prepareToRecord(), newRecorder.record() else {
            throw RingifyError.permissionDenied
        }
        recorder = newRecorder
        recordingURL = url
    }

    func pause() { recorder?.pause() }

    func resume() throws {
        guard recorder?.record() == true else { throw RingifyError.corruptMedia }
    }

    func stop() -> URL? {
        recorder?.stop()
        let result = recordingURL
        recorder = nil
        recordingURL = nil
        return result
    }

    func discard() {
        let url = stop()
        if let url { try? FileManager.default.removeItem(at: url) }
    }
}
