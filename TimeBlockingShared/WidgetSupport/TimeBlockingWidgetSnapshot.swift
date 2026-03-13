import Foundation

enum TimeBlockingWidgetStoreConfiguration {
    static let appGroupIdentifier = "group.com.melichan.TimeBlocking"
    static let snapshotKey = "timeblocking.widget.snapshot.v1"
}

struct TimeBlockingWidgetBlockSnapshot: Codable, Hashable, Sendable {
    let title: String
    let categoryTitle: String
    let startDate: Date
    let endDate: Date
}

struct TimeBlockingWidgetTodaySummarySnapshot: Codable, Hashable, Sendable {
    let plannedCount: Int
    let completedCount: Int
    let scheduledMinutes: Int

    var isEmpty: Bool {
        plannedCount == 0 && completedCount == 0 && scheduledMinutes == 0
    }
}

struct TimeBlockingWidgetSnapshot: Codable, Hashable, Sendable {
    let generatedAt: Date
    let referenceDay: Date
    let upcomingBlocks: [TimeBlockingWidgetBlockSnapshot]
    let todaySummary: TimeBlockingWidgetTodaySummarySnapshot

    static func empty(
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TimeBlockingWidgetSnapshot {
        TimeBlockingWidgetSnapshot(
            generatedAt: now,
            referenceDay: calendar.startOfDay(for: now),
            upcomingBlocks: [],
            todaySummary: TimeBlockingWidgetTodaySummarySnapshot(
                plannedCount: 0,
                completedCount: 0,
                scheduledMinutes: 0
            )
        )
    }

    func nextBlock(
        at date: Date = .now,
        calendar: Calendar = .current
    ) -> TimeBlockingWidgetBlockSnapshot? {
        upcomingBlocks.first { block in
            block.startDate > date
        }
    }

    func summaryForCurrentDay(
        at date: Date = .now,
        calendar: Calendar = .current
    ) -> TimeBlockingWidgetTodaySummarySnapshot? {
        guard calendar.isDate(referenceDay, inSameDayAs: date) else {
            return nil
        }

        return todaySummary
    }

    func recommendedRefreshDate(
        from date: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let startOfToday = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? date.addingTimeInterval(3600)
        let blockBoundaries = upcomingBlocks
            .flatMap { [$0.startDate, $0.endDate] }
            .filter { $0 > date }

        return (blockBoundaries + [nextDay]).min() ?? nextDay
    }
}

enum TimeBlockingWidgetSnapshotStoreError: Error {
    case unavailableSharedDefaults
}

struct TimeBlockingWidgetSnapshotStore {
    private let defaults: UserDefaults?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(suiteName: String = TimeBlockingWidgetStoreConfiguration.appGroupIdentifier) {
        defaults = UserDefaults(suiteName: suiteName)
    }

    func load() -> TimeBlockingWidgetSnapshot? {
        guard
            let defaults,
            let data = defaults.data(forKey: TimeBlockingWidgetStoreConfiguration.snapshotKey)
        else {
            return nil
        }

        return try? decoder.decode(TimeBlockingWidgetSnapshot.self, from: data)
    }

    func save(_ snapshot: TimeBlockingWidgetSnapshot) throws {
        guard let defaults else {
            throw TimeBlockingWidgetSnapshotStoreError.unavailableSharedDefaults
        }

        let data = try encoder.encode(snapshot)
        defaults.set(data, forKey: TimeBlockingWidgetStoreConfiguration.snapshotKey)
    }
}
