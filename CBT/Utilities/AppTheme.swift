import Foundation
import SwiftUI

enum AppColorTheme: String, CaseIterable, Identifiable {
    case cyan = "Cyan"
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case orange = "Orange"
    case emerald = "Emerald"
    case gold = "Gold"
    case red = "Red"
    case indigo = "Indigo"
    case teal = "Teal"

    var id: String { rawValue }

    var primaryHex: String {
        switch self {
        case .blue: return "007AFF"
        case .purple: return "9C80FC"
        case .pink: return "FF8FB1"
        case .orange: return "FF9F43"
        case .emerald: return "2ECC71"
        case .gold: return "F6C852"
        case .red: return "FF3B30"
        case .cyan: return "32ADE6"
        case .indigo: return "5856D6"
        case .teal: return "30B0C7"
        }
    }

    var secondaryHex: String {
        switch self {
        case .blue: return "0056B3"
        case .purple: return "8B5CF6"
        case .pink: return "FF6B9D"
        case .orange: return "F57C00"
        case .emerald: return "10B981"
        case .gold: return "FF9F0A"
        case .red: return "CC2F26"
        case .cyan: return "0071A4"
        case .indigo: return "3634A3"
        case .teal: return "1A778C"
        }
    }
}


enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
