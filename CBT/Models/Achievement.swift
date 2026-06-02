import Foundation
import SwiftData

enum AchievementUnlockCondition: String, CaseIterable, Codable, Hashable, Sendable {
    case streakCount = "StreakCount"
    case exercisesCompleted = "ExercisesCompleted"
    case thoughtRecordsCount = "ThoughtRecordsCount"
    case moodCheckInCount = "MoodCheckInCount"
    case guidedJournalCount = "GuidedJournalCount"
    case breathingSessionCount = "BreathingSessionCount"
    case coursesCompleted = "CoursesCompleted"
    case weeklyReportViewed = "WeeklyReportViewed"
    case plannedActivitiesCompleted = "PlannedActivitiesCompleted"
    case assessmentsCompleted = "AssessmentsCompleted"
    case activeWeeksCount = "ActiveWeeksCount"
    case contentModalitiesTried = "ContentModalitiesTried"
    case returnedAfterMissedDay = "ReturnedAfterMissedDay"
    case copingToolsTried = "CopingToolsTried"
    case reflectionCount = "ReflectionCount"
    case badDayModeUsed = "BadDayModeUsed"

    var label: String {
        switch self {
        case .streakCount: return "Best run"
        case .exercisesCompleted: return "Exercises"
        case .thoughtRecordsCount: return "Thought Records"
        case .moodCheckInCount: return "Mood Check-Ins"
        case .guidedJournalCount: return "Guided Journals"
        case .breathingSessionCount: return "Breathing Sessions"
        case .coursesCompleted: return "Courses"
        case .weeklyReportViewed: return "Weekly Overview"
        case .plannedActivitiesCompleted: return "Planned Activities"
        case .assessmentsCompleted: return "Assessments"
        case .activeWeeksCount: return "Active Weeks"
        case .contentModalitiesTried: return "Content Styles"
        case .returnedAfterMissedDay: return "Returning"
        case .copingToolsTried: return "Coping Tools"
        case .reflectionCount: return "Reflections"
        case .badDayModeUsed: return "Support"
        }
    }

    var progressUnit: String {
        switch self {
        case .streakCount: return "days"
        case .exercisesCompleted: return "exercises"
        case .thoughtRecordsCount: return "records"
        case .moodCheckInCount: return "check-ins"
        case .guidedJournalCount: return "journals"
        case .breathingSessionCount: return "sessions"
        case .coursesCompleted: return "courses"
        case .weeklyReportViewed: return "viewed"
        case .plannedActivitiesCompleted: return "activities"
        case .assessmentsCompleted: return "assessments"
        case .activeWeeksCount: return "weeks"
        case .contentModalitiesTried: return "styles"
        case .returnedAfterMissedDay: return "returns"
        case .copingToolsTried: return "tools"
        case .reflectionCount: return "reflections"
        case .badDayModeUsed: return "used"
        }
    }
}

@Model
final class Achievement {
    var id: UUID = UUID()
    var title: String = ""
    var achievementDescription: String = ""
    var imageName: String = ""
    var isUnlocked: Bool = false
    var unlockConditionStorage: String = AchievementUnlockCondition.streakCount.rawValue
    var createdAt: Date = Date()
    var unlockedAt: Date?

    var unlockCondition: AchievementUnlockCondition {
        get { AchievementUnlockCondition(rawValue: unlockConditionStorage) ?? .streakCount }
        set { unlockConditionStorage = newValue.rawValue }
    }

    var description: String {
        achievementDescription
    }

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        imageName: String,
        isUnlocked: Bool = false,
        unlockCondition: AchievementUnlockCondition,
        createdAt: Date = Date(),
        unlockedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.achievementDescription = description
        self.imageName = imageName
        self.isUnlocked = isUnlocked
        self.unlockConditionStorage = unlockCondition.rawValue
        self.createdAt = createdAt
        self.unlockedAt = unlockedAt
    }
}
