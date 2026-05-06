import SwiftUI
import StoreKit
import SwiftData

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var preferences: [AppPreferences]
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    let config: SubscriptionConfig

    @State private var selectedPlanID: String?
    @State private var isPurchasing = false

    private var appPreferences: AppPreferences? {
        preferences.first
    }

    private var yearlyProduct: Product? {
        subscriptionManager.availableProducts.first { $0.id == SubscriptionProductIDs.yearly }
    }

    private var monthlyProduct: Product? {
        subscriptionManager.availableProducts.first { $0.id == SubscriptionProductIDs.monthly }
    }

    private var lifetimeProduct: Product? {
        subscriptionManager.availableProducts.first { $0.id == SubscriptionProductIDs.lifetime }
    }

    init(config: SubscriptionConfig = .mock) {
        self.config = config
        _selectedPlanID = State(initialValue: SubscriptionProductIDs.lifetime)
    }

    var body: some View {
        TimePaywallTemplateView(
            config: config,
            yearlyProduct: yearlyProduct,
            monthlyProduct: monthlyProduct,
            lifetimeProduct: lifetimeProduct,
            isLoading: subscriptionManager.isLoading,
            availableProductsEmpty: subscriptionManager.availableProducts.isEmpty,
            errorMessage: subscriptionManager.errorMessage,
            selectedPlanID: selectedPlanID,
            isPurchasing: isPurchasing,
            onSelectPlan: { planID in
                selectedPlanID = planID
            },
            onPurchase: handleCTAPress,
            onRestore: handleRestore,
            onClose: {
                dismiss()
            },
            onTryAgain: {
                Task { await subscriptionManager.loadProducts(force: true) }
            },
            onTerms: {
                if let url = URL(string: "https://xeo.com/TimeBlocking/terms.html") {
                    openURL(url)
                }
            },
            onPrivacy: {
                if let url = URL(string: "https://xeo.com/TimeBlocking/privacy.html") {
                    openURL(url)
                }
            }
        )
        .onAppear {
            if subscriptionManager.availableProducts.isEmpty {
                Task {
                    await subscriptionManager.loadProducts()
                    if selectedPlanID == nil || selectedPlanID == SubscriptionProductIDs.lifetime,
                       let firstProduct = subscriptionManager.availableProducts.first {
                        selectedPlanID = firstProduct.id
                    }
                }
            }
        }
        .onChange(of: subscriptionManager.isPremium) { _, isPremium in
            if isPremium {
                updateAppPreferences()
                dismiss()
            }
        }
    }

    private func handleCTAPress() {
        let planID = selectedPlanID ?? yearlyProduct?.id ?? ""
        guard let productToPurchase = subscriptionManager.availableProducts.first(where: { $0.id == planID }) else {
            return
        }

        isPurchasing = true
        Task {
            let success = await subscriptionManager.purchase(productToPurchase)
            await MainActor.run {
                isPurchasing = false
                if success {
                    updateAppPreferences()
                    HapticManager.shared.success()
                    dismiss()
                } else {
                    HapticManager.shared.error()
                }
            }
        }
    }

    private func handleRestore() {
        isPurchasing = true
        Task {
            await subscriptionManager.restorePurchases()
            await MainActor.run {
                isPurchasing = false
                if subscriptionManager.isPremium {
                    updateAppPreferences()
                }
            }
        }
    }

    private func updateAppPreferences() {
        guard let appPreferences else { return }
        appPreferences.isPremium = subscriptionManager.isPremium
        try? modelContext.save()
    }
}

#Preview {
    SubscriptionView(config: .mock)
        .modelContainer(for: AppPreferences.self, inMemory: true)
}
