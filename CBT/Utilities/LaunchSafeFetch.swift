import Foundation
import OSLog
import SwiftData

struct HomeDashboardSnapshot: Sendable {
    let activeDates: Set<Date>
    let completionSnapshot: DailyPlanCompletionSnapshot
    let recommendations: [DailyRecommendation]
    let latestMoodScore: Int?
    let latestMoodDate: Date?
    let personalization: HomePersonalizedSnapshot

    static let empty = HomeDashboardSnapshot(
        activeDates: [],
        completionSnapshot: .empty,
        recommendations: [],
        latestMoodScore: nil,
        latestMoodDate: nil,
        personalization: .empty
    )
}

private protocol CreatedAtRecord: SoftDeletableRecord {
    var createdAt: Date { get }
}

extension MoodEntry: CreatedAtRecord {}
extension MoodCheckIn: CreatedAtRecord {}
extension ThoughtRecord: CreatedAtRecord {}
extension ExerciseCompletion: CreatedAtRecord {}
extension JournalEntry: CreatedAtRecord {}
extension PlannedActivity: CreatedAtRecord {}
extension BreathingSession: CreatedAtRecord {}
extension TinyWinCompletion: CreatedAtRecord {}
extension ValueActionCompletion: CreatedAtRecord {}
extension DailyPlanCompletion: CreatedAtRecord {
    var createdAt: Date { completedAt }
}

enum LaunchSafeFetch {
    private static let disableHomeDashboardFetches = false

