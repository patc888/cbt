import Foundation
import SwiftData
import CloudKit
import UserNotifications
import SwiftUI

extension Notification.Name {
    static let didResetData = Notification.Name("didResetData")
}

@Observable
final class DataResetManager {
    static let shared = DataResetManager()

    // 1. Clears AppStorage/UserDefaults
    // 2. Cancels scheduled local notifications
    // 3. Wipes SwiftData default.store directly without triggering CloudKit sync closures
    func performLocalWipe() {
        // 1. Clear UserDefaults & AppStorage
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        
        // 2. Clear notifications
        Task {
            await ReminderManager.shared.cancelAllCBTReminders()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
        
        // 3. Wipe local SwiftData default.store
        let storeURL = ModelConfiguration().url
        let storeDir = storeURL.deletingLastPathComponent()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: storeDir, includingPropertiesForKeys: nil)
            for file in files {
                if file.lastPathComponent.hasPrefix(storeURL.lastPathComponent) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            print("Failed to access store directory: \(error)")
        }
        
        // 4. Broadcast reset so UI recreates its context
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .didResetData, object: nil)
        }
    }

    // Deletes CloudKit synced database and then wipes local data
    func performGlobalWipe() async throws {
        let container = CKContainer.default()
        let database = container.privateCloudDatabase
        
        // The automatic SwiftData CloudKit zone name. 
        // SwiftData typically uses "com.apple.coredata.cloudkit.zone" for the default synced store.
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        
        do {
            // This permanently deletes the zone and all records within it in the user's private database.
            try await database.deleteRecordZone(withID: zoneID)
        } catch let error as CKError {
            // If the zone doesn't exist, we can't delete it, which is fine for a reset.
            if error.code == .zoneNotFound || error.code == .notAuthenticated || error.code == .networkUnavailable {
                // Not an error we need to stop for
            } else {
                throw error
            }
        } catch {
            throw error
        }
        
        // Trigger local wipe after cloud wipe attempt
        await MainActor.run {
            self.performLocalWipe()
        }
    }
}
