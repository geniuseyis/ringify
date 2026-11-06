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
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
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
        if emphasis == .prominent { return .white }
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
                    Image(systemName: systemImage).foregroundStyle(.tint)
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
            ProgressView().controlSize(.large).tint(RingifyTheme.accent)
            Text(title).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct WaveformView: View {
    let samples: [Float]
    var tint: Color = RingifyTheme.accent
    var dimmedTint: Color = Color.secondary.opacity(0.22)
    var selection: ClosedRange<Double> = 0...1

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let values = samples.isEmpty ? [Float(0)] : samples
                let width = max(1, size.width / CGFloat(values.count))
                for (index, rawValue) in values.enumerated() {
                    let x = CGFloat(index) * width
                    let normalizedX = Double(index) / Double(max(1, values.count - 1))
                    let magnitude = rawValue.isFinite ? max(0.03, min(1, CGFloat(abs(rawValue)))) : 0.03
                    let height = max(3, magnitude * size.height)
                    let rect = CGRect(
                        x: x,
                        y: (size.height - height) / 2,
                        width: max(1.5, width * 0.58),
                        height: height
                    )
                    let color = selection.contains(normalizedX) ? tint : dimmedTint
                    context.fill(Path(roundedRect: rect, cornerRadius: width), with: .color(color))
                }
            }
            .accessibilityHidden(true)
        }
    }

}

struct DurationText: View {
    let seconds: TimeInterval

    var body: some View {
        Text(Self.formatted(seconds))
            .font(.system(.body, design: .monospaced, weight: .medium))
            .contentTransition(.numericText())
    }

    static func formatted(_ seconds: TimeInterval) -> String {
        let safe = max(0, seconds.isFinite ? seconds : 0)
        let minutes = Int(safe) / 60
        let remainder = safe - Double(minutes * 60)
        return String(format: "%02d:%04.1f", minutes, remainder)
    }
}
