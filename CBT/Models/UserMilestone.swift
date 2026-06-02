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
        entryCountBadges.keys.sorted().map { threshold in
            let badge = entryCountBadges[threshold]!
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
