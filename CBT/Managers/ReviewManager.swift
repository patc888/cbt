import StoreKit
import SwiftUI
import OSLog

#if canImport(UIKit)
import UIKit
#endif

/// ReviewManager handles the logic for requesting the App Store rating prompt (SKStoreReviewController).
/// It ensures the prompt is timed after significant usage and avoids interrupting critical user tasks.
@MainActor
class ReviewManager {
    static let shared = ReviewManager()
    
    // Thresholds
    private let minimumActionsBeforeReview = 4
    private let minimumDaysSinceFirstLaunch = 7
    private let minimumDaysBetweenReviews = 120 // 4 months
    
    // Keys
    private let userDefaultsKey = "com.xeo.CBT.reviewActionCount"
    private let lastVersionKey = "com.xeo.CBT.lastReviewVersion"
    private let firstLaunchDateKey = "com.xeo.CBT.firstLaunchDate"
    private let lastReviewDateKey = "com.xeo.CBT.lastReviewDate"
    
    private let logger = AppLogger.make(category: "Review")
    
    private init() {
        // Track first launch date if not already set
        if UserDefaults.standard.object(forKey: firstLaunchDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstLaunchDateKey)
        }
    }
    
    /// Call this after a significant user action (e.g. completing an exercise, mood check-in)
    func logSignificantAction() {
        var count = UserDefaults.standard.integer(forKey: userDefaultsKey)
        count += 1
        UserDefaults.standard.set(count, forKey: userDefaultsKey)
        
        logger.debug("Logged significant action. New count: \(count)")
        checkAndRequestReview(currentCount: count)
    }
    
    private func checkAndRequestReview(currentCount: Int) {
        // 1. Action threshold check
        guard currentCount >= minimumActionsBeforeReview else {
            logger.debug("Action count threshold not met: \(currentCount)/\(self.minimumActionsBeforeReview)")
            return
        }
        
        // 2. Days since first launch check
        if let firstLaunchDate = UserDefaults.standard.object(forKey: firstLaunchDateKey) as? Date {
            let daysSinceLaunch = Calendar.current.dateComponents([.day], from: firstLaunchDate, to: Date()).day ?? 0
            guard daysSinceLaunch >= minimumDaysSinceFirstLaunch else {
                logger.debug("Days since first launch threshold not met: \(daysSinceLaunch)/\(self.minimumDaysSinceFirstLaunch)")
                return
            }
        }
        
        // 3. Days since last review check
        if let lastReviewDate = UserDefaults.standard.object(forKey: lastReviewDateKey) as? Date {
            let daysSinceLastReview = Calendar.current.dateComponents([.day], from: lastReviewDate, to: Date()).day ?? 0
            guard daysSinceLastReview >= minimumDaysBetweenReviews else {
                logger.debug("Days since last review threshold not met: \(daysSinceLastReview)/\(self.minimumDaysBetweenReviews)")
                return
            }
        }
        
        // 4. Once per version check
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: lastVersionKey) ?? ""
        
        if currentVersion == lastVersion {
            logger.debug("Review already requested for version \(currentVersion)")
            return
        }
        
        // All checks passed. 
        // We trigger a delay to ensure any current UI transitions (dismissals, etc.) are finished.
        Task {
            logger.info("Scheduling review prompt with 2s delay...")
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            requestReview(version: currentVersion)
        }
    }
    
    private func requestReview(version: String) {
        #if canImport(UIKit)
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            logger.warning("Could not find active window scene to request review")
            return
        }
        
        logger.info("Triggering SKStoreReviewController for version \(version)")
        SKStoreReviewController.requestReview(in: scene)
        #else
        logger.info("Triggering SKStoreReviewController (non-UIKit)")
        SKStoreReviewController.requestReview()
        #endif
        
        // Update tracking to ensure we don't spam
        UserDefaults.standard.set(version, forKey: lastVersionKey)
        UserDefaults.standard.set(0, forKey: userDefaultsKey)
        UserDefaults.standard.set(Date(), forKey: lastReviewDateKey)
    }
}
