import OSLog
import SwiftData

struct HomeDashboardSnapshot: Sendable {
    let activeDates: Set<Date>
    let completionSnapshot: DailyPlanCompletionSnapshot
    let recommendations: [DailyRecommendation]
    let latestMoodScore: Int?

    static let empty = HomeDashboardSnapshot(
        activeDates: [],
        completionSnapshot: .empty,
        recommendations: [],
        latestMoodScore: nil
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

        let latestMoodScore = fetch(
            FetchDescriptor<MoodEntry>(
                predicate: #Predicate<MoodEntry> {
                    $0.isDeleted == false
                },
                sortBy: [SortDescriptor(\MoodEntry.createdAt, order: .reverse)]
            ),
            from: context,
            logger: logger,
            label: "homeDashboardSnapshot.latestMood"
        ).first?.moodScore

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

        var activeDates = Set<Date>()
        for date in moodDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in thoughtDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in exerciseDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in breathingDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in breathingSessionDates { activeDates.insert(calendar.startOfDay(for: date)) }
        
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

        let completionSnapshot = DailyPlanCompletionSnapshot(entries: [
            .moodCheckIn: fetchCount(
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
            ) > 0 ? .completed : .incomplete,
            .thoughtRecord: fetchCount(
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
            ) > 0 ? .completed : .incomplete,
            .exercises: fetchCount(
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
            ) > 0 ? .completed : .incomplete,
            .breathingReset: (breathingJournalCount + breathingSessionCount) > 0 ? .completed : .incomplete,
            .tipOfTheDay: .notTracked,
            .activityPlanner: fetchCount(
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
            ) > 0 ? .completed : .incomplete
        ])

        return HomeDashboardSnapshot(
            activeDates: activeDates,
            completionSnapshot: completionSnapshot,
            recommendations: [],
            latestMoodScore: latestMoodScore
        )
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
