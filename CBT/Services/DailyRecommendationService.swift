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

nonisolated enum DailyPlanMode: String, CaseIterable, Hashable, Sendable, Codable {
    case full
    case quick
    case lowEnergy

    var title: String {
        switch self {
        case .full: return "Full"
        case .quick: return "Quick"
        case .lowEnergy: return "Low Energy"
        }
    }
}

nonisolated struct AdaptiveDifficultySelector: Sendable {
    static func selectMode(
        latestMoodScore: Int?,
        latestEnergyScore: Int?,
        latestStressScore: Int?,
        missedDays: Int?,
        recentEngagementCount: Int
    ) -> DailyPlanMode {
        let mood = latestMoodScore ?? 5
        let recentLowEngagement = recentEngagementCount <= 1 || (missedDays ?? 0) >= 2

        if latestEnergyScore.map({ $0 <= 3 }) == true ||
            latestStressScore.map({ $0 >= 8 }) == true ||
            mood <= 3 {
            return .lowEnergy
        }

        if latestEnergyScore.map({ $0 <= 5 }) == true ||
            latestStressScore.map({ $0 >= 6 }) == true ||
            recentLowEngagement {
            return .quick
        }

        return .full
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
    case weeklyReview
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
        case .weeklyReview:
            return "cbt://insights/weekly-review"
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
    let mode: DailyPlanMode

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
        if destination == .weeklyReview {
            return nil
        }

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
        if mode == .lowEnergy {
            return "Under 1 min"
        }
        return estimatedDurationMinutes == 1 ? "1 min" : "\(estimatedDurationMinutes) min"
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

nonisolated struct DailyPlanMoodSample: Hashable, Sendable {
    let createdAt: Date
    let moodScore: Int
    let intensity: Int?
    let energyScore: Int?
    let stressScore: Int?
    let emotions: [String]
    let triggers: [String]
    let sensations: [String]
    let contextTags: [String]
}

nonisolated struct DailyPlanExerciseSummary: Hashable, Sendable {
    let id: String
    let title: String
    let category: String
    let duration: Int
    let description: String
    let isCompletedToday: Bool
}

nonisolated struct DailyPlanUserPreferences: Hashable, Sendable {
    let goals: Set<String>
    let interests: Set<String>
    let feedbackScores: [String: Int]
    let lighterPlanUntil: Date?
    let preferredSessionLength: String?
    let preferredDaypart: String?
    let commonTriggers: Set<String>
    let helpfulInterventions: Set<String>

    static let empty = DailyPlanUserPreferences(
        goals: [],
        interests: [],
        feedbackScores: [:],
        lighterPlanUntil: nil,
        preferredSessionLength: nil,
        preferredDaypart: nil,
        commonTriggers: [],
        helpfulInterventions: []
    )

    init(
        goals: Set<String>,
        interests: Set<String>,
        feedbackScores: [String: Int] = [:],
        lighterPlanUntil: Date? = nil,
        preferredSessionLength: String? = nil,
        preferredDaypart: String? = nil,
        commonTriggers: Set<String> = [],
        helpfulInterventions: Set<String> = []
    ) {
        self.goals = goals
        self.interests = interests
        self.feedbackScores = feedbackScores
        self.lighterPlanUntil = lighterPlanUntil
        self.preferredSessionLength = preferredSessionLength
        self.preferredDaypart = preferredDaypart
        self.commonTriggers = commonTriggers
        self.helpfulInterventions = helpfulInterventions
    }

    func feedbackScore(for type: DailyRecommendationType) -> Int {
        feedbackScores[type.rawValue] ?? 0
    }

    func prefersLighterPlan(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let lighterPlanUntil else { return false }
        return lighterPlanUntil >= calendar.startOfDay(for: date)
    }
}

nonisolated struct DailyPlanRecommendationInput: Hashable, Sendable {
    let today: Date
    let now: Date
    let moodSamples: [DailyPlanMoodSample]
    let thoughtRecordDistortions: [String]
    let missedDays: Int?
    let currentStreak: Int
    let hasMoodToday: Bool
    let hasThoughtRecordToday: Bool
    let hasBreathingToday: Bool
    let hasActivityCompletedToday: Bool
    let incompleteExercise: DailyPlanExerciseSummary?
    let completedExerciseIDs: Set<String>
    let exercises: [DailyPlanExerciseSummary]
    let preferences: DailyPlanUserPreferences
    let hasAnyUserData: Bool
    let recentEngagementCount: Int
    let helpfulnessScores: [DailyRecommendationType: Double]

    init(
        today: Date,
        now: Date,
        moodSamples: [DailyPlanMoodSample],
        thoughtRecordDistortions: [String],
        missedDays: Int?,
        currentStreak: Int,
        hasMoodToday: Bool,
        hasThoughtRecordToday: Bool,
        hasBreathingToday: Bool,
        hasActivityCompletedToday: Bool,
        incompleteExercise: DailyPlanExerciseSummary?,
        completedExerciseIDs: Set<String>,
        exercises: [DailyPlanExerciseSummary],
        preferences: DailyPlanUserPreferences,
        hasAnyUserData: Bool,
        recentEngagementCount: Int,
        helpfulnessScores: [DailyRecommendationType: Double] = [:],
        dailyPlanCompletions: [DailyPlanCompletion] = []
    ) {
        self.today = today
        self.now = now
        self.moodSamples = moodSamples
        self.thoughtRecordDistortions = thoughtRecordDistortions
        self.missedDays = missedDays
        self.currentStreak = currentStreak
        self.hasMoodToday = hasMoodToday
        self.hasThoughtRecordToday = hasThoughtRecordToday
        self.hasBreathingToday = hasBreathingToday
        self.hasActivityCompletedToday = hasActivityCompletedToday
        self.incompleteExercise = incompleteExercise
        self.completedExerciseIDs = completedExerciseIDs
        self.exercises = exercises
        self.preferences = preferences
        self.hasAnyUserData = hasAnyUserData
        self.recentEngagementCount = recentEngagementCount
        self.helpfulnessScores = helpfulnessScores
    }
}

nonisolated struct DailyPlanRecommendationEngine: Sendable {
    func recommendations(from input: DailyPlanRecommendationInput) -> [DailyRecommendation] {
        if !input.hasAnyUserData {
            return onboardingStarterPlan(input).map { adaptedRecommendation($0, for: input) }
        }

        var recommendations = [DailyRecommendationType: DailyRecommendation]()

        if let unfinished = input.incompleteExercise {
            upsert(
                recommendation(
                    type: .libraryExercise,
                    title: "Continue Where You Left Off",
                    subtitle: unfinished.title,
                    reason: "Because an exercise is still unfinished.",
                    destination: .libraryExercise(exerciseID: unfinished.id),
                    priority: 106,
                    duration: unfinished.duration,
                    isCompletedToday: unfinished.isCompletedToday
                ),
                into: &recommendations
            )
        }

        if input.missedDays == 1 {
            upsert(
                recommendation(
                    type: .moodCheckIn,
                    title: "Restart Gently",
                    subtitle: "Yesterday can stay yesterday. Check in with today.",
                    reason: "Because you only missed yesterday, and one light check-in restarts the rhythm.",
                    destination: .moodCheckIn,
                    priority: 100,
                    duration: 1,
                    isCompletedToday: input.hasMoodToday
                ),
                into: &recommendations
            )
        } else if (input.missedDays ?? 0) >= 2 {
            upsert(
                recommendation(
                    type: .moodCheckIn,
                    title: "Gentle Restart",
                    subtitle: "Start again with one light check-in.",
                    reason: "Because it has been \(input.missedDays ?? 2) days since your last check-in.",
                    destination: .moodCheckIn,
                    priority: 100,
                    duration: 1,
                    isCompletedToday: input.hasMoodToday
                ),
                into: &recommendations
            )
            upsert(
                recommendation(
                    type: .breathingReset,
                    title: "Bad Day Mode Reset",
                    subtitle: "One steady minute, no pressure.",
                    reason: "Because a gentle restart works best when the first step is small.",
                    destination: .breathingReset(durationSeconds: 60),
                    priority: 92,
                    duration: 1,
                    isCompletedToday: input.hasBreathingToday
                ),
                into: &recommendations
            )
        }

        if highStressTrend(in: input) {
            let reason = input.moodSamples.first.map { sample in
                Calendar.current.isDateInYesterday(sample.createdAt)
                    ? "Because stress was high yesterday."
                    : "Because recent stress or anxiety has been high."
            } ?? "Because recent stress or anxiety has been high."
            upsert(
                recommendation(
                    type: .breathingReset,
                    title: "Breathing Reset",
                    subtitle: "Lower the stress signal first.",
                    reason: reason,
                    destination: .breathingReset(durationSeconds: 120),
                    priority: 96,
                    duration: 2,
                    isCompletedToday: input.hasBreathingToday
                ),
                into: &recommendations
            )
            if let exercise = firstExercise(matching: ["Grounding", "Anxiety Reset", "Distress Tolerance"], in: input) {
                upsert(
                    recommendation(
                        type: .libraryExercise,
                        title: exercise.title,
                        subtitle: exercise.description,
                        reason: "Because grounding can help when anxiety or stress is elevated.",
                        destination: .libraryExercise(exerciseID: exercise.id),
                        priority: 88,
                        duration: exercise.duration,
                        isCompletedToday: exercise.isCompletedToday
                    ),
                    into: &recommendations
                )
            }
        }

        if lowMoodTrend(in: input), let exercise = firstExercise(matching: ["Behavioral Activation", "Self Compassion", "Gratitude"], in: input) {
            upsert(
                recommendation(
                    type: .behavioralActivation,
                    title: "Tiny Win",
                    subtitle: "Choose one small nourishing action.",
                    reason: "Because recent mood has been low.",
                    destination: .behavioralActivation,
                    priority: 90,
                    duration: 5,
                    isCompletedToday: input.hasActivityCompletedToday
                ),
                into: &recommendations
            )
            upsert(
                recommendation(
                    type: .libraryExercise,
                    title: exercise.title,
                    subtitle: exercise.description,
                    reason: "Because low energy responds better to small, doable steps.",
                    destination: .libraryExercise(exerciseID: exercise.id),
                    priority: 82,
                    duration: exercise.duration,
                    isCompletedToday: exercise.isCompletedToday
                ),
                into: &recommendations
            )
        }

        if let trigger = repeatedTrigger(in: input), let exercise = exerciseFor(trigger: trigger, in: input) {
            upsert(
                recommendation(
                    type: .libraryExercise,
                    title: exercise.title,
                    subtitle: exercise.description,
                    reason: "Because \(trigger) has shown up repeatedly in recent check-ins.",
                    destination: .libraryExercise(exerciseID: exercise.id),
                    priority: 86,
                    duration: exercise.duration,
                    isCompletedToday: exercise.isCompletedToday
                ),
                into: &recommendations
            )
        }

        if let distortion = mostFrequent(input.thoughtRecordDistortions), !input.hasThoughtRecordToday {
            upsert(
                recommendation(
                    type: .thoughtRecord,
                    title: "Thought Record",
                    subtitle: "Work through one automatic thought.",
                    reason: "Because you recently logged \(distortion).",
                    destination: .thoughtRecord,
                    priority: 78,
                    duration: 8,
                    isCompletedToday: input.hasThoughtRecordToday
                ),
                into: &recommendations
            )
        }

        if input.currentStreak > 0, !input.hasMoodToday {
            upsert(
                recommendation(
                    type: .moodCheckIn,
                    title: "Keep Your Streak Going",
                    subtitle: "A quick check-in counts as today’s practice.",
                    reason: "Because your current streak is \(input.currentStreak) \(input.currentStreak == 1 ? "day" : "days").",
                    destination: .moodCheckIn,
                    priority: 84,
                    duration: 1,
                    isCompletedToday: input.hasMoodToday
                ),
                into: &recommendations
            )
        }

        addPreferenceRecommendation(from: input, into: &recommendations)
        addFallbacks(from: input, into: &recommendations)

        let personalizedLimit = input.preferences.prefersLighterPlan(on: input.today) ||
            input.preferences.preferredSessionLength == DailyPlanSessionLength.quick.rawValue ? 2 : 4
        return recommendations.values
            .sorted { lhs, rhs in
                let lhsScore = bestNextStepScore(for: lhs, input: input)
                let rhsScore = bestNextStepScore(for: rhs, input: input)
                if lhsScore == rhsScore {
                    return lhs.title < rhs.title
                }
                return lhsScore > rhsScore
            }
            .prefix(personalizedLimit)
            .map { adaptedRecommendation($0, for: input) }
    }

    func selectedMode(from input: DailyPlanRecommendationInput) -> DailyPlanMode {
        let latest = input.moodSamples.first
        return AdaptiveDifficultySelector.selectMode(
            latestMoodScore: latest?.moodScore,
            latestEnergyScore: latest?.energyScore,
            latestStressScore: latest?.stressScore ?? latest?.intensity,
            missedDays: input.missedDays,
            recentEngagementCount: input.recentEngagementCount
        )
    }

    private func adaptedRecommendation(
        _ recommendation: DailyRecommendation,
        for input: DailyPlanRecommendationInput
    ) -> DailyRecommendation {
        switch selectedMode(from: input) {
        case .full:
            return recommendation.with(mode: .full)
        case .quick:
            return quickVariant(of: recommendation)
        case .lowEnergy:
            return lowEnergyVariant(of: recommendation)
        }
    }

    private func quickVariant(of recommendation: DailyRecommendation) -> DailyRecommendation {
        switch recommendation.type {
        case .thoughtRecord:
            return recommendation.with(
                title: "Quick Thought Check",
                subtitle: "Name one thought and one kinder alternative.",
                priority: recommendation.priority + 4,
                duration: min(recommendation.estimatedDurationMinutes, 3),
                mode: .quick
            )
        case .libraryExercise, .courseLesson:
            return recommendation.with(
                subtitle: "Use the shortest useful version.",
                duration: min(recommendation.estimatedDurationMinutes, 3),
                mode: .quick
            )
        case .behavioralActivation:
            return recommendation.with(
                title: "Quick Tiny Win",
                subtitle: "Pick one small action you can start now.",
                duration: 2,
                mode: .quick
            )
        case .breathingReset, .sleepWindDown:
            return recommendation.with(
                destination: .breathingReset(durationSeconds: 60),
                duration: 1,
                mode: .quick
            )
        default:
            return recommendation.with(mode: .quick)
        }
    }

    private func lowEnergyVariant(of recommendation: DailyRecommendation) -> DailyRecommendation {
        switch recommendation.type {
        case .breathingReset, .sleepWindDown:
            return recommendation.with(
                title: "Low Energy Reset",
                subtitle: "One gentle minute. Stop when you need to.",
                destination: .breathingReset(durationSeconds: 45),
                priority: recommendation.priority + 8,
                duration: 1,
                mode: .lowEnergy
            )
        case .moodCheckIn:
            return recommendation.with(
                title: "One-Tap Check-In",
                subtitle: "Just name the basics for right now.",
                duration: 1,
                mode: .lowEnergy
            )
        case .behavioralActivation:
            return recommendation.with(
                title: "Low Energy Tiny Win",
                subtitle: "Do one step that takes less than a minute.",
                priority: recommendation.priority + 4,
                duration: 1,
                mode: .lowEnergy
            )
        case .thoughtRecord:
            return recommendation.with(
                title: "Name One Thought",
                subtitle: "Write one sentence. That counts.",
                duration: 1,
                mode: .lowEnergy
            )
        case .guidedJournal:
            return recommendation.with(
                title: "One-Line Journal",
                subtitle: "One sentence is enough for today.",
                duration: 1,
                mode: .lowEnergy
            )
        case .libraryExercise, .courseLesson:
            return recommendation.with(
                subtitle: "Try only the first small step.",
                duration: 1,
                mode: .lowEnergy
            )
        case .safetySupport:
            return recommendation.with(mode: .lowEnergy)
        }
    }

    private func onboardingStarterPlan(_ input: DailyPlanRecommendationInput) -> [DailyRecommendation] {
        [
            recommendation(
                type: .moodCheckIn,
                title: "Mood Check-In",
                subtitle: "Start with one gentle check-in.",
                reason: "Because there is no Daily Plan history yet.",
                destination: .moodCheckIn,
                priority: 82,
                duration: 1,
                isCompletedToday: input.hasMoodToday
            ),
            recommendation(
                type: .breathingReset,
                title: "3-Minute Breathing",
                subtitle: "A short reset before anything deeper.",
                reason: "Because breathing is an easy first practice with no setup.",
                destination: .breathingReset(durationSeconds: 180),
                priority: 78,
                duration: 3,
                isCompletedToday: input.hasBreathingToday
            ),
            recommendation(
                type: .courseLesson,
                title: "Intro to CBT Course",
                subtitle: "Learn the basics at your own pace.",
                reason: "Because a quick orientation makes the tools easier to use.",
                destination: .introToCBT,
                priority: 72,
                duration: 4,
                isCompletedToday: false
            )
        ]
    }

    private func addFallbacks(
        from input: DailyPlanRecommendationInput,
        into recommendations: inout [DailyRecommendationType: DailyRecommendation]
    ) {
        if !input.hasMoodToday {
            upsert(
                recommendation(
                    type: .moodCheckIn,
                    title: "Mood Check-In",
                    subtitle: "Capture how you feel right now.",
                    reason: "Because a check-in gives today a starting point.",
                    destination: .moodCheckIn,
                    priority: 60,
                    duration: 1,
                    isCompletedToday: false
                ),
                into: &recommendations
            )
        }

        if !input.hasBreathingToday {
            upsert(
                recommendation(
                    type: .breathingReset,
                    title: "Breathing Reset",
                    subtitle: "Take one minute to slow the pace.",
                    reason: "Because a short reset is available whenever you want one.",
                    destination: .breathingReset(durationSeconds: 60),
                    priority: 54,
                    duration: 1,
                    isCompletedToday: false
                ),
                into: &recommendations
            )
        }

        if !input.hasThoughtRecordToday {
            upsert(
                recommendation(
                    type: .thoughtRecord,
                    title: "Thought Record",
                    subtitle: "Work through one automatic thought.",
                    reason: "Because no thought record has been logged today.",
                    destination: .thoughtRecord,
                    priority: 50,
                    duration: 8,
                    isCompletedToday: false
                ),
                into: &recommendations
            )
        }

        if recommendations.count < 2, !input.hasActivityCompletedToday {
            upsert(
                recommendation(
                    type: .behavioralActivation,
                    title: "Plan One Small Activity",
                    subtitle: "Pick a small nourishing or mastery task.",
                    reason: "Because a concrete activity gives the day a reachable next step.",
                    destination: .behavioralActivation,
                    priority: 46,
                    duration: 5,
                    isCompletedToday: false
                ),
                into: &recommendations
            )
        }
    }

    private func bestNextStepScore(
        for recommendation: DailyRecommendation,
        input: DailyPlanRecommendationInput
    ) -> Int {
        var score = recommendation.priority
        let hour = Calendar.current.component(.hour, from: input.now)
        let preferenceScore = input.preferences.feedbackScore(for: recommendation.type)
        score += max(-24, min(24, preferenceScore * 8))

        if recommendation.isCompletedToday {
            score -= 200
        }

        if input.incompleteExercise?.id == destinationExerciseID(for: recommendation.destination) {
            score += 24
        }

        if let helpfulnessScore = input.helpfulnessScores[recommendation.type] {
            score += Int((helpfulnessScore * 18).rounded())
        }

        if !input.hasMoodToday && recommendation.type == .moodCheckIn {
            score += (input.missedDays ?? 0) > 0 ? 30 : 18
        }

        if hour < 11 {
            switch recommendation.type {
            case .moodCheckIn, .behavioralActivation:
                score += 8
            default:
                break
            }
        } else if hour >= 20 {
            switch recommendation.type {
            case .breathingReset, .sleepWindDown, .guidedJournal:
                score += 10
            case .thoughtRecord:
                score += 4
            default:
                break
            }
        }

        if selectedMode(from: input) == .lowEnergy {
            switch recommendation.type {
            case .breathingReset, .moodCheckIn, .behavioralActivation:
                score += 10
            case .courseLesson:
                score -= 8
            default:
                break
            }
        }

        if input.preferences.prefersLighterPlan(on: input.today) {
            score -= max(0, recommendation.estimatedDurationMinutes - 1) * 4
            if recommendation.type == .moodCheckIn || recommendation.type == .breathingReset {
                score += 10
            }
        }

        if let preferredDaypart = DailyPlanDaypart(rawValue: input.preferences.preferredDaypart ?? ""),
           isPreferredDaypart(preferredDaypart, hour: hour) {
            score += 8
        }

        if input.preferences.helpfulInterventions.contains(interventionID(for: recommendation.type)) {
            score += 12
        }

        switch DailyPlanSessionLength(rawValue: input.preferences.preferredSessionLength ?? "") {
        case .quick:
            score -= max(0, recommendation.estimatedDurationMinutes - 3) * 5
        case .standard:
            if (4...8).contains(recommendation.estimatedDurationMinutes) {
                score += 6
            }
        case .deeper:
            if recommendation.estimatedDurationMinutes >= 6 {
                score += 8
            }
        case nil:
            break
        }

        return score
    }

    private func destinationExerciseID(for destination: DailyRecommendationDestination) -> String? {
        if case .libraryExercise(let exerciseID) = destination {
            return exerciseID
        }
        return nil
    }

    private func addPreferenceRecommendation(
        from input: DailyPlanRecommendationInput,
        into recommendations: inout [DailyRecommendationType: DailyRecommendation]
    ) {
        if input.preferences.interests.contains(DailyPlanInterest.breathing.rawValue), !input.hasBreathingToday {
            upsert(
                recommendation(
                    type: .breathingReset,
                    title: "Breathing Reset",
                    subtitle: "Use your preferred quick reset.",
                    reason: "Because breathing is one of your Daily Plan interests.",
                    destination: .breathingReset(durationSeconds: 60),
                    priority: 70,
                    duration: 1,
                    isCompletedToday: false
                ),
                into: &recommendations
            )
        }

        if input.preferences.feedbackScore(for: .breathingReset) >= 2, !input.hasBreathingToday {
            upsert(
                recommendation(
                    type: .breathingReset,
                    title: "Breathing Reset",
                    subtitle: "Use the reset that tends to work for you.",
                    reason: "Because you marked breathing as helpful before.",
                    destination: .breathingReset(durationSeconds: 60),
                    priority: 74,
                    duration: 1,
                    isCompletedToday: false
                ),
                into: &recommendations
            )
        }

        if input.preferences.goals.contains(DailyPlanGoal.understandThoughts.rawValue), !input.hasThoughtRecordToday {
            upsert(
                recommendation(
                    type: .thoughtRecord,
                    title: "Thought Record",
                    subtitle: "Make one thought easier to inspect.",
                    reason: "Because understanding thoughts is one of your Daily Plan goals.",
                    destination: .thoughtRecord,
                    priority: 68,
                    duration: 8,
                    isCompletedToday: false
                ),
                into: &recommendations
            )
        }

        if input.preferences.feedbackScore(for: .guidedJournal) >= 2 {
            upsert(
                recommendation(
                    type: .guidedJournal,
                    title: "Guided Journal",
                    subtitle: "Use reflection because it has helped before.",
                    reason: "Because you marked journaling as helpful before.",
                    destination: .guidedJournal(kind: "daily_reflection"),
                    priority: 66,
                    duration: 4,
                    isCompletedToday: false
                ),
                into: &recommendations
            )
        }

        addHelpfulInterventionRecommendations(from: input, into: &recommendations)
        addCommonTriggerRecommendations(from: input, into: &recommendations)
    }

    private func addHelpfulInterventionRecommendations(
        from input: DailyPlanRecommendationInput,
        into recommendations: inout [DailyRecommendationType: DailyRecommendation]
    ) {
        if input.preferences.helpfulInterventions.contains(DailyPlanHelpfulIntervention.breathing.rawValue), !input.hasBreathingToday {
            upsert(
                recommendation(
                    type: .breathingReset,
                    title: "Preferred Reset",
                    subtitle: "Use a tool that has helped before.",
                    reason: "Because breathing is one of the supports that helps you.",
                    destination: .breathingReset(durationSeconds: 60),
                    priority: 76,
                    duration: 1,
                    isCompletedToday: false
                ),
                into: &recommendations
            )
        }

        if input.preferences.helpfulInterventions.contains(DailyPlanHelpfulIntervention.thoughtRecord.rawValue), !input.hasThoughtRecordToday {
            upsert(
                recommendation(
                    type: .thoughtRecord,
                    title: "Helpful Thought Check",
                    subtitle: "Use the kind of support that has worked for you.",
                    reason: "Because thought checks are one of the supports that helps you.",
                    destination: .thoughtRecord,
                    priority: 74,
                    duration: 6,
                    isCompletedToday: false
                ),
                into: &recommendations
            )
        }

        if input.preferences.helpfulInterventions.contains(DailyPlanHelpfulIntervention.activity.rawValue), !input.hasActivityCompletedToday {
            upsert(
                recommendation(
                    type: .behavioralActivation,
                    title: "Helpful Tiny Action",
                    subtitle: "Repeat a small action-based support.",
                    reason: "Because tiny actions are one of the supports that helps you.",
                    destination: .behavioralActivation,
                    priority: 72,
                    duration: 3,
                    isCompletedToday: false
                ),
                into: &recommendations
            )
        }

        if input.preferences.helpfulInterventions.contains(DailyPlanHelpfulIntervention.journaling.rawValue) {
            upsert(
                recommendation(
                    type: .guidedJournal,
                    title: "Helpful Journal Prompt",
                    subtitle: "Give the pattern a few lines.",
                    reason: "Because journaling is one of the supports that helps you.",
                    destination: .guidedJournal(kind: "open"),
                    priority: 70,
                    duration: 4,
                    isCompletedToday: false
                ),
                into: &recommendations
            )
        }
    }

    private func addCommonTriggerRecommendations(
        from input: DailyPlanRecommendationInput,
        into recommendations: inout [DailyRecommendationType: DailyRecommendation]
    ) {
        for trigger in input.preferences.commonTriggers {
            guard let dailyPlanTrigger = DailyPlanCommonTrigger(rawValue: trigger),
                  let exercise = exerciseFor(preferredTrigger: dailyPlanTrigger, in: input) else { continue }

            upsert(
                recommendation(
                    type: .libraryExercise,
                    title: exercise.title,
                    subtitle: exercise.description,
                    reason: "Because \(dailyPlanTrigger.title.lowercased()) is a common trigger for you.",
                    destination: .libraryExercise(exerciseID: exercise.id),
                    priority: 73,
                    duration: exercise.duration,
                    isCompletedToday: exercise.isCompletedToday
                ),
                into: &recommendations
            )
        }
    }

    private func highStressTrend(in input: DailyPlanRecommendationInput) -> Bool {
        let recent = Array(input.moodSamples.prefix(5))
        guard !recent.isEmpty else { return false }
        return recent.contains { sample in
            (sample.intensity ?? 0) >= 7 || searchableText(for: sample).containsAny([
                "anxious", "anxiety", "stress", "stressed", "overwhelmed", "panic", "worried", "worry"
            ])
        }
    }

    private func lowMoodTrend(in input: DailyPlanRecommendationInput) -> Bool {
        let recent = Array(input.moodSamples.prefix(3))
        guard !recent.isEmpty else { return false }
        let average = Double(recent.map(\.moodScore).reduce(0, +)) / Double(recent.count)
        return average <= 3.5 || recent.first?.moodScore ?? 10 <= 3
    }

    private func repeatedTrigger(in input: DailyPlanRecommendationInput) -> String? {
        mostFrequent(input.moodSamples.prefix(8).flatMap(\.triggers), minimumCount: 2)
    }

    private func exerciseFor(trigger: String, in input: DailyPlanRecommendationInput) -> DailyPlanExerciseSummary? {
        let lowered = trigger.lowercased()
        if lowered.contains("work") || lowered.contains("school") || lowered.contains("deadline") {
            return firstExercise(matching: ["Thought Reframing", "Cognitive Distortions"], in: input)
        }
        if lowered.contains("sleep") || lowered.contains("tired") {
            return firstExercise(matching: ["Wellness Basics", "Mindfulness"], in: input)
        }
        if lowered.contains("conflict") || lowered.contains("relationship") || lowered.contains("family") {
            return firstExercise(matching: ["Emotion Regulation", "Self Compassion"], in: input)
        }
        return firstExercise(matching: ["Grounding", "Thought Reframing", "Behavioral Activation"], in: input)
    }

    private func firstExercise(matching categories: [String], in input: DailyPlanRecommendationInput) -> DailyPlanExerciseSummary? {
        let matches = categories.flatMap { category in
            input.exercises.filter { $0.category.caseInsensitiveCompare(category) == .orderedSame }
        }
        return matches.first { !input.completedExerciseIDs.contains($0.id) }
            ?? matches.first
            ?? input.exercises.first { !input.completedExerciseIDs.contains($0.id) }
            ?? input.exercises.first
    }

    private func mostFrequent(_ values: [String], minimumCount: Int = 1) -> String? {
        var counts = [String: (display: String, count: Int)]()
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            let current = counts[key] ?? (display: trimmed, count: 0)
            counts[key] = (display: current.display, count: current.count + 1)
        }

        return counts.values
            .filter { $0.count >= minimumCount }
            .sorted {
                if $0.count == $1.count {
                    return $0.display < $1.display
                }
                return $0.count > $1.count
            }
            .first?
            .display
    }

    private func searchableText(for sample: DailyPlanMoodSample) -> String {
        (sample.emotions + sample.triggers + sample.sensations + sample.contextTags)
            .joined(separator: " ")
            .lowercased()
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

    private func recommendation(
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
            isCompletedToday: isCompletedToday,
            mode: .full
        )
    }
}

private extension DailyRecommendation {
    nonisolated func with(
        title: String? = nil,
        subtitle: String? = nil,
        reason: String? = nil,
        destination: DailyRecommendationDestination? = nil,
        priority: Int? = nil,
        duration: Int? = nil,
        mode: DailyPlanMode
    ) -> DailyRecommendation {
        let destination = destination ?? self.destination
        return DailyRecommendation(
            id: "\(type.rawValue)-\(destination.deepLink)-\(mode.rawValue)",
            type: type,
            title: title ?? self.title,
            subtitle: subtitle ?? self.subtitle,
            reason: reason ?? self.reason,
            destination: destination,
            priority: priority ?? self.priority,
            estimatedDurationMinutes: max(1, duration ?? estimatedDurationMinutes),
            isCompletedToday: isCompletedToday,
            mode: mode
        )
    }
}

private extension String {
    nonisolated func containsAny(_ terms: [String]) -> Bool {
        terms.contains { contains($0) }
    }
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

nonisolated enum DailyPlanFeedbackAction: String, Sendable {
    case helped
    case notHelpful
    case tooMuchToday
}

nonisolated struct DailyPlanFeedbackProfile: Codable, Hashable, Sendable {
    var typeScores: [String: Int] = [:]
    var lighterPlanUntil: Date?
    var updatedAt: Date?

    static let empty = DailyPlanFeedbackProfile()
}

@MainActor
struct DailyPlanFeedbackStore {
    static let shared = DailyPlanFeedbackStore()
    static let defaultsKey = "cbt_daily_plan_feedback_profile_v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func profile() -> DailyPlanFeedbackProfile {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let profile = try? JSONDecoder().decode(DailyPlanFeedbackProfile.self, from: data) else {
            return .empty
        }
        return profile
    }

    func preferences(now: Date = Date(), calendar: Calendar = .current) -> DailyPlanUserPreferences {
        let profile = profile()
        return DailyPlanUserPreferences(
            goals: decodedIDs(for: DailyPlanPersonalizationKeys.goals),
            interests: decodedIDs(for: DailyPlanPersonalizationKeys.interests),
            feedbackScores: profile.typeScores,
            lighterPlanUntil: profile.lighterPlanUntil
        )
    }

    func record(_ action: DailyPlanFeedbackAction, for recommendation: DailyRecommendation, now: Date = Date(), calendar: Calendar = .current) {
        var profile = profile()
        profile.updatedAt = now

        switch action {
        case .helped:
            adjustScore(for: recommendation.type, by: 1, in: &profile)
        case .notHelpful:
            adjustScore(for: recommendation.type, by: -1, in: &profile)
        case .tooMuchToday:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            profile.lighterPlanUntil = tomorrow
            adjustScore(for: recommendation.type, by: -1, in: &profile)
        }

        save(profile)
    }

    private func decodedIDs(for key: String) -> Set<String> {
        guard let rawValue = defaults.string(forKey: key), !rawValue.isEmpty else {
            return []
        }
        return Set(rawValue.split(separator: ",").map(String.init))
    }

    private func adjustScore(for type: DailyRecommendationType, by delta: Int, in profile: inout DailyPlanFeedbackProfile) {
        let current = profile.typeScores[type.rawValue] ?? 0
        profile.typeScores[type.rawValue] = max(-3, min(3, current + delta))
    }

    private func save(_ profile: DailyPlanFeedbackProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
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
                        title: "Open your rough patch plan",
                        subtitle: "Keep support steps and trusted people close.",
                        reason: "Coping resources should stay reachable whenever mood is very low.",
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
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now

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
        let dailyPlanCompletions = fetch(
            FetchDescriptor<DailyPlanCompletion>(
                predicate: #Predicate<DailyPlanCompletion> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\DailyPlanCompletion.completedAt, order: .reverse)]
            ),
            from: context,
            label: "dailyPlanCompletions"
        )
        let helpfulnessFeedback = fetch(
            FetchDescriptor<HelpfulnessFeedback>(
                predicate: #Predicate<HelpfulnessFeedback> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\HelpfulnessFeedback.createdAt, order: .reverse)]
            ),
            from: context,
            label: "helpfulnessFeedback"
        )

        let moodSignals = makeMoodSignals(moodEntries: moodEntries, moodCheckIns: moodCheckIns)
        let latestMood = moodSignals.first
        let dailyPlanCompletionsToday = dailyPlanCompletions.filter { $0.date >= dayStart && $0.date < dayEnd }
        let dailyPlanTypesToday = Set(dailyPlanCompletionsToday.map(\.itemType))
        let hasMoodToday = moodSignals.contains { isDate($0.createdAt, inSameDayAs: dayStart, calendar: calendar) } ||
            dailyPlanTypesToday.contains(DailyPlanCompletionItemType.moodCheckIn.rawValue)
        let hasThoughtToday = thoughtRecords.contains { $0.createdAt >= dayStart && $0.createdAt < dayEnd } ||
            dailyPlanTypesToday.contains(DailyPlanCompletionItemType.thoughtRecord.rawValue)
        let hasBreathingToday = breathingSessions.contains { $0.createdAt >= dayStart && $0.createdAt < dayEnd } ||
            journalEntries.contains { $0.sourceKind == SessionSourceKind.breathing.rawValue && $0.createdAt >= dayStart && $0.createdAt < dayEnd } ||
            dailyPlanTypesToday.contains(DailyPlanCompletionItemType.breathingReset.rawValue)
        let hasActivityCompletedToday = plannedActivities.contains {
            $0.isCompleted && (($0.completedAt ?? $0.scheduledDate) >= dayStart) && (($0.completedAt ?? $0.scheduledDate) < dayEnd)
        } || dailyPlanTypesToday.contains(DailyPlanCompletionItemType.activityPlanner.rawValue) ||
            dailyPlanTypesToday.contains(DailyPlanCompletionItemType.quickAction.rawValue)
        let activeDates = activeDays(
            moodSignals: moodSignals,
            thoughtRecords: thoughtRecords,
            exerciseCompletions: exerciseCompletions,
            journalEntries: journalEntries,
            guidedJournalEntries: guidedJournalEntries,
            breathingSessions: breathingSessions,
            plannedActivities: plannedActivities,
            dailyPlanCompletions: dailyPlanCompletions,
            calendar: calendar
        )
        let currentStreak = currentStreak(from: activeDates, today: todayStart, calendar: calendar)
        let missedCheckInDays = daysSinceLatestMood(latestMood, dayStart: dayStart, calendar: calendar)
        let completedExerciseIDs = Set(exerciseCompletions.map(\.exerciseID))

        let hasNoUserData = hasNoUserData(
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
            achievements: achievements,
            dailyPlanCompletions: dailyPlanCompletions
        )

        let engineInput = DailyPlanRecommendationInput(
            today: dayStart,
            now: now,
            moodSamples: makeDailyPlanMoodSamples(moodEntries: moodEntries, moodCheckIns: moodCheckIns),
            thoughtRecordDistortions: thoughtRecords
                .filter { $0.createdAt >= fourteenDaysAgo }
                .flatMap(\.distortions),
            missedDays: missedCheckInDays,
            currentStreak: currentStreak,
            hasMoodToday: hasMoodToday,
            hasThoughtRecordToday: hasThoughtToday,
            hasBreathingToday: hasBreathingToday,
            hasActivityCompletedToday: hasActivityCompletedToday,
            incompleteExercise: unfinishedCourseExercise(
                courses: courses,
                libraryItems: libraryItems,
                exerciseCompletions: exerciseCompletions,
                dayStart: dayStart,
                dayEnd: dayEnd
            ),
            completedExerciseIDs: completedExerciseIDs,
            exercises: ExerciseService.shared.exercises.map { exercise in
                makeExerciseSummary(
                    exercise,
                    exerciseCompletions: exerciseCompletions,
                    dailyPlanCompletions: dailyPlanCompletionsToday,
                    dayStart: dayStart,
                    dayEnd: dayEnd
                )
            },
            preferences: DailyPlanFeedbackStore.shared.preferences(now: now, calendar: calendar),
            hasAnyUserData: !hasNoUserData,
            recentEngagementCount: activeDates.filter { $0 >= sevenDaysAgo }.count,
            helpfulnessScores: HelpfulnessFeedbackService.shared.recommendationScores(
                from: helpfulnessFeedback,
                since: fourteenDaysAgo
            )
        )

        return DailyPlanRecommendationEngine().recommendations(from: engineInput)
    }

    func primaryRecommendations(
        from context: ModelContext,
        lastOpenedAt: Date? = nil,
        now: Date = Date()
    ) -> [DailyRecommendation] {
        FirstSevenDaysJourneyService.shared.ensureStartedForNewUserIfNeeded(in: context, now: now)
        let journeyStatus = FirstSevenDaysJourneyService.shared.status(from: context, now: now)
        let journeyRecommendation = FirstSevenDaysJourneyService.shared.recommendation(for: journeyStatus)
        let baseRecommendations = recommendations(for: now, in: context, now: now, lastOpenedAt: lastOpenedAt)

        return ([journeyRecommendation].compactMap { $0 } + baseRecommendations)
            .reduce(into: [String: DailyRecommendation]()) { result, recommendation in
                result[recommendation.id] = recommendation
            }
            .values
            .sorted {
                if $0.priority == $1.priority {
                    return $0.title < $1.title
                }
                return $0.priority > $1.priority
            }
            .prefix(4)
            .map { $0 }
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
            isCompletedToday: isCompletedToday,
            mode: .full
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
                title: "Open Rough Patch Plan",
                subtitle: "Review support steps and trusted people.",
                reason: "Coping resources stay available when mood is very low.",
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
        achievements: [Achievement],
        dailyPlanCompletions: [DailyPlanCompletion]
    ) -> Bool {
        moodSignals.isEmpty &&
            thoughtRecords.isEmpty &&
            exerciseCompletions.isEmpty &&
            journalEntries.isEmpty &&
            guidedJournalEntries.isEmpty &&
            breathingSessions.isEmpty &&
            plannedActivities.isEmpty &&
            dailyPlanCompletions.isEmpty &&
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
                    subtitle: kind == .morningIntentions ? "Set one direction for the day." : "Name one win, one hard thing, and tomorrow's anchor.",
                    reason: "A guided prompt can make reflection easier to start.",
                    destination: .guidedJournal(kind: kind.rawValue),
                    priority: 46,
                    duration: kind == .morningIntentions ? 3 : 2,
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

    private func makeDailyPlanMoodSamples(
        moodEntries: [MoodEntry],
        moodCheckIns: [MoodCheckIn]
    ) -> [DailyPlanMoodSample] {
        let entrySamples = moodEntries.map { entry in
            DailyPlanMoodSample(
                createdAt: entry.createdAt,
                moodScore: entry.moodScore,
                intensity: entry.intensity,
                energyScore: entry.energyScore,
                stressScore: entry.anxietyStressScore,
                emotions: entry.emotions,
                triggers: entry.triggers,
                sensations: entry.sensations,
                contextTags: entry.contextTags
            )
        }
        let checkInSamples = moodCheckIns.map { checkIn in
            DailyPlanMoodSample(
                createdAt: checkIn.createdAt,
                moodScore: checkIn.moodScore,
                intensity: nil,
                energyScore: nil,
                stressScore: nil,
                emotions: [],
                triggers: [],
                sensations: [],
                contextTags: []
            )
        }

        return (entrySamples + checkInSamples).sorted { $0.createdAt > $1.createdAt }
    }

    private func makeExerciseSummary(
        _ exercise: Exercise,
        exerciseCompletions: [ExerciseCompletion],
        dailyPlanCompletions: [DailyPlanCompletion] = [],
        dayStart: Date,
        dayEnd: Date
    ) -> DailyPlanExerciseSummary {
        let exerciseType = DailyPlanCompletionItemType.exercise.rawValue
        return DailyPlanExerciseSummary(
            id: exercise.id,
            title: exercise.title,
            category: exercise.category,
            duration: exercise.duration,
            description: exercise.description,
            isCompletedToday: exerciseCompletions.contains { completion in
                completion.exerciseID == exercise.id &&
                    completion.createdAt >= dayStart &&
                    completion.createdAt < dayEnd
            } || dailyPlanCompletions.contains { completion in
                completion.itemType == exerciseType &&
                    (completion.itemID == nil || completion.itemID == exercise.id) &&
                    completion.date >= dayStart &&
                    completion.date < dayEnd
            }
        )
    }

    private func unfinishedCourseExercise(
        courses: [Course],
        libraryItems: [LibraryItem],
        exerciseCompletions: [ExerciseCompletion],
        dayStart: Date,
        dayEnd: Date
    ) -> DailyPlanExerciseSummary? {
        let course = courses
            .filter { !$0.isCompleted && !$0.completedItemIDs.isEmpty }
            .sorted {
                if $0.completedItemIDs.count == $1.completedItemIDs.count {
                    return $0.title < $1.title
                }
                return $0.completedItemIDs.count > $1.completedItemIDs.count
            }
            .first

        guard let course else { return nil }
        let orderedItems = course.orderedItems(from: libraryItems)
        guard
            let nextItem = orderedItems.first(where: { !course.completedItemIDs.contains($0.id) }),
            let exercise = LibraryService.shared.exercise(for: nextItem)
        else {
            return nil
        }

        return makeExerciseSummary(
            exercise,
            exerciseCompletions: exerciseCompletions,
            dayStart: dayStart,
            dayEnd: dayEnd
        )
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
        dailyPlanCompletions: [DailyPlanCompletion] = [],
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
        for completion in dailyPlanCompletions {
            dates.insert(calendar.startOfDay(for: completion.date))
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
