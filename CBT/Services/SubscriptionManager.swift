import Foundation
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    static let isV1FreeModeEnabled = true
    
    @Published var subscriptionStatus: SubscriptionStatus = .subscribed
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    enum SubscriptionStatus {
        case subscribed
    }

    private init() {}

    func startListeningIfNeeded() {
        subscriptionStatus = .subscribed
        isLoading = false
        errorMessage = nil
    }
    
    func loadProducts() async {}
    
    func purchase(_ productId: String) async -> Bool {
        _ = productId
        errorMessage = nil
        return false
    }
    
    func restorePurchases() async {
        isLoading = false
        errorMessage = nil
    }
    
    func checkSubscriptionStatus() async {
        subscriptionStatus = .subscribed
    }
    
    var isPremium: Bool {
        true
    }
}
