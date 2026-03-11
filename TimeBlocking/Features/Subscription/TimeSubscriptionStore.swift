import Foundation
import Observation
import StoreKit

struct TimeSubscriptionConfig: Sendable {
    struct Plan: Identifiable, Hashable, Sendable {
        let id: String
        let productID: String?
        let title: String
        let subtitle: String
        let fallbackPrice: String
        let fallbackDetail: String
        let badge: String?
        let isRecommended: Bool
        let isLifetime: Bool

        init(id: String, productID: String?, title: String, subtitle: String, fallbackPrice: String, fallbackDetail: String, badge: String? = nil, isRecommended: Bool = false, isLifetime: Bool = false) {
            self.id = id
            self.productID = productID
            self.title = title
            self.subtitle = subtitle
            self.fallbackPrice = fallbackPrice
            self.fallbackDetail = fallbackDetail
            self.badge = badge
            self.isRecommended = isRecommended
            self.isLifetime = isLifetime
        }

    }

    struct Feature: Identifiable, Hashable, Sendable {
        let id: String
        let icon: String
        let title: String
        let description: String
    }

    struct SecondaryAction: Identifiable, Hashable, Sendable {
        var id: String { title }
        let title: String
        let actionID: String
    }

    let title: String
    let subtitle: String
    let ctaTitle: String
    let activeTitle: String
    let activeMessage: String
    let restoreTitle: String
    let billingFootnote: String
    let missingSetupMessage: String
    let plans: [Plan]
    let features: [Feature]
    let secondaryActions: [SecondaryAction]

    var recommendedPlanID: String? {
        plans.first(where: \.isRecommended)?.id ?? plans.first?.id
    }

    var productIDs: [String] {
        plans.compactMap(\.productID)
    }
}

extension TimeSubscriptionConfig {
    private enum ProductIDs {
        static let monthly = "com.melichan.TimeBlocking.monthly"
        static let yearly = "com.melichan.TimeBlocking.yearly"
        static let lifetime = "com.melichan.TimeBlocking.lifetime"
    }

    nonisolated static let time = TimeSubscriptionConfig(
        title: "Full Access",
        subtitle: "One subscription for all your devices with unlimited planning power and sync.",
        ctaTitle: "Continue",
        activeTitle: "Full Access Active",
        activeMessage: "All premium planning features are unlocked on this account.",
        restoreTitle: "Restore Purchases",
        billingFootnote: "Subscriptions are billed through Apple. Prices may vary by region.",
        missingSetupMessage: "Store configuration is currently unavailable.",
        plans: [
            Plan(
                id: "yearly",
                productID: ProductIDs.yearly,
                title: "Yearly",
                subtitle: "Best for consistent planning",
                fallbackPrice: "$23.99",
                fallbackDetail: "Billed annually · Save 50%",
                badge: "50% OFF",
                isRecommended: true
            ),
            Plan(
                id: "monthly",
                productID: ProductIDs.monthly,
                title: "Monthly",
                subtitle: "Flexible access",
                fallbackPrice: "$3.99",
                fallbackDetail: "Billed monthly",
                isRecommended: false
            ),
            Plan(
                id: "lifetime",
                productID: ProductIDs.lifetime,
                title: "Lifetime",
                subtitle: "One-time payment",
                fallbackPrice: "$49.99",
                fallbackDetail: "one-time payment",
                isLifetime: true
            )
        ],
        features: [
            Feature(
                id: "unlimited-blocks",
                icon: "calendar.badge.clock",
                title: "Unlimited Time Blocks",
                description: "Plan every detail of your day without any restrictions on block count."
            ),
            Feature(
                id: "advanced-rules",
                icon: "sparkles",
                title: "Smart Regeneration",
                description: "Unlock advanced generation rules to automatically rebuild your schedule."
            ),
            Feature(
                id: "icloud-sync",
                icon: "icloud.fill",
                title: "Multi-Device Sync",
                description: "Your schedule stays perfectly in sync across iPhone, iPad, and Mac."
            ),
            Feature(
                id: "templates",
                icon: "square.on.square",
                title: "Premium Templates",
                description: "Save and reuse complex day structures for work, deep work, and routines."
            )
        ],
        secondaryActions: [
            SecondaryAction(title: "Restore", actionID: "restore"),
            SecondaryAction(title: "Terms of Use", actionID: "terms"),
            SecondaryAction(title: "Privacy Policy", actionID: "privacy")
        ]
    )
}

