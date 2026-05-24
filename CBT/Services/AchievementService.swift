import Foundation
import OSLog
import SwiftData

struct AchievementProgress: Equatable {
    let currentValue: Int
    let targetCount: Int
    let label: String

    var completedValue: Int {
        min(max(currentValue, 0), targetCount)
    }

    var fraction: Double {
        guard targetCount > 0 else { return 0 }
        return min(Double(completedValue) / Double(targetCount), 1)
    }

    var progressText: String {
        "\(completedValue) of \(targetCount) \(label.lowercased())"
    }
}

@MainActor
final class AchievementService {
    static let shared = AchievementService()

    private struct AchievementDefinition {
        let title: String
        let description: String
        let imageName: String
        let unlockCondition: AchievementUnlockCondition
        let targetCount: Int
    }

    private static let logger = AppLogger.make(category: "Achievements")
    private static let weeklyReportViewedKey = "cbt.achievements.weeklyReportViewed"

    private let definitions: [AchievementDefinition] = [
        AchievementDefinition(
            title: "First Step",
            description: "Complete your first CBT exercise.",
            imageName: "figure.mind.and.body",
            unlockCondition: .exercisesCompleted,
            targetCount: 1
        ),
        AchievementDefinition(
            title: "Practice Builder",
            description: "Complete five CBT exercises.",
            imageName: "checkmark.seal.fill",
            unlockCondition: .exercisesCompleted,
            targetCount: 5
        ),
        AchievementDefinition(
            title: "Practice Anchor",
            description: "Complete twenty CBT exercises.",
            imageName: "target",
            unlockCondition: .exercisesCompleted,
            targetCount: 20
        ),
        AchievementDefinition(
            title: "Thought Catcher",
            description: "Save your first thought record.",
            imageName: "brain.head.profile",
            unlockCondition: .thoughtRecordsCount,
            targetCount: 1
        ),
        AchievementDefinition(
            title: "Reframe Rookie",
            description: "Save five thought records.",
            imageName: "lightbulb.fill",
            unlockCondition: .thoughtRecordsCount,
            targetCount: 5
        ),
        AchievementDefinition(
            title: "Pattern Spotter",
            description: "Save ten thought records.",
            imageName: "sparkle.magnifyingglass",
            unlockCondition: .thoughtRecordsCount,
            targetCount: 10
        ),
        AchievementDefinition(
            title: "Deep Reframer",
            description: "Save twenty-five thought records.",
            imageName: "lightbulb.max.fill",
            unlockCondition: .thoughtRecordsCount,
            targetCount: 25
        ),
        AchievementDefinition(
            title: "Three-Day Flame",
            description: "Log activity for three days in a row.",
            imageName: "flame.fill",
            unlockCondition: .streakCount,
            targetCount: 3
        ),
        AchievementDefinition(
            title: "Steady Week",
            description: "Log activity for seven days in a row.",
            imageName: "calendar.badge.checkmark",
            unlockCondition: .streakCount,
            targetCount: 7
        ),
        AchievementDefinition(
            title: "Two-Week Rhythm",
            description: "Log activity for fourteen days in a row.",
            imageName: "calendar.circle.fill",
            unlockCondition: .streakCount,
            targetCount: 14
        ),
        AchievementDefinition(
            title: "Monthly Momentum",
            description: "Log activity for thirty days in a row.",
            imageName: "flame.circle.fill",
            unlockCondition: .streakCount,
            targetCount: 30
        ),
        AchievementDefinition(
            title: "Mood Noted",
            description: "Save your first mood check-in.",
            imageName: "face.smiling",
            unlockCondition: .moodCheckInCount,
            targetCount: 1
        ),
        AchievementDefinition(
            title: "Mood Mapper",
            description: "Save seven mood check-ins.",
            imageName: "chart.line.uptrend.xyaxis",
            unlockCondition: .moodCheckInCount,
            targetCount: 7
        ),
        AchievementDefinition(
            title: "Mood Explorer",
            description: "Save thirty mood check-ins.",
            imageName: "map.fill",
            unlockCondition: .moodCheckInCount,
            targetCount: 30
        ),
        AchievementDefinition(
            title: "Mood Historian",
            description: "Save seventy-five mood check-ins.",
            imageName: "chart.bar.xaxis",
            unlockCondition: .moodCheckInCount,
            targetCount: 75
        ),
        AchievementDefinition(
            title: "First Reflection",
            description: "Complete your first guided journal.",
            imageName: "book.closed.fill",
            unlockCondition: .guidedJournalCount,
            targetCount: 1
        ),
        AchievementDefinition(
            title: "Reflection Rhythm",
            description: "Complete ten guided journals.",
            imageName: "text.book.closed.fill",
            unlockCondition: .guidedJournalCount,
            targetCount: 10
        ),
        AchievementDefinition(
            title: "Reflection Library",
            description: "Complete twenty-five guided journals.",
            imageName: "books.vertical.fill",
            unlockCondition: .guidedJournalCount,
            targetCount: 25
        ),
        AchievementDefinition(
            title: "First Reset",
            description: "Complete your first breathing session.",
            imageName: "wind",
            unlockCondition: .breathingSessionCount,
            targetCount: 1
        ),
        AchievementDefinition(
            title: "Breath Companion",
            description: "Complete ten breathing sessions.",
            imageName: "lungs.fill",
            unlockCondition: .breathingSessionCount,
            targetCount: 10
        ),
        AchievementDefinition(
            title: "Calm Repertoire",
            description: "Complete twenty-five breathing sessions.",
            imageName: "leaf.fill",
            unlockCondition: .breathingSessionCount,
            targetCount: 25
        ),
        AchievementDefinition(
            title: "Course Opener",
            description: "Complete your first course.",
            imageName: "graduationcap.fill",
            unlockCondition: .coursesCompleted,
            targetCount: 1
        ),
        AchievementDefinition(
            title: "Learning Path",
            description: "Complete five courses.",
            imageName: "signpost.right.fill",
            unlockCondition: .coursesCompleted,
            targetCount: 5
        ),
        AchievementDefinition(
            title: "Course Collector",
            description: "Complete ten courses.",
            imageName: "books.vertical.circle.fill",
            unlockCondition: .coursesCompleted,
            targetCount: 10
        ),
        AchievementDefinition(
            title: "Week in View",
            description: "Open your weekly overview for the first time.",
            imageName: "calendar",
            unlockCondition: .weeklyReportViewed,
            targetCount: 1
        ),
        AchievementDefinition(
            title: "Intentional Action",
            description: "Complete your first planned activity.",
            imageName: "figure.walk.motion",
            unlockCondition: .plannedActivitiesCompleted,
            targetCount: 1
        ),
        AchievementDefinition(
            title: "Activity Explorer",
            description: "Complete ten planned activities.",
            imageName: "checklist.checked",
            unlockCondition: .plannedActivitiesCompleted,
            targetCount: 10
        ),
        AchievementDefinition(
            title: "Activity Momentum",
            description: "Complete twenty-five planned activities.",
            imageName: "figure.walk.circle.fill",
            unlockCondition: .plannedActivitiesCompleted,
            targetCount: 25
        ),
        AchievementDefinition(
            title: "Self-Check",
            description: "Complete your first assessment.",
            imageName: "list.clipboard.fill",
            unlockCondition: .assessmentsCompleted,
            targetCount: 1
        ),
        AchievementDefinition(
            title: "Assessment Habit",
            description: "Complete three assessments.",
            imageName: "checklist.checked",
            unlockCondition: .assessmentsCompleted,
            targetCount: 3
        ),
        AchievementDefinition(
            title: "Four-Week Anchor",
            description: "Show up for your care during four different weeks.",
            imageName: "calendar.badge.clock",
            unlockCondition: .activeWeeksCount,
            targetCount: 4
        ),
        AchievementDefinition(
            title: "Eight-Week Thread",
            description: "Show up for your care during eight different weeks.",
            imageName: "calendar.badge.plus",
            unlockCondition: .activeWeeksCount,
            targetCount: 8
        ),
        AchievementDefinition(
            title: "Skill Sampler",
            description: "Try CBT, DBT, ACT, and mindfulness content.",
            imageName: "square.grid.2x2.fill",
            unlockCondition: .contentModalitiesTried,
            targetCount: 4
        )
    ]

