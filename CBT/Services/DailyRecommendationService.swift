import Foundation
import OSLog
import SwiftData

nonisolated enum DailyRecommendationType: String, Hashable, Sendable {
    case moodCheckIn
    case thoughtRecord
    case breathingReset
    case guidedJournal
    case libraryExercise
    case courseLesson
    case behavioralActivation
    case sleepWindDown
    case safetySupport

    var iconName: String {
        switch self {
        case .moodCheckIn:
            return "face.smiling"
        case .thoughtRecord:
            return "brain.head.profile"
        case .breathingReset:
            return "wind"
        case .guidedJournal:
            return "pencil.and.list.clipboard"
        case .libraryExercise:
            return "figure.mind.and.body"
        case .courseLesson:
            return "graduationcap.fill"
        case .behavioralActivation:
            return "calendar.badge.clock"
        case .sleepWindDown:
            return "moon.stars.fill"
        case .safetySupport:
            return "cross.case.fill"
        }
    }
}

nonisolated enum DailyRecommendationDestination: Hashable, Sendable {
    case moodCheckIn
    case thoughtRecord
    case breathingReset(durationSeconds: Int)
    case guidedJournal(kind: String)
    case libraryExercise(exerciseID: String)
    case course(courseID: String)
    case program(programID: String)
    case introToCBT
    case behavioralActivation
    case assessments
    case safetySupport

    var deepLink: String {
        switch self {
        case .moodCheckIn:
            return "cbt://daily-plan/mood-check-in"
        case .thoughtRecord:
            return "cbt://daily-plan/thought-record"
        case .breathingReset(let durationSeconds):
            return "cbt://daily-plan/breathing-reset?duration=\(durationSeconds)"
        case .guidedJournal(let kind):
            return "cbt://journal/guided/\(kind)"
        case .libraryExercise(let exerciseID):
            return "cbt://library/exercise/\(exerciseID)"
        case .course(let courseID):
            return "cbt://library/course/\(courseID)"
        case .program(let programID):
            return "cbt://program/\(programID)"
        case .introToCBT:
            return "cbt://daily-plan/intro-to-cbt"
        case .behavioralActivation:
            return "cbt://exercises/activity-planner"
        case .assessments:
            return "cbt://assessments"
        case .safetySupport:
            return "cbt://safety-plan"
        }
    }
}

nonisolated struct DailyRecommendation: Identifiable, Hashable, Sendable {
    let id: String
    let type: DailyRecommendationType
    let title: String
    let subtitle: String
    let reason: String
    let destination: DailyRecommendationDestination
    let priority: Int
    let estimatedDurationMinutes: Int
    let isCompletedToday: Bool

    var iconName: String {
        type.iconName
    }

    var icon: String {
        iconName
    }

    var why: String {
        reason
    }

    var actionTitle: String {
        "\(priorityLabel) • \(durationLabel)"
    }

    var completionItem: DailyPlanItem? {
        switch type {
        case .moodCheckIn:
            return .moodCheckIn
        case .thoughtRecord:
            return .thoughtRecord
        case .breathingReset, .sleepWindDown:
            return .breathingReset
        case .libraryExercise, .courseLesson:
            return .exercises
        case .behavioralActivation:
            return .activityPlanner
        case .guidedJournal, .safetySupport:
            return nil
        }
    }

    var durationLabel: String {
        estimatedDurationMinutes == 1 ? "1 min" : "\(estimatedDurationMinutes) min"
    }

    var priorityLabel: String {
        switch priority {
        case 80...:
            return "High"
        case 60..<80:
            return "Medium"
        default:
            return "Light"
        }
    }
}

nonisolated struct MoodCheckInRecommendationInput: Hashable, Sendable {
    let moodScore: Int
    let intensity: Int
    let emotions: [String]
    let triggers: [String]
    let activityTags: [String]
    let sensations: [String]
    let contextTags: [String]
    let notes: String?
}

nonisolated struct MoodCheckInNextStepPlan: Hashable, Sendable {
    let supportiveMessage: String
    let recommendations: [DailyRecommendation]
}

private extension MoodCheckInRecommendationInput {
    var isLowMood: Bool {
        moodScore <= 2 || containsAny(["sad", "lonely", "hopeless", "numb", "depressed"])
    }

    var hasAnxietySignal: Bool {
        containsAny([
            "anxious",
            "anxiety",
            "stressed",
            "stress",
            "worried",
            "worry",
            "panic",
            "panicked",
            "nervous",
            "overwhelmed",
            "tight chest",
            "racing heart",
            "restless",
            "tense shoulders",
            "stomach flutter",
            "shaky"
        ])
    }

    var isGoodMood: Bool {
        moodScore >= 4 || containsAny(["happy", "calm", "grateful", "excited", "content", "hopeful"])
    }

    private var searchableText: String {
        let fields = [
            emotions,
            triggers,
            activityTags,
            sensations,
            contextTags,
            [notes ?? ""]
        ]

        return fields
            .flatMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func containsAny(_ terms: [String]) -> Bool {
        let text = searchableText
        return terms.contains { text.contains($0) }
    }
}

@MainActor
struct DailyRecommendationService {
    static let shared = DailyRecommendationService()
    static let lastHomeVisitKey = "cbt_home_lastOpenedAt"

    private static let logger = AppLogger.make(category: "DailyRecommendation")
    private let anxietyKeywords = [
        "anxious", "anxiety", "worry", "worried", "panic", "fear", "fearful",
        "nervous", "stress", "stressed", "overwhelmed", "restless", "on edge"
    ]

