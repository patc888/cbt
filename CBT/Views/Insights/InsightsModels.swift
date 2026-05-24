import Foundation

struct EmotionCount: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

struct DistortionCount: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

struct DailyMoodAverage: Identifiable {
    let id = UUID()
    let date: Date
    let averageScore: Double
}

struct WeeklyMoodAverage: Identifiable {
    let id = UUID()
    let weekStart: Date
    let averageScore: Double
}

struct TriggerCount: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

struct ContextTagMoodCorrelation: Identifiable {
    let id = UUID()
    let name: String
    let entryCount: Int
    let averageMood: Double
    let deltaFromOverall: Double
}

struct InsightsDashboardSnapshot: Sendable {
    let activeDaysCount: Int
    let dailyMoodAverages: [DailyMoodAverage]
    let weeklyMoodAverages: [WeeklyMoodAverage]
    let moodVolatilityLast30Days: Double?
    let currentStreak: Int
    let longestStreak: Int
    let averageMood: Double?
    let averageIntensityImprovement: Int?
    let consistencyGoalTarget: Int
    let consistencyProgress: Double
    let moodGoalProgress: Double
    let thoughtGoalProgress: Double
    let exerciseGoalTarget: Int
    let exerciseProgress: Double
    let milestonesCompleted: Int
    let topEmotions: [EmotionCount]
    let topTriggers: [TriggerCount]
    let topDistortions: [DistortionCount]
    let contextTagCorrelations: [ContextTagMoodCorrelation]
}
