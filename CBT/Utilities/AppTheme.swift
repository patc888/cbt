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
    case mint = "Mint"
    case rose = "Rose"
    case coral = "Coral"
    case lavender = "Lavender"
    case lime = "Lime"
    case graphite = "Graphite"

    var id: String { rawValue }

    var primaryHex: String {
        switch self {
        case .cyan: return "32ADE6"
        case .blue: return "007AFF"
        case .purple: return "9C80FC"
        case .pink: return "FF8FB1"
        case .orange: return "FF9F43"
        case .emerald: return "2ECC71"
        case .gold: return "F6C852"
        case .red: return "FF3B30"
        case .indigo: return "5856D6"
        case .teal: return "30B0C7"
        case .mint: return "00C7BE"
        case .rose: return "F43F5E"
        case .coral: return "FF6B4A"
        case .lavender: return "C084FC"
        case .lime: return "65A30D"
        case .graphite: return "64748B"
        }
    }

    var secondaryHex: String {
        switch self {
        case .cyan: return "0071A4"
        case .blue: return "0056B3"
        case .purple: return "8B5CF6"
        case .pink: return "FF6B9D"
        case .orange: return "F57C00"
        case .emerald: return "10B981"
        case .gold: return "FF9F0A"
        case .red: return "CC2F26"
        case .indigo: return "3634A3"
        case .teal: return "1A778C"
        case .mint: return "008C82"
        case .rose: return "BE123C"
        case .coral: return "C2410C"
        case .lavender: return "7E22CE"
        case .lime: return "3F6212"
        case .graphite: return "334155"
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
