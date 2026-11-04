// Presentation math only. Zoom never changes source time, PCM or edit settings.
enum StudioZoomRules {
    static let range = 1.0...4.0

    static func proposed(start: Double, magnification: Double) -> Double {
        let origin = start.isFinite ? min(range.upperBound, max(range.lowerBound, start)) : range.lowerBound
        guard magnification.isFinite, magnification > 0 else { return origin }
        // A factor above the maximum viewport scale cannot change the clamped
        // result. Limit it before multiplication to avoid numeric overflow.
        return min(range.upperBound, max(range.lowerBound, origin * min(range.upperBound, magnification)))
    }
}
