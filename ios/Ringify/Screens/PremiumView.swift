import Foundation
import RingifyCore
import StoreKit
import SwiftUI

struct PremiumView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric private var benefitIconWidth: CGFloat = 28
    @State private var selected: ProPlan = .yearly
    @State private var showManage = false
    /// True when the project limit sheet opens this screen, so people see why it appeared.
    var showsProjectLimitNotice = false

    private var selectedProduct: Product? { purchases.product(for: selected) }
    private var selectedPrice: String { selectedProduct?.displayPrice ?? model.localized("premium.store.unavailable") }
    private var manageCurrentSubscription: Bool { purchases.isPro && !purchases.hasLifetime && selected != .lifetime }
    private var actionTitle: LocalizedStringKey {
        if purchases.hasLifetime { return "premium.active" }
        if manageCurrentSubscription { return "premium.manage" }
        return "premium.purchase"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if showsProjectLimitNotice { projectLimitNotice }
                header
                benefits
                plans
                detailsLinks
            }
            .padding(.horizontal, RingifyTheme.horizontalPadding)
            .padding(.vertical, 16)
        }
        .background(RingifyTheme.background)
        .ringifyBottomBar { purchaseBar }
        .navigationTitle("premium.navigationTitle")
        .navigationBarTitleDisplayMode(.inline)
        .manageSubscriptionsSheet(isPresented: $showManage)
        .task {
            if purchases.products.isEmpty { await purchases.loadProducts() }
            await purchases.refreshEntitlements()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await purchases.refreshEntitlements()
                    await purchases.loadProducts()
                }
            }
        }
    }

    private var projectLimitNotice: some View {
        RingifyRow(Text("premium.limit.title").font(.headline), systemImage: "lock.fill")
            .padding(.horizontal, RingifyTheme.horizontalPadding)
            .padding(.vertical, 4)
            .ringifyCard(padding: 0)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Ringify Pro")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
            Text("premium.plans.intro")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if purchases.isPro { activeStatus }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var activeStatus: some View {
        Label {
            Text(LocalizedStringKey(purchases.hasLifetime ? "premium.lifetime.active" : "premium.active"))
        } icon: {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(RingifyTheme.success)
                .accessibilityHidden(true)
        }
        .font(.footnote.weight(.semibold))
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("slider.horizontal.3", title: model.uiText("Normalize ile dengeli ses", "Balanced sound with normalization"))
            benefit("square.stack", title: model.uiText("3 kayıtlı proje için alan", "Room for 3 saved projects"))
            benefit("checkmark.seal", title: model.uiText("Her planda aynı Pro kapsamı", "The same Pro features in every plan"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ringifyCard()
    }

    private func benefit(_ icon: String, title: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: benefitIconWidth)
                .accessibilityHidden(true)
        }
    }

    private var plans: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("premium.plans.choose")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            ForEach(ProPlan.allCases) { plan in planButton(plan) }
            chargeDisclosure
        }
    }

    private var planShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: RingifyTheme.cardRadius, style: .continuous)
    }

    private func planButton(_ plan: ProPlan) -> some View {
        let isSelected = selected == plan
        return Button { selected = plan } label: {
            HStack(spacing: 12) {
                planDetails(plan)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? RingifyTheme.accent : Color.secondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ringifyCard()
            .overlay {
                if isSelected {
                    planShape.strokeBorder(RingifyTheme.accent, lineWidth: 2)
                }
            }
            .contentShape(planShape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func planDetails(_ plan: ProPlan) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.localized("premium.plan.\(plan.rawValue)"))
                    .font(.headline)
                Text(model.localized("premium.period.\(plan.rawValue)"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(purchases.product(for: plan)?.displayPrice ?? model.localized("premium.store.unavailable"))
                .font(.headline)
                .monospacedDigit()
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
        }
    }

    private var chargeDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.localized("premium.billing.\(selected.rawValue)"))
            if selected == .lifetime && purchases.isPro && !purchases.hasLifetime {
                Text("premium.lifetime.existingSubscription")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder private var purchaseBar: some View {
        Text(model.localized("premium.plan.\(selected.rawValue)") + " · " + selectedPrice)
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        RingifyPrimaryButton(title: actionTitle, systemImage: "crown.fill",
            isLoading: purchases.isBusy,
            isDisabled: purchases.hasLifetime || purchases.pendingPlan != nil || purchases.pendingSlot != nil ||
                (!manageCurrentSubscription && selectedProduct == nil)) {
            if manageCurrentSubscription { showManage = true }
            else { Task { await purchases.purchase(selected) } }
        }
        PurchaseFeedbackView()
        if selectedProduct == nil && !purchases.isBusy {
            Button { Task { await purchases.loadProducts() } } label: {
                Text("premium.reload")
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
    }

    private var detailsLinks: some View {
        VStack(spacing: 12) {
            linkCard {
                NavigationLink { PurchaseSupportView() } label: {
                    detailRow(model.uiText("Ödeme ve satın alımları geri yükleme", "Billing and restore purchases"), icon: "arrow.clockwise")
                }
                Divider()
                NavigationLink { ProComparisonView() } label: {
                    detailRow(model.uiText("Normal ve Pro'yu karşılaştır", "Compare Normal and Pro"), icon: "list.bullet.rectangle")
                }
                Divider()
                NavigationLink { ProFAQView() } label: {
                    detailRow(model.uiText("Sık sorulan sorular", "Frequently asked questions"), icon: "questionmark.circle")
                }
                Divider()
                NavigationLink { ProjectCapacityView() } label: {
                    detailRow(model.uiText("Proje kapasitesi ve ek yuvalar", "Project capacity and extra slots"), icon: "square.stack.3d.up")
                }
            }
            linkCard {
                NavigationLink { RingifyTermsView() } label: {
                    detailRow(model.uiText("Kullanım koşulları", "Terms of use"), icon: "doc.text")
                }
                Divider()
                NavigationLink { RingifyPrivacyView() } label: {
                    detailRow(model.localized("settings.privacy"), icon: "hand.raised")
                }
            }
        }
    }

    private func linkCard<Rows: View>(@ViewBuilder _ rows: () -> Rows) -> some View {
        VStack(spacing: 0) { rows() }
            .padding(.horizontal, RingifyTheme.horizontalPadding)
            .ringifyCard(padding: 0)
            .buttonStyle(.plain)
    }

    private func detailRow(_ title: String, icon: String) -> some View {
        RingifyRow(Text(title), systemImage: icon, showsChevron: true)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
    }
}

private struct ProComparisonView: View {
    @EnvironmentObject private var model: AppModel
    private let sharedFeatures = ["import", "record", "trim", "playback", "gain", "wav", "reopen", "management", "privacy"]

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    planSummary("Normal", count: ProAccessPolicy.normalProjectLimit, pro: false)
                    planSummary("Pro", count: ProAccessPolicy.proProjectLimit, pro: true)
                }
            }
            Section(model.uiText("Pro ile gelenler", "Included with Pro")) {
                Label("premium.compare.normalize", systemImage: "slider.horizontal.3")
                Label(model.uiText("3 kayıtlı proje", "3 saved projects"), systemImage: "square.stack")
                Label("premium.compare.analysis", systemImage: "waveform.path")
            }
            Section(model.uiText("Her iki planda", "In both plans")) {
                ForEach(sharedFeatures, id: \.self) { key in
                    Label(model.localized("premium.compare.\(key)"), systemImage: "checkmark")
                }
            }
            Section(model.uiText("Proje alanı", "Project capacity")) {
                Text("premium.legacy.preserved").foregroundStyle(.secondary)
                Text(model.uiText(
                    "Bir projeyi silmek yuvasını yeniden kullanılabilir yapar. Pro sona ererse kayıtların ve satın alınan yuvaların korunur; yeni proje oluşturma Normal sınırını izler. Pro etkinken ayrı kalıcı ürünlerle en fazla 20 ek yuva alınabilir.",
                    "Deleting a project frees capacity. If Pro ends, projects and purchased slots are preserved; new projects follow the Normal limit. While Pro is active, up to 20 extra slots can be purchased as separate permanent products."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .ringifyStudioAppearance()
        .navigationTitle(model.uiText("Normal ve Pro", "Normal and Pro"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func planSummary(_ title: String, count: Int, pro: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(pro ? RingifyTheme.Studio.accent : Color.primary)
            Text(model.uiText("\(count) kayıtlı proje", count == 1 ? "1 saved project" : "\(count) saved projects")).font(.subheadline)
            Text(pro ? model.localized("premium.compare.normalize") : model.uiText("Temel düzenleme", "Core editing"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProFAQView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            Section {
                faq(model.uiText("Planlar arasında ne fark var?", "How do the plans differ?"), answer: model.localized("premium.plans.sameScope"))
                faq(model.uiText("Ömür boyu plan yenilenir mi?", "Does Lifetime renew?"),
                    answer: model.uiText("Hayır. Ömür boyu Pro tek ödemedir. Haftalık, aylık ve yıllık planlar aboneliktir.",
                        "No. Lifetime Pro is a one-time purchase. Weekly, monthly and yearly plans are subscriptions."))
                faq(model.uiText("Pro biterse projelerime ne olur?", "What happens to my projects if Pro ends?"),
                    answer: model.uiText("Mevcut projelerin ve ayarların korunur. Yeni proje oluştururken Normal planın 1 proje sınırı uygulanır.",
                        "Your existing projects and settings are preserved. Creating a new project follows the Normal limit of 1 saved project."))
                faq(model.uiText("Ek proje yuvası alabilir miyim?", "Can I buy an extra project slot?"),
                    answer: model.uiText("Proje kapasitesi sayfasından, Pro etkinken ayrı kalıcı ürünler olarak en fazla 20 ek yuva alınabilir. Aynı Apple hesabıyla geri yüklenir; tutar Apple ödeme ekranında gösterilir.",
                        "From Project Capacity, active Pro owners can buy up to 20 separate permanent slots. Restore them with the same Apple account; Apple displays the purchase price."))
            }
            Section {
                NavigationLink { PurchaseSupportView() } label: {
                    SettingsNavigationRow(title: model.uiText("Ödeme ve geri yükleme yardımı", "Billing and restore help"), icon: "creditcard")
                }
            }
        }
        .listStyle(.insetGrouped)
        .ringifyStudioAppearance()
        .navigationTitle(model.uiText("Pro Hakkında Sorular", "Pro Questions"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func faq(_ question: String, answer: String) -> some View {
        DisclosureGroup(question) {
            Text(answer).font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8)
        }
        .padding(.vertical, 5)
    }
}

struct PurchaseSupportView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var model: AppModel
    @State private var showManage = false

    var body: some View {
        List {
            Section(model.uiText("Satın alma durumu", "Purchase status")) {
                LabeledContent(model.uiText("Erişim", "Access"), value: purchases.isPro ? "Ringify Pro" : "Ringify Normal")
                if purchases.hasLifetime {
                    Label("premium.lifetime.active", systemImage: "checkmark.seal.fill").foregroundStyle(RingifyTheme.success)
                }
                ForEach(ProPlan.allCases.filter { purchases.verifiedPlans.contains($0) }) { plan in
                    LabeledContent(model.uiText("Doğrulanan plan", "Verified plan"), value: model.localized("premium.plan.\(plan.rawValue)"))
                }
                PurchaseFeedbackView()
            }
            Section {
                Button {
                    Task { await purchases.restorePurchases() }
                } label: {
                    Label("premium.restore", systemImage: "arrow.clockwise").frame(minHeight: 44)
                }
                .disabled(purchases.isBusy)
                if purchases.isBusy { ProgressView("common.processing") }
            } footer: {
                Text(model.uiText("Satın alırken kullandığın Apple Hesabıyla App Store'a giriş yap. Geri yükleme yeni bir ödeme başlatmaz.",
                    "Sign in to the App Store with the Apple Account used for your purchase. Restoring does not start a new payment."))
            }
            Section(model.uiText("Abonelik ve ödeme", "Subscription and billing")) {
                Button { showManage = true } label: {
                    Label("premium.manage", systemImage: "creditcard").frame(minHeight: 44)
                }
                Text("premium.terms").font(.footnote).foregroundStyle(.secondary)
                Text(model.uiText("Yenileme, iptal ve ödeme bilgilerini Apple'ın abonelik ekranında kontrol edebilirsin.",
                    "Review renewal, cancellation and billing details in Apple's subscription screen."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                NavigationLink { RingifyTermsView() } label: {
                    SettingsNavigationRow(title: model.uiText("Kullanım koşulları", "Terms of use"), icon: "doc.text")
                }
                NavigationLink { RingifyPrivacyView() } label: {
                    SettingsNavigationRow(title: model.localized("settings.privacy"), icon: "hand.raised")
                }
            }
        }
        .listStyle(.insetGrouped)
        .ringifyStudioAppearance()
        .navigationTitle(model.uiText("Satın Alımlar", "Purchases"))
        .navigationBarTitleDisplayMode(.inline)
        .manageSubscriptionsSheet(isPresented: $showManage)
        .task { await purchases.refreshEntitlements() }
    }
}

private struct PurchaseFeedbackView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if purchases.state == .pending {
            Label("premium.pending", systemImage: "clock").font(.footnote)
        }
        if case .failed(let message) = purchases.state {
            Label(model.localized(message), systemImage: "exclamationmark.circle")
                .font(.footnote).foregroundStyle(RingifyTheme.danger)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}
