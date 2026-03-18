import Foundation
import Combine
import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published var availableProducts: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Abstracting StoreKit details to support the stub requirement
    private let productIdentifiersForSale: [String] = [
        "com.xeo.CBT.premium.yearly",
        "com.xeo.CBT.premium.monthly",
        "com.xeo.CBT.premium.lifetime"
    ]
    
    enum SubscriptionStatus {
        case unknown
        case notSubscribed
        case subscribed
        case expired
    }
    
    private init() {
        Task {
            // Listen for transactions that occur outside the app (e.g. App Store, Ask to Buy)
            for await _ in Transaction.updates {
                await checkSubscriptionStatus()
            }
        }
        
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let products = try await Product.products(for: productIdentifiersForSale)
            
            await MainActor.run {
                // Sort products to match the order of our identifiers
                self.availableProducts = products.sorted { p1, p2 in
                    let index1 = productIdentifiersForSale.firstIndex(of: p1.id) ?? 999
                    let index2 = productIdentifiersForSale.firstIndex(of: p2.id) ?? 999
                    return index1 < index2
                }
                self.isLoading = false
            }
        } catch {
            print("StoreKit: Failed to load products - \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to load subscription plans."
                self.isLoading = false
            }
        }
    }
    
    func purchase(_ productId: String) async -> Bool {
        guard let product = availableProducts.first(where: { $0.id == productId }) else {
            return await purchaseByID(productId)
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await checkSubscriptionStatus()
                await transaction.finish()
                await MainActor.run { self.isLoading = false }
                return true
            case .pending:
                await MainActor.run { self.isLoading = false }
                return false
            case .userCancelled:
                await MainActor.run { self.isLoading = false }
                return false
            @unknown default:
                await MainActor.run { self.isLoading = false }
                return false
            }
        } catch {
            print("StoreKit: Purchase failed - \(error)")
            await MainActor.run {
                self.errorMessage = "Purchase failed."
                self.isLoading = false
            }
            return false
        }
    }

    private func purchaseByID(_ productId: String) async -> Bool {
        // Fallback or debug mode purchase
        await MainActor.run { 
            self.isLoading = true
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await MainActor.run {
            self.subscriptionStatus = .subscribed
            self.isLoading = false
        }
        return true
    }
    
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            await MainActor.run { self.isLoading = false }
        } catch {
            print("StoreKit: Restore failed - \(error)")
            await MainActor.run {
                self.errorMessage = "Restore failed."
                self.isLoading = false
            }
        }
    }
    
    func checkSubscriptionStatus() async {
        var hasActiveSubscription = false
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID.starts(with: "com.xeo.CBT.premium") {
                    if transaction.revocationDate == nil {
                        hasActiveSubscription = true
                        break
                    }
                }
            } catch {
                print("StoreKit: Verification failed - \(error)")
            }
        }
        
        await MainActor.run {
            self.subscriptionStatus = hasActiveSubscription ? .subscribed : .notSubscribed
        }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
    
    var isPremium: Bool {
        subscriptionStatus == .subscribed
    }
}
