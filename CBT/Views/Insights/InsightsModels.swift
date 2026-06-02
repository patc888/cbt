import Foundation

struct EmotionCount: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let count: Int
}

struct DistortionCount: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let count: Int
}

struct DailyMoodAverage: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let averageScore: Double
}

struct WeeklyMoodAverage: Identifiable, Sendable {
    let id = UUID()
    let weekStart: Date
    let averageScore: Double
}

struct TriggerCount: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let count: Int
}

struct ContextTagMoodCorrelation: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let entryCount: Int
    let averageMood: Double
    let deltaFromOverall: Double
}

struct ActivityMoodAverage: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let entryCount: Int
    let averageMood: Double
}

struct ActivityTagFrequency: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let dayCount: Int
}

struct TriggerEmotionPattern: Identifiable, Sendable {
    let id = UUID()
    let trigger: String
    let emotion: String
    let count: Int
}

struct SensationCount: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let count: Int
}

enum MoodTrendDirection: Sendable {
    case higher
    case lower
    case steady
}

struct MoodTrendInsight: Identifiable, Sendable {
    let id = UUID()
    let windowDays: Int
    let direction: MoodTrendDirection
    let delta: Double
    let earlierAverage: Double
    let recentAverage: Double
    let daysWithData: Int
}

struct CheckInConsistencyInsight: Sendable {
    let daysCheckedInLast7: Int
    let daysCheckedInLast30: Int
    let currentStreak: Int
    let longestStreak: Int
    let totalCheckInDays: Int

    static let empty = CheckInConsistencyInsight(
        daysCheckedInLast7: 0,
        daysCheckedInLast30: 0,
        currentStreak: 0,
        longestStreak: 0,
        totalCheckInDays: 0
    )
}

struct PlainLanguagePatternInsight: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let message: String
    let iconName: String
}

struct InsightsPatternSummary: Sendable {
    let activityMoodAverages: [ActivityMoodAverage]
    let lowMoodActivityTags: [ActivityTagFrequency]
    let highMoodActivityTags: [ActivityTagFrequency]
    let triggerEmotionPatterns: [TriggerEmotionPattern]
    let anxietySensations: [SensationCount]
    let moodTrends: [MoodTrendInsight]
    let checkInConsistency: CheckInConsistencyInsight
    let insightCards: [PlainLanguagePatternInsight]

    static let empty = InsightsPatternSummary(
        activityMoodAverages: [],
        lowMoodActivityTags: [],
        highMoodActivityTags: [],
        triggerEmotionPatterns: [],
        anxietySensations: [],
        moodTrends: [],
        checkInConsistency: .empty,
        insightCards: []
    )
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
    let patternSummary: InsightsPatternSummary
    let personalGrowth: PersonalGrowthSnapshot
}
