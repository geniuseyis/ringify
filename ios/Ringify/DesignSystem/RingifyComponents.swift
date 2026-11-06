import Foundation
import RingifyCore
import SwiftUI

// MARK: - Actions

extension View {
    /// The single most important action on a screen. Apply to `Button`, `ShareLink` or `PhotosPicker`.
    func ringifyPrimaryAction() -> some View { modifier(RingifyPrimaryActionStyle()) }

    /// A supporting action beside the primary one: neutral fill with an accent label.
    func ringifySecondaryAction() -> some View { modifier(RingifySecondaryActionStyle()) }

    /// Pins a screen's main controls above the home indicator or tab bar, so they
    /// stay reachable however long the content is. Content scrolls beneath it.
    func ringifyBottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        modifier(RingifyBottomBarModifier(bar: bar()))
    }

    /// Grouped surface for custom content outside a List, such as the waveform editor.
    func ringifyCard(padding: CGFloat = 16) -> some View { modifier(RingifyCardModifier(padding: padding)) }

    /// Surface with a hairline border, for tiles and cards on scrolling pages.
    func ringifyOutlinedCard(padding: CGFloat = 16, radius: CGFloat = 20) -> some View {
        modifier(RingifyOutlinedCardModifier(padding: padding, radius: radius))
    }
}

private struct RingifyPrimaryActionStyle: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26, *) {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.borderedProminent)
            }
        }
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .font(.headline)
        .tint(RingifyTheme.action)
        .foregroundStyle(RingifyTheme.onAction)
    }
}

private struct RingifySecondaryActionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
    }
}

private struct RingifyBottomBarModifier<Bar: View>: ViewModifier {
    let bar: Bar

    private var container: some View {
        VStack(spacing: 8) { bar }
            .padding(.horizontal, RingifyTheme.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 8)
    }

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .bottom, spacing: 0) { container }
        } else {
            content.safeAreaInset(edge: .bottom, spacing: 0) {
                container
                    .background(.bar)
                    .overlay(alignment: .top) { Divider() }
            }
        }
    }
}

private struct RingifyOutlinedCardModifier: ViewModifier {
    let padding: CGFloat
    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(padding)
            .background(RingifyTheme.surface, in: shape)
            .overlay { shape.strokeBorder(RingifyTheme.hairline.opacity(0.6), lineWidth: 0.5) }
            .contentShape(shape)
    }
}

/// Press feedback for custom cards and tiles: a slight dim and scale, no tint.
struct RingifyPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Monochrome symbol in a rounded square, the icon of tiles and source cards.
struct RingifyIconTile: View {
    let systemImage: String
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .background(RingifyTheme.subtleFill, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct RingifyCardModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RingifyTheme.surface, in: RoundedRectangle(cornerRadius: RingifyTheme.cardRadius, style: .continuous))
    }
}

struct RingifyPrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(RingifyTheme.onAction)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .foregroundStyle(RingifyTheme.onAction)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .ringifyPrimaryAction()
        .disabled(isDisabled || isLoading)
    }
}

/// Round transport control with an exact diameter. Liquid Glass on iOS 26, a
/// solid or material fill before it. Always at least a 44 pt target.
struct RingifyCircleButton: View {
    enum Emphasis: Sendable { case prominent, standard }

    let title: String
    let systemImage: String
    var emphasis: Emphasis = .standard
    var diameter: CGFloat = 44
    var isSelected = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    private var symbolColor: Color {
        if emphasis == .prominent { return RingifyTheme.onAction }
        return isSelected ? RingifyTheme.accent : .primary
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(emphasis == .prominent ? .title2.weight(.semibold) : .body.weight(.semibold))
                .foregroundStyle(symbolColor)
                .frame(width: max(44, diameter), height: max(44, diameter))
                .modifier(RingifyCircleFill(emphasis: emphasis))
                .contentShape(Circle())
                .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct RingifyCircleFill: ViewModifier {
    let emphasis: RingifyCircleButton.Emphasis

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            switch emphasis {
            case .prominent:
                content.glassEffect(.regular.tint(RingifyTheme.action).interactive(), in: .circle)
            case .standard:
                content.glassEffect(.regular.interactive(), in: .circle)
            }
        } else {
            switch emphasis {
            case .prominent:
                content.background(RingifyTheme.action, in: Circle())
            case .standard:
                content.background(.regularMaterial, in: Circle())
            }
        }
    }
}

// MARK: - Rows

/// Standard row for Lists and Forms: tinted symbol, title, optional subtitle,
/// optional trailing value and optional chevron. Use the chevron only when the
/// row navigates; a row that opens a system picker or runs an action has none.
struct RingifyRow: View {
    private let title: Text
    private let subtitle: Text?
    private let systemImage: String
    private let value: Text?
    private let showsChevron: Bool
    private let iconTint: Color?

