import Foundation
import SwiftData
import SwiftUI

enum Weekday: Int, CaseIterable, Codable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sunday:
            "Sunday"
        case .monday:
            "Monday"
        case .tuesday:
            "Tuesday"
        case .wednesday:
            "Wednesday"
        case .thursday:
            "Thursday"
        case .friday:
            "Friday"
        case .saturday:
            "Saturday"
        }
    }
}

enum AppColorTheme: String, CaseIterable, Codable, Identifiable {
    case purple = "Purple"
    case pink = "Pink"
    case blue = "Blue"
    case orange = "Orange"
    case green = "Green"
    case emerald = "Emerald"
    case gold = "Gold"
    case red = "Red"
    case indigo = "Indigo"
    case teal = "Teal"
    case cyan = "Cyan"
    case rose = "Rose"
    case lavender = "Lavender"
    case slate = "Slate"
    
    var id: String { rawValue }
    
    var primaryHex: String {
        switch self {
        case .purple: return "9C80FC"
        case .pink: return "FF8FB1"
        case .blue: return "007AFF"
        case .orange: return "FF9F43"
        case .green: return "86E3CE"
        case .emerald: return "2ECC71"
        case .gold: return "F6C852"
        case .red: return "FF3B30"
        case .indigo: return "818CF8"
        case .teal: return "2DD4BF"
        case .cyan: return "67E8F9"
        case .rose: return "F472B6"
        case .lavender: return "C084FC"
        case .slate: return "94A3B8"
        }
    }
    
    var secondaryHex: String {
        switch self {
        case .purple: return "8B5CF6"
        case .pink: return "FF6B9D"
        case .blue: return "0056B3"
        case .orange: return "F57C00"
        case .green: return "5DBEA3"
        case .emerald: return "10B981"
        case .gold: return "FF9F0A"
        case .red: return "CC2F26"
        case .indigo: return "6366F1"
        case .teal: return "14B8A6"
        case .cyan: return "06B6D4"
        case .rose: return "E11D48"
        case .lavender: return "A855F7"
        case .slate: return "64748B"
        }
    }
}

enum AppTheme: String, CaseIterable, Codable, Identifiable {
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


@Model
final class AppPreferences {
    var id: String = "app-preferences"
    var defaultBlockDurationMinutes: Int = 60
    var dayStartHour: Int = 6
    var firstWeekday: Weekday = Weekday.monday
    var notificationsEnabled: Bool? = false
    var notificationLeadTimeMinutes: Int? = 0
    var showsCompletedBlocks: Bool? = true
    var appTheme: AppTheme? = AppTheme.system
    var selectedColorTheme: AppColorTheme? = AppColorTheme.purple
    var isImmersive: Bool? = true
    var hapticsEnabled: Bool? = true
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        id: String = "app-preferences",
        defaultBlockDurationMinutes: Int = 60,
        dayStartHour: Int = 6,
        firstWeekday: Weekday = .monday,
        notificationsEnabled: Bool? = false,
        notificationLeadTimeMinutes: Int? = 0,
        showsCompletedBlocks: Bool? = true,
        appTheme: AppTheme? = .system,
        selectedColorTheme: AppColorTheme? = .purple,
        isImmersive: Bool? = true,
        hapticsEnabled: Bool? = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.defaultBlockDurationMinutes = defaultBlockDurationMinutes
        self.dayStartHour = dayStartHour
        self.firstWeekday = firstWeekday
        self.notificationsEnabled = notificationsEnabled
        self.notificationLeadTimeMinutes = notificationLeadTimeMinutes
        self.showsCompletedBlocks = showsCompletedBlocks
        self.appTheme = appTheme
        self.selectedColorTheme = selectedColorTheme
        self.isImmersive = isImmersive
        self.hapticsEnabled = hapticsEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