    private init() {}

    func evaluateAchievements(in modelContext: ModelContext) {
        do {
            try seedDefaultAchievementsIfNeeded(in: modelContext)

            let achievements = try fetchAchievements(in: modelContext)
            let counts = try achievementCounts(in: modelContext)
            var changed = false

            for achievement in achievements where !achievement.isUnlocked {
                guard let definition = definition(for: achievement) else { continue }
                let currentValue = counts.value(for: definition.unlockCondition)

                if currentValue >= definition.targetCount {
                    achievement.isUnlocked = true
                    achievement.unlockedAt = Date()
                    changed = true
                }
            }

            if changed {
                try modelContext.save()
            }
        } catch {
            Self.logger.error("Failed to evaluate achievements: \(error.localizedDescription, privacy: .private)")
        }
    }

    func progressSnapshots(in modelContext: ModelContext) -> [String: AchievementProgress] {
        do {
            try seedDefaultAchievementsIfNeeded(in: modelContext)
            let counts = try achievementCounts(in: modelContext)

            return Dictionary(
                uniqueKeysWithValues: definitions.map { definition in
                    (
                        definition.title,
                        AchievementProgress(
                            currentValue: counts.value(for: definition.unlockCondition),
                            targetCount: definition.targetCount,
                            label: definition.unlockCondition.progressUnit
                        )
                    )
                }
            )
        } catch {
            Self.logger.error("Failed to load achievement progress: \(error.localizedDescription, privacy: .private)")
            return [:]
        }
    }