    @MainActor
    static func moodEntries(
        from context: ModelContext,
        logger: Logger = AppLogger.make(category: "LaunchSafeFetch")
    ) -> [MoodEntry] {
        fetch(
            FetchDescriptor<MoodEntry>(
                predicate: #Predicate<MoodEntry> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\MoodEntry.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "moodEntries"
        )
    }

    @MainActor
    static func moodCheckIns(
        from context: ModelContext,
        logger: Logger = AppLogger.make(category: "LaunchSafeFetch")
    ) -> [MoodCheckIn] {
        fetch(
            FetchDescriptor<MoodCheckIn>(
                predicate: #Predicate<MoodCheckIn> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\MoodCheckIn.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "moodCheckIns"
        )
    }

    @MainActor
    static func thoughtRecords(
        from context: ModelContext,
        logger: Logger = AppLogger.make(category: "LaunchSafeFetch")
    ) -> [ThoughtRecord] {
        fetch(
            FetchDescriptor<ThoughtRecord>(
                predicate: #Predicate<ThoughtRecord> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\ThoughtRecord.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "thoughtRecords"
        )
    }

    @MainActor
    static func exerciseCompletions(
        from context: ModelContext,
        logger: Logger = AppLogger.make(category: "LaunchSafeFetch")
    ) -> [ExerciseCompletion] {
        fetch(
            FetchDescriptor<ExerciseCompletion>(
                predicate: #Predicate<ExerciseCompletion> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\ExerciseCompletion.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "exerciseCompletions"
        )
    }

    @MainActor
    static func exerciseCompletions(
        for exerciseID: String,
        from context: ModelContext,
        logger: Logger = AppLogger.make(category: "LaunchSafeFetch")
    ) -> [ExerciseCompletion] {
        fetch(
            FetchDescriptor<ExerciseCompletion>(
                predicate: #Predicate<ExerciseCompletion> {
                    $0.exerciseID == exerciseID && $0.isDeleted == false
                },
                sortBy: [SortDescriptor(\ExerciseCompletion.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "exerciseCompletions.filtered"
        )
    }

    @MainActor
    static func journalEntries(
        from context: ModelContext,
        logger: Logger = AppLogger.make(category: "LaunchSafeFetch")
    ) -> [JournalEntry] {
        fetch(
            FetchDescriptor<JournalEntry>(
                predicate: #Predicate<JournalEntry> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\JournalEntry.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "journalEntries"
        )
    }

    @MainActor
    static func personalValues(
        from context: ModelContext,
        logger: Logger = AppLogger.make(category: "LaunchSafeFetch")
    ) -> [PersonalValue] {
        fetch(
            FetchDescriptor<PersonalValue>(
                predicate: #Predicate<PersonalValue> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\PersonalValue.createdAt)]
            ),
            from: context,
            logger: logger,
            label: "personalValues"
        )
    }

    @MainActor
    static func valueActionCompletions(
        from context: ModelContext,
        logger: Logger = AppLogger.make(category: "LaunchSafeFetch")
    ) -> [ValueActionCompletion] {
        fetch(
            FetchDescriptor<ValueActionCompletion>(
                predicate: #Predicate<ValueActionCompletion> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\ValueActionCompletion.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "valueActionCompletions"
        )
    }

    @MainActor
    static func flexibleJournalEntries(
        from context: ModelContext,
        logger: Logger = AppLogger.make(category: "LaunchSafeFetch")
    ) -> [FlexibleJournalEntry] {
        fetch(
            FetchDescriptor<FlexibleJournalEntry>(
                sortBy: [SortDescriptor(\FlexibleJournalEntry.date, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "flexibleJournalEntries"
        )
    }

    @MainActor
    static func breathingSessions(
        from context: ModelContext,
        logger: Logger = AppLogger.make(category: "LaunchSafeFetch")
    ) -> [BreathingSession] {
        fetch(
            FetchDescriptor<BreathingSession>(
                predicate: #Predicate<BreathingSession> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\BreathingSession.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "breathingSessions"
        )
    }

    @MainActor
    static func userSettings(
        from context: ModelContext,
        logger: Logger = AppLogger.make(category: "LaunchSafeFetch")
    ) -> [UserSettings] {
        fetch(
            FetchDescriptor<UserSettings>(),
            from: context,
            logger: logger,
            label: "userSettings"
        )
    }

    @MainActor
    static func homeDashboardSnapshot(
        selectedDate: Date,
        visibleDates: [Date],
        from context: ModelContext,
        logger: Logger = AppLogger.make(category: "LaunchSafeFetch")
    ) -> HomeDashboardSnapshot {
        if disableHomeDashboardFetches {
            logger.debug("Home dashboard SwiftData snapshot disabled for stabilization build")
            return .empty
        }

        guard
            let firstVisibleDate = visibleDates.min(),
            let lastVisibleDate = visibleDates.max()
        else {
            return .empty
        }

        let calendar = Calendar.current
        let breathingSourceKind: String? = SessionSourceKind.breathing.rawValue
        let windowStart = calendar.startOfDay(for: firstVisibleDate)
        guard let windowEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastVisibleDate)) else {
            return .empty
        }

        let selectedDayStart = calendar.startOfDay(for: selectedDate)
        guard let selectedDayEnd = calendar.date(byAdding: .day, value: 1, to: selectedDayStart) else {
            return .empty
        }

        let moodDates = createdDates(
            FetchDescriptor<MoodEntry>(
                predicate: #Predicate<MoodEntry> {
                    $0.isDeleted == false &&
                    $0.createdAt >= windowStart &&
                    $0.createdAt < windowEnd
                },
                sortBy: [SortDescriptor(\MoodEntry.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.moodDates"
        )

        let latestMood = fetch(
            FetchDescriptor<MoodEntry>(
                predicate: #Predicate<MoodEntry> {
                    $0.isDeleted == false
                },
                sortBy: [SortDescriptor(\MoodEntry.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.latestMood"
        ).first

        let latestMoodCheckIn = fetch(
            FetchDescriptor<MoodCheckIn>(
                predicate: #Predicate<MoodCheckIn> {
                    $0.isDeleted == false
                },
                sortBy: [SortDescriptor(\MoodCheckIn.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.latestMoodCheckIn"
        ).first

        let thoughtDates = createdDates(
            FetchDescriptor<ThoughtRecord>(
                predicate: #Predicate<ThoughtRecord> {
                    $0.isDeleted == false &&
                    $0.createdAt >= windowStart &&
                    $0.createdAt < windowEnd
                },
                sortBy: [SortDescriptor(\ThoughtRecord.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.thoughtDates"
        )

        let exerciseDates = createdDates(
            FetchDescriptor<ExerciseCompletion>(
                predicate: #Predicate<ExerciseCompletion> {
                    $0.isDeleted == false &&
                    $0.createdAt >= windowStart &&
                    $0.createdAt < windowEnd
                },
                sortBy: [SortDescriptor(\ExerciseCompletion.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.exerciseDates"
        )

        let breathingDates = createdDates(
            FetchDescriptor<JournalEntry>(
                predicate: #Predicate<JournalEntry> {
                    $0.isDeleted == false &&
                    $0.sourceKind == breathingSourceKind &&
                    $0.createdAt >= windowStart &&
                    $0.createdAt < windowEnd
                },
                sortBy: [SortDescriptor(\JournalEntry.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.breathingDates"
        )

        let breathingSessionDates = createdDates(
            FetchDescriptor<BreathingSession>(
                predicate: #Predicate<BreathingSession> {
                    $0.isDeleted == false &&
                    $0.createdAt >= windowStart &&
                    $0.createdAt < windowEnd
                },
                sortBy: [SortDescriptor(\BreathingSession.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.breathingSessionDates"
        )

        let tinyWinDates = createdDates(
            FetchDescriptor<TinyWinCompletion>(
                predicate: #Predicate<TinyWinCompletion> {
                    $0.isDeleted == false &&
                    $0.createdAt >= windowStart &&
                    $0.createdAt < windowEnd
                },
                sortBy: [SortDescriptor(\TinyWinCompletion.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.tinyWinDates"
        )

        let valueActionDates = createdDates(
            FetchDescriptor<ValueActionCompletion>(
                predicate: #Predicate<ValueActionCompletion> {
                    $0.isDeleted == false &&
                    $0.createdAt >= windowStart &&
                    $0.createdAt < windowEnd
                },
                sortBy: [SortDescriptor(\ValueActionCompletion.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.valueActionDates"
        )

        let dailyPlanCompletionDates = createdDates(
            FetchDescriptor<DailyPlanCompletion>(
                predicate: #Predicate<DailyPlanCompletion> {
                    $0.isDeleted == false &&
                    $0.date >= windowStart &&
                    $0.date < windowEnd
                },
                sortBy: [SortDescriptor(\DailyPlanCompletion.completedAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.dailyPlanCompletionDates"
        )

        let moodCheckInDates = createdDates(
            FetchDescriptor<MoodCheckIn>(
                predicate: #Predicate<MoodCheckIn> {
                    $0.isDeleted == false &&
                    $0.createdAt >= windowStart &&
                    $0.createdAt < windowEnd
                },
                sortBy: [SortDescriptor(\MoodCheckIn.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.moodCheckInDates"
        )

        var activeDates = Set<Date>()
        for date in moodDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in moodCheckInDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in thoughtDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in exerciseDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in breathingDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in breathingSessionDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in tinyWinDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in valueActionDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in dailyPlanCompletionDates { activeDates.insert(calendar.startOfDay(for: date)) }
        
        let activityDates = createdDates(
            FetchDescriptor<PlannedActivity>(
                predicate: #Predicate<PlannedActivity> {
                    $0.isDeleted == false &&
                    $0.createdAt >= windowStart &&
                    $0.createdAt < windowEnd
                }
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.activityDates"
        )
        for date in activityDates { activeDates.insert(calendar.startOfDay(for: date)) }

        let breathingJournalCount = fetchCount(
            FetchDescriptor<JournalEntry>(
                predicate: #Predicate<JournalEntry> {
                    $0.isDeleted == false &&
                    $0.sourceKind == breathingSourceKind &&
                    $0.createdAt >= selectedDayStart &&
                    $0.createdAt < selectedDayEnd
                }
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.breathingJournalCount"
        )

        let breathingSessionCount = fetchCount(
            FetchDescriptor<BreathingSession>(
                predicate: #Predicate<BreathingSession> {
                    $0.isDeleted == false &&
                    $0.createdAt >= selectedDayStart &&
                    $0.createdAt < selectedDayEnd
                }
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.breathingSessionCount"
        )

        let moodCount = fetchCount(
            FetchDescriptor<MoodEntry>(
                predicate: #Predicate<MoodEntry> {
                    $0.isDeleted == false &&
                    $0.createdAt >= selectedDayStart &&
                    $0.createdAt < selectedDayEnd
                }
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.moodCount"
        )
        let moodCheckInCount = fetchCount(
            FetchDescriptor<MoodCheckIn>(
                predicate: #Predicate<MoodCheckIn> {
                    $0.isDeleted == false &&
                    $0.createdAt >= selectedDayStart &&
                    $0.createdAt < selectedDayEnd
                }
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.moodCheckInCount"
        )
        let thoughtCount = fetchCount(
            FetchDescriptor<ThoughtRecord>(
                predicate: #Predicate<ThoughtRecord> {
                    $0.isDeleted == false &&
                    $0.createdAt >= selectedDayStart &&
                    $0.createdAt < selectedDayEnd
                }
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.thoughtCount"
        )
        let exerciseCount = fetchCount(
            FetchDescriptor<ExerciseCompletion>(
                predicate: #Predicate<ExerciseCompletion> {
                    $0.isDeleted == false &&
                    $0.createdAt >= selectedDayStart &&
                    $0.createdAt < selectedDayEnd
                }
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.exerciseCount"
        )
        let activityPlannerCount = fetchCount(
            FetchDescriptor<PlannedActivity>(
                predicate: #Predicate<PlannedActivity> {
                    $0.isDeleted == false &&
                    $0.createdAt >= selectedDayStart &&
                    $0.createdAt < selectedDayEnd
                }
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.activityPlannerCount"
        )
        let tinyWinCount = fetchCount(
            FetchDescriptor<TinyWinCompletion>(
                predicate: #Predicate<TinyWinCompletion> {
                    $0.isDeleted == false &&
                    $0.createdAt >= selectedDayStart &&
                    $0.createdAt < selectedDayEnd
                }
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.tinyWinCount"
        )
        let valueActionCount = fetchCount(
            FetchDescriptor<ValueActionCompletion>(
                predicate: #Predicate<ValueActionCompletion> {
                    $0.isDeleted == false &&
                    $0.createdAt >= selectedDayStart &&
                    $0.createdAt < selectedDayEnd
                }
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.valueActionCount"
        )

        let moodCheckInType = DailyPlanCompletionItemType.moodCheckIn.rawValue
        let thoughtRecordType = DailyPlanCompletionItemType.thoughtRecord.rawValue
        let exerciseType = DailyPlanCompletionItemType.exercise.rawValue
        let breathingResetType = DailyPlanCompletionItemType.breathingReset.rawValue
        let tipOfTheDayType = DailyPlanCompletionItemType.tipOfTheDay.rawValue
        let activityPlannerType = DailyPlanCompletionItemType.activityPlanner.rawValue
        let quickActionType = DailyPlanCompletionItemType.quickAction.rawValue
        let tinyWinType = DailyPlanCompletionItemType.tinyWin.rawValue
        let dailyPlanCompletionsToday = fetch(
            FetchDescriptor<DailyPlanCompletion>(
                predicate: #Predicate<DailyPlanCompletion> {
                    $0.isDeleted == false &&
                    $0.date >= selectedDayStart &&
                    $0.date < selectedDayEnd
                },
                sortBy: [SortDescriptor(\DailyPlanCompletion.completedAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.dailyPlanCompletionsToday"
        )
        let dailyPlanTypesToday = Set(dailyPlanCompletionsToday.map(\.itemType))

        let hasCheckInToday = (moodCount + moodCheckInCount) > 0 || dailyPlanTypesToday.contains(moodCheckInType)
        let completionSnapshot = DailyPlanCompletionSnapshot(entries: [
            .moodCheckIn: hasCheckInToday ? .completed : .incomplete,
            .thoughtRecord: thoughtCount > 0 || dailyPlanTypesToday.contains(thoughtRecordType) ? .completed : .incomplete,
            .exercises: exerciseCount > 0 || dailyPlanTypesToday.contains(exerciseType) ? .completed : .incomplete,
            .breathingReset: (breathingJournalCount + breathingSessionCount) > 0 || dailyPlanTypesToday.contains(breathingResetType) ? .completed : .incomplete,
            .tipOfTheDay: dailyPlanTypesToday.contains(tipOfTheDayType) ? .completed : .notTracked,
            .activityPlanner: activityPlannerCount > 0 || dailyPlanTypesToday.contains(activityPlannerType) ? .completed : .incomplete,
            .tinyWin: tinyWinCount > 0 || dailyPlanTypesToday.contains(tinyWinType) ? .completed : .incomplete,
            .valueAction: valueActionCount > 0 || dailyPlanTypesToday.contains(quickActionType) ? .completed : .incomplete
        ])

        let completedTodayCount = completionSnapshot.entries.values.filter(\.isCompleted).count
        let weekStart = calendar.date(byAdding: .day, value: -6, to: selectedDayStart) ?? selectedDayStart
        let weeklyActivityCount = activeDates.filter { $0 >= weekStart && $0 <= selectedDayStart }.count
        let latestMoodSignal = latestMoodCheckIn.map { checkIn in
            latestMood.map { mood in
                mood.createdAt > checkIn.createdAt ? (mood.moodScore, mood.createdAt) : (checkIn.moodScore, checkIn.createdAt)
            } ?? (checkIn.moodScore, checkIn.createdAt)
        } ?? latestMood.map { ($0.moodScore, $0.createdAt) }
        let latestRichMood = latestMood
        let shouldShowLowEnergyMode = latestRichMood.map { mood in
            mood.energyScore.map { $0 <= 3 } == true ||
                mood.anxietyStressScore.map { $0 >= 8 } == true ||
                mood.moodScore <= 3
        } ?? (latestMoodSignal?.0 ?? 10 <= 3)
        let personalization = HomePersonalizedSnapshot(
            hasCheckInToday: hasCheckInToday,
            missedDayCount: BadDayModeService.context(
                activeDays: activeDates,
                latestMoodScore: latestMoodSignal?.0,
                latestMoodDate: latestMoodSignal?.1,
                today: selectedDayStart,
                calendar: calendar
            ).missedDays,
            completedTodayCount: completedTodayCount,
            weeklyActivityCount: weeklyActivityCount,
            shouldShowLowEnergyMode: shouldShowLowEnergyMode,
            continueItem: homeContinueItem(context: context, logger: logger),
            insight: homeInsightPreview(context: context, logger: logger, calendar: calendar, today: selectedDayStart)
        )

        return HomeDashboardSnapshot(
            activeDates: activeDates,
            completionSnapshot: completionSnapshot,
            recommendations: [],
            latestMoodScore: latestMoodSignal?.0,
            latestMoodDate: latestMoodSignal?.1,
            personalization: personalization
        )
    }

    private static func homeContinueItem(
        context: ModelContext,
        logger: Logger
    ) -> HomeContinueItem? {
        let partialThought = fetch(
            FetchDescriptor<ThoughtRecord>(
                predicate: #Predicate<ThoughtRecord> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\ThoughtRecord.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homePersonalization.partialThoughts"
        )
        .first { record in
            !record.automaticThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            record.balancedThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if partialThought != nil {
            return HomeContinueItem(
                title: String(localized: "Finish a thought record"),
                subtitle: String(localized: "A balanced thought is still waiting."),
                systemImage: "brain.head.profile",
                action: .thoughtRecord
            )
        }

        let partialJournal = fetch(
            FetchDescriptor<FlexibleJournalEntry>(
                sortBy: [SortDescriptor(\FlexibleJournalEntry.date, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homePersonalization.partialJournals"
        )
        .first { entry in
            entry.responses.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        if let partialJournal {
            let template = JournalTemplate.template(matching: partialJournal.templateType)
            return HomeContinueItem(
                title: template?.title ?? String(localized: "Finish a guided journal"),
                subtitle: String(localized: "Pick up the reflection you started."),
                systemImage: "book.pages",
                action: .journal
            )
        }

        let course = fetch(
            FetchDescriptor<Course>(
                sortBy: [SortDescriptor(\Course.title)]
            ),
            from: context,
            logger: logger,
            label: "homePersonalization.courses"
        )
        .first { course in
            !course.completedItemIDs.isEmpty && !course.isCompleted
        }

        if let course {
            let completed = max(course.completedLessonCount, course.completedItemIDs.count)
            let total = max(course.progressTotal, course.itemIDs.count)
            return HomeContinueItem(
                title: course.title,
                subtitle: total > 0
                    ? String(localized: "\(completed) of \(total) lessons complete")
                    : String(localized: "Keep going with this course."),
                systemImage: "graduationcap.fill",
                action: .recommendation(.course(courseID: course.id))
            )
        }

        return nil
    }

    private static func homeInsightPreview(
        context: ModelContext,
        logger: Logger,
        calendar: Calendar,
        today: Date
    ) -> HomeInsightPreview? {
        let cutoff = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let moodScores = fetch(
            FetchDescriptor<MoodEntry>(
                predicate: #Predicate<MoodEntry> {
                    $0.isDeleted == false &&
                    $0.createdAt >= cutoff
                },
                sortBy: [SortDescriptor(\MoodEntry.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeInsight.moodEntries"
        ).map(\.moodScore) + fetch(
            FetchDescriptor<MoodCheckIn>(
                predicate: #Predicate<MoodCheckIn> {
                    $0.isDeleted == false &&
                    $0.createdAt >= cutoff
                },
                sortBy: [SortDescriptor(\MoodCheckIn.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeInsight.moodCheckIns"
        ).map(\.moodScore)

        if moodScores.count >= 3 {
            let average = Double(moodScores.reduce(0, +)) / Double(moodScores.count)
            return HomeInsightPreview(
                title: String(localized: "Recent mood average"),
                subtitle: String(localized: "\(moodScores.count) check-ins in the last 2 weeks"),
                value: String(format: "%.1f/10", average)
            )
        }

        let thoughtImprovements = fetch(
            FetchDescriptor<ThoughtRecord>(
                predicate: #Predicate<ThoughtRecord> {
                    $0.isDeleted == false &&
                    $0.createdAt >= cutoff
                },
                sortBy: [SortDescriptor(\ThoughtRecord.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeInsight.thoughtRecords"
        )
        .map { $0.intensityBefore - $0.intensityAfter }
        .filter { $0 > 0 }

        if thoughtImprovements.count >= 2 {
            let average = thoughtImprovements.reduce(0, +) / thoughtImprovements.count
            return HomeInsightPreview(
                title: String(localized: "Reframes are helping"),
                subtitle: String(localized: "\(thoughtImprovements.count) thought records reviewed"),
                value: String(localized: "\(average) pts")
            )
        }

        return nil
    }

    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        from context: ModelContext,
        logger: Logger,
        label: StaticString
    ) -> [T] {
        do {
            var descriptor = descriptor
            descriptor.includePendingChanges = false
            return try context.fetch(descriptor)
        } catch {
            logger.error(
                "Failed launch-safe fetch label=\(label) error=\(error.localizedDescription, privacy: .private)"
            )
            return []
        }
    }
    private static func fetchCount<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        from context: ModelContext,
        logger: Logger,
        label: StaticString
    ) -> Int {
        do {
            var descriptor = descriptor
            descriptor.includePendingChanges = false
            return try context.fetchCount(descriptor)
        } catch {
            logger.error(
                "Failed launch-safe count label=\(label) error=\(error.localizedDescription, privacy: .private)"
            )
            return 0
        }
    }

    private static func createdDates<T: CreatedAtRecord>(
        _ descriptor: FetchDescriptor<T>,
        from context: ModelContext,
        logger: Logger,
        label: StaticString
    ) -> [Date] {
        fetch(
            descriptor,
            from: context,
            logger: logger,
            label: label
        ).map { $0.createdAt }
    }
}
