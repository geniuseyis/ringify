import Foundation
import SwiftUI

struct RingtoneGuideView: View {
    private enum Method: String { case modern, garageBand }
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var numberSize: CGFloat = 32
    @State private var method: Method?

    private var supportsModernFlow: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    private var selectedMethod: Method { method ?? (supportsModernFlow ? .modern : .garageBand) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(spacing: 14) {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.largeTitle)
                        .foregroundStyle(RingifyTheme.Studio.accent)
                        .frame(width: 80, height: 80)
                        .background(RingifyTheme.Studio.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 22))
                        .accessibilityHidden(true)
                    Text(model.uiText("Kendi sesinle çalsın.", "Make it sound like you."))
                        .font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Text(selectedMethod == .modern ? LocalizedStringKey("guide.modern.title") : LocalizedStringKey("guide.legacy.title"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                if supportsModernFlow {
                    if typeSize.isAccessibilitySize {
                        methodPicker.pickerStyle(.menu).accessibilityIdentifier("guide.method")
                    } else {
                        methodPicker.pickerStyle(.segmented).accessibilityIdentifier("guide.method")
                    }
                }
                if selectedMethod == .modern {
                    step(1, title: "guide.modern.step1.title", message: "guide.modern.step1.message")
                    step(2, title: "guide.modern.step2.title", message: "guide.modern.step2.message")
                    step(3, title: "guide.modern.step3.title", message: "guide.modern.step3.message")
                } else {
                    step(1, title: "guide.legacy.step1.title", message: "guide.legacy.step1.message")
                    step(2, title: "guide.legacy.step2.title", message: "guide.legacy.step2.message")
                    step(3, title: "guide.legacy.step3.title", message: "guide.legacy.step3.message")
                    step(4, title: "guide.legacy.step4.title", message: "guide.legacy.step4.message")
                }

                DisclosureGroup(model.uiText("Yöntem hakkında", "About this method")) {
                    Text("guide.disclaimer").font(.subheadline).foregroundStyle(.secondary)
                        .padding(.top, 10)
                }
                .modifier(NativeContentCard())
                if let exported = model.exportedRingtone {
                    ShareLink(item: exported.url) {
                        Label("export.share", systemImage: "square.and.arrow.up")
                            .multilineTextAlignment(.center)
                            .modifier(NativePrimaryActionLabel())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("guide.share")
                    Button("common.done") { dismiss() }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .buttonStyle(.bordered)
                } else {
                    NativePrimaryAction(title: "common.done", icon: "checkmark") { dismiss() }
                }
                Button(model.uiText("Yardım Merkezi", "Help Center"), systemImage: "questionmark.circle") { router.push(.help) }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("guide.help")
            }
            .padding(RingifyTheme.horizontalPadding)
        }
        .background(RingifyTheme.Studio.background)
        .tint(RingifyTheme.Studio.accent)
        .ringifyStudioAppearance()
        .navigationTitle("guide.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var methodPicker: some View {
        Picker(model.uiText("Yöntem", "Method"), selection: Binding(get: { selectedMethod }, set: { method = $0 })) {
            Text("iOS 26+").tag(Method.modern)
            Text("GarageBand").tag(Method.garageBand)
        }
        .frame(minHeight: 44)
    }

    private func step(_ number: Int, title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
        return layout {
            Text(number.formatted())
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: numberSize, height: numberSize)
                .background(RingifyTheme.Studio.action, in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .modifier(NativeContentCard())
        .accessibilityElement(children: .combine)
    }
}
