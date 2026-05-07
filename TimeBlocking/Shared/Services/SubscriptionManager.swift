import Foundation
import StoreKit
import SwiftData
import SwiftUI
import Combine
import os.log

private let logger = Logger(subsystem: "com.xeo.TimeBlocking", category: "StoreKit")

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published private(set) var hasLifetimeAccess = false
    @Published var availableProducts: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastLoadError: String?
    
    var modelContainer: ModelContainer?
    
    let productIdentifiers = [
        "com.xeo.timeblocking.monthly",
        "com.xeo.timeblocking.yearly",
        "com.xeo.timeblocking.lifetime"
    ]

    private let lifetimeProductIdentifier = "com.xeo.timeblocking.lifetime"
    
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
        if !force && !availableProducts.isEmpty { return } // Avoid fetch storms
        
        isLoading = true
        errorMessage = nil
        lastLoadError = nil
        
        logger.info("Requesting products for identifiers: \(self.productIdentifiers, privacy: .public)")
        
        do {
            let products = try await Product.products(for: productIdentifiers)
            logger.info("Successfully fetched \(products.count) products.")
            
            logger.debug("IDs requested: \(self.productIdentifiers, privacy: .public), count returned: \(products.count), returned product IDs: \(products.map { $0.id }, privacy: .public)")
            
            for product in products {
                logger.info("Received product [ID: \(product.id, privacy: .public)] [Name: \(product.displayName, privacy: .public)]")
            }
            
            self.availableProducts = products.sorted { product1, product2 in
                // Sort by price, monthly first
                product1.id.contains("monthly") && !product2.id.contains("monthly")
            }
            self.isLoading = false
            await checkSubscriptionStatus()
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
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
                if productIdentifiers.contains(transaction.productID) {
                    if transaction.revocationDate == nil && (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
                        if transaction.productID == lifetimeProductIdentifier {
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
                    logger.info("Synced AppPreferences entitlement cache → premium: \(isPremium)")
                }
            }
        } catch {
            logger.error("Failed to sync AppPreferences entitlement cache: \(error.localizedDescription)")
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
                    logger.error("Transaction verification failed: \(error.localizedDescription)")
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
            SubscriptionPlan(id: "com.xeo.timeblocking.yearly", label: String(localized: "Yearly"), price: "", billingFrequency: String(localized: "per year"), isRecommended: true),
            SubscriptionPlan(id: "com.xeo.timeblocking.monthly", label: String(localized: "Monthly"), price: "", billingFrequency: String(localized: "per month"))
        ],
        oneTimeOption: SubscriptionPlan(id: "com.xeo.timeblocking.lifetime", label: String(localized: "Lifetime"), price: "", billingFrequency: String(localized: "one-time payment")),
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
