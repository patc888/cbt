import Foundation
import SwiftData

/// App settings model for CBT
@Model
final class UserSettings {
    var uuid: UUID?
    
    /// Appearance Settings
    var hapticsEnabled: Bool?
    var currentIcon: String?
    
    /// Security Settings
    var appLockEnabled: Bool?
    
    init(
        hapticsEnabled: Bool = true,
        appLockEnabled: Bool = false
    ) {
        self.uuid = UUID()
        self.hapticsEnabled = hapticsEnabled
        self.appLockEnabled = appLockEnabled
    }
}
