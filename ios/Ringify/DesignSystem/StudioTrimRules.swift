import RingifyCore

enum StudioTrimRules {
    enum Boundary: CaseIterable, Sendable { case start, end }

    // Shared by hardware keyboard and VoiceOver adjustments. Invalid input
    // leaves the current edit intact instead of inventing a new selection.
    static func adjustedSelection(_ selection: EditSelection, boundary: Boundary,
        delta: Double, sourceDuration: Double) -> EditSelection {
        guard delta.isFinite,
            case .success = RingtoneRules().validate(selection: selection, sourceDuration: sourceDuration) else { return selection }
        var next = selection
        switch boundary {
        case .start:
            let proposed = snappedSourceBoundary(selection.start + delta, duration: sourceDuration)
            next.start = min(selection.end - RingtoneRules.minimumDuration,
                max(0, max(selection.end - RingtoneRules.maximumDuration, proposed)))
        case .end:
            let proposed = snappedSourceBoundary(selection.end + delta, duration: sourceDuration)
            next.end = max(selection.start + RingtoneRules.minimumDuration,
                min(sourceDuration, min(selection.start + RingtoneRules.maximumDuration, proposed)))
        }
        // Fractional source times can make (start + 29) - start slightly
        // greater than 29. Move one representable value inward, without
        // quantizing the user's timecode or relaxing domain validation.
        if next.duration > RingtoneRules.maximumDuration {
            switch boundary {
            case .start: next.start = next.start.nextUp
            case .end: next.end = next.end.nextDown
            }
        } else if next.duration < RingtoneRules.minimumDuration {
            switch boundary {
            case .start: next.start = next.start.nextDown
            case .end: next.end = next.end.nextUp
            }
        }
        guard case .success = RingtoneRules().validate(selection: next, sourceDuration: sourceDuration) else { return selection }
        return next
    }

    // Apply selection-duration constraints after this presentation-only snap.
    static func snappedSourceBoundary(_ time: Double, duration: Double) -> Double {
        guard time.isFinite else { return 0 }
        guard duration.isFinite, duration > 0 else { return time }
        if abs(time) <= 0.06 { return 0 }
        if abs(duration - time) <= 0.06 { return duration }
        return time
    }
}
