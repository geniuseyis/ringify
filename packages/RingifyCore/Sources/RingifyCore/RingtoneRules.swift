import Foundation

public struct RingtoneRules: Sendable {
    public static let minimumDuration: TimeInterval = 1
    public static let maximumDuration: TimeInterval = 29
    public static let maximumFilenameLength = 80

    public init() {}

    public func validate(
        selection: EditSelection,
        sourceDuration: TimeInterval
    ) -> Result<EditSelection, SelectionValidationError> {
        guard selection.start.isFinite, selection.end.isFinite, sourceDuration.isFinite else {
            return .failure(.nonFiniteValue)
        }
        guard selection.start >= 0 else {
            return .failure(.negativeStart)
        }
        guard selection.end > selection.start else {
            return .failure(.endNotAfterStart)
        }
        guard selection.duration >= Self.minimumDuration else {
            return .failure(.shorterThanMinimum(minimum: Self.minimumDuration))
        }
        guard selection.duration <= Self.maximumDuration else {
            return .failure(.longerThanMaximum(maximum: Self.maximumDuration))
        }
        guard sourceDuration >= 0, selection.end <= sourceDuration + 0.001 else {
            return .failure(.exceedsSourceDuration)
        }
        return .success(selection)
    }

    public func validate(filename: String) -> Result<String, FilenameValidationError> {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard trimmed.count <= Self.maximumFilenameLength else {
            return .failure(.tooLong(maximum: Self.maximumFilenameLength))
        }
        guard !trimmed.contains("/"), !trimmed.contains("\\"), !trimmed.contains(":") else {
            return .failure(.containsPathSeparator)
        }
        let baseName = (trimmed as NSString).deletingPathExtension
        let reserved = [".", "..", "con", "prn", "aux", "nul"]
        guard !reserved.contains(baseName.lowercased()) else { return .failure(.reservedName) }
        return .success(baseName)
    }

    public func safeFilename(from proposedName: String, fallback: String = "Ringify") -> String {
        let illegal = CharacterSet(charactersIn: "/\\:\0").union(.controlCharacters)
        let components = proposedName.components(separatedBy: illegal)
        let cleaned = components.joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = cleaned.isEmpty ? fallback : cleaned
        let limited = String(candidate.prefix(Self.maximumFilenameLength))
        switch validate(filename: limited) {
        case .success(let value): return value
        case .failure: return fallback
        }
    }

    public func clampedSelection(
        start: TimeInterval,
        end: TimeInterval,
        sourceDuration: TimeInterval
    ) -> EditSelection {
        let safeSource = max(0, sourceDuration.isFinite ? sourceDuration : 0)
        let maximumEnd = min(safeSource, Self.maximumDuration)
        guard maximumEnd >= Self.minimumDuration else {
            return EditSelection(start: 0, end: maximumEnd)
        }
        let safeStart = min(max(0, start.isFinite ? start : 0), safeSource - Self.minimumDuration)
        let desiredEnd = end.isFinite ? end : safeStart + Self.minimumDuration
        let safeEnd = min(max(safeStart + Self.minimumDuration, desiredEnd), min(safeSource, safeStart + Self.maximumDuration))
        return EditSelection(start: safeStart, end: safeEnd)
    }
}
