import Foundation
import OSLog
import SwiftData

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
            title: "Thought Catcher",
            description: "Save your first thought record.",
            imageName: "brain.head.profile",
            unlockCondition: .thoughtRecordsCount,
            targetCount: 1
        ),
        AchievementDefinition(
            title: "Pattern Spotter",
            description: "Save ten thought records.",
            imageName: "sparkle.magnifyingglass",
            unlockCondition: .thoughtRecordsCount,
            targetCount: 10
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
        let exercises = try modelContext.fetch(FetchDescriptor<ExerciseCompletion>())
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

        let activeDates = Set(
            thoughts.map(\.createdAt) +
            exercises.map(\.createdAt) +
            journals.map(\.createdAt) +
            flexibleJournals.map(\.date) +
            moodEntries.map(\.createdAt) +
            moodCheckIns.map(\.createdAt) +
            breathingSessions.map(\.createdAt)
        )
        .map { Calendar.current.startOfDay(for: $0) }

        return AchievementCounts(
            streakCount: Self.currentStreak(from: activeDates),
            exercisesCompleted: exercises.count,
            thoughtRecordsCount: thoughts.count
        )
    }

    private static func currentStreak(from activeDays: [Date], calendar: Calendar = .current) -> Int {
        let uniqueDays = Set(activeDays).sorted()
        guard !uniqueDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let lastActiveDay = uniqueDays.last,
              lastActiveDay >= yesterday else {
            return 0
        }

        var streak = 1
        guard uniqueDays.count > 1 else { return streak }

        for index in (0..<(uniqueDays.count - 1)).reversed() {
            let previousDay = uniqueDays[index]
            let currentDay = uniqueDays[index + 1]
            let daysBetween = calendar.dateComponents([.day], from: previousDay, to: currentDay).day ?? 0

            if daysBetween == 1 {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }
}

private struct AchievementCounts {
    let streakCount: Int
    let exercisesCompleted: Int
    let thoughtRecordsCount: Int

    func value(for condition: AchievementUnlockCondition) -> Int {
        switch condition {
        case .streakCount: return streakCount
        case .exercisesCompleted: return exercisesCompleted
        case .thoughtRecordsCount: return thoughtRecordsCount
        }
    }
}
