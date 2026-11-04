@preconcurrency import AVFoundation
import Foundation
import RingifyCore

/// Owns the only writer reference so readers never race a buffered file tail.
/// iOS 17 finalizes on release; newer systems also expose explicit close().
final class FinalizedPCMWriter {
    private var file: AVAudioFile?

    init(url: URL, settings: [String: Any]) throws {
        file = try AVAudioFile(forWriting: url, settings: settings,
            commonFormat: .pcmFormatFloat32, interleaved: false)
    }

    func write(from buffer: AVAudioPCMBuffer) throws {
        guard let file else { throw RingifyError.exportVerificationFailed }
        try file.write(from: buffer)
    }

    func finish() {
        if #available(iOS 18.0, *) { file?.close() }
        file = nil
    }
}