@MainActor
@Observable
final class TimeSubscriptionStore {
    enum AccessState: Equatable {
        case unknown
        case inactive
        case active
    }

    enum PurchaseState: Equatable {
        case idle
        case loadingProducts
        case purchasing(planID: String)
        case restoring
    }

    let config: TimeSubscriptionConfig
    var accessState: AccessState = .unknown
    var purchaseState: PurchaseState = .idle
    var availableProductsByID: [String: Product] = [:]
    var lastErrorMessage: String?

    @ObservationIgnored
    private var updatesTask: Task<Void, Never>?

    init(config: TimeSubscriptionConfig) {
        self.config = config
        updatesTask = observeTransactionUpdates()

        Task {
            await refresh()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var isPremium: Bool {
        accessState == .active
    }

    var hasConfiguredProducts: Bool {
        !config.productIDs.isEmpty
    }

    var isBusy: Bool {
        purchaseState != .idle
    }

    func refresh() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func product(for plan: TimeSubscriptionConfig.Plan) -> Product? {
        guard let productID = plan.productID else {
            return nil
        }

        return availableProductsByID[productID]
    }

    func loadProducts() async {
        lastErrorMessage = nil

        guard hasConfiguredProducts else {
            availableProductsByID = [:]
            purchaseState = .idle
            return
        }

        purchaseState = .loadingProducts

        do {
            let products = try await Product.products(for: config.productIDs)
            availableProductsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            availableProductsByID = [:]
            lastErrorMessage = "Could not load subscriptions from the App Store."
        }

        purchaseState = .idle
    }

    func purchase(plan: TimeSubscriptionConfig.Plan) async -> Bool {
        guard let product = product(for: plan) else {
            lastErrorMessage = config.missingSetupMessage
            return false
        }

        lastErrorMessage = nil
        purchaseState = .purchasing(planID: plan.id)

        defer {
            purchaseState = .idle
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                guard case .verified(let transaction) = verificationResult else {
                    lastErrorMessage = "The App Store could not verify the purchase."
                    return false
                }

                await transaction.finish()
                await refreshEntitlements()
                return isPremium
            case .pending:
                lastErrorMessage = "The purchase is pending approval."
                return false
            case .userCancelled:
                return false
            @unknown default:
                lastErrorMessage = "The purchase could not be completed."
                return false
            }
        } catch {
            lastErrorMessage = "The App Store purchase request failed."
            return false
        }
    }

    func restorePurchases() async {
        lastErrorMessage = nil
        purchaseState = .restoring

        defer {
            purchaseState = .idle
        }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastErrorMessage = "Restore purchases failed."
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else {
                    return
                }

                await self.handle(transactionResult: result)
            }
        }
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = transactionResult else {
            return
        }

        guard config.productIDs.contains(transaction.productID) else {
            return
        }

        await transaction.finish()
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        guard hasConfiguredProducts else {
            accessState = .inactive
            return
        }

        var hasActiveEntitlement = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            guard config.productIDs.contains(transaction.productID) else {
                continue
            }

            guard transaction.revocationDate == nil else {
                continue
            }

            if let expirationDate = transaction.expirationDate, expirationDate < .now {
                continue
            }

            hasActiveEntitlement = true
            break
        }

        accessState = hasActiveEntitlement ? .active : .inactive
    }
}
