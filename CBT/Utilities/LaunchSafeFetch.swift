import OSLog
import SwiftData

struct HomeDashboardSnapshot: Sendable {
    let activeDates: Set<Date>
    let completionSnapshot: DailyPlanCompletionSnapshot

    static let empty = HomeDashboardSnapshot(
        activeDates: [],
        completionSnapshot: .empty
    )
}

private protocol CreatedAtRecord: SoftDeletableRecord {
    var createdAt: Date { get }
}

extension MoodEntry: CreatedAtRecord {}
extension ThoughtRecord: CreatedAtRecord {}
extension ExerciseCompletion: CreatedAtRecord {}
extension JournalEntry: CreatedAtRecord {}

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

        var activeDates = Set<Date>()
        for date in moodDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in thoughtDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in exerciseDates { activeDates.insert(calendar.startOfDay(for: date)) }
        for date in breathingDates { activeDates.insert(calendar.startOfDay(for: date)) }

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
            .breathingReset: fetchCount(
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
                label: "homeDashboardSnapshot.breathingCount"
            ) > 0 ? .completed : .incomplete,
            .tipOfTheDay: .notTracked
        ])

        return HomeDashboardSnapshot(
            activeDates: activeDates,
            completionSnapshot: completionSnapshot
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
