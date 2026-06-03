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

struct ThoughtRecordCompletionStats: Sendable {
    let completedCount: Int
    let draftCount: Int
    let savedReframeCount: Int
    let favoriteReframeCount: Int
    let averageIntensityChange: Int?
    let recurringDistortions: [DistortionCount]

    static let empty = ThoughtRecordCompletionStats(
        completedCount: 0,
        draftCount: 0,
        savedReframeCount: 0,
        favoriteReframeCount: 0,
        averageIntensityChange: nil,
        recurringDistortions: []
    )
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

struct AdaptiveModeUsageCount: Identifiable, Sendable {
    let id = UUID()
    let mode: DailyPlanMode
    let count: Int
}

enum CalendarMoodTimeBucket: String, CaseIterable, Sendable {
    case morning
    case afternoon
    case evening
    case night

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }
}

struct WeekdayMoodPattern: Identifiable, Sendable {
    let id: Int
    let weekday: Int
    let label: String
    let averageScore: Double
    let entryCount: Int
}

struct TimeOfDayMoodPattern: Identifiable, Sendable {
    let id: CalendarMoodTimeBucket
    let bucket: CalendarMoodTimeBucket
    let averageMood: Double
    let entryCount: Int
}

struct TriggerDayTypePattern: Identifiable, Sendable {
    let id: String
    let trigger: String
    let weekdayCount: Int
    let weekendCount: Int

    var totalCount: Int {
        weekdayCount + weekendCount
    }
}

struct SleepMoodPattern: Identifiable, Sendable {
    let id: String
    let label: String
    let averageMood: Double
    let entryCount: Int
}

struct ExerciseMoodAfterCompletionPattern: Sendable {
    let completionCount: Int
    let matchedMoodCount: Int
    let averageMoodAfterCompletion: Double?
    let averageMoodWithoutRecentExercise: Double?
    let deltaFromOtherMoodEntries: Double?

    static let empty = ExerciseMoodAfterCompletionPattern(
        completionCount: 0,
        matchedMoodCount: 0,
        averageMoodAfterCompletion: nil,
        averageMoodWithoutRecentExercise: nil,
        deltaFromOtherMoodEntries: nil
    )
}

struct CalendarMoodPatternSummary: Sendable {
    let moodByWeekday: [WeekdayMoodPattern]
    let stressByWeekday: [WeekdayMoodPattern]
    let moodByTimeOfDay: [TimeOfDayMoodPattern]
    let triggerFrequencyByDayType: [TriggerDayTypePattern]
    let sleepQualityVsMood: [SleepMoodPattern]
    let exerciseMoodAfterCompletion: ExerciseMoodAfterCompletionPattern

    static let empty = CalendarMoodPatternSummary(
        moodByWeekday: [],
        stressByWeekday: [],
        moodByTimeOfDay: [],
        triggerFrequencyByDayType: [],
        sleepQualityVsMood: [],
        exerciseMoodAfterCompletion: .empty
    )
}

struct PlainLanguagePatternInsight: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let message: String
    let iconName: String
    let occurrenceCount: Int?
    let actionTitle: String?
    let actionDescription: String?
    let actionCategory: String

    var canCreatePlan: Bool {
        actionTitle != nil
    }

    var actionPrompt: String? {
        guard actionTitle != nil else { return nil }

        if let occurrenceCount, occurrenceCount >= 3 {
            return String(localized: "This pattern showed up \(occurrenceCount) times. Try one tiny next step.")
        }

        return String(localized: "Try one tiny next step.")
    }

    init(
        title: String,
        message: String,
        iconName: String,
        occurrenceCount: Int? = nil,
        actionTitle: String? = nil,
        actionDescription: String? = nil,
        actionCategory: String = "Nourishing"
    ) {
        self.title = title
        self.message = message
        self.iconName = iconName
        self.occurrenceCount = occurrenceCount
        self.actionTitle = actionTitle
        self.actionDescription = actionDescription
        self.actionCategory = PlannedActivity.normalizedCategory(actionCategory)
    }
}

struct PersonalCopingPlanItem: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let whenText: String
    let tryText: String
    let reason: String
    let iconName: String
    let matchCount: Int
}

struct InsightsPatternSummary: Sendable {
    let activityMoodAverages: [ActivityMoodAverage]
    let lowMoodActivityTags: [ActivityTagFrequency]
    let highMoodActivityTags: [ActivityTagFrequency]
    let triggerEmotionPatterns: [TriggerEmotionPattern]
    let anxietySensations: [SensationCount]
    let moodTrends: [MoodTrendInsight]
    let checkInConsistency: CheckInConsistencyInsight
    let adaptiveModeUsage: [AdaptiveModeUsageCount]
    let calendarPatterns: CalendarMoodPatternSummary
    let insightCards: [PlainLanguagePatternInsight]
    let personalCopingPlan: [PersonalCopingPlanItem]

    static let empty = InsightsPatternSummary(
        activityMoodAverages: [],
        lowMoodActivityTags: [],
        highMoodActivityTags: [],
        triggerEmotionPatterns: [],
        anxietySensations: [],
        moodTrends: [],
        checkInConsistency: .empty,
        adaptiveModeUsage: [],
        calendarPatterns: .empty,
        insightCards: [],
        personalCopingPlan: []
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
    let thoughtRecordStats: ThoughtRecordCompletionStats
    let contextTagCorrelations: [ContextTagMoodCorrelation]
    let patternSummary: InsightsPatternSummary
    let personalGrowth: PersonalGrowthSnapshot
    let triggerLibrary: TriggerLibrarySnapshot
}
