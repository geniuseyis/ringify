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
    @Environment(\.ringifyVisualStyle) private var style
    private var wave: Color { style == .studio ? RingifyTheme.Studio.wave : RingifyTheme.AppleV2.wave }

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
                Rectangle().fill(wave.opacity(0.10))
                    .frame(width: proxy.size.width * CGFloat(selectionRange.upperBound - selectionRange.lowerBound))
                    .offset(x: proxy.size.width * CGFloat(selectionRange.lowerBound))
                WaveformView(samples: project.waveformSamples, tint: wave,
                    dimmedTint: style == .studio ? RingifyTheme.Studio.outsideWave : Color.secondary.opacity(0.22), selection: selectionRange)
                Rectangle().fill(style == .studio ? RingifyTheme.Studio.canvasText : Color.primary)
                    .frame(width: 2)
                    .offset(x: min(max(0, proxy.size.width - 2), proxy.size.width * CGFloat(cursorFraction)))
            }
            .clipped()
        }
        .frame(height: 110)
        .background(style == .studio ? RingifyTheme.Studio.canvas : Color.clear, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityHidden(true)
    }
}

import RingifyCore
import SwiftUI

struct NativeContentCard: ViewModifier {
    var padding: CGFloat = 16
    @Environment(\.ringifyVisualStyle) private var style
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.padding(padding)
            .background(style.surface, in: RoundedRectangle(cornerRadius: style.cardRadius))
            .overlay {
                if style == .studio {
                    RoundedRectangle(cornerRadius: style.cardRadius)
                        .strokeBorder(contrast == .increased ? RingifyTheme.Studio.strongBorder : RingifyTheme.Studio.border)
                        .allowsHitTesting(false)
                }
            }
    }
}

struct NativePrimaryActionLabel: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.ringifyVisualStyle) private var style
    func body(content: Content) -> some View {
        content.font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(style.action, in: RoundedRectangle(cornerRadius: style.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: style.controlRadius)
                    .strokeBorder(.white.opacity(contrast == .increased ? 0.6 : 0.2), lineWidth: contrast == .increased ? 2 : 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: style.action.opacity(contrast == .increased ? 0 : (style == .studio ? 0.12 : 0.16)), radius: 10, y: 4)
    }
}

struct NativePressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.ringifyVisualStyle) private var style
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.045 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: style == .studio ? 0.16 : RingifyTheme.AppleV2.controlPressDuration), value: configuration.isPressed)
    }
}

struct NativePrimaryAction: View {
    let title: LocalizedStringKey
    var icon: String = "arrow.right"
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .multilineTextAlignment(.center)
                .modifier(NativePrimaryActionLabel())
        }
        .buttonStyle(NativePressButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1)
    }
}

struct NativeProjectIdentity: View {
    let project: RingtoneProject
    @Environment(\.ringifyVisualStyle) private var style

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(style.accent)
                .frame(width: 44, height: 44)
                .background(style.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(project.name).font(.headline)
                Text(project.sourceFilename).font(.caption).foregroundStyle(.secondary)
                Text(DurationText.formatted(project.selection.duration))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}