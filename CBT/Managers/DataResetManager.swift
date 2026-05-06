import Foundation
import OSLog

extension Notification.Name {
    static let requestDataReset = Notification.Name("requestDataReset")
    static let didResetData = Notification.Name("didResetData")
    static let exerciseFlowDidEnter = Notification.Name("exerciseFlowDidEnter")
    static let exerciseFlowDidExit = Notification.Name("exerciseFlowDidExit")
}

@Observable
final class DataResetManager {
    nonisolated static let shared = DataResetManager()
    private nonisolated static let cloudSyncKey = "com.melichan.CBT.cloudSyncEnabled"
    private nonisolated static let localPreferenceKeys = [
        cloudSyncKey,
        "lastCloudSyncDate"
    ]
    
    nonisolated static var isCloudSyncEnabled: Bool {
        get {
            true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: cloudSyncKey)
        }
    }
    
    func requestLocalWipe() {
        NotificationCenter.default.post(name: .requestDataReset, object: nil)
    }

    func deleteCloudData() async throws {
        requestLocalWipe()
    }

    func resetLocalPreferences() {
        for key in Self.localPreferenceKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
