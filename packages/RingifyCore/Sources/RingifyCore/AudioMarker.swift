import Foundation

public struct AudioMarker: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var time: TimeInterval
    public var label: String
    public init(id: UUID = UUID(), time: TimeInterval, label: String) { self.id = id; self.time = time; self.label = label }
}

public enum AudioMarkers {
    public static let maximumCount = 64
    public static func validated(_ markers: [AudioMarker], sourceDuration: TimeInterval) throws -> [AudioMarker] {
        guard sourceDuration.isFinite, sourceDuration > 0, sourceDuration <= 1_800,
              markers.count <= maximumCount, Set(markers.map(\.id)).count == markers.count else { throw RingifyError.corruptMedia }
        for marker in markers {
            guard marker.time.isFinite, marker.time >= 0, marker.time <= sourceDuration,
                  try ProjectCollection.validatedName(marker.label) == marker.label else { throw RingifyError.corruptMedia }
        }
        return markers.sorted { $0.time == $1.time ? $0.id.uuidString < $1.id.uuidString : $0.time < $1.time }
    }
    /// A live recorder clock can exceed the decoded codec boundary by a few frames.
    public static func fittingRecording(_ markers: [AudioMarker], sourceDuration: TimeInterval) throws -> [AudioMarker] {
        guard markers.allSatisfy({ $0.time.isFinite && $0.time <= sourceDuration + 0.1 }) else { throw RingifyError.corruptMedia }
        return try validated(markers.map { AudioMarker(id: $0.id, time: min($0.time, sourceDuration), label: $0.label) }, sourceDuration: sourceDuration)
    }
    public static func selection(for marker: AudioMarker, sourceDuration: TimeInterval, preferredDuration: TimeInterval) throws -> EditSelection {
        _ = try validated([marker], sourceDuration: sourceDuration)
        guard preferredDuration.isFinite, (1...29).contains(preferredDuration), sourceDuration >= 1 else { throw RingifyError.corruptMedia }
        let duration = min(preferredDuration, sourceDuration)
        let start = min(marker.time, sourceDuration - duration)
        return EditSelection(start: start, end: start + duration)
    }
}
