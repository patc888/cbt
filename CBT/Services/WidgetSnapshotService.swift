import Foundation
import OSLog
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

struct WidgetRetentionSnapshot: Codable, Equatable {
    static let appGroupIdentifier = AppConfiguration.appGroupIdentifier
    static let defaultsKey = "cbt.widget.retentionSnapshot.v1"

    var generatedAt: Date
    var hasActivity: Bool
    var hasActivityToday: Bool
    var currentStreak: Int
    var weeklyActivityCount: Int
    var weeklyCheckInCount: Int
    var weeklyPracticeCount: Int
    var lastActivityKind: String?

    static let empty = WidgetRetentionSnapshot(
        generatedAt: Date.distantPast,
        hasActivity: false,
        hasActivityToday: false,
        currentStreak: 0,
        weeklyActivityCount: 0,
        weeklyCheckInCount: 0,
        weeklyPracticeCount: 0,
        lastActivityKind: nil
    )
}

@MainActor
enum WidgetSnapshotService {
    private static let logger = AppLogger.make(category: "WidgetSnapshotService")

    static func publishSnapshot(from modelContext: ModelContext, now: Date = Date()) {
        do {
            let snapshot = try makeSnapshot(from: modelContext, now: now)
            guard let defaults = UserDefaults(suiteName: WidgetRetentionSnapshot.appGroupIdentifier),
                  let data = try? JSONEncoder().encode(snapshot)
            else { return }

            defaults.set(data, forKey: WidgetRetentionSnapshot.defaultsKey)

            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            logger.error("Widget snapshot publish failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    private static func makeSnapshot(from modelContext: ModelContext, now: Date) throws -> WidgetRetentionSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today

        var activeDays = Set<Date>()
        var weeklyActivityCount = 0
        var weeklyCheckInCount = 0
        var weeklyPracticeCount = 0
        var lastActivity: (date: Date, kind: String)?

        func record(_ date: Date, kind: String, checkIn: Bool = false, practice: Bool = false) {
            activeDays.insert(calendar.startOfDay(for: date))

            if date >= weekStart && date <= now {
                weeklyActivityCount += 1
                if checkIn { weeklyCheckInCount += 1 }
                if practice { weeklyPracticeCount += 1 }
            }

            if lastActivity.map({ date > $0.date }) ?? true {
                lastActivity = (date, kind)
            }
        }

        try modelContext.fetch(FetchDescriptor<MoodCheckIn>()).forEach { item in
            guard !item.isDeleted else { return }
            record(item.createdAt, kind: "check-in", checkIn: true)
        }

        try modelContext.fetch(FetchDescriptor<MoodEntry>()).forEach { item in
            guard !item.isDeleted else { return }
            record(item.createdAt, kind: "mood", checkIn: true)
        }

        try modelContext.fetch(FetchDescriptor<ExerciseCompletion>()).forEach { item in
            guard !item.isDeleted else { return }
            record(item.createdAt, kind: "practice", practice: true)
        }

        try modelContext.fetch(FetchDescriptor<JournalEntry>()).forEach { item in
            guard !item.isDeleted else { return }
            record(item.createdAt, kind: "journal")
        }

        try modelContext.fetch(FetchDescriptor<ThoughtRecord>()).forEach { item in
            guard !item.isDeleted else { return }
            record(item.createdAt, kind: "thought record", practice: true)
        }

        try modelContext.fetch(FetchDescriptor<BreathingSession>()).forEach { item in
            guard !item.isDeleted else { return }
            record(item.createdAt, kind: "breathing", practice: true)
        }

        try modelContext.fetch(FetchDescriptor<PlannedActivity>()).forEach { item in
            guard !item.isDeleted, item.isCompleted else { return }
            record(item.completedAt ?? item.createdAt, kind: "activity", practice: true)
        }

        return WidgetRetentionSnapshot(
            generatedAt: now,
            hasActivity: !activeDays.isEmpty,
            hasActivityToday: activeDays.contains(today),
            currentStreak: currentStreak(from: activeDays, calendar: calendar, today: today),
            weeklyActivityCount: weeklyActivityCount,
            weeklyCheckInCount: weeklyCheckInCount,
            weeklyPracticeCount: weeklyPracticeCount,
            lastActivityKind: lastActivity?.kind
        )
    }

    private static func currentStreak(from activeDays: Set<Date>, calendar: Calendar, today: Date) -> Int {
        guard activeDays.contains(today) else { return 0 }

        var day = today
        var count = 0
        while activeDays.contains(day) {
            count += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previousDay
        }
        return count
    }
}
