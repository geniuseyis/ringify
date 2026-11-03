import Foundation

/// Shared gain/fade rules for native preview and export. No sample hard clipping.
public struct AudioGainEnvelope: Sendable {
    public let gain: Double
    private let sampleRate: Double
    private let frames: Int64
    private let fadeIn: Double
    private let fadeOut: Double

    public init(peak: Double, settings: AudioEffectSettings, sampleRate: Double, frames: Int64) throws {
        try settings.studio.validate(sampleRate: sampleRate)
        try LoopCrossfadeRules.validate(settings.loopCrossfadeDuration)
        guard peak.isFinite, peak >= 0, sampleRate.isFinite, sampleRate > 0, frames > 0,
              settings.volume.isFinite, settings.volume >= 0,
              settings.fadeInDuration.isFinite, settings.fadeInDuration >= 0,
              settings.fadeOutDuration.isFinite, settings.fadeOutDuration >= 0 else {
            throw RingifyError.corruptMedia
        }
        let requested = settings.volume * (settings.normalize && peak > 0 ? 0.95 / peak : 1)
        let safe = peak > 0 ? (settings.studio.limiterEnabled ? requested : min(requested, 0.99 / peak)) : 0
        guard safe.isFinite else { throw RingifyError.corruptMedia }
        self.gain = safe
        self.sampleRate = sampleRate
        self.frames = frames
        let duration = Double(frames) / sampleRate
        self.fadeIn = min(settings.fadeInDuration, duration / 2)
        self.fadeOut = min(settings.fadeOutDuration, duration / 2)
    }

    public func gain(at frame: Int64) -> Double {
        guard frame >= 0, frame < frames else { return 0 }
        let attack = fadeIn > 0 ? min(1, Double(frame) / (fadeIn * sampleRate)) : 1
        let release = fadeOut > 0 ? min(1, Double(frames - 1 - frame) / (fadeOut * sampleRate)) : 1
        return gain * min(attack, release)
    }
}
