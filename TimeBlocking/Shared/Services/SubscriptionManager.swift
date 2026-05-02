import Foundation
import Combine
import StoreKit
import SwiftUI
import OSLog

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TimeBlocking", category: "Subscription")

    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published var availableProducts: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastLoadError: String?

    let productIdentifiers: [String] = [
        SubscriptionProductIDs.monthly,
        SubscriptionProductIDs.yearly,
        SubscriptionProductIDs.lifetime
    ]

    private var updateListenerTask: Task<Void, Error>?

    enum SubscriptionStatus {
        case unknown
        case notSubscribed
        case subscribed
        case expired
    }

    private init() {
        startListeningForTransactions()
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func loadProducts(force: Bool = false) async {
        if isLoading { return }
        if !force && !availableProducts.isEmpty { return }

        isLoading = true
        errorMessage = nil
        lastLoadError = nil

        logger.debug("StoreKit: Requesting products for identifiers: \(self.productIdentifiers)")

        do {
            let products = try await Product.products(for: productIdentifiers)
            logger.info("StoreKit: Successfully fetched \(products.count) products.")

            #if DEBUG
            print("DEBUG: IDs requested: \(productIdentifiers), count returned: \(products.count), returned product IDs: \(products.map { $0.id })")
            #endif

            for product in products {
                logger.debug("StoreKit: Received product [ID: \(product.id)] [Name: \(product.displayName)]")
            }

            availableProducts = products.sorted { product1, product2 in
                Self.productSortRank(product1.id) < Self.productSortRank(product2.id)
            }
            isLoading = false
            await checkSubscriptionStatus()
        } catch {
            logger.error("StoreKit: Failed to load products. Error: \(error.localizedDescription)")
            errorMessage = "Failed to load subscription options: \(error.localizedDescription)"
            lastLoadError = error.localizedDescription
            isLoading = false
        }
    }

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkSubscriptionStatus()
                isLoading = false
                return true
            case .userCancelled:
                isLoading = false
                return false
            case .pending:
                isLoading = false
                errorMessage = "Purchase is pending approval"
                return false
            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Purchase failed: \(error.localizedDescription)"
                self.isLoading = false
            }
            return false
        }
    }

    func restorePurchases() async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            isLoading = false
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func checkSubscriptionStatus() async {
        var status: SubscriptionStatus = .notSubscribed

        for productID in productIdentifiers {
            guard let product = try? await Product.products(for: [productID]).first else {
                continue
            }

            if let subscription = product.subscription,
               let state = try? await subscription.status.first {
                switch state.state {
                case .subscribed, .inGracePeriod:
                    status = .subscribed
                case .expired, .revoked:
                    if status != .subscribed {
                        status = .expired
                    }
                default:
                    break
                }
            } else if product.type == .nonConsumable {
                for await result in Transaction.currentEntitlements {
                    if case .verified(let transaction) = result, transaction.productID == productID {
                        status = .subscribed
                        break
                    }
                }
            }
        }

        subscriptionStatus = status

        let isPremiumNow = status == .subscribed
        if NSUbiquitousKeyValueStore.default.bool(forKey: "hasPro") != isPremiumNow {
            NSUbiquitousKeyValueStore.default.set(isPremiumNow, forKey: "hasPro")
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }

    var isPremium: Bool {
        subscriptionStatus == .subscribed
    }

    var hasPro: Bool {
        isPremium
    }

    private func startListeningForTransactions() {
        updateListenerTask = Task.detached { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    Task { @MainActor [weak self] in
                        await self?.checkSubscriptionStatus()
                    }
                } catch {
                    logger.error("Transaction verification failed: \(error)")
                }
            }
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    nonisolated private static func productSortRank(_ productID: String) -> Int {
        switch productID {
        case SubscriptionProductIDs.monthly:
            0
        case SubscriptionProductIDs.yearly:
            1
        case SubscriptionProductIDs.lifetime:
            2
        default:
            3
        }
    }
}

