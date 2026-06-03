import Foundation

struct UserMilestone: Identifiable, Equatable, Sendable {
    let id: String
    let badgeID: String
    let title: String
    let entryCount: Int
    let achievedAt: Date?

    var isAchieved: Bool {
        achievedAt != nil
    }
}

enum UserMilestoneSchema {
    static let entryCountBadges: [Int: (badgeID: String, title: String)] = [
        5: ("growth.entries.5", "First Five"),
        20: ("growth.entries.20", "Steady Practice"),
        50: ("growth.entries.50", "Deepening Habit")
    ]

    static func milestones(for entryCount: Int, achievedAt: Date? = Date()) -> [UserMilestone] {
        entryCountBadges.keys.sorted().compactMap { threshold in
            guard let badge = entryCountBadges[threshold] else { return nil }
            return UserMilestone(
                id: badge.badgeID,
                badgeID: badge.badgeID,
                title: badge.title,
                entryCount: threshold,
                achievedAt: entryCount >= threshold ? achievedAt : nil
            )
        }
    }

    static func badgeID(forExactEntryCount entryCount: Int) -> String? {
        entryCountBadges[entryCount]?.badgeID
    }
}

struct PersonalGrowthSnapshot: Sendable {
    let consistencyScore: Int
    let entriesLastThreeMonths: Int
    let averageEntriesPerWeek: Double
    let weeklyEntryCounts: [Int]
    let milestones: [UserMilestone]
    let topEmotionTags: [EmotionCount]

    static let empty = PersonalGrowthSnapshot(
        consistencyScore: 0,
        entriesLastThreeMonths: 0,
        averageEntriesPerWeek: 0,
        weeklyEntryCounts: [],
        milestones: UserMilestoneSchema.milestones(for: 0, achievedAt: nil),
        topEmotionTags: []
    )
}

struct PersonalGrowthActivityEvent: Sendable {
    let date: Date
    let emotionTags: [String]

    init(date: Date, emotionTags: [String] = []) {
        self.date = date
        self.emotionTags = emotionTags
    }
}

enum PersonalGrowthCalculator {
    static let weeklyEntryTarget = 5.0

    static func snapshot(
        events: [PersonalGrowthActivityEvent],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> PersonalGrowthSnapshot {
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: referenceDate) ?? referenceDate
        let recentEvents = events.filter { $0.date >= threeMonthsAgo && $0.date <= referenceDate }
        let weekGroups = Dictionary(grouping: recentEvents) { event in
            calendar.dateInterval(of: .weekOfYear, for: event.date)?.start ?? calendar.startOfDay(for: event.date)
        }

        let weekStarts = makeWeekStarts(from: threeMonthsAgo, through: referenceDate, calendar: calendar)
        let weeklyEntryCounts = weekStarts.map { weekGroups[$0]?.count ?? 0 }
        let averageEntriesPerWeek = weeklyEntryCounts.isEmpty ? 0 : Double(weeklyEntryCounts.reduce(0, +)) / Double(weeklyEntryCounts.count)
        let consistencyScore = Int((min(averageEntriesPerWeek / weeklyEntryTarget, 1.0) * 100).rounded())

        var emotionCounts: [String: (displayName: String, count: Int)] = [:]
        for event in events {
            for emotion in event.emotionTags {
                let displayName = emotion.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = displayName.lowercased()
                guard !key.isEmpty else { continue }
                var bucket = emotionCounts[key] ?? (displayName: displayName.capitalized, count: 0)
                bucket.count += 1
                emotionCounts[key] = bucket
            }
        }

        let topEmotionTags = emotionCounts.values.map {
            EmotionCount(name: $0.displayName, count: $0.count)
        }
        .sorted { first, second in
            if first.count == second.count {
                return first.name < second.name
            }
            return first.count > second.count
        }
        .prefix(3)
        .map { $0 }

        return PersonalGrowthSnapshot(
            consistencyScore: consistencyScore,
            entriesLastThreeMonths: recentEvents.count,
            averageEntriesPerWeek: averageEntriesPerWeek,
            weeklyEntryCounts: weeklyEntryCounts,
            milestones: UserMilestoneSchema.milestones(for: recentEvents.count, achievedAt: recentEvents.map(\.date).max()),
            topEmotionTags: topEmotionTags
        )
    }

    private static func makeWeekStarts(from startDate: Date, through endDate: Date, calendar: Calendar) -> [Date] {
        var starts: [Date] = []
        var cursor = calendar.dateInterval(of: .weekOfYear, for: startDate)?.start ?? calendar.startOfDay(for: startDate)
        let final = calendar.dateInterval(of: .weekOfYear, for: endDate)?.start ?? calendar.startOfDay(for: endDate)

        while cursor <= final {
            starts.append(cursor)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        return starts
    }
}
