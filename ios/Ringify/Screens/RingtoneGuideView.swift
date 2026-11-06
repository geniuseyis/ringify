import Foundation
import SwiftUI

struct RingtoneGuideView: View {
    private enum Method: String { case modern, garageBand }
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var method: Method?

    private var supportsModernFlow: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    private var selectedMethod: Method { method ?? (supportsModernFlow ? .modern : .garageBand) }

    var body: some View {
        List {
            if supportsModernFlow {
                Section {
                    methodRow
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
            stepsSection
            Section {
                DisclosureGroup(model.uiText("Yöntem hakkında", "About this method")) {
                    Text("guide.disclaimer").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Section {
                Button { router.push(.help) } label: {
                    RingifyRow(Text(model.uiText("Yardım Merkezi", "Help Center")), systemImage: "questionmark.circle", showsChevron: true)
                }
                .accessibilityIdentifier("guide.help")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("guide.title")
        .navigationBarTitleDisplayMode(.inline)
        .ringifyBottomBar { bottomActions }
    }

    @ViewBuilder private var methodRow: some View {
        if typeSize.isAccessibilitySize {
            methodPicker.pickerStyle(.menu).accessibilityIdentifier("guide.method")
        } else {
            methodPicker.pickerStyle(.segmented).accessibilityIdentifier("guide.method")
        }
    }

    private var methodPicker: some View {
        Picker(model.uiText("Yöntem", "Method"), selection: Binding(get: { selectedMethod }, set: { method = $0 })) {
            Text("iOS 26+").tag(Method.modern)
            Text("GarageBand").tag(Method.garageBand)
        }
        .frame(minHeight: 44)
    }

    private var stepsSection: some View {
        Section {
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
        } header: {
            Text(selectedMethod == .modern ? LocalizedStringKey("guide.modern.title") : LocalizedStringKey("guide.legacy.title"))
                .textCase(nil)
        }
    }

    private func step(_ number: Int, title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "\(number).circle.fill")
                .foregroundStyle(.tint)
                .accessibilityLabel(number.formatted())
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var bottomActions: some View {
        if let exported = model.exportedRingtone {
            ShareLink(item: exported.url) {
                Label("export.share", systemImage: "square.and.arrow.up")
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .ringifyPrimaryAction()
            .accessibilityIdentifier("guide.share")
            Button { dismiss() } label: {
                Text("common.done").frame(maxWidth: .infinity)
            }
            .ringifySecondaryAction()
        } else {
            RingifyPrimaryButton(title: "common.done", systemImage: "checkmark") { dismiss() }
        }
    }
}
