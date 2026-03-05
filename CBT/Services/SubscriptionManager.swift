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
        "com.xeo.WeightTracker.premium.monthly",
        "com.xeo.WeightTracker.premium.yearly",
        "com.xeo.MeliWeightTracker.premium.lifetime"
    ]
    
    enum SubscriptionStatus {
        case unknown
        case notSubscribed
        case subscribed
        case expired
    }
    
    private init() {
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        // STUB MODE:
        // We do not load real StoreKit Products since no IAP is configured yet in CBT.
        // Once IAP is fully configured, swap this logic back to `Product.products(for: productIdentifiersForSale)`
        await MainActor.run {
            self.availableProducts = [] // Empty since we can't create fake StoreKit 2 `Product` structs synchronously here.
            
            // To prevent crashes when availableProducts is empty but purchasing is clicked,
            // the UI will rely on its own placeholder text internally when products are missing.
            self.isLoading = false
        }
    }
    
    func purchase(_ productId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        // STUB MODE PURCHASE
        // Simulate a network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            self.subscriptionStatus = .subscribed
            self.isLoading = false
        }
        
        return true
    }
    
    // STUB override for the direct product purchase (since we might not have real Products)
    func purchase(product: Any) async -> Bool {
        // Not used realistically until real StoreKit is wired
        return await purchase("stub")
    }
    
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        // STUB MODE RESTORE
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            self.isLoading = false
            self.errorMessage = nil // Not changing subscription status for now, just success no-op
        }
    }
    
    func checkSubscriptionStatus() async {
        // Default to not subscribed locally until purchased during testing.
        if self.subscriptionStatus == .unknown {
            self.subscriptionStatus = .notSubscribed
        }
    }
    
    var isPremium: Bool {
        subscriptionStatus == .subscribed
    }
}