    func nextStepsAfterMoodCheckIn(for input: MoodCheckInRecommendationInput) -> MoodCheckInNextStepPlan {
        if input.isLowMood {
            return MoodCheckInNextStepPlan(
                supportiveMessage: "You saved this check-in. That is already a small act of care.",
                recommendations: [
                    makeRecommendation(
                        type: .behavioralActivation,
                        title: "Try one small nourishing activity",
                        subtitle: "Pick something brief and kind to your body.",
                        reason: "A tiny doable action can be a gentle next step when mood is low.",
                        destination: .behavioralActivation,
                        priority: 96,
                        duration: 5,
                        isCompletedToday: false
                    ),
                    makeRecommendation(
                        type: .breathingReset,
                        title: "One-minute grounding",
                        subtitle: "Slow the pace before choosing what comes next.",
                        reason: "When mood is low, a brief reset can make the next step feel smaller.",
                        destination: .breathingReset(durationSeconds: 60),
                        priority: 92,
                        duration: 1,
                        isCompletedToday: false
                    ),
                    makeRecommendation(
                        type: .safetySupport,
                        title: "Open your safety plan",
                        subtitle: "Keep support steps and trusted contacts close.",
                        reason: "Safety resources should stay reachable whenever mood is very low.",
                        destination: .safetySupport,
                        priority: 84,
                        duration: 2,
                        isCompletedToday: false
                    )
                ]
            )
        }

        if input.hasAnxietySignal {
            return MoodCheckInNextStepPlan(
                supportiveMessage: "You named what is happening. A small steadying step is enough.",
                recommendations: [
                    makeRecommendation(
                        type: .breathingReset,
                        title: "Breathing reset",
                        subtitle: "One minute of paced breathing.",
                        reason: "A steady breathing cue can be a useful next step for anxious moments.",
                        destination: .breathingReset(durationSeconds: 60),
                        priority: 94,
                        duration: 1,
                        isCompletedToday: false
                    ),
                    makeRecommendation(
                        type: .libraryExercise,
                        title: "Worry unpacker",
                        subtitle: "Move worries into a small container.",
                        reason: "Giving worry a place can lower the mental noise.",
                        destination: .libraryExercise(exerciseID: "exercise_016"),
                        priority: 88,
                        duration: 10,
                        isCompletedToday: false
                    ),
                    makeRecommendation(
                        type: .libraryExercise,
                        title: "Grounding exercise",
                        subtitle: "Use your senses to find the room again.",
                        reason: "Grounding can bring attention back to what is here now.",
                        destination: .libraryExercise(exerciseID: "exercise_003"),
                        priority: 86,
                        duration: 7,
                        isCompletedToday: false
                    )
                ]
            )
        }

        if input.isGoodMood {
            return MoodCheckInNextStepPlan(
                supportiveMessage: "This one is worth letting in for a moment.",
                recommendations: [
                    makeRecommendation(
                        type: .libraryExercise,
                        title: "Savor this moment",
                        subtitle: "Notice what helped this feel good.",
                        reason: "Savoring makes positive moments easier to remember.",
                        destination: .libraryExercise(exerciseID: "exercise_005"),
                        priority: 80,
                        duration: 4,
                        isCompletedToday: false
                    ),
                    makeRecommendation(
                        type: .guidedJournal,
                        title: "Gratitude reflection",
                        subtitle: "Capture one specific thing you appreciate.",
                        reason: "Gratitude can help capture a good moment while it is fresh.",
                        destination: .guidedJournal(kind: "gratitude_reflection"),
                        priority: 78,
                        duration: 4,
                        isCompletedToday: false
                    )
                ]
            )
        }

        return MoodCheckInNextStepPlan(
            supportiveMessage: "You captured the moment. You can stop here or choose one light next step.",
            recommendations: [
                makeRecommendation(
                    type: .breathingReset,
                    title: "Breathing reset",
                    subtitle: "Take one steady minute.",
                    reason: "A short reset keeps the next step simple.",
                    destination: .breathingReset(durationSeconds: 60),
                    priority: 62,
                    duration: 1,
                    isCompletedToday: false
                ),
                makeRecommendation(
                    type: .guidedJournal,
                    title: "Journal more",
                    subtitle: "Give this check-in a little more room.",
                    reason: "A few extra lines can make patterns easier to spot.",
                    destination: .guidedJournal(kind: "open"),
                    priority: 58,
                    duration: 4,
                    isCompletedToday: false
                )
            ]
        )
    }

    func recommendations(
        for date: Date = Date(),
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        lastOpenedAt: Date? = nil
    ) -> [DailyRecommendation] {
        let dayStart = calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now) ?? now
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now

        let moodEntries = fetch(
            FetchDescriptor<MoodEntry>(
                predicate: #Predicate<MoodEntry> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\MoodEntry.createdAt, order: .reverse)]
            ),
            from: context,
            label: "moodEntries"
        )
        let moodCheckIns = fetch(
            FetchDescriptor<MoodCheckIn>(
                predicate: #Predicate<MoodCheckIn> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\MoodCheckIn.createdAt, order: .reverse)]
            ),
            from: context,
            label: "moodCheckIns"
        )
        let thoughtRecords = fetch(
            FetchDescriptor<ThoughtRecord>(
                predicate: #Predicate<ThoughtRecord> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\ThoughtRecord.createdAt, order: .reverse)]
            ),
            from: context,
            label: "thoughtRecords"
        )
        let exerciseCompletions = fetch(
            FetchDescriptor<ExerciseCompletion>(
                predicate: #Predicate<ExerciseCompletion> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\ExerciseCompletion.createdAt, order: .reverse)]
            ),
            from: context,
            label: "exerciseCompletions"
        )
        let journalEntries = fetch(
            FetchDescriptor<JournalEntry>(
                predicate: #Predicate<JournalEntry> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\JournalEntry.createdAt, order: .reverse)]
            ),
            from: context,
            label: "journalEntries"
        )
        let guidedJournalEntries = fetch(
            FetchDescriptor<FlexibleJournalEntry>(
                sortBy: [SortDescriptor(\FlexibleJournalEntry.date, order: .reverse)]
            ),
            from: context,
            label: "guidedJournalEntries"
        )
        let breathingSessions = fetch(
            FetchDescriptor<BreathingSession>(
                predicate: #Predicate<BreathingSession> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\BreathingSession.createdAt, order: .reverse)]
            ),
            from: context,
            label: "breathingSessions"
        )
        let plannedActivities = fetch(
            FetchDescriptor<PlannedActivity>(
                predicate: #Predicate<PlannedActivity> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\PlannedActivity.scheduledDate)]
            ),
            from: context,
            label: "plannedActivities"
        )
        let assessmentLogs = fetch(
            FetchDescriptor<AssessmentLog>(
                sortBy: [SortDescriptor(\AssessmentLog.date, order: .reverse)]
            ),
            from: context,
            label: "assessmentLogs"
        )
        let programProgresses = fetch(
            FetchDescriptor<ProgramProgress>(
                predicate: #Predicate<ProgramProgress> { $0.isDeleted == false }
            ),
            from: context,
            label: "programProgresses"
        )
        let courses = fetch(
            FetchDescriptor<Course>(sortBy: [SortDescriptor(\Course.title)]),
            from: context,
            label: "courses"
        )
        let libraryItems = fetch(
            FetchDescriptor<LibraryItem>(
                sortBy: [SortDescriptor(\LibraryItem.category), SortDescriptor(\LibraryItem.title)]
            ),
            from: context,
            label: "libraryItems"
        )
        let achievements = fetch(
            FetchDescriptor<Achievement>(
                sortBy: [SortDescriptor(\Achievement.createdAt, order: .reverse)]
            ),
            from: context,
            label: "achievements"
        )

