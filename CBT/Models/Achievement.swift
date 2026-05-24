import Foundation
import SwiftData

enum AchievementUnlockCondition: String, CaseIterable, Codable {
    case streakCount = "StreakCount"
    case exercisesCompleted = "ExercisesCompleted"
    case thoughtRecordsCount = "ThoughtRecordsCount"

    var label: String {
        switch self {
        case .streakCount: return "Streak"
        case .exercisesCompleted: return "Exercises"
        case .thoughtRecordsCount: return "Thought Records"
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