    func monthlyBadgeProgress(
        in modelContext: ModelContext,
        for date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> MonthlyBadgeProgress {
        let moodEntries = try modelContext.fetch(FetchDescriptor<MoodEntry>())
            .filter { !$0.isDeleted }
        let moodCheckIns = try modelContext.fetch(FetchDescriptor<MoodCheckIn>())
            .filter { !$0.isDeleted }
        let thoughts = try modelContext.fetch(FetchDescriptor<ThoughtRecord>())
            .filter { !$0.isDeleted }
        let exerciseCompletions = try modelContext.fetch(FetchDescriptor<ExerciseCompletion>())
            .filter { !$0.isDeleted }
        let journals = try modelContext.fetch(FetchDescriptor<JournalEntry>())
            .filter { !$0.isDeleted }
        let flexibleJournals = try modelContext.fetch(FetchDescriptor<FlexibleJournalEntry>())
        let breathingSessions = try modelContext.fetch(FetchDescriptor<BreathingSession>())
            .filter { !$0.isDeleted }
        let plannedActivities = try modelContext.fetch(FetchDescriptor<PlannedActivity>())
            .filter { !$0.isDeleted && $0.isCompleted }
        let courses = try modelContext.fetch(FetchDescriptor<Course>())

        let snapshot = MonthlyBadgeActivitySnapshot(
            moodEntryDates: moodEntries.map(\.createdAt),
            moodCheckInDates: moodCheckIns.map(\.createdAt),
            thoughtRecordDates: thoughts.map(\.createdAt),
            exerciseCompletionDates: exerciseCompletions.map(\.createdAt),
            journalEntries: journals.map {
                MonthlyBadgeJournalActivity(createdAt: $0.createdAt, sourceKind: $0.sourceKind)
            },
            flexibleJournalDates: flexibleJournals.map(\.date),
            breathingSessionDates: breathingSessions.map(\.createdAt),
            plannedActivityCompletionDates: plannedActivities.map { $0.completedAt ?? $0.createdAt },
            courseCompletionDates: courses.compactMap(\.completedAt)
        )

        return MonthlyBadgeCalculator.progress(
            for: date,
            snapshot: snapshot,
            calendar: calendar
        )
    }

    func recordWeeklyReportViewed(in modelContext: ModelContext) {
        if !UserDefaults.standard.bool(forKey: Self.weeklyReportViewedKey) {
            UserDefaults.standard.set(true, forKey: Self.weeklyReportViewedKey)
        }
        evaluateAchievements(in: modelContext)
    }

    func seedDefaultAchievementsIfNeeded(in modelContext: ModelContext) throws {
        let existing = try fetchAchievements(in: modelContext)
        let existingByTitle = Dictionary(grouping: existing, by: \.title)
        var inserted = false
        var updated = false

        for definition in definitions {
            if let matches = existingByTitle[definition.title], let canonical = matches.first {
                if canonical.achievementDescription != definition.description {
                    canonical.achievementDescription = definition.description
                    updated = true
                }
                if canonical.imageName != definition.imageName {
                    canonical.imageName = definition.imageName
                    updated = true
                }
                if canonical.unlockCondition != definition.unlockCondition {
                    canonical.unlockCondition = definition.unlockCondition
                    updated = true
                }
                for duplicate in matches.dropFirst() {
                    modelContext.delete(duplicate)
                    updated = true
                }
            } else {
                modelContext.insert(
                    Achievement(
                        title: definition.title,
                        description: definition.description,
                        imageName: definition.imageName,
                        unlockCondition: definition.unlockCondition
                    )
                )
                inserted = true
            }
        }

        if inserted || updated {
            try modelContext.save()
        }
    }

    private func fetchAchievements(in modelContext: ModelContext) throws -> [Achievement] {
        var descriptor = FetchDescriptor<Achievement>(
            sortBy: [
                SortDescriptor(\.createdAt)
            ]
        )
        descriptor.includePendingChanges = true
        return try modelContext.fetch(descriptor).sorted {
            if $0.isUnlocked != $1.isUnlocked {
                return $0.isUnlocked && !$1.isUnlocked
            }
            return $0.createdAt < $1.createdAt
        }
    }

    private func definition(for achievement: Achievement) -> AchievementDefinition? {
        definitions.first { $0.title == achievement.title }
    }

    private func achievementCounts(in modelContext: ModelContext) throws -> AchievementCounts {
        let thoughts = try modelContext.fetch(FetchDescriptor<ThoughtRecord>())
            .filter { !$0.isDeleted }
        let exerciseCompletions = try modelContext.fetch(FetchDescriptor<ExerciseCompletion>())
            .filter { !$0.isDeleted }
        let journals = try modelContext.fetch(FetchDescriptor<JournalEntry>())
            .filter { !$0.isDeleted }
        let moodEntries = try modelContext.fetch(FetchDescriptor<MoodEntry>())
            .filter { !$0.isDeleted }
        let moodCheckIns = try modelContext.fetch(FetchDescriptor<MoodCheckIn>())
            .filter { !$0.isDeleted }
        let flexibleJournals = try modelContext.fetch(FetchDescriptor<FlexibleJournalEntry>())
        let breathingSessions = try modelContext.fetch(FetchDescriptor<BreathingSession>())
            .filter { !$0.isDeleted }
        let courses = try modelContext.fetch(FetchDescriptor<Course>())
        let plannedActivities = try modelContext.fetch(FetchDescriptor<PlannedActivity>())
            .filter { !$0.isDeleted }
        let assessmentLogs = try modelContext.fetch(FetchDescriptor<AssessmentLog>())
        let personalityAssessmentLogs = try modelContext.fetch(FetchDescriptor<PersonalityAssessmentLog>())

        let completedPlannedActivityDates = plannedActivities.compactMap { activity in
            activity.isCompleted ? (activity.completedAt ?? activity.createdAt) : nil
        }
        let completedCourseDates = courses.compactMap { course in
            course.isCompleted ? course.completedAt : nil
        }

        let activeDates = Set(
            thoughts.map(\.createdAt) +
            exerciseCompletions.map(\.createdAt) +
            journals.map(\.createdAt) +
            flexibleJournals.map(\.date) +
            moodEntries.map(\.createdAt) +
            moodCheckIns.map(\.createdAt) +
            breathingSessions.map(\.createdAt) +
            completedPlannedActivityDates +
            completedCourseDates +
            assessmentLogs.map(\.date) +
            personalityAssessmentLogs.map(\.date)
        )
        .map { Calendar.current.startOfDay(for: $0) }

        return AchievementCounts(
            streakCount: Self.longestDailyRun(from: activeDates),
            exercisesCompleted: exerciseCompletions.count,
            thoughtRecordsCount: thoughts.count,
            moodCheckInCount: max(moodEntries.count, moodCheckIns.count),
            guidedJournalCount: flexibleJournals.count,
            breathingSessionCount: breathingSessions.count,
            coursesCompleted: courses.filter(\.isCompleted).count,
            weeklyReportViewed: UserDefaults.standard.bool(forKey: Self.weeklyReportViewedKey) ? 1 : 0,
            plannedActivitiesCompleted: plannedActivities.filter(\.isCompleted).count,
            assessmentsCompleted: assessmentLogs.count + personalityAssessmentLogs.count,
            activeWeeksCount: Self.activeWeekCount(from: activeDates),
            contentModalitiesTried: Self.contentModalitiesTried(
                from: exerciseCompletions,
                courses: courses
            ).count
        )
    }

    private static func longestDailyRun(from activeDays: [Date], calendar: Calendar = .current) -> Int {
        let uniqueDays = Set(activeDays).sorted()
        guard !uniqueDays.isEmpty else { return 0 }

        var longestRun = 1
        var currentRun = 1
        guard uniqueDays.count > 1 else { return longestRun }

        for index in 1..<uniqueDays.count {
            let previousDay = uniqueDays[index - 1]
            let currentDay = uniqueDays[index]
            let daysBetween = calendar.dateComponents([.day], from: previousDay, to: currentDay).day ?? 0

            if daysBetween == 1 {
                currentRun += 1
            } else if daysBetween > 1 {
                currentRun = 1
            }
            longestRun = max(longestRun, currentRun)
        }

        return longestRun
    }

    private static func activeWeekCount(from activeDates: [Date], calendar: Calendar = .current) -> Int {
        Set(activeDates.map { date in
            calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        }).count
    }

    private static func contentModalitiesTried(
        from completions: [ExerciseCompletion],
        courses: [Course]
    ) -> Set<ContentModality> {
        var exerciseIDs = Set(completions.map(\.exerciseID))
        for course in courses {
            exerciseIDs.formUnion(course.completedItemIDs)
        }

        return exerciseIDs.reduce(into: Set<ContentModality>()) { result, exerciseID in
            guard let exercise = ExerciseService.shared.exercise(withID: exerciseID) else { return }
            result.formUnion(modalities(for: exercise))
        }
    }

    private static func modalities(for exercise: Exercise) -> Set<ContentModality> {
        let fields = ([exercise.displayApproach, exercise.category] + (exercise.tags ?? []))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        return fields.reduce(into: Set<ContentModality>()) { result, field in
            if field == "cbt" || field.contains("cognitive behavioral") {
                result.insert(.cbt)
            }
            if field == "dbt" || field.contains("dialectical behavior") {
                result.insert(.dbt)
            }
            if field == "act" || field.contains("acceptance and commitment") {
                result.insert(.act)
            }
            if field == "mindfulness" || field.contains("mindful") {
                result.insert(.mindfulness)
            }
        }
    }
}

private struct AchievementCounts {
    let streakCount: Int
    let exercisesCompleted: Int
    let thoughtRecordsCount: Int
    let moodCheckInCount: Int
    let guidedJournalCount: Int
    let breathingSessionCount: Int
    let coursesCompleted: Int
    let weeklyReportViewed: Int
    let plannedActivitiesCompleted: Int
    let assessmentsCompleted: Int
    let activeWeeksCount: Int
    let contentModalitiesTried: Int

    func value(for condition: AchievementUnlockCondition) -> Int {
        switch condition {
        case .streakCount: return streakCount
        case .exercisesCompleted: return exercisesCompleted
        case .thoughtRecordsCount: return thoughtRecordsCount
        case .moodCheckInCount: return moodCheckInCount
        case .guidedJournalCount: return guidedJournalCount
        case .breathingSessionCount: return breathingSessionCount
        case .coursesCompleted: return coursesCompleted
        case .weeklyReportViewed: return weeklyReportViewed
        case .plannedActivitiesCompleted: return plannedActivitiesCompleted
        case .assessmentsCompleted: return assessmentsCompleted
        case .activeWeeksCount: return activeWeeksCount
        case .contentModalitiesTried: return contentModalitiesTried
        }
    }
}

private enum ContentModality: Hashable {
    case cbt
    case dbt
    case act
    case mindfulness
}
