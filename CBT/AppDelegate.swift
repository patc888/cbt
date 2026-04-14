import SwiftUI
import UserNotifications
import os

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let logger = AppLogger.make(category: "AppDelegate")
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        logger.info("Application did finish launching.")
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        logger.info("Successfully registered for remote notifications. Token: \(token, privacy: .private)")
        
        // Pass the token to our backend service
        Task {
            await BackendService.shared.registerDeviceToken(token)
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        logger.error("Failed to register for remote notifications: \(error.localizedDescription, privacy: .public)")
    }
}
