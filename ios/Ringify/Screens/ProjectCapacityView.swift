import RingifyCore
import StoreKit
import SwiftUI

struct ProjectCapacityView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        List {
            Section(model.uiText("Proje alanın", "Your project capacity")) {
                NativeMetadataRow(title: model.uiText("Geçerli sınır", "Current limit"), value: String(purchases.projectLimit))
                NativeMetadataRow(title: model.uiText("Satın alınan ek yuvalar", "Purchased extra slots"), value: "\(purchases.verifiedSlots.count) / 20")
                Text(model.uiText("Normal 1, Pro 3 temel proje içerir. Ek yuvalar yalnız Pro etkinken kapasiteye eklenir. Mevcut projeler sınır düşse de silinmez.",
                    "Normal includes 1 project and Pro includes 3. Extra slots add capacity while Pro is active. Existing projects are never deleted when the limit decreases."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section(model.uiText("Kalıcı ek yuva", "Permanent extra slot")) {
                if let slot = purchases.nextSlot {
                    if let product = purchases.product(for: slot) {
                        LabeledContent(model.uiText("Yuva \(slot.index)", "Slot \(slot.index)"), value: product.displayPrice)
                        Button { Task { await purchases.purchaseNextSlot() } } label: {
                            Label(model.uiText("1 ek yuva satın al", "Buy 1 extra slot"), systemImage: "plus.square").frame(minHeight: 44)
                        }
                        .disabled(!purchases.isPro || purchases.isBusy || purchases.pendingSlot != nil || purchases.pendingPlan != nil)
                        .accessibilityIdentifier("capacity.purchase")
                    } else {
                        Text("premium.store.unavailable").foregroundStyle(.secondary)
                        Button("premium.reload") { Task { await purchases.loadProducts() } }.disabled(purchases.isBusy).frame(minHeight: 44)
                    }
                } else { Label(model.uiText("20 ek yuvanın tamamına sahipsin", "You own all 20 extra slots"), systemImage: "checkmark.seal") }
                if !purchases.isPro { Text("premium.slot.requiresPro").font(.footnote).foregroundStyle(.secondary) }
                Text(model.uiText("Her yuva ayrı bir kalıcı satın alımdır; abonelik değildir. Projeyi silince yuva yeniden kullanılabilir. Aynı Apple hesabıyla satın alımları geri yükleyebilirsin.",
                    "Each slot is a separate permanent purchase, not a subscription. Deleting a project frees capacity. Restore purchases with the same Apple account."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                switch purchases.slotState {
                case .purchasing, .loading: ProgressView(model.uiText("İşleniyor…", "Processing…"))
                case .pending: Label(model.uiText("Apple onayı bekleniyor", "Waiting for Apple approval"), systemImage: "clock")
                case .failed(let message): Text(model.localized(message)).foregroundStyle(RingifyTheme.danger)
                case .purchased: Label(model.uiText("Satın alınan yuvalar geri yüklenebilir", "Purchased slots can be restored"), systemImage: "checkmark.seal")
                case .idle: EmptyView()
                }
                if case .failed(let message) = purchases.state { Text(model.localized(message)).foregroundStyle(RingifyTheme.danger) }
                Button("premium.restore") { Task { await purchases.restorePurchases() } }.disabled(purchases.isBusy).frame(minHeight: 44)
                    .accessibilityIdentifier("capacity.restore")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(model.uiText("Proje kapasitesi", "Project capacity"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await reload() } } }
    }
    private func reload() async { await purchases.refreshEntitlements(); await purchases.loadProducts() }
}
