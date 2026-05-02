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
    case blue = "Blue"
    case emerald = "Emerald"
    case red = "Red"
    case indigo = "Indigo"
    case rose = "Rose"
    case lavender = "Lavender"
    case amber = "Amber"
    case fuchsia = "Fuchsia"
    case crimson = "Crimson"
    case forest = "Forest"
    case ocean = "Ocean"
    case berry = "Berry"
    case coral = "Coral"
    
    var id: String { rawValue }
    
    var primaryHex: String {
        switch self {
        case .purple: return "9C80FC"
        case .blue: return "007AFF"
        case .emerald: return "2ECC71"
        case .red: return "FF4D4D"
        case .indigo: return "818CF8"
        case .rose: return "F472B6"
        case .lavender: return "C084FC"
        case .amber: return "F59E0B"
        case .fuchsia: return "E879F9"
        case .crimson: return "DC143C"
        case .forest: return "228B22"
        case .ocean: return "0077BE"
        case .berry: return "C71585"
        case .coral: return "FF7F50"
        }
    }
    
    var secondaryHex: String {
        switch self {
        case .purple: return "8B5CF6"
        case .blue: return "0056B3"
        case .emerald: return "10B981"
        case .red: return "D63031"
        case .indigo: return "6366F1"
        case .rose: return "E11D48"
        case .lavender: return "A855F7"
        case .amber: return "D97706"
        case .fuchsia: return "C026D3"
        case .crimson: return "990000"
        case .forest: return "006400"
        case .ocean: return "005A8D"
        case .berry: return "8B008B"
        case .coral: return "E9967A"
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
    var selectedColorTheme: AppColorTheme? = AppColorTheme.red
    var isImmersive: Bool? = true
    var hapticsEnabled: Bool? = true
    var appLockEnabled: Bool? = false
    var isPremium: Bool? = false
    var hasSeenOnboarding: Bool = false
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
        selectedColorTheme: AppColorTheme? = .red,
        isImmersive: Bool? = true,
        hapticsEnabled: Bool? = true,
        appLockEnabled: Bool? = false,
        isPremium: Bool? = false,
        hasSeenOnboarding: Bool = false,
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
        self.appLockEnabled = appLockEnabled
        self.isPremium = isPremium
        self.hasSeenOnboarding = hasSeenOnboarding
        self.createdAt = createdAt

        self.updatedAt = updatedAt
    }
}
