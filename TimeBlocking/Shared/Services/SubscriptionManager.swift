import Foundation
import StoreKit
import SwiftData
import SwiftUI
import Combine
import os.log

@MainActor
class SubscriptionManager: ObservableObject {
    nonisolated static let logger = Logger(subsystem: "com.melichan.TimeBlocking", category: "StoreKit")
    static let shared = SubscriptionManager()
    
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published private(set) var hasLifetimeAccess = false
    @Published var availableProducts: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastLoadError: String?
    
    var modelContainer: ModelContainer?
    
    enum ProductKind: Int, CaseIterable {
        case yearly
        case monthly
        case lifetime

        nonisolated var canonicalIdentifier: String {
            switch self {
            case .yearly:
                "com.melichan.timeblocking.yearly"
            case .monthly:
                "com.melichan.timeblocking.monthly"
            case .lifetime:
                "com.melichan.timeblocking.lifetime"
            }
        }

        nonisolated var legacyIdentifier: String {
            switch self {
            case .yearly:
                "com.xeo.timeblocking.yearly"
            case .monthly:
                "com.xeo.timeblocking.monthly"
            case .lifetime:
                "com.xeo.timeblocking.lifetime"
            }
        }

        nonisolated var candidateIdentifiers: [String] {
            [canonicalIdentifier, legacyIdentifier]
        }

        nonisolated func matches(productIdentifier: String) -> Bool {
            let normalizedID = productIdentifier.lowercased()
            if candidateIdentifiers.contains(where: { $0.lowercased() == normalizedID }) {
                return true
            }

            switch self {
            case .yearly:
                return normalizedID.contains("yearly") || normalizedID.contains("annual")
            case .monthly:
                return normalizedID.contains("monthly") || normalizedID.contains("month")
            case .lifetime:
                return normalizedID.contains("lifetime")
            }
        }
    }

    var productIdentifiers: [String] {
        ProductKind.allCases.flatMap(\.candidateIdentifiers)
    }
    
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
        
        let requestedIDs = productIdentifiers
        Self.logger.info("Requesting products for identifiers: \(requestedIDs, privacy: .public)")
        
        do {
            let products = try await fetchProducts(for: requestedIDs)
            Self.logger.info("Successfully fetched \(products.count) products.")
            
            for product in products {
                Self.logger.info("Received product [ID: \(product.id, privacy: .public)] [Name: \(product.displayName, privacy: .public)]")
            }
            
            if products.isEmpty {
                let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
                let message = "No StoreKit products returned for bundle \(bundleID) and IDs: \(requestedIDs.joined(separator: ", "))"
                Self.logger.error("\(message, privacy: .public)")
                self.errorMessage = String(localized: "Unable to load subscription options. Please try again.")
                self.lastLoadError = message
            }

            self.availableProducts = products.sortedByStoreOrder()
            self.isLoading = false
            await checkSubscriptionStatus()
        } catch {
            Self.logger.error("Failed to load products: \(error.localizedDescription)")
            self.errorMessage = "Failed to load subscription options: \(error.localizedDescription)"
            self.lastLoadError = error.localizedDescription
            self.isLoading = false
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
            self.isLoading = false
        } catch {
            self.errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    func checkSubscriptionStatus() async {
        var status: SubscriptionStatus = .notSubscribed
        var hasLifetimeAccessNow = false
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if Self.productKind(for: transaction.productID) != nil {
                    if transaction.revocationDate == nil && (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
                        if Self.productKind(for: transaction.productID) == .lifetime {
                            hasLifetimeAccessNow = true
                        }
                        status = .subscribed
                        if hasLifetimeAccessNow {
                            break
                        }
                    }
                }
            }
        }
        
        self.subscriptionStatus = status
        self.hasLifetimeAccess = hasLifetimeAccessNow
        
        let isPremiumNow = (status == .subscribed)
        
        if NSUbiquitousKeyValueStore.default.bool(forKey: "hasPro") != isPremiumNow {
            NSUbiquitousKeyValueStore.default.set(isPremiumNow, forKey: "hasPro")
            NSUbiquitousKeyValueStore.default.synchronize()
        }
        
