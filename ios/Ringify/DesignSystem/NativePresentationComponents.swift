import RingifyCore
import SwiftUI

/// Title and value in one row. Wraps by itself at large Dynamic Type sizes.
struct NativeMetadataRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title) {
            Text(value)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

// These are the actual stored source peaks. Highlighting and cursor positions
// use source time; this does not claim to visualize newly rendered effect PCM.
struct NativeSelectionWaveform: View {
    let project: RingtoneProject
    var elapsed: TimeInterval = 0
    var height: CGFloat = 88

    var selectionRange: ClosedRange<Double> {
        let duration = project.sourceDuration.isFinite && project.sourceDuration > 0 ? project.sourceDuration : 1
        let start = min(1, max(0, project.selection.start.isFinite ? project.selection.start / duration : 0))
        let end = min(1, max(start, project.selection.end.isFinite ? project.selection.end / duration : start))
        return start...end
    }

    var cursorFraction: Double {
        let duration = project.sourceDuration.isFinite && project.sourceDuration > 0 ? project.sourceDuration : 1
        return min(selectionRange.upperBound, max(selectionRange.lowerBound, selectionRange.lowerBound + (elapsed.isFinite ? max(0, elapsed) : 0) / duration))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                WaveformView(samples: project.waveformSamples, selection: selectionRange)
                Capsule()
                    .fill(Color.primary)
                    .frame(width: 2)
                    .offset(x: min(max(0, proxy.size.width - 2), proxy.size.width * CGFloat(cursorFraction)))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
