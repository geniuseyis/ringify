@preconcurrency import AVFoundation
import Foundation
import RingifyCore

@MainActor
final class AVAudioPlaybackService: NSObject, AudioPlaybackService, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var monitor: Timer?
    private var playbackSelection: EditSelection?
    private var loopsSelection = false
    private var loadedURL: URL?

    var isPlaying: Bool { player?.isPlaying == true }
    var currentTime: TimeInterval { player?.currentTime ?? 0 }

    func load(url: URL) throws {
        // All transport views call load before resuming. Reuse the same paused player.
        if loadedURL == url, player != nil { return }
        stop()
        player = nil
        loadedURL = nil
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        let loadedPlayer = try AVAudioPlayer(contentsOf: url)
        loadedPlayer.delegate = self
        guard loadedPlayer.prepareToPlay() else { throw RingifyError.corruptMedia }
        player = loadedPlayer
        loadedURL = url
    }

    func play(selection: EditSelection?, loop: Bool) throws {
        guard let player else { throw RingifyError.corruptMedia }
        if let selection {
            guard selection.start.isFinite, selection.end.isFinite,
                  selection.start >= 0, selection.end > selection.start, selection.end <= player.duration else {
                throw RingifyError.invalidSelection(.exceedsSourceDuration)
            }
            if player.currentTime < selection.start || player.currentTime >= selection.end {
                player.currentTime = selection.start
            }
        }
        playbackSelection = selection
        loopsSelection = loop
        if selection == nil, player.currentTime >= player.duration { player.currentTime = 0 }
        guard player.play() else { throw RingifyError.corruptMedia }
        startMonitor()
    }

    func pause() {
        player?.pause()
        monitor?.invalidate()
        monitor = nil
    }

    func stop() {
        player?.stop()
        player?.currentTime = playbackSelection?.start ?? 0
        monitor?.invalidate()
        monitor = nil
    }

    func seek(to time: TimeInterval) {
        guard let player, time.isFinite else { return }
        player.currentTime = min(max(0, time), player.duration)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag, loopsSelection, let playbackSelection {
            player.currentTime = playbackSelection.start
            if player.play() { startMonitor(); return }
        }
        monitor?.invalidate()
        monitor = nil
    }

    private func startMonitor() {
        monitor?.invalidate()
        monitor = Timer.scheduledTimer(
            timeInterval: 0.03,
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func tick() {
        guard let player, let selection = playbackSelection, player.currentTime >= selection.end else { return }
        if loopsSelection {
            player.currentTime = selection.start
            player.play()
        } else {
            pause()
            player.currentTime = selection.start
        }
    }
}