        let moodSignals = makeMoodSignals(moodEntries: moodEntries, moodCheckIns: moodCheckIns)
        let latestMood = moodSignals.first
        let hasMoodToday = moodSignals.contains { isDate($0.createdAt, inSameDayAs: dayStart, calendar: calendar) }
        let hasThoughtToday = thoughtRecords.contains { $0.createdAt >= dayStart && $0.createdAt < dayEnd }
        let hasBreathingToday = breathingSessions.contains { $0.createdAt >= dayStart && $0.createdAt < dayEnd } ||
            journalEntries.contains { $0.sourceKind == SessionSourceKind.breathing.rawValue && $0.createdAt >= dayStart && $0.createdAt < dayEnd }
        let hasGuidedJournalToday = guidedJournalEntries.contains { $0.date >= dayStart && $0.date < dayEnd }
        let hasExerciseToday = exerciseCompletions.contains { $0.createdAt >= dayStart && $0.createdAt < dayEnd }
        let hasActivityCompletedToday = plannedActivities.contains {
            $0.isCompleted && (($0.completedAt ?? $0.scheduledDate) >= dayStart) && (($0.completedAt ?? $0.scheduledDate) < dayEnd)
        }

        if hasNoUserData(
            moodSignals: moodSignals,
            thoughtRecords: thoughtRecords,
            exerciseCompletions: exerciseCompletions,
            journalEntries: journalEntries,
            guidedJournalEntries: guidedJournalEntries,
            breathingSessions: breathingSessions,
            plannedActivities: plannedActivities,
            assessmentLogs: assessmentLogs,
            programProgresses: programProgresses,
            courses: courses,
            achievements: achievements
        ) {
            return beginnerPlan(
                hasMoodToday: hasMoodToday,
                hasBreathingToday: hasBreathingToday
            )
        }

        let recentLowMood = moodSignals.contains { $0.createdAt >= threeDaysAgo && $0.moodScore <= 3 }
        let veryLowMood = latestMood.map { $0.moodScore <= 2 } ?? false
        if veryLowMood {
            return veryLowMoodPlan(
                hasBreathingToday: hasBreathingToday,
                oneSmallStepCompletedToday: exerciseCompletedToday(
                    exerciseID: "exercise_007",
                    exerciseCompletions: exerciseCompletions,
                    dayStart: dayStart,
                    dayEnd: dayEnd
                )
            )
        }

        if hasNotOpenedForDays(lastOpenedAt, now: now, calendar: calendar) {
            return lowFrictionReturnPlan(
                hasMoodToday: hasMoodToday,
                hasBreathingToday: hasBreathingToday,
                oneSmallStepCompletedToday: exerciseCompletedToday(
                    exerciseID: "exercise_007",
                    exerciseCompletions: exerciseCompletions,
                    dayStart: dayStart,
                    dayEnd: dayEnd
                )
            )
        }

        if anxietyRelatedEmotionsAreCommon(moodEntries.filter { $0.createdAt >= fourteenDaysAgo }) {
            return anxietyCommonPlan(
                hasBreathingToday: hasBreathingToday,
                hasGuidedJournalToday: hasGuidedJournalToday,
                anxietyResetCompletedToday: exerciseCompletedToday(
                    exerciseID: "exercise_012",
                    exerciseCompletions: exerciseCompletions,
                    dayStart: dayStart,
                    dayEnd: dayEnd
                )
            )
        }

        let missedCheckInDays = daysSinceLatestMood(latestMood, dayStart: dayStart, calendar: calendar)
        let missedCheckIn = !hasMoodToday && (missedCheckInDays == nil || (missedCheckInDays ?? 0) >= 1)
        let anxietyContext = recentAnxietyContext(
            moodEntries: moodEntries.filter { $0.createdAt >= fourteenDaysAgo },
            thoughtRecords: thoughtRecords.filter { $0.createdAt >= fourteenDaysAgo }
        )
        let topDistortion = mostFrequent(
            thoughtRecords
                .filter { $0.createdAt >= fourteenDaysAgo }
                .flatMap(\.distortions)
        )
        let pendingActivity = plannedActivities
            .filter { !$0.isCompleted && $0.scheduledDate < dayEnd }
            .sorted { $0.scheduledDate < $1.scheduledDate }
            .first
        let assessmentTrend = mostRelevantAssessmentTrend(from: assessmentLogs, since: thirtyDaysAgo)
        let completedExerciseIDs = Set(exerciseCompletions.map(\.exerciseID))
        let recentExercise = exerciseCompletions
            .first { $0.createdAt >= sevenDaysAgo }
            .flatMap { ExerciseService.shared.exercise(withID: $0.exerciseID) }
        let activeDates = activeDays(
            moodSignals: moodSignals,
            thoughtRecords: thoughtRecords,
            exerciseCompletions: exerciseCompletions,
            journalEntries: journalEntries,
            guidedJournalEntries: guidedJournalEntries,
            breathingSessions: breathingSessions,
            plannedActivities: plannedActivities,
            calendar: calendar
        )
        let currentStreak = currentStreak(from: activeDates, today: todayStart, calendar: calendar)
        let hasActiveToday = activeDates.contains(todayStart)
        let hour = calendar.component(.hour, from: now)
        let recentAchievement = achievements.first { achievement in
            guard let unlockedAt = achievement.unlockedAt else { return false }
            return unlockedAt >= sevenDaysAgo
        }