extension Product {
    var isYearly: Bool {
        if id.localizedCaseInsensitiveContains("yearly") {
            return true
        }
        if let subscription {
            let period = subscription.subscriptionPeriod
            return (period.unit == .year && period.value == 1) || (period.unit == .month && period.value == 12)
        }
        return false
    }

    var displayTitle: String {
        if isYearly {
            return String(localized: "Yearly")
        }

        if id.localizedCaseInsensitiveContains("monthly") {
            return String(localized: "Monthly")
        }

        if let subscription {
            switch subscription.subscriptionPeriod.unit {
            case .month:
                return String(localized: "Monthly")
            case .year:
                return String(localized: "Yearly")
            case .week:
                return String(localized: "Weekly")
            case .day:
                return String(localized: "Daily")
            @unknown default:
                return displayName
            }
        } else if type == .nonConsumable || id.localizedCaseInsensitiveContains("lifetime") {
            return String(localized: "Lifetime Access")
        }

        return displayName
    }
}

enum SubscriptionError: Error {
    case failedVerification
}

struct SubscriptionProductIDs {
    static let monthly = "com.xeo.timeblocking.monthly"
    static let yearly = "com.xeo.timeblocking.yearly"
    static let lifetime = "com.xeo.timeblocking.lifetime"

    static var all: Set<String> {
        [monthly, yearly, lifetime]
    }
}

struct SubscriptionConfig: Codable, Equatable {
    let title: String
    let subtitle: String
    let plans: [SubscriptionPlan]
    let oneTimeOption: SubscriptionPlan?
    let features: [SubscriptionFeature]
    let ctaTitle: String
    let secondaryActions: [SecondaryAction]

    struct SubscriptionPlan: Identifiable, Codable, Equatable {
        let id: String
        let label: String
        let price: String
        let billingFrequency: String
        let badge: String?
        let isRecommended: Bool

        init(id: String, label: String, price: String, billingFrequency: String, badge: String? = nil, isRecommended: Bool = false) {
            self.id = id
            self.label = label
            self.price = price
            self.billingFrequency = billingFrequency
            self.badge = badge
            self.isRecommended = isRecommended
        }
    }

    struct SubscriptionFeature: Identifiable, Codable, Equatable {
        var id: String { title }
        let icon: String
        let title: String
        let description: String
    }

    struct SecondaryAction: Identifiable, Codable, Equatable {
        var id: String { title }
        let title: String
        let actionID: String
    }
}

extension SubscriptionConfig {
    static let mock = SubscriptionConfig(
        title: "Full Access",
        subtitle: "One subscription for all your devices with unlimited time blocking.",
        plans: [
            SubscriptionPlan(id: SubscriptionProductIDs.yearly, label: "Yearly", price: "", billingFrequency: "", badge: "50% OFF", isRecommended: true),
            SubscriptionPlan(id: SubscriptionProductIDs.monthly, label: "Monthly", price: "", billingFrequency: "")
        ],
        oneTimeOption: SubscriptionPlan(id: SubscriptionProductIDs.lifetime, label: "Lifetime Access", price: "", billingFrequency: ""),
        features: [
            SubscriptionFeature(icon: "calendar.badge.clock", title: "Unlimited Planning", description: "Create as many time blocks, routines, and plans as you need."),
            SubscriptionFeature(icon: "chart.line.uptrend.xyaxis", title: "Productivity Insights", description: "See patterns in your focus time and completed blocks."),
            SubscriptionFeature(icon: "icloud.fill", title: "iCloud Sync", description: "Keep your schedule safe and updated across your devices."),
            SubscriptionFeature(icon: "paintpalette.fill", title: "Premium Themes", description: "Personalize your planner with all color options.")
        ],
        ctaTitle: "Update to Full Access",
        secondaryActions: [
            SecondaryAction(title: "Restore", actionID: "restore"),
            SecondaryAction(title: "Terms of Use", actionID: "terms"),
            SecondaryAction(title: "Privacy Policy", actionID: "privacy")
        ]
    )
}
