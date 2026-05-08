import SwiftUI
import StoreKit
import Observation
import OSLog

@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()
    
    private let logger = Logger(subsystem: "com.melichan.CBT", category: "Subscription")
    
    var availableProducts: [Product] = []
    var subscriptionStatus: SubscriptionStatus = .notSubscribed
    var isLoading = false
    var errorMessage: String?
    
    private var updateListenerTask: Task<Void, Never>?
    
    private let productIdentifiers: Set<String> = [
        SubscriptionProductIDs.monthly,
        SubscriptionProductIDs.yearly,
        SubscriptionProductIDs.lifetime
    ]
    
    private init() {
        startListeningForTransactions()
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    enum SubscriptionStatus {
        case notSubscribed
        case subscribed
        case expired
    }
    
    func loadProducts(force: Bool = false) async {
        if !force && !availableProducts.isEmpty {
            return
        }

        await MainActor.run { 
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let products = try await Product.products(for: productIdentifiers)
            await MainActor.run {
                self.availableProducts = products.sorted(by: { productSortRank($0.id) < productSortRank($1.id) })
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load products: \(error.localizedDescription)"
                self.isLoading = false
            }
            logger.error("Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkSubscriptionStatus()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            logger.error("Purchase failed: \(error)")
            return false
        }
    }
    
    func restorePurchases() async {
        await MainActor.run { 
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            await MainActor.run { self.isLoading = false }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func checkSubscriptionStatus() async {
        var status: SubscriptionStatus = .notSubscribed
        
        // Check for active subscriptions and lifetime purchases
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if productIdentifiers.contains(transaction.productID) {
                    status = .subscribed
                    break
                }
            } catch {
                logger.error("Entitlement verification failed: \(error)")
            }
        }
        
        await MainActor.run {
            self.subscriptionStatus = status
            
            // Update internal state via UserDefaults/CloudKit if needed
            let isPremiumNow = (status == .subscribed)
            if NSUbiquitousKeyValueStore.default.bool(forKey: "hasPro") != isPremiumNow {
                NSUbiquitousKeyValueStore.default.set(isPremiumNow, forKey: "hasPro")
                NSUbiquitousKeyValueStore.default.synchronize()
            }
        }
    }
    
    var isPremium: Bool {
        subscriptionStatus == .subscribed
    }
    
    private func startListeningForTransactions() {
        updateListenerTask = Task.detached { [weak self] in
            guard let self = self else { return }
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.checkSubscriptionStatus()
                } catch {
                    self.logger.error("Transaction verification failed: \(error)")
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

    private func productSortRank(_ productID: String) -> Int {
        switch productID {
        case SubscriptionProductIDs.monthly:
            return 0
        case SubscriptionProductIDs.yearly:
            return 1
        case SubscriptionProductIDs.lifetime:
            return 2
        default:
            return 3
        }
    }
}

enum SubscriptionError: Error {
    case failedVerification
}

struct SubscriptionProductIDs {
    static let monthly = "com.melichan.CBT.monthly"
    static let yearly = "com.melichan.CBT.yearly"
    static let lifetime = "com.melichan.CBT.lifetime"
    
    static var all: Set<String> {
        [monthly, yearly, lifetime]
    }
}