        var recommendations = [DailyRecommendationType: DailyRecommendation]()

        if missedCheckIn {
            let reason = missedCheckInDays.map { days in
                days <= 1 ? "No mood check-in has been logged today." : "It has been \(days) days since the last mood check-in."
            } ?? "No mood check-in has been logged yet."
            upsert(
                makeRecommendation(
                    type: .moodCheckIn,
                    title: "Mood Check-In",
                    subtitle: "Capture how you feel right now.",
                    reason: reason,
                    destination: .moodCheckIn,
                    priority: currentStreak > 0 && !hasActiveToday ? 84 : 74,
                    duration: 1,
                    isCompletedToday: hasMoodToday
                ),
                into: &recommendations
            )
        }

        if anxietyContext != nil || assessmentTrend?.suggestedFocus == .anxietyReset {
            let reason: String
            if let anxietyContext {
                reason = "Recent entries mention \(anxietyContext)."
            } else {
                reason = assessmentTrend?.reason ?? "Recent tracking suggests a short reset may fit today."
            }
            upsert(
                makeRecommendation(
                    type: .breathingReset,
                    title: "Breathing Reset",
                    subtitle: "Take one minute to slow the pace.",
                    reason: reason,
                    destination: .breathingReset(durationSeconds: 60),
                    priority: 82,
                    duration: 1,
                    isCompletedToday: hasBreathingToday
                ),
                into: &recommendations
            )
        }

        if let topDistortion, !hasThoughtToday {
            upsert(
                makeRecommendation(
                    type: .thoughtRecord,
                    title: "Thought Record",
                    subtitle: "Work through one automatic thought.",
                    reason: "You recently logged \(topDistortion).",
                    destination: .thoughtRecord,
                    priority: recentLowMood ? 78 : 68,
                    duration: 8,
                    isCompletedToday: hasThoughtToday
                ),
                into: &recommendations
            )
        }

        if let pendingActivity {
            upsert(
                makeRecommendation(
                    type: .behavioralActivation,
                    title: pendingActivity.title.isEmpty ? "Behavioral Activation" : pendingActivity.title,
                    subtitle: "Complete or reflect on a planned activity.",
                    reason: "A planned activity is still open.",
                    destination: .behavioralActivation,
                    priority: recentLowMood ? 76 : 66,
                    duration: 5,
                    isCompletedToday: hasActivityCompletedToday
                ),
                into: &recommendations
            )
        } else if recentLowMood || assessmentTrend?.suggestedFocus == .activation {
            upsert(
                makeRecommendation(
                    type: .behavioralActivation,
                    title: "Plan One Small Activity",
                    subtitle: "Pick a small nourishing or mastery task.",
                    reason: assessmentTrend?.suggestedFocus == .activation ? assessmentTrend?.reason ?? "Recent tracking makes a small activity a good fit." : "Recent mood entries were on the lower side.",
                    destination: .behavioralActivation,
                    priority: 64,
                    duration: 5,
                    isCompletedToday: hasActivityCompletedToday
                ),
                into: &recommendations
            )
        }

        if !hasGuidedJournalToday, hour < 12 {
            upsert(
                makeRecommendation(
                    type: .guidedJournal,
                    title: "Morning Intentions",
                    subtitle: "Set one direction for the day.",
                    reason: "It is still early enough to choose a small intention.",
                    destination: .guidedJournal(kind: DailyCheckInKind.morningIntentions.rawValue),
                    priority: currentStreak > 0 && !hasActiveToday ? 62 : 52,
                    duration: 3,
                    isCompletedToday: hasGuidedJournalToday
                ),
                into: &recommendations
            )
        } else if !hasGuidedJournalToday, hour >= 17 {
            upsert(
                makeRecommendation(
                    type: .guidedJournal,
                    title: "Evening Reflection",
                    subtitle: "Notice what happened and what you need next.",
                    reason: "Evening is a natural time to close the loop.",
                    destination: .guidedJournal(kind: DailyCheckInKind.eveningReflection.rawValue),
                    priority: 58,
                    duration: 4,
                    isCompletedToday: hasGuidedJournalToday
                ),
                into: &recommendations
            )
        }

        if hour >= 20, !hasBreathingToday {
            upsert(
                makeRecommendation(
                    type: .sleepWindDown,
                    title: "Sleep Wind-Down",
                    subtitle: "Try a short calming reset before bed.",
                    reason: "It is later in the day.",
                    destination: .breathingReset(durationSeconds: 120),
                    priority: 80,
                    duration: 2,
                    isCompletedToday: hasBreathingToday
                ),
                into: &recommendations
            )
        }

        if let exercise = exerciseRecommendation(
            recentExercise: recentExercise,
            topDistortion: topDistortion,
            hasAnxietyContext: anxietyContext != nil,
            recentLowMood: recentLowMood,
            completedExerciseIDs: completedExerciseIDs
        ) {
            let reason = exerciseReason(
                exercise: exercise,
                recentExercise: recentExercise,
                topDistortion: topDistortion,
                hasAnxietyContext: anxietyContext != nil,
                recentLowMood: recentLowMood
            )
            upsert(
                makeRecommendation(
                    type: .libraryExercise,
                    title: exercise.title,
                    subtitle: exercise.description,
                    reason: reason,
                    destination: .libraryExercise(exerciseID: exercise.id),
                    priority: recentExercise == nil ? 48 : 56,
                    duration: exercise.duration,
                    isCompletedToday: hasExerciseToday && exerciseCompletions.contains { completion in
                        completion.exerciseID == exercise.id && completion.createdAt >= dayStart && completion.createdAt < dayEnd
                    }
                ),
                into: &recommendations
            )
        }

        if let courseRecommendation = courseRecommendation(
            courses: courses,
            libraryItems: libraryItems,
            programProgresses: programProgresses,
            now: now,
            calendar: calendar
        ) {
            upsert(courseRecommendation, into: &recommendations)
        }

