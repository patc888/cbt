import SwiftUI

enum AppIcon: String, CaseIterable, Identifiable {
    case primary = "Default"
    case feather = "Feather"
    case stealth = "Stealth"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .primary: return "Default"
        case .feather: return "Feather"
        case .stealth: return "Stealth"
        }
    }

    var iconName: String? {
        switch self {
        case .primary: return nil
        case .feather: return "AppIcon-Feather"
        case .stealth: return "AppIcon-Stealth"
        }
    }

    var previewImage: String {
        switch self {
        case .primary: return "AppIcon2Preview"
        case .feather: return "AppIconFeatherPreview"
        case .stealth: return "AppIconStealthPreview"
        }
    }
}
