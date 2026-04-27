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
    
    nonisolated static var isCloudSyncEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: cloudSyncKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: cloudSyncKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: cloudSyncKey)
        }
    }
    
    func requestLocalWipe() {
        // Mocked for compilation; implementation removed for safety during launch
    }

    func deleteCloudData() async throws {
        // Mocked for compilation; implementation removed for safety during launch
    }
}