    init(_ title: Text, subtitle: Text? = nil, systemImage: String, value: Text? = nil,
         showsChevron: Bool = false, iconTint: Color? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.value = value
        self.showsChevron = showsChevron
        self.iconTint = iconTint
    }

    var body: some View {
        HStack(spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    title.foregroundStyle(.primary)
                    if let subtitle {
                        subtitle.font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                if let iconTint {
                    Image(systemName: systemImage).foregroundStyle(iconTint)
                } else {
                    // Monochrome symbols; violet is reserved for small highlights.
                    Image(systemName: systemImage).foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let value {
                value.foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
            if showsChevron {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// A project as a row: real waveform thumbnail, name, and duration with status.
struct RingifyProjectLabel: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    let project: RingtoneProject
    /// Optional extra line, such as the project's collections.
    var detail: String? = nil

    private var summary: String {
        let status = project.status == .exported
            ? model.uiText("Zil sesi", "Ringtone")
            : model.uiText("Taslak", "Draft")
        return DurationText.formatted(project.selection.duration) + " · " + status
    }

    var body: some View {
        HStack(spacing: 12) {
            RingifyWaveformThumbnail(samples: project.waveformSamples)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .foregroundStyle(.primary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                Text(summary)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if project.library.favorite {
                Image(systemName: "star.fill")
                    .font(.footnote)
                    .foregroundStyle(.yellow)
                    .accessibilityLabel(model.uiText("Favori", "Favorite"))
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - States

struct RingifyEmptyState: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .ringifyPrimaryAction()
            }
        }
    }
}

struct RingifyLoadingView: View {
    var title: LocalizedStringKey = "common.processing"

    var body: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Waveform

/// Reduces stored peaks to the bars a width can show. It only ever reports
/// measured peaks: with fewer samples than bars it returns the samples, and it
/// never interpolates new values.
enum WaveformBars {
    static func peaks(_ samples: [Float], maximumBars: Int) -> [Float] {
        guard maximumBars > 0, !samples.isEmpty else { return [] }
        guard samples.count > maximumBars else { return samples.map(sanitized) }
        return (0..<maximumBars).map { bar in
            let lower = bar * samples.count / maximumBars
            let upper = (bar + 1) * samples.count / maximumBars
            return samples[lower..<upper].reduce(Float.zero) { max($0, sanitized($1)) }
        }
    }

    private static func sanitized(_ value: Float) -> Float {
        value.isFinite ? min(1, abs(value)) : 0
    }
}

/// Discrete rounded bars, like Voice Memos. Bars never overlap, so real audio
/// keeps its shape instead of merging into a solid block.
struct WaveformView: View {
    let samples: [Float]
    var tint: Color = RingifyTheme.violet
    var dimmedTint: Color = Color(uiColor: .tertiaryLabel)
    var selection: ClosedRange<Double> = 0...1
    var barWidth: CGFloat = 2
    var barGap: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let maximumBars = max(1, Int((size.width + barGap) / (barWidth + barGap)))
            let peaks = WaveformBars.peaks(samples, maximumBars: maximumBars)
            guard !peaks.isEmpty else { return }
            let step = size.width / CGFloat(peaks.count)
            // When zoomed past the stored peaks, widen bars instead of leaving wide gaps.
            let drawnWidth = max(barWidth, min(step - barGap, barWidth * 2))
            for (index, peak) in peaks.enumerated() {
                let height = max(2, CGFloat(peak) * size.height)
                let rect = CGRect(x: CGFloat(index) * step + (step - drawnWidth) / 2,
                                  y: (size.height - height) / 2,
                                  width: drawnWidth,
                                  height: height)
                let position = (Double(index) + 0.5) / Double(peaks.count)
                context.fill(Path(roundedRect: rect, cornerRadius: drawnWidth / 2),
                             with: .color(selection.contains(position) ? tint : dimmedTint))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Small real-waveform image for project rows. Falls back to a symbol when no
/// peaks are stored; it never draws invented audio.
struct RingifyWaveformThumbnail: View {
    let samples: [Float]
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(RingifyTheme.subtleFill)
            if samples.isEmpty {
                Image(systemName: "waveform").foregroundStyle(.tint)
            } else {
                WaveformView(samples: samples)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 9)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Time

struct DurationText: View {
    let seconds: TimeInterval

    var body: some View {
        Text(Self.formatted(seconds))
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    static func formatted(_ seconds: TimeInterval) -> String {
        let safe = max(0, seconds.isFinite ? seconds : 0)
        let minutes = Int(safe) / 60
        let remainder = safe - Double(minutes * 60)
        return String(format: "%02d:%04.1f", minutes, remainder)
    }

    /// Short form for timeline rulers, where tenths would only add noise: 0:05.
    static func ruler(_ seconds: TimeInterval) -> String {
        let safe = max(0, seconds.isFinite ? seconds : 0)
        let total = Int(safe.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
