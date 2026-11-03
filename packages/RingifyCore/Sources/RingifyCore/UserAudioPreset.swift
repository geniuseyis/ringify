import Foundation

public struct UserAudioPreset: Codable, Identifiable, Equatable, Sendable {
    public static let maximumCount = 64
    public let id: UUID
    public var name: String
    public var effects: AudioEffectSettings
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), name: String, effects: AudioEffectSettings, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.name = name; self.effects = effects
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
    public func validate() throws {
        guard try ProjectCollection.validatedName(name) == name,
              createdAt.timeIntervalSinceReferenceDate.isFinite, updatedAt.timeIntervalSinceReferenceDate.isFinite,
              [effects.volume, effects.fadeInDuration, effects.fadeOutDuration].allSatisfy({ $0.isFinite && $0 >= 0 }),
              effects.volume <= 1.5, effects.fadeInDuration <= 5, effects.fadeOutDuration <= 5 else { throw RingifyError.corruptMedia }
        try effects.studio.validate()
        try LoopCrossfadeRules.validate(effects.loopCrossfadeDuration)
    }
    public func applying(selectionDuration: TimeInterval, sampleRate: Double) throws -> AudioEffectSettings {
        try validate()
        try effects.studio.validate(sampleRate: sampleRate)
        return try effects.limitingFades(to: selectionDuration)
    }
}