        if currentStreak > 0, !hasActiveToday {
            upsert(
                makeRecommendation(
                    type: .moodCheckIn,
                    title: "Keep Your Streak Going",
                    subtitle: "A quick check-in counts as today’s practice.",
                    reason: "Your current streak is \(currentStreak) \(currentStreak == 1 ? "day" : "days").",
                    destination: .moodCheckIn,
                    priority: 86,
                    duration: 1,
                    isCompletedToday: hasMoodToday
                ),
                into: &recommendations
            )
        } else if let recentAchievement {
            upsert(
                makeRecommendation(
                    type: .libraryExercise,
                    title: "Build on \(recentAchievement.title)",
                    subtitle: "Try one short practice to keep momentum.",
                    reason: "You recently unlocked an achievement.",
                    destination: exerciseRecommendation(
                        recentExercise: recentExercise,
                        topDistortion: topDistortion,
                        hasAnxietyContext: anxietyContext != nil,
                        recentLowMood: recentLowMood,
                        completedExerciseIDs: completedExerciseIDs
                    ).map { .libraryExercise(exerciseID: $0.id) } ?? .behavioralActivation,
                    priority: 50,
                    duration: 5,
                    isCompletedToday: hasExerciseToday
                ),
                into: &recommendations
            )
        }

        addFallbacks(
            to: &recommendations,
            hasMoodToday: hasMoodToday,
            hasThoughtToday: hasThoughtToday,
            hasBreathingToday: hasBreathingToday,
            hasGuidedJournalToday: hasGuidedJournalToday,
            hasActivityCompletedToday: hasActivityCompletedToday,
            hour: hour,
            completedExerciseIDs: completedExerciseIDs,
            dayStart: dayStart,
            dayEnd: dayEnd,
            exerciseCompletions: exerciseCompletions
        )

        return recommendations.values
            .sorted { first, second in
                if first.priority == second.priority {
                    return first.title < second.title
                }
                return first.priority > second.priority
            }
            .prefix(3)
            .map { $0 }
    }

    func primaryRecommendations(
        from context: ModelContext,
        lastOpenedAt: Date? = nil,
        now: Date = Date()
    ) -> [DailyRecommendation] {
        recommendations(for: now, in: context, now: now, lastOpenedAt: lastOpenedAt)
    }

    private func makeRecommendation(
        type: DailyRecommendationType,
        title: String,
        subtitle: String,
        reason: String,
        destination: DailyRecommendationDestination,
        priority: Int,
        duration: Int,
        isCompletedToday: Bool
    ) -> DailyRecommendation {
        DailyRecommendation(
            id: "\(type.rawValue)-\(destination.deepLink)",
            type: type,
            title: title,
            subtitle: subtitle,
            reason: reason,
            destination: destination,
            priority: priority,
            estimatedDurationMinutes: max(1, duration),
            isCompletedToday: isCompletedToday
        )
    }

    private func beginnerPlan(
        hasMoodToday: Bool,
        hasBreathingToday: Bool
    ) -> [DailyRecommendation] {
        [
            makeRecommendation(
                type: .moodCheckIn,
                title: "Mood Check-In",
                subtitle: "Start with one gentle check-in.",
                reason: "This gives your plan a simple starting point.",
                destination: .moodCheckIn,
                priority: 82,
                duration: 1,
                isCompletedToday: hasMoodToday
            ),
            makeRecommendation(
                type: .breathingReset,
                title: "3-Minute Breathing",
                subtitle: "A short reset before anything deeper.",
                reason: "Breathing is an easy first practice with no setup.",
                destination: .breathingReset(durationSeconds: 180),
                priority: 78,
                duration: 3,
                isCompletedToday: hasBreathingToday
            ),
            makeRecommendation(
                type: .courseLesson,
                title: "Intro to CBT Course",
                subtitle: "Learn the basics at your own pace.",
                reason: "A quick orientation makes the tools easier to use.",
                destination: .introToCBT,
                priority: 72,
                duration: 4,
                isCompletedToday: false
            )
        ]
    }

    private func veryLowMoodPlan(
        hasBreathingToday: Bool,
        oneSmallStepCompletedToday: Bool
    ) -> [DailyRecommendation] {
        [
            makeRecommendation(
                type: .breathingReset,
                title: "Grounding + Breathing",
                subtitle: "Settle your body before choosing next steps.",
                reason: "Your latest mood check-in was very low.",
                destination: .breathingReset(durationSeconds: 180),
                priority: 100,
                duration: 3,
                isCompletedToday: hasBreathingToday
            ),
            makeRecommendation(
                type: .libraryExercise,
                title: "One Small Step",
                subtitle: "Try a tiny behavioral activation task.",
                reason: "A small action can create a little momentum.",
                destination: .libraryExercise(exerciseID: "exercise_007"),
                priority: 94,
                duration: 5,
                isCompletedToday: oneSmallStepCompletedToday
            ),
            makeRecommendation(
                type: .safetySupport,
                title: "Open Safety Plan",
                subtitle: "Review support steps and trusted contacts.",
                reason: "Safety resources stay available when mood is very low.",
                destination: .safetySupport,
                priority: 88,
                duration: 2,
                isCompletedToday: false
            )
        ]
    }

    private func anxietyCommonPlan(
        hasBreathingToday: Bool,
        hasGuidedJournalToday: Bool,
        anxietyResetCompletedToday: Bool
    ) -> [DailyRecommendation] {
        [
            makeRecommendation(
                type: .breathingReset,
                title: "Breathing Reset",
                subtitle: "Lower your body's stress signal.",
                reason: "Anxiety-related emotions are common in recent check-ins.",
                destination: .breathingReset(durationSeconds: 120),
                priority: 90,
                duration: 2,
                isCompletedToday: hasBreathingToday
            ),
            makeRecommendation(
                type: .guidedJournal,
                title: "Worry Journal",
                subtitle: "Move worries out of your head and onto the page.",
                reason: "Writing worries down can make them easier to sort.",
                destination: .guidedJournal(kind: "worry_journal"),
                priority: 86,
                duration: 4,
                isCompletedToday: hasGuidedJournalToday
            ),
            makeRecommendation(
                type: .libraryExercise,
                title: "Anxiety Reset Exercise",
                subtitle: "Practice progressive relaxation.",
                reason: "A guided reset can release tension that keeps worry active.",
                destination: .libraryExercise(exerciseID: "exercise_012"),
                priority: 82,
                duration: 6,
                isCompletedToday: anxietyResetCompletedToday
            )
        ]
    }

