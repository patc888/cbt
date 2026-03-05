import SwiftUI

enum AppIcon: String, CaseIterable, Identifiable {
    case primary = "Default"
    case stealth = "Stealth"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .primary: return "Default"
        case .stealth: return "Stealth"
        }
    }

    var iconName: String? {
        switch self {
        case .primary: return nil
        case .stealth: return "AppIcon-Stealth"
        }
    }

    var previewImage: String {
        switch self {
        case .primary: return "AppIcon" // standard icon
        case .stealth: return "AppIcon-Stealth"
        }
    }
}
