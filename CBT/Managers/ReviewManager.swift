import StoreKit
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

@MainActor
class ReviewManager {
    static let shared = ReviewManager()
    
    private let minimumActionsBeforeReview = 5
    private let userDefaultsKey = "com.xeo.CBT.reviewActionCount"
    private let lastVersionKey = "com.xeo.CBT.lastReviewVersion"
    
    private init() {}
    
    /// Call this after a significant user action (e.g. completing an exercise, mood check-in)
    func logSignificantAction() {
        var count = UserDefaults.standard.integer(forKey: userDefaultsKey)
        count += 1
        UserDefaults.standard.set(count, forKey: userDefaultsKey)
        
        checkAndRequestReview(currentCount: count)
    }
    
    private func checkAndRequestReview(currentCount: Int) {
        // Only prompt if they've reached the threshold
        guard currentCount >= minimumActionsBeforeReview else { return }
        
        // Only prompt once per version
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: lastVersionKey) ?? ""
        
        guard currentVersion != lastVersion else { return }
        
        requestReview(version: currentVersion)
    }
    
    private func requestReview(version: String) {
        #if canImport(UIKit)
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
            UserDefaults.standard.set(version, forKey: lastVersionKey)
            // Reset count if you want to prompt again in future versions after more usage
            UserDefaults.standard.set(0, forKey: userDefaultsKey)
        }
        #else
        SKStoreReviewController.requestReview()
        UserDefaults.standard.set(version, forKey: lastVersionKey)
        UserDefaults.standard.set(0, forKey: userDefaultsKey)
        #endif
    }
}