    private func lowFrictionReturnPlan(
        hasMoodToday: Bool,
        hasBreathingToday: Bool,
        oneSmallStepCompletedToday: Bool
    ) -> [DailyRecommendation] {
        [
            makeRecommendation(
                type: .moodCheckIn,
                title: "Mood Check-In",
                subtitle: "A one-minute re-entry point.",
                reason: "After a break, a light check-in is enough.",
                destination: .moodCheckIn,
                priority: 78,
                duration: 1,
                isCompletedToday: hasMoodToday
            ),
            makeRecommendation(
                type: .breathingReset,
                title: "Breathing Reset",
                subtitle: "One minute to settle back in.",
                reason: "It is quick, familiar, and low pressure.",
                destination: .breathingReset(durationSeconds: 60),
                priority: 74,
                duration: 1,
                isCompletedToday: hasBreathingToday
            ),
            makeRecommendation(
                type: .libraryExercise,
                title: "One Small Step",
                subtitle: "Choose something tiny and doable.",
                reason: "Low-friction action helps restart the habit gently.",
                destination: .libraryExercise(exerciseID: "exercise_007"),
                priority: 70,
                duration: 5,
                isCompletedToday: oneSmallStepCompletedToday
            )
        ]
    }

    private func upsert(
        _ recommendation: DailyRecommendation,
        into recommendations: inout [DailyRecommendationType: DailyRecommendation]
    ) {
        guard let existing = recommendations[recommendation.type] else {
            recommendations[recommendation.type] = recommendation
            return
        }

        if recommendation.priority > existing.priority {
            recommendations[recommendation.type] = recommendation
        }
    }

    private func hasNoUserData(
        moodSignals: [MoodSignal],
        thoughtRecords: [ThoughtRecord],
        exerciseCompletions: [ExerciseCompletion],
        journalEntries: [JournalEntry],
        guidedJournalEntries: [FlexibleJournalEntry],
        breathingSessions: [BreathingSession],
        plannedActivities: [PlannedActivity],
        assessmentLogs: [AssessmentLog],
        programProgresses: [ProgramProgress],
        courses: [Course],
        achievements: [Achievement]
    ) -> Bool {
        moodSignals.isEmpty &&
            thoughtRecords.isEmpty &&
            exerciseCompletions.isEmpty &&
            journalEntries.isEmpty &&
            guidedJournalEntries.isEmpty &&
            breathingSessions.isEmpty &&
            plannedActivities.isEmpty &&
            assessmentLogs.isEmpty &&
            !programProgresses.contains { $0.completedDays > 0 || $0.lastCompletedAt != nil } &&
            !courses.contains { !$0.completedItemIDs.isEmpty || $0.isCompleted } &&
            !achievements.contains { $0.isUnlocked || $0.unlockedAt != nil }
    }

    private func hasNotOpenedForDays(_ lastOpenedAt: Date?, now: Date, calendar: Calendar) -> Bool {
        guard let lastOpenedAt else { return false }
        let lastDay = calendar.startOfDay(for: lastOpenedAt)
        let today = calendar.startOfDay(for: now)
        let daysAway = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        return daysAway >= 3
    }

    private func anxietyRelatedEmotionsAreCommon(_ moodEntries: [MoodEntry]) -> Bool {
        let recentEntries = Array(moodEntries.prefix(12))
        guard recentEntries.count >= 3 else { return false }

        let matches = recentEntries.filter { entry in
            let values = entry.emotions + entry.triggers + entry.sensations + entry.contextTags
            return values.contains(where: containsAnxietyKeyword)
        }

        return matches.count >= 2 && Double(matches.count) / Double(recentEntries.count) >= 0.34
    }

    private func exerciseCompletedToday(
        exerciseID: String,
        exerciseCompletions: [ExerciseCompletion],
        dayStart: Date,
        dayEnd: Date
    ) -> Bool {
        exerciseCompletions.contains { completion in
            completion.exerciseID == exerciseID &&
                completion.createdAt >= dayStart &&
                completion.createdAt < dayEnd
        }
    }

    private func addFallbacks(
        to recommendations: inout [DailyRecommendationType: DailyRecommendation],
        hasMoodToday: Bool,
        hasThoughtToday: Bool,
        hasBreathingToday: Bool,
        hasGuidedJournalToday: Bool,
        hasActivityCompletedToday: Bool,
        hour: Int,
        completedExerciseIDs: Set<String>,
        dayStart: Date,
        dayEnd: Date,
        exerciseCompletions: [ExerciseCompletion]
    ) {
        if !hasMoodToday {
            upsert(
                makeRecommendation(
                    type: .moodCheckIn,
                    title: "Mood Check-In",
                    subtitle: "Capture how you feel right now.",
                    reason: "A check-in gives today a starting point.",
                    destination: .moodCheckIn,
                    priority: 60,
                    duration: 1,
                    isCompletedToday: hasMoodToday
                ),
                into: &recommendations
            )
        }

        if !hasBreathingToday {
            upsert(
                makeRecommendation(
                    type: .breathingReset,
                    title: "Breathing Reset",
                    subtitle: "Take one minute to slow the pace.",
                    reason: "A short reset is available whenever you want one.",
                    destination: .breathingReset(durationSeconds: 60),
                    priority: 54,
                    duration: 1,
                    isCompletedToday: hasBreathingToday
                ),
                into: &recommendations
            )
        }

        if !hasThoughtToday {
            upsert(
                makeRecommendation(
                    type: .thoughtRecord,
                    title: "Thought Record",
                    subtitle: "Work through one automatic thought.",
                    reason: "No thought record has been logged today.",
                    destination: .thoughtRecord,
                    priority: 50,
                    duration: 8,
                    isCompletedToday: hasThoughtToday
                ),
                into: &recommendations
            )
        }

        if !hasGuidedJournalToday {
            let kind: DailyCheckInKind = hour >= 17 ? .eveningReflection : .morningIntentions
            upsert(
                makeRecommendation(
                    type: .guidedJournal,
                    title: kind.title,
                    subtitle: kind == .morningIntentions ? "Set one direction for the day." : "Notice what happened and what you need next.",
                    reason: "A guided prompt can make reflection easier to start.",
                    destination: .guidedJournal(kind: kind.rawValue),
                    priority: 46,
                    duration: kind == .morningIntentions ? 3 : 4,
                    isCompletedToday: hasGuidedJournalToday
                ),
                into: &recommendations
            )
        }

        if let exercise = firstExercise(
            matching: ["Grounding", "Thought Reframing", "Behavioral Activation", "Self Compassion"],
            excluding: completedExerciseIDs
        ) {
            upsert(
                makeRecommendation(
                    type: .libraryExercise,
                    title: exercise.title,
                    subtitle: exercise.description,
                    reason: "This is a short practice you have not completed recently.",
                    destination: .libraryExercise(exerciseID: exercise.id),
                    priority: 42,
                    duration: exercise.duration,
                    isCompletedToday: exerciseCompletions.contains { completion in
                        completion.exerciseID == exercise.id && completion.createdAt >= dayStart && completion.createdAt < dayEnd
                    }
                ),
                into: &recommendations
            )
        }

        if !hasActivityCompletedToday {
            upsert(
                makeRecommendation(
                    type: .behavioralActivation,
                    title: "Plan One Small Activity",
                    subtitle: "Pick a small nourishing or mastery task.",
                    reason: "A concrete activity gives the day a reachable next step.",
                    destination: .behavioralActivation,
                    priority: 38,
                    duration: 5,
                    isCompletedToday: hasActivityCompletedToday
                ),
                into: &recommendations
            )
        }
    }