        syncAppPreferencesModel(isPremium: isPremiumNow)
    }
    
    var isPremium: Bool {
        subscriptionStatus == .subscribed
    }
    
    private func syncAppPreferencesModel(isPremium: Bool) {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        do {
            let existing = try context.fetch(FetchDescriptor<AppPreferences>())
            if let settings = existing.first {
                var didChange = false
                if settings.isPremium != isPremium {
                    settings.isPremium = isPremium
                    didChange = true
                }
                if didChange {
                    try context.save()
                    Self.logger.info("Synced AppPreferences entitlement cache → premium: \(isPremium)")
                }
            }
        } catch {
            Self.logger.error("Failed to sync AppPreferences entitlement cache: \(error.localizedDescription)")
            self.errorMessage = "Failed to synchronize local settings: \(error.localizedDescription)"
        }
    }
    
    private func startListeningForTransactions() {
        updateListenerTask = Task.detached { [weak self] in
            guard let self = self else { return }
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    Task { @MainActor [weak self] in
                        await self?.checkSubscriptionStatus()
                    }
                } catch {
                    Self.logger.error("Transaction verification failed: \(error.localizedDescription)")
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

    nonisolated static func productKind(for productIdentifier: String) -> ProductKind? {
        ProductKind.allCases.first { $0.matches(productIdentifier: productIdentifier) }
    }

    func product(for kind: ProductKind) -> Product? {
        availableProducts.first { product in
            kind.matches(productIdentifier: product.id)
        }
    }

    private func fetchProducts(for identifiers: [String]) async throws -> [Product] {
        let maxAttempts = 3

        for attempt in 1...maxAttempts {
            let products = try await Product.products(for: identifiers)
            if !products.isEmpty || attempt == maxAttempts {
                return products
            }

            Self.logger.warning("StoreKit returned no products on attempt \(attempt, privacy: .public). Retrying.")
            try await Task.sleep(for: .milliseconds(350 * attempt))
        }

        return []
    }
}

private extension Array where Element == Product {
    func sortedByStoreOrder() -> [Product] {
        sorted { lhs, rhs in
            let lhsOrder = SubscriptionManager.productKind(for: lhs.id)?.rawValue ?? Int.max
            let rhsOrder = SubscriptionManager.productKind(for: rhs.id)?.rawValue ?? Int.max

            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }

            return lhs.price < rhs.price
        }
    }
}

enum SubscriptionError: Error {
    case failedVerification
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
        let icon: String // SF Symbol name
        let title: String
        let description: String
    }
    
    struct SecondaryAction: Identifiable, Codable, Equatable {
        var id: String { title }
        let title: String
        let actionID: String // To be handled by the view model
    }
}

extension SubscriptionConfig {
    static let mock = SubscriptionConfig(
        title: String(localized: "Full Access"),
        subtitle: String(localized: "One subscription for all your devices with unlimited time blocking."),
        plans: [
            SubscriptionPlan(id: "com.melichan.timeblocking.yearly", label: String(localized: "Yearly"), price: "", billingFrequency: String(localized: "per year"), isRecommended: true),
            SubscriptionPlan(id: "com.melichan.timeblocking.monthly", label: String(localized: "Monthly"), price: "", billingFrequency: String(localized: "per month"))
        ],
        oneTimeOption: SubscriptionPlan(id: "com.melichan.timeblocking.lifetime", label: String(localized: "Lifetime"), price: "", billingFrequency: String(localized: "one-time payment")),
        features: [
            SubscriptionFeature(icon: "calendar.badge.clock", title: String(localized: "Unlimited Planning"), description: String(localized: "Create as many time blocks, routines, and plans as you need.")),
            SubscriptionFeature(icon: "chart.line.uptrend.xyaxis", title: String(localized: "Productivity Insights"), description: String(localized: "See patterns in your focus time and completed blocks.")),
            SubscriptionFeature(icon: "icloud.fill", title: String(localized: "iCloud Sync"), description: String(localized: "Keep your schedule safe and updated across your devices.")),
            SubscriptionFeature(icon: "paintpalette.fill", title: String(localized: "Premium Themes"), description: String(localized: "Personalize your planner with all color options."))
        ],
        ctaTitle: String(localized: "Continue"),
        secondaryActions: [
            SecondaryAction(title: String(localized: "Restore"), actionID: "restore"),
            SecondaryAction(title: String(localized: "Terms of Use"), actionID: "terms"),
            SecondaryAction(title: String(localized: "Privacy Policy"), actionID: "privacy")
        ]
    )
}