    private struct MoodSignal {
        let createdAt: Date
        let moodScore: Int
    }

    private enum AssessmentFocus {
        case anxietyReset
        case activation
        case reflection
    }

    private struct AssessmentTrend {
        let reason: String
        let suggestedFocus: AssessmentFocus
    }

    private func makeMoodSignals(moodEntries: [MoodEntry], moodCheckIns: [MoodCheckIn]) -> [MoodSignal] {
        let moodEntrySignals = moodEntries.map {
            MoodSignal(createdAt: $0.createdAt, moodScore: $0.moodScore)
        }
        let checkInSignals = moodCheckIns.map {
            MoodSignal(createdAt: $0.createdAt, moodScore: $0.moodScore)
        }

        return (moodEntrySignals + checkInSignals).sorted { $0.createdAt > $1.createdAt }
    }

    private func daysSinceLatestMood(_ latestMood: MoodSignal?, dayStart: Date, calendar: Calendar) -> Int? {
        guard let latestMood else { return nil }
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: latestMood.createdAt),
            to: dayStart
        ).day
    }

    private func recentAnxietyContext(moodEntries: [MoodEntry], thoughtRecords: [ThoughtRecord]) -> String? {
        var tokens = [String]()

        for entry in moodEntries {
            let values = entry.emotions + entry.triggers + entry.sensations + entry.contextTags
            if values.contains(where: containsAnxietyKeyword) {
                tokens.append(contentsOf: values)
            }
        }

        for record in thoughtRecords where record.emotions.contains(where: containsAnxietyKeyword) {
            tokens.append(contentsOf: record.emotions)
        }

        return mostFrequent(tokens)
    }

    private func containsAnxietyKeyword(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        return anxietyKeywords.contains { lowercased.contains($0) }
    }

    private func mostFrequent(_ values: [String]) -> String? {
        var counts = [String: (display: String, count: Int)]()
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            let current = counts[key] ?? (display: trimmed, count: 0)
            counts[key] = (display: current.display, count: current.count + 1)
        }

        return counts.values
            .sorted {
                if $0.count == $1.count {
                    return $0.display < $1.display
                }
                return $0.count > $1.count
            }
            .first?
            .display
    }

    private func mostRelevantAssessmentTrend(from logs: [AssessmentLog], since cutoff: Date) -> AssessmentTrend? {
        let grouped = Dictionary(grouping: logs) { $0.assessmentType.uppercased() }

        for (type, entries) in grouped.sorted(by: { $0.key < $1.key }) {
            let sorted = entries.sorted { $0.date > $1.date }
            guard sorted.count >= 2, let latest = sorted.first, latest.date >= cutoff else { continue }

            let previous = sorted[1]
            let latestValue = latest.scoreValue ?? Double(latest.score)
            let previousValue = previous.scoreValue ?? Double(previous.score)
            let delta = latestValue - previousValue

            if type.contains("MAAS"), delta <= -0.5 {
                return AssessmentTrend(
                    reason: "Your recent \(latest.assessmentType) score moved lower.",
                    suggestedFocus: .reflection
                )
            }

            if !type.contains("MAAS"), delta >= 2 {
                if type.contains("PHQ") {
                    return AssessmentTrend(
                        reason: "Your recent \(latest.assessmentType) score moved upward.",
                        suggestedFocus: .activation
                    )
                }

                return AssessmentTrend(
                    reason: "Your recent \(latest.assessmentType) score moved upward.",
                    suggestedFocus: .anxietyReset
                )
            }
        }

        return nil
    }

    private func exerciseRecommendation(
        recentExercise: Exercise?,
        topDistortion: String?,
        hasAnxietyContext: Bool,
        recentLowMood: Bool,
        completedExerciseIDs: Set<String>
    ) -> Exercise? {
        if hasAnxietyContext {
            return firstExercise(matching: ["Anxiety Reset", "Grounding", "Distress Tolerance"], excluding: completedExerciseIDs)
        }

        if topDistortion != nil {
            return firstExercise(matching: ["Thought Reframing", "Cognitive Distortions"], excluding: completedExerciseIDs)
        }

        if recentLowMood {
            return firstExercise(matching: ["Behavioral Activation", "Self Compassion", "Gratitude"], excluding: completedExerciseIDs)
        }

        if let recentExercise {
            return firstExercise(matching: [recentExercise.category], excluding: completedExerciseIDs)
        }

        return firstExercise(matching: ["Grounding", "Thought Reframing", "Behavioral Activation"], excluding: completedExerciseIDs)
    }

    private func exerciseReason(
        exercise: Exercise,
        recentExercise: Exercise?,
        topDistortion: String?,
        hasAnxietyContext: Bool,
        recentLowMood: Bool
    ) -> String {
        if hasAnxietyContext {
            return "This practice matches recent anxiety or stress entries."
        }

        if let topDistortion {
            return "This practice pairs with recent \(topDistortion) entries."
        }

        if recentLowMood {
            return "A small action can fit days when mood has been lower."
        }

        if let recentExercise, recentExercise.category == exercise.category {
            return "You recently completed a \(recentExercise.category) practice."
        }

        return "This is a short practice from the library."
    }

    private func firstExercise(matching categories: [String], excluding completedExerciseIDs: Set<String>) -> Exercise? {
        let exercises = ExerciseService.shared.exercises
        let categoryMatches = categories.flatMap { category in
            exercises.filter { $0.category == category }
        }

        return categoryMatches.first { !completedExerciseIDs.contains($0.id) }
            ?? categoryMatches.first
            ?? exercises.first { !completedExerciseIDs.contains($0.id) }
            ?? exercises.first
    }

    private func courseRecommendation(
        courses: [Course],
        libraryItems: [LibraryItem],
        programProgresses: [ProgramProgress],
        now: Date,
        calendar: Calendar
    ) -> DailyRecommendation? {
        if let progress = programProgresses.first(where: { $0.programID == CBTProgram.tacklingProcrastination.id }) {
            let completedDays = min(progress.completedDays, CBTProgram.tacklingProcrastination.days.count)
            if completedDays < CBTProgram.tacklingProcrastination.days.count {
                let title = completedDays == 0 ? "Start \(CBTProgram.tacklingProcrastination.title)" : "Continue \(CBTProgram.tacklingProcrastination.title)"
                let completedToday = progress.lastCompletedAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false
                return makeRecommendation(
                    type: .courseLesson,
                    title: title,
                    subtitle: "Open the next short course lesson.",
                    reason: "Course progress is \(completedDays) of \(CBTProgram.tacklingProcrastination.days.count) days.",
                    destination: .program(programID: CBTProgram.tacklingProcrastination.id),
                    priority: completedToday ? 34 : 52,
                    duration: 6,
                    isCompletedToday: completedToday
                )
            }
        } else {
            return makeRecommendation(
                type: .courseLesson,
                title: "Start \(CBTProgram.tacklingProcrastination.title)",
                subtitle: "Open the first short course lesson.",
                reason: "No course lesson has been completed yet.",
                destination: .program(programID: CBTProgram.tacklingProcrastination.id),
                priority: 40,
                duration: 6,
                isCompletedToday: false
            )
        }

        let nextCourse = courses
            .filter { !$0.isCompleted && !$0.orderedItems(from: libraryItems).isEmpty }
            .sorted {
                if $0.completedItemIDs.count == $1.completedItemIDs.count {
                    return $0.title < $1.title
                }
                return $0.completedItemIDs.count > $1.completedItemIDs.count
            }
            .first

        guard let nextCourse else { return nil }
        let orderedItems = nextCourse.orderedItems(from: libraryItems)
        let nextItem = orderedItems.first { !nextCourse.completedItemIDs.contains($0.id) } ?? orderedItems.first

        return makeRecommendation(
            type: .courseLesson,
            title: "Continue \(nextCourse.title)",
            subtitle: nextItem.map { "Next: \($0.title)" } ?? "Open the next course step.",
            reason: "Course progress is \(nextCourse.completedItemIDs.count) of \(orderedItems.count) steps.",
            destination: .course(courseID: nextCourse.id),
            priority: 48,
            duration: nextItem?.duration ?? 6,
            isCompletedToday: false
        )
    }

    private func activeDays(
        moodSignals: [MoodSignal],
        thoughtRecords: [ThoughtRecord],
        exerciseCompletions: [ExerciseCompletion],
        journalEntries: [JournalEntry],
        guidedJournalEntries: [FlexibleJournalEntry],
        breathingSessions: [BreathingSession],
        plannedActivities: [PlannedActivity],
        calendar: Calendar
    ) -> Set<Date> {
        var dates = Set<Date>()
        for signal in moodSignals {
            dates.insert(calendar.startOfDay(for: signal.createdAt))
        }
        for record in thoughtRecords {
            dates.insert(calendar.startOfDay(for: record.createdAt))
        }
        for completion in exerciseCompletions {
            dates.insert(calendar.startOfDay(for: completion.createdAt))
        }
        for entry in journalEntries {
            dates.insert(calendar.startOfDay(for: entry.createdAt))
        }
        for entry in guidedJournalEntries {
            dates.insert(calendar.startOfDay(for: entry.date))
        }
        for session in breathingSessions {
            dates.insert(calendar.startOfDay(for: session.createdAt))
        }
        for activity in plannedActivities {
            dates.insert(calendar.startOfDay(for: activity.createdAt))
            if let completedAt = activity.completedAt {
                dates.insert(calendar.startOfDay(for: completedAt))
            }
        }
        return dates
    }

    private func currentStreak(from activeDays: Set<Date>, today: Date, calendar: Calendar) -> Int {
        guard !activeDays.isEmpty else { return 0 }

        let sortedDays = activeDays.sorted()
        guard let lastActiveDay = sortedDays.last else { return 0 }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        guard lastActiveDay == today || lastActiveDay == yesterday else { return 0 }

        var streak = 1
        var cursor = lastActiveDay

        while let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor),
              activeDays.contains(previousDay) {
            streak += 1
            cursor = previousDay
        }

        return streak
    }

    private func isDate(_ date: Date, inSameDayAs dayStart: Date, calendar: Calendar) -> Bool {
        calendar.isDate(date, inSameDayAs: dayStart)
    }

    private func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        from context: ModelContext,
        label: StaticString
    ) -> [T] {
        do {
            var descriptor = descriptor
            descriptor.includePendingChanges = false
            return try context.fetch(descriptor)
        } catch {
            Self.logger.error("Recommendation fetch failed label=\(label) error=\(error.localizedDescription, privacy: .private)")
            return []
        }
    }
}
