import Foundation
import SwiftData
import SwiftUI

// MARK: - Value-type snapshots for background processing
// SwiftData @Model objects are not Sendable; we must extract values
// on the caller's actor before entering a detached task.
private struct MoodSnapshot: Sendable {
    let createdAt: Date
    let moodScore: Int
    let emotions: [String]
    let triggers: [String]
    let sensations: [String]
    let contextTags: [String]
    let activityTags: [String]
    let notes: String?
    let intensity: Int?
    let anxietyStressScore: Int?
    let sleepQualityScore: Int?
    let energyScore: Int?
}

private struct MoodCheckInSnapshot: Sendable {
    let createdAt: Date
    let moodScore: Int
    let notes: String?
}

private struct MoodScoreSnapshot: Sendable {
    let createdAt: Date
    let moodScore: Int
}

private struct ThoughtSnapshot: Sendable {
    let createdAt: Date
    let situation: String
    let automaticThought: String
    let intensityBefore: Int
    let intensityAfter: Int
    let emotions: [String]
    let distortions: [String]
    let balancedThought: String
    let isDraft: Bool
    let isComplete: Bool
    let completedAt: Date?
    let isSavedReframe: Bool
    let isFavoriteReframe: Bool
}

private struct ExerciseSnapshot: Sendable {
    let createdAt: Date
    let exerciseID: String
    let adaptiveMode: String
}

private struct JournalSnapshot: Sendable {
    let createdAt: Date
    let title: String
    let body: String
}

private struct FlexibleJournalSnapshot: Sendable {
    let date: Date
    let responses: [String]
}

private struct BreathingSnapshot: Sendable {
    let createdAt: Date
}

private struct InsightsCalculationResult: Sendable {
    let activeDaysCount: Int
    let dailyMoodAverages: [DailyMoodAverage]
    let averageMood: Double?
    let averageIntensityImprovement: Int?
    let consistencyGoalTarget: Int
    let consistencyProgress: Double
    let moodGoalProgress: Double
    let thoughtGoalProgress: Double
    let exerciseGoalTarget: Int
    let exerciseProgress: Double
    let milestonesCompleted: Int
    let topEmotions: [EmotionCount]
    let topTriggers: [TriggerCount]
    let topDistortions: [DistortionCount]
    let thoughtRecordStats: ThoughtRecordCompletionStats
    let contextTagCorrelations: [ContextTagMoodCorrelation]
    let weeklyMoodAverages: [WeeklyMoodAverage]
    let moodVolatilityLast30Days: Double?
    let currentStreak: Int
    let longestStreak: Int
    let patternSummary: InsightsPatternSummary
    let personalGrowth: PersonalGrowthSnapshot
    let retentionInsights: RetentionInsightsSnapshot
    let triggerLibrary: TriggerLibrarySnapshot
}

@MainActor
@Observable
final class InsightsViewModel {
    var isCalculating = true
    
    // Derived values
    var activeDaysCount: Int = 0
    var dailyMoodAverages: [DailyMoodAverage] = []
    
    // A) 1) Weekly average mood (last 8 weeks)
    var weeklyMoodAverages: [WeeklyMoodAverage] = []
    
    // A) 2) Mood Volatility
    var moodVolatilityLast30Days: Double?
    
    // A) 3) Streaks
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    
    var averageMood: Double?
    var averageIntensityImprovement: Int?
    
    var consistencyGoalTarget: Int = 3
    var consistencyProgress: Double = 0
    
    var moodGoalProgress: Double = 0
    var thoughtGoalProgress: Double = 0
    
    var exerciseGoalTarget: Int = 2
    var exerciseProgress: Double = 0
    
    var milestonesCompleted: Int = 0
    
    // B & C) Top 5 Metrics
    var topEmotions: [EmotionCount] = []
    var topTriggers: [TriggerCount] = []
    var topDistortions: [DistortionCount] = []
    var thoughtRecordStats: ThoughtRecordCompletionStats = .empty
    var contextTagCorrelations: [ContextTagMoodCorrelation] = []
    var patternSummary: InsightsPatternSummary = .empty
    var personalGrowth: PersonalGrowthSnapshot = .empty
    var retentionInsights: RetentionInsightsSnapshot = .empty
    var triggerLibrary: TriggerLibrarySnapshot = .empty
    
    @MainActor
    func recalculate(
        timeRangeDays: Int, // 7 or 30
        moodEntries: [MoodEntry],
        moodCheckIns: [MoodCheckIn],
        thoughtRecords: [ThoughtRecord],
        exerciseCompletions: [ExerciseCompletion],
        journalEntries: [JournalEntry],
        flexibleJournalEntries: [FlexibleJournalEntry],
        breathingSessions: [BreathingSession],
        moodGoalValue: Int
    ) async {
        isCalculating = true

        // Snapshot query-backed models on the caller's actor so the detached
        // task only works with value types.
        let moods = moodEntries.map {
            MoodSnapshot(
                createdAt: $0.createdAt,
                moodScore: $0.moodScore,
                emotions: $0.emotions,
                triggers: $0.triggers,
                sensations: $0.sensations,
                contextTags: $0.contextTags,
                activityTags: $0.activityTags,
                notes: $0.notes,
                intensity: $0.intensity,
                anxietyStressScore: $0.anxietyStressScore,
                sleepQualityScore: $0.sleepQualityScore,
                energyScore: $0.energyScore
            )
        }
        let checkIns = moodCheckIns.map {
            MoodCheckInSnapshot(
                createdAt: $0.createdAt,
                moodScore: MoodEntry.clampMoodScore($0.moodScore),
                notes: $0.notes
            )
        }
        let thoughts = thoughtRecords.map {
            ThoughtSnapshot(
                createdAt: $0.createdAt,
                situation: $0.situation,
                automaticThought: $0.automaticThought,
                intensityBefore: $0.intensityBefore,
                intensityAfter: $0.intensityAfter,
                emotions: $0.emotions,
                distortions: $0.distortions,
                balancedThought: $0.balancedThought,
                isDraft: $0.isDraft,
                isComplete: $0.isComplete,
                completedAt: $0.completedAt,
                isSavedReframe: $0.isSavedReframe,
                isFavoriteReframe: $0.isFavoriteReframe
            )
        }
        let exercises = exerciseCompletions.map {
            ExerciseSnapshot(
                createdAt: $0.createdAt,
                exerciseID: $0.exerciseID,
                adaptiveMode: ExerciseCompletion.normalizedAdaptiveMode($0.adaptiveMode)
            )
        }
        let journals = journalEntries.map {
            JournalSnapshot(createdAt: $0.createdAt, title: $0.title, body: $0.body)
        }
        let flexibleJournals = flexibleJournalEntries.map {
            FlexibleJournalSnapshot(date: $0.date, responses: $0.responses)
        }
        let breathing = breathingSessions.map {
            BreathingSnapshot(createdAt: $0.createdAt)
        }

        let results = await Task.detached(priority: .userInitiated) {
            let calendar = Calendar.current
            let now = Date()
            let moodScores = moods.map {
                MoodScoreSnapshot(createdAt: $0.createdAt, moodScore: $0.moodScore)
            } + checkIns.map {
                MoodScoreSnapshot(createdAt: $0.createdAt, moodScore: $0.moodScore)
            }
            
            // 1. Cutoffs
            let rangeCutoff = calendar.date(byAdding: .day, value: -timeRangeDays, to: now) ?? now
            let thirtyDaysCutoff = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            let eightWeeksCutoff = calendar.date(byAdding: .weekOfYear, value: -8, to: now) ?? now
            
            // 2. Filter data for the primary time range
            let filteredMoods = moods.filter { $0.createdAt >= rangeCutoff }
            let filteredThoughts = thoughts.filter { $0.createdAt >= rangeCutoff }
            let filteredCompletedThoughts = filteredThoughts.filter { $0.isComplete }
            let filteredExercises = exercises.filter { $0.createdAt >= rangeCutoff }
            let filteredMoodScores = moodScores.filter { $0.createdAt >= rangeCutoff }
            
            // 3. Active days
            let moodDays = filteredMoodScores.map { calendar.startOfDay(for: $0.createdAt) }
            let thoughtDays = filteredCompletedThoughts.map { calendar.startOfDay(for: $0.completedAt ?? $0.createdAt) }
            let exerciseDays = filteredExercises.map { calendar.startOfDay(for: $0.createdAt) }
            let journalDaysRange = journals.filter { $0.createdAt >= rangeCutoff }.map { calendar.startOfDay(for: $0.createdAt) }
            
            let activeDaysCount = Set(moodDays + thoughtDays + exerciseDays + journalDaysRange).count
            
            // 4. Daily Mood Averages (for the timeRange)
            let dailyGroups = Dictionary(grouping: filteredMoodScores) { calendar.startOfDay(for: $0.createdAt) }
            let dailyMoodAverages = dailyGroups.map { day, entries in
                DailyMoodAverage(date: day, averageScore: Double(entries.map(\.moodScore).reduce(0, +)) / Double(entries.count))
            }.sorted { $0.date < $1.date }
            
            // 5. Overall Averages (for the timeRange)
            let averageMood = filteredMoodScores.isEmpty ? nil : Double(filteredMoodScores.map(\.moodScore).reduce(0, +)) / Double(filteredMoodScores.count)
            let overallMoodAverage = averageMood ?? 0
            
            let validThoughts = filteredCompletedThoughts.filter { (0...100).contains($0.intensityBefore) && (0...100).contains($0.intensityAfter) }
            let averageIntensityImprovement: Int? = validThoughts.isEmpty ? nil : (validThoughts.map { $0.intensityBefore - $0.intensityAfter }.reduce(0, +) / validThoughts.count)
            
            // 6. Goals Progress
            let consistencyGoalTarget = max(3, Int((Double(timeRangeDays) * 0.7).rounded()))
            let consistencyProgress = consistencyGoalTarget > 0 ? min(1, Double(activeDaysCount) / Double(consistencyGoalTarget)) : 0
            
            let moodGoalProgress = filteredMoodScores.isEmpty ? 0 : Double(filteredMoodScores.filter { $0.moodScore >= moodGoalValue }.count) / Double(filteredMoodScores.count)
            
            let thoughtGoalProgress = min(1, Double(max(0, averageIntensityImprovement ?? 0)) / 15.0)
            
            let exerciseGoalTarget = max(2, timeRangeDays / 4)
            let exerciseProgress = exerciseGoalTarget > 0 ? min(1, Double(filteredExercises.count) / Double(exerciseGoalTarget)) : 0
            
            let milestonesCompleted = [consistencyProgress, moodGoalProgress, thoughtGoalProgress, exerciseProgress].filter { $0 >= 1.0 }.count
            
            // 7. Top Metrics (for time range)
            var emotionCounts = [String: Int]()
            var triggerCounts = [String: Int]()
            var distortionCounts = [String: Int]()
            
            for mood in filteredMoods {
                for emotion in mood.emotions {
                    let e = emotion.trimmingCharacters(in: .whitespaces).lowercased()
                    if !e.isEmpty { emotionCounts[e, default: 0] += 1 }
                }
                for trigger in mood.triggers {
                    let t = trigger.trimmingCharacters(in: .whitespaces).lowercased()
                    if !t.isEmpty { triggerCounts[t, default: 0] += 1 }
                }
            }
            for thought in filteredCompletedThoughts {
                for emotion in thought.emotions {
                    let e = emotion.trimmingCharacters(in: .whitespaces).lowercased()
                    if !e.isEmpty { emotionCounts[e, default: 0] += 1 }
                }
                for distortion in thought.distortions {
                    let d = distortion.trimmingCharacters(in: .whitespaces).lowercased()
                    if !d.isEmpty { distortionCounts[d, default: 0] += 1 }
                }
            }
            
            let topEmotions = emotionCounts.map { EmotionCount(name: $0.key.capitalized, count: $0.value) }
                .sorted { $0.count > $1.count }.prefix(5).map { $0 }
            
            let topTriggers = triggerCounts.map { TriggerCount(name: $0.key.capitalized, count: $0.value) }
                .sorted { $0.count > $1.count }.prefix(5).map { $0 }

            let topDistortions = distortionCounts.map { DistortionCount(name: $0.key.capitalized, count: $0.value) }
                .sorted { $0.count > $1.count }.prefix(5).map { $0 }

            let thoughtRecordStats = makeThoughtRecordCompletionStats(from: filteredThoughts)

            let contextTagGroups = Dictionary(grouping: filteredMoods.flatMap { mood in
                mood.contextTags.map { tag in
                    (tag: tag.trimmingCharacters(in: .whitespacesAndNewlines), moodScore: mood.moodScore)
                }
                .filter { !$0.tag.isEmpty }
            }) { $0.tag.lowercased() }

            let contextTagCorrelations = contextTagGroups.compactMap { _, values -> ContextTagMoodCorrelation? in
                guard !values.isEmpty else { return nil }
                let average = Double(values.map { $0.moodScore }.reduce(0, +)) / Double(values.count)
                let displayName = values.first?.tag.capitalized ?? ""
                return ContextTagMoodCorrelation(
                    name: displayName,
                    entryCount: values.count,
                    averageMood: average,
                    deltaFromOverall: average - overallMoodAverage
                )
            }
            .sorted { first, second in
                let firstMagnitude = abs(first.deltaFromOverall)
                let secondMagnitude = abs(second.deltaFromOverall)
                if firstMagnitude == secondMagnitude {
                    return first.entryCount > second.entryCount
                }
                return firstMagnitude > secondMagnitude
            }
            .prefix(5)
            .map { $0 }
            
            // 8. Weekly Averages (last 8 weeks)
            let eightWeeksMoodScores = moodScores.filter { $0.createdAt >= eightWeeksCutoff }
            let weeklyGroups = Dictionary(grouping: eightWeeksMoodScores) { entry in
                calendar.dateInterval(of: .weekOfYear, for: entry.createdAt)?.start ?? calendar.startOfDay(for: entry.createdAt)
            }
            let weeklyMoodAverages = weeklyGroups.map { weekStart, entries in
                WeeklyMoodAverage(weekStart: weekStart, averageScore: Double(entries.map(\.moodScore).reduce(0, +)) / Double(entries.count))
            }.sorted { $0.weekStart < $1.weekStart }
            
            // 9. Mood Volatility (last 30 days)
            let thirtyDaysMoodScores = moodScores.filter { $0.createdAt >= thirtyDaysCutoff }
            let thirtyDailyGroups = Dictionary(grouping: thirtyDaysMoodScores) { calendar.startOfDay(for: $0.createdAt) }
            let thirtyAveragePairs = thirtyDailyGroups.map { day, entries in
                (date: day, avg: Double(entries.map(\.moodScore).reduce(0, +)) / Double(entries.count))
            }.sorted { $0.date < $1.date }
            
            var volatility: Double? = nil
            if thirtyAveragePairs.count >= 2 {
                var totalDiff = 0.0
                for i in 1..<thirtyAveragePairs.count {
                    totalDiff += abs(thirtyAveragePairs[i].avg - thirtyAveragePairs[i-1].avg)
                }
                volatility = totalDiff / Double(thirtyAveragePairs.count - 1)
            }

            let patternSummary = makePatternSummary(
                moods: moods,
                moodScores: moodScores,
                exercises: exercises,
                calendar: calendar,
                now: now
            )
            let personalGrowth = makePersonalGrowthSnapshot(
                moods: moods,
                checkIns: checkIns,
                thoughts: thoughts.filter { $0.isComplete },
                exercises: exercises,
                journals: journals,
                flexibleJournals: flexibleJournals,
                calendar: calendar,
                now: now
            )
            let retentionInsights = RetentionInsightsService.snapshot(
                moods: moods.map {
                    RetentionMoodEvent(
                        createdAt: $0.createdAt,
                        moodScore: $0.moodScore,
                        triggers: $0.triggers,
                        energyScore: $0.energyScore
                    )
                },
                checkIns: checkIns.map { RetentionDatedEvent(createdAt: $0.createdAt) },
                thoughts: thoughts.filter { $0.isComplete }.map {
                    RetentionThoughtEvent(
                        createdAt: $0.completedAt ?? $0.createdAt,
                        intensityBefore: $0.intensityBefore,
                        intensityAfter: $0.intensityAfter
                    )
                },
                exerciseCompletions: exercises.map { RetentionDatedEvent(createdAt: $0.createdAt) },
                journalEntries: journals.map { RetentionDatedEvent(createdAt: $0.createdAt) },
                flexibleJournalEntries: flexibleJournals.map { RetentionDatedEvent(createdAt: $0.date) },
                breathingSessions: breathing.map { RetentionDatedEvent(createdAt: $0.createdAt) },
                referenceDate: now,
                calendar: calendar
            )
            let triggerLibrary = PersonalizedTriggerLibraryService.snapshot(
                events: makeTriggerEvents(
                    moods: moods,
                    checkIns: checkIns,
                    thoughts: thoughts,
                    journals: journals,
                    flexibleJournals: flexibleJournals
                ),
                completedToolIDs: Set(exercises.map(\.exerciseID)),
                referenceDate: now,
                calendar: calendar
            )
            
            // 10. Streaks (across all time)
            let allMoodDays = moodScores.map { calendar.startOfDay(for: $0.createdAt) }
            let allThoughtDays = thoughts.filter { $0.isComplete }.map { calendar.startOfDay(for: $0.completedAt ?? $0.createdAt) }
            let allExerciseDays = exercises.map { calendar.startOfDay(for: $0.createdAt) }
            let allJournalDays = journals.map { calendar.startOfDay(for: $0.createdAt) }
            
            let allActiveDates = Set(allMoodDays + allThoughtDays + allExerciseDays + allJournalDays).sorted()
            
            var cStreak = 0
            var lStreak = 0
            let today = calendar.startOfDay(for: now)
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                return InsightsCalculationResult(
                    activeDaysCount: activeDaysCount,
                    dailyMoodAverages: dailyMoodAverages,
                    averageMood: averageMood,
                    averageIntensityImprovement: averageIntensityImprovement,
                    consistencyGoalTarget: consistencyGoalTarget,
                    consistencyProgress: consistencyProgress,
                    moodGoalProgress: moodGoalProgress,
                    thoughtGoalProgress: thoughtGoalProgress,
                    exerciseGoalTarget: exerciseGoalTarget,
                    exerciseProgress: exerciseProgress,
                    milestonesCompleted: milestonesCompleted,
                    topEmotions: topEmotions,
                    topTriggers: topTriggers,
                    topDistortions: topDistortions,
                    thoughtRecordStats: thoughtRecordStats,
                    contextTagCorrelations: contextTagCorrelations,
                    weeklyMoodAverages: weeklyMoodAverages,
                    moodVolatilityLast30Days: volatility,
                    currentStreak: 0,
                    longestStreak: 0,
                    patternSummary: patternSummary,
                    personalGrowth: personalGrowth,
                    retentionInsights: retentionInsights,
                    triggerLibrary: triggerLibrary
                )
            }
            
            if !allActiveDates.isEmpty {
                var currentChain = 1
                var maxChain = 1
                
                for i in 1..<allActiveDates.count {
                    let prev = allActiveDates[i-1]
                    let curr = allActiveDates[i]
                    let daysDiff = calendar.dateComponents([.day], from: prev, to: curr).day ?? 0
                    
                    if daysDiff == 1 {
                        currentChain += 1
                        maxChain = max(maxChain, currentChain)
                    } else if daysDiff > 1 {
                        currentChain = 1
                    }
                }
                lStreak = maxChain
                
                // Determine current streak
                // If today or yesterday is the last active date, calculate backwards from the last active date
                if let lastActive = allActiveDates.last {
                    if lastActive >= yesterday {
                        var rollingStreak = 1
                        for i in (0..<(allActiveDates.count - 1)).reversed() {
                            let curr = allActiveDates[i+1]
                            let prev = allActiveDates[i]
                            let daysDiff = calendar.dateComponents([.day], from: prev, to: curr).day ?? 0
                            if daysDiff == 1 {
                                rollingStreak += 1
                            } else {
                                break
                            }
                        }
                        cStreak = rollingStreak
                    } else {
                        cStreak = 0 // broke the streak
                    }
                }
            }
            
            return InsightsCalculationResult(
                activeDaysCount: activeDaysCount,
                dailyMoodAverages: dailyMoodAverages,
                averageMood: averageMood,
                averageIntensityImprovement: averageIntensityImprovement,
                consistencyGoalTarget: consistencyGoalTarget,
                consistencyProgress: consistencyProgress,
                moodGoalProgress: moodGoalProgress,
                thoughtGoalProgress: thoughtGoalProgress,
                exerciseGoalTarget: exerciseGoalTarget,
                exerciseProgress: exerciseProgress,
                milestonesCompleted: milestonesCompleted,
                topEmotions: topEmotions,
                topTriggers: topTriggers,
                topDistortions: topDistortions,
                thoughtRecordStats: thoughtRecordStats,
                contextTagCorrelations: contextTagCorrelations,
                weeklyMoodAverages: weeklyMoodAverages,
                moodVolatilityLast30Days: volatility,
                currentStreak: cStreak,
                longestStreak: lStreak,
                patternSummary: patternSummary,
                personalGrowth: personalGrowth,
                retentionInsights: retentionInsights,
                triggerLibrary: triggerLibrary
            )
        }.value
        
        await MainActor.run {
            self.activeDaysCount = results.activeDaysCount
            self.dailyMoodAverages = results.dailyMoodAverages
            self.averageMood = results.averageMood
            self.averageIntensityImprovement = results.averageIntensityImprovement
            self.consistencyGoalTarget = results.consistencyGoalTarget
            self.consistencyProgress = results.consistencyProgress
            self.moodGoalProgress = results.moodGoalProgress
            self.thoughtGoalProgress = results.thoughtGoalProgress
            self.exerciseGoalTarget = results.exerciseGoalTarget
            self.exerciseProgress = results.exerciseProgress
            self.milestonesCompleted = results.milestonesCompleted
            self.topEmotions = results.topEmotions
            self.topTriggers = results.topTriggers
            self.topDistortions = results.topDistortions
            self.thoughtRecordStats = results.thoughtRecordStats
            self.contextTagCorrelations = results.contextTagCorrelations
            self.weeklyMoodAverages = results.weeklyMoodAverages
            self.moodVolatilityLast30Days = results.moodVolatilityLast30Days
            self.currentStreak = results.currentStreak
            self.longestStreak = results.longestStreak
            self.patternSummary = results.patternSummary
            self.personalGrowth = results.personalGrowth
            self.retentionInsights = results.retentionInsights
            self.triggerLibrary = results.triggerLibrary
            
            self.isCalculating = false
        }
    }

    var dashboardSnapshot: InsightsDashboardSnapshot {
        InsightsDashboardSnapshot(
            activeDaysCount: activeDaysCount,
            dailyMoodAverages: dailyMoodAverages,
            weeklyMoodAverages: weeklyMoodAverages,
            moodVolatilityLast30Days: moodVolatilityLast30Days,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            averageMood: averageMood,
            averageIntensityImprovement: averageIntensityImprovement,
            consistencyGoalTarget: consistencyGoalTarget,
            consistencyProgress: consistencyProgress,
            moodGoalProgress: moodGoalProgress,
            thoughtGoalProgress: thoughtGoalProgress,
            exerciseGoalTarget: exerciseGoalTarget,
            exerciseProgress: exerciseProgress,
            milestonesCompleted: milestonesCompleted,
            topEmotions: topEmotions,
            topTriggers: topTriggers,
            topDistortions: topDistortions,
            thoughtRecordStats: thoughtRecordStats,
            contextTagCorrelations: contextTagCorrelations,
            patternSummary: patternSummary,
            personalGrowth: personalGrowth,
            triggerLibrary: triggerLibrary
        )
    }
}

private nonisolated func makeThoughtRecordCompletionStats(from thoughts: [ThoughtSnapshot]) -> ThoughtRecordCompletionStats {
    let completed = thoughts.filter { $0.isComplete }
    let drafts = thoughts.filter { !$0.isComplete }
    let validIntensityChanges = completed
        .filter { (0...100).contains($0.intensityBefore) && (0...100).contains($0.intensityAfter) }
        .map { $0.intensityBefore - $0.intensityAfter }
    let averageChange = validIntensityChanges.isEmpty
        ? nil
        : validIntensityChanges.reduce(0, +) / validIntensityChanges.count

    var distortionCounts = [String: (displayName: String, count: Int)]()
    for thought in completed {
        for distortion in thought.distortions {
            let trimmed = distortion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            let existing = distortionCounts[key]
            distortionCounts[key] = (existing?.displayName ?? trimmed, (existing?.count ?? 0) + 1)
        }
    }

    let recurringDistortions = distortionCounts.values
        .filter { $0.count >= 2 }
        .map { DistortionCount(name: $0.displayName, count: $0.count) }
        .sorted { first, second in
            if first.count == second.count {
                return first.name < second.name
            }
            return first.count > second.count
        }

    return ThoughtRecordCompletionStats(
        completedCount: completed.count,
        draftCount: drafts.count,
        savedReframeCount: completed.filter { $0.isSavedReframe && !$0.balancedThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count,
        favoriteReframeCount: completed.filter { $0.isFavoriteReframe && !$0.balancedThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count,
        averageIntensityChange: averageChange,
        recurringDistortions: recurringDistortions
    )
}

private func makeTriggerEvents(
    moods: [MoodSnapshot],
    checkIns: [MoodCheckInSnapshot],
    thoughts: [ThoughtSnapshot],
    journals: [JournalSnapshot],
    flexibleJournals: [FlexibleJournalSnapshot]
) -> [TriggerSourceEvent] {
    moods.map { mood in
        TriggerSourceEvent(
            date: mood.createdAt,
            sourceKind: .checkIn,
            explicitTags: mood.triggers,
            text: (mood.contextTags + mood.activityTags + [mood.notes ?? ""]).joined(separator: " "),
            moodScore: mood.moodScore,
            stressScore: mood.anxietyStressScore
        )
    } + checkIns.map { checkIn in
        TriggerSourceEvent(
            date: checkIn.createdAt,
            sourceKind: .checkIn,
            text: checkIn.notes ?? "",
            moodScore: checkIn.moodScore
        )
    } + thoughts.map { thought in
        TriggerSourceEvent(
            date: thought.createdAt,
            sourceKind: .thoughtRecord,
            text: [thought.situation, thought.automaticThought].joined(separator: " "),
            stressScore: thought.intensityBefore > 0 ? max(1, min(10, Int((Double(thought.intensityBefore) / 10.0).rounded()))) : nil
        )
    } + journals.map { journal in
        TriggerSourceEvent(
            date: journal.createdAt,
            sourceKind: .journal,
            text: [journal.title, journal.body].joined(separator: " ")
        )
    } + flexibleJournals.map { journal in
        TriggerSourceEvent(
            date: journal.date,
            sourceKind: .journal,
            text: journal.responses.joined(separator: " ")
        )
    }
}

private func makePersonalGrowthSnapshot(
    moods: [MoodSnapshot],
    checkIns: [MoodCheckInSnapshot],
    thoughts: [ThoughtSnapshot],
    exercises: [ExerciseSnapshot],
    journals: [JournalSnapshot],
    flexibleJournals: [FlexibleJournalSnapshot],
    calendar: Calendar,
    now: Date
) -> PersonalGrowthSnapshot {
    let events = moods.map { PersonalGrowthActivityEvent(date: $0.createdAt, emotionTags: $0.emotions) }
        + checkIns.map { PersonalGrowthActivityEvent(date: $0.createdAt) }
        + thoughts.map { PersonalGrowthActivityEvent(date: $0.createdAt, emotionTags: $0.emotions) }
        + exercises.map { PersonalGrowthActivityEvent(date: $0.createdAt) }
        + journals.map { PersonalGrowthActivityEvent(date: $0.createdAt) }
        + flexibleJournals.map { PersonalGrowthActivityEvent(date: $0.date) }

    return PersonalGrowthCalculator.snapshot(
        events: events,
        referenceDate: now,
        calendar: calendar
    )
}

private enum InsightNameStyle {
    case title
    case lower
}

private func legacyMakePatternSummary(
    moods: [MoodSnapshot],
    moodScores: [MoodScoreSnapshot],
    calendar: Calendar,
    now: Date
) -> InsightsPatternSummary {
    let activityMoodAverages = legacyMakeActivityMoodAverages(from: moods)
    let activityTagsByMoodDay = makeActivityTagsByMoodDay(
        moods: moods,
        moodScores: moodScores,
        calendar: calendar
    )
    let triggerEmotionPatterns = legacyMakeTriggerEmotionPatterns(from: moods)
    let anxietySensations = makeAnxietySensations(from: moods)
    let moodTrends = [7, 30].compactMap {
        makeMoodTrend(days: $0, moodScores: moodScores, calendar: calendar, now: now)
    }
    let checkInConsistency = makeCheckInConsistency(
        moodScores: moodScores,
        calendar: calendar,
        now: now
    )
    let overallMoodAverage = moodScores.isEmpty ? nil : Double(moodScores.map(\.moodScore).reduce(0, +)) / Double(moodScores.count)

    let insightCards = makePlainLanguagePatternInsights(
        activityMoodAverages: activityMoodAverages,
        lowMoodActivityTags: activityTagsByMoodDay.low,
        highMoodActivityTags: activityTagsByMoodDay.high,
        triggerEmotionPatterns: triggerEmotionPatterns,
        anxietySensations: anxietySensations,
        moodTrends: moodTrends,
        checkInConsistency: checkInConsistency,
        calendarPatterns: .empty,
        overallMoodAverage: overallMoodAverage
    )

    return InsightsPatternSummary(
        activityMoodAverages: activityMoodAverages,
        lowMoodActivityTags: activityTagsByMoodDay.low,
        highMoodActivityTags: activityTagsByMoodDay.high,
        triggerEmotionPatterns: triggerEmotionPatterns,
        anxietySensations: anxietySensations,
        moodTrends: moodTrends,
        checkInConsistency: checkInConsistency,
        adaptiveModeUsage: [],
        calendarPatterns: .empty,
        insightCards: insightCards,
        personalCopingPlan: makePersonalCopingPlan(from: moods, calendar: calendar)
    )
}

private func legacyMakeActivityMoodAverages(from moods: [MoodSnapshot]) -> [ActivityMoodAverage] {
    var buckets: [String: (displayName: String, totalMood: Int, count: Int)] = [:]

    for mood in moods {
        for tag in uniqueNormalizedItems(mood.contextTags, style: .title) {
            var bucket = buckets[tag.key] ?? (displayName: tag.displayName, totalMood: 0, count: 0)
            bucket.totalMood += mood.moodScore
            bucket.count += 1
            buckets[tag.key] = bucket
        }
    }

    return buckets.values.map { bucket in
        ActivityMoodAverage(
            name: bucket.displayName,
            entryCount: bucket.count,
            averageMood: Double(bucket.totalMood) / Double(bucket.count)
        )
    }
    .sorted { first, second in
        if first.averageMood == second.averageMood {
            if first.entryCount == second.entryCount {
                return first.name < second.name
            }
            return first.entryCount > second.entryCount
        }
        return first.averageMood > second.averageMood
    }
}

private func makeActivityTagsByMoodDay(
    moods: [MoodSnapshot],
    moodScores: [MoodScoreSnapshot],
    calendar: Calendar
) -> (low: [ActivityTagFrequency], high: [ActivityTagFrequency]) {
    let dailyAverages = dailyMoodAverages(from: moodScores, calendar: calendar)
    let lowMoodDays = Set(dailyAverages.filter { $0.average <= 4.0 }.map(\.date))
    let highMoodDays = Set(dailyAverages.filter { $0.average >= 7.0 }.map(\.date))
    let moodEntriesByDay = Dictionary(grouping: moods) { calendar.startOfDay(for: $0.createdAt) }

    func frequencies(for days: Set<Date>) -> [ActivityTagFrequency] {
        var buckets: [String: (displayName: String, count: Int)] = [:]

        for day in days {
            guard let entries = moodEntriesByDay[day] else { continue }
            var tagsForDay: [String: String] = [:]

            for entry in entries {
                for tag in uniqueNormalizedItems(entry.contextTags, style: .title) where tagsForDay[tag.key] == nil {
                    tagsForDay[tag.key] = tag.displayName
                }
            }

            for (key, displayName) in tagsForDay {
                var bucket = buckets[key] ?? (displayName: displayName, count: 0)
                bucket.count += 1
                buckets[key] = bucket
            }
        }

        return buckets.values.map {
            ActivityTagFrequency(name: $0.displayName, dayCount: $0.count)
        }
        .sorted { first, second in
            if first.dayCount == second.dayCount {
                return first.name < second.name
            }
            return first.dayCount > second.dayCount
        }
    }

    return (low: frequencies(for: lowMoodDays), high: frequencies(for: highMoodDays))
}

private func legacyMakeTriggerEmotionPatterns(from moods: [MoodSnapshot]) -> [TriggerEmotionPattern] {
    var pairBuckets: [String: (trigger: String, emotion: String, count: Int)] = [:]

    for mood in moods {
        let triggers = uniqueNormalizedItems(mood.triggers, style: .title)
            .filter { $0.key != "nothing specific" }
        let emotions = uniqueNormalizedItems(mood.emotions, style: .title)

        guard !triggers.isEmpty, !emotions.isEmpty else { continue }

        for trigger in triggers {
            for emotion in emotions {
                let key = "\(trigger.key)|\(emotion.key)"
                var bucket = pairBuckets[key] ?? (trigger: trigger.displayName, emotion: emotion.displayName, count: 0)
                bucket.count += 1
                pairBuckets[key] = bucket
            }
        }
    }

    let pairs = pairBuckets.values.map {
        TriggerEmotionPattern(trigger: $0.trigger, emotion: $0.emotion, count: $0.count)
    }

    return Dictionary(grouping: pairs, by: \.trigger)
        .compactMap { _, values in
            values.sorted { first, second in
                if first.count == second.count {
                    return first.emotion < second.emotion
                }
                return first.count > second.count
            }
            .first
        }
        .sorted { first, second in
            if first.count == second.count {
                return first.trigger < second.trigger
            }
            return first.count > second.count
        }
}

private func makeAnxietySensations(from moods: [MoodSnapshot]) -> [SensationCount] {
    var buckets: [String: (displayName: String, count: Int)] = [:]

    for mood in moods where isAnxietyRelated(mood) {
        for sensation in uniqueNormalizedItems(mood.sensations, style: .lower) {
            var bucket = buckets[sensation.key] ?? (displayName: sensation.displayName, count: 0)
            bucket.count += 1
            buckets[sensation.key] = bucket
        }
    }

    return buckets.values.map {
        SensationCount(name: $0.displayName, count: $0.count)
    }
    .sorted { first, second in
        if first.count == second.count {
            return first.name < second.name
        }
        return first.count > second.count
    }
}

private func makeMoodTrend(
    days: Int,
    moodScores: [MoodScoreSnapshot],
    calendar: Calendar,
    now: Date
) -> MoodTrendInsight? {
    guard let cutoff = calendar.date(byAdding: .day, value: -days, to: now),
          let midpoint = calendar.date(byAdding: .day, value: -(days / 2), to: now)
    else {
        return nil
    }

    let dailyAverages = dailyMoodAverages(
        from: moodScores.filter { $0.createdAt >= cutoff },
        calendar: calendar
    )
    guard dailyAverages.count >= 2 else { return nil }

    let midpointDay = calendar.startOfDay(for: midpoint)
    let earlier = dailyAverages.filter { $0.date < midpointDay }
    let recent = dailyAverages.filter { $0.date >= midpointDay }
    guard !earlier.isEmpty, !recent.isEmpty else { return nil }

    let earlierAverage = average(earlier.map(\.average))
    let recentAverage = average(recent.map(\.average))
    let delta = recentAverage - earlierAverage
    let direction: MoodTrendDirection

    if abs(delta) < 0.25 {
        direction = .steady
    } else if delta > 0 {
        direction = .higher
    } else {
        direction = .lower
    }

    return MoodTrendInsight(
        windowDays: days,
        direction: direction,
        delta: delta,
        earlierAverage: earlierAverage,
        recentAverage: recentAverage,
        daysWithData: dailyAverages.count
    )
}

private func makeCheckInConsistency(
    moodScores: [MoodScoreSnapshot],
    calendar: Calendar,
    now: Date
) -> CheckInConsistencyInsight {
    let today = calendar.startOfDay(for: now)
    let checkInDays = Set(moodScores.map { calendar.startOfDay(for: $0.createdAt) }).sorted()
    guard !checkInDays.isEmpty else { return .empty }

    let sevenDayStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
    let thirtyDayStart = calendar.date(byAdding: .day, value: -29, to: today) ?? today
    let daysCheckedInLast7 = checkInDays.filter { $0 >= sevenDayStart && $0 <= today }.count
    let daysCheckedInLast30 = checkInDays.filter { $0 >= thirtyDayStart && $0 <= today }.count

    return CheckInConsistencyInsight(
        daysCheckedInLast7: daysCheckedInLast7,
        daysCheckedInLast30: daysCheckedInLast30,
        currentStreak: currentStreak(in: checkInDays, calendar: calendar, today: today),
        longestStreak: longestStreak(in: checkInDays, calendar: calendar),
        totalCheckInDays: checkInDays.count
    )
}

private func makePlainLanguagePatternInsights(
    activityMoodAverages: [ActivityMoodAverage],
    lowMoodActivityTags: [ActivityTagFrequency],
    highMoodActivityTags: [ActivityTagFrequency],
    triggerEmotionPatterns: [TriggerEmotionPattern],
    anxietySensations: [SensationCount],
    moodTrends: [MoodTrendInsight],
    checkInConsistency: CheckInConsistencyInsight,
    calendarPatterns: CalendarMoodPatternSummary,
    overallMoodAverage: Double?
) -> [PlainLanguagePatternInsight] {
    var cards: [PlainLanguagePatternInsight] = []

    if let topActivity = activityMoodAverages.first {
        let message: String
        if let overallMoodAverage, topActivity.entryCount >= 2, topActivity.averageMood >= overallMoodAverage + 0.25 {
            message = "Your mood tends to be higher in check-ins tagged \(topActivity.name)."
        } else if topActivity.entryCount >= 2 {
            message = "\(topActivity.name) often shows up with an average mood of \(formatMood(topActivity.averageMood))/10."
        } else {
            message = "So far, \(topActivity.name) appears with an average mood of \(formatMood(topActivity.averageMood))/10."
        }

        cards.append(PlainLanguagePatternInsight(
            title: "Activity Mood",
            message: message,
            iconName: "tag",
            occurrenceCount: topActivity.entryCount,
            actionTitle: "Add \(topActivity.name) to my week",
            actionDescription: "A small plan based on an activity pattern from recent check-ins.",
            actionCategory: "Nourishing"
        ))
    }

    if let lowMoodTag = lowMoodActivityTags.first {
        cards.append(PlainLanguagePatternInsight(
            title: "Low Mood Tags",
            message: "Low mood days often include \(joinedNames(lowMoodActivityTags.prefix(2).map(\.name))).",
            iconName: "arrow.down.heart",
            occurrenceCount: lowMoodTag.dayCount,
            actionTitle: "Make \(lowMoodTag.name) easier",
            actionDescription: "Choose one tiny support step before or after this low-mood pattern.",
            actionCategory: "Mastery"
        ))
    }

    if let highMoodTag = highMoodActivityTags.first {
        cards.append(PlainLanguagePatternInsight(
            title: "High Mood Tags",
            message: "High mood days often include \(joinedNames(highMoodActivityTags.prefix(2).map(\.name))).",
            iconName: "arrow.up.heart",
            occurrenceCount: highMoodTag.dayCount,
            actionTitle: "Repeat \(highMoodTag.name)",
            actionDescription: "Make a small plan to repeat a pattern that has been linked with steadier mood.",
            actionCategory: "Nourishing"
        ))
    }

    if let triggerEmotion = triggerEmotionPatterns.first {
        cards.append(PlainLanguagePatternInsight(
            title: "Triggers And Emotions",
            message: "\(triggerEmotion.trigger) appears often with \(triggerEmotion.emotion.lowercased()) emotions.",
            iconName: "arrow.triangle.branch",
            occurrenceCount: triggerEmotion.count,
            actionTitle: "Plan support for \(triggerEmotion.trigger)",
            actionDescription: "Pick one small, doable support step for when this trigger shows up.",
            actionCategory: "Nourishing"
        ))
    }

    if let anxietySensation = anxietySensations.first {
        cards.append(PlainLanguagePatternInsight(
            title: "Anxiety Body Cues",
            message: "Anxiety-related entries often show \(joinedNames(anxietySensations.prefix(2).map(\.name))).",
            iconName: "waveform.path.ecg",
            occurrenceCount: anxietySensation.count,
            actionTitle: "Body cue reset: \(anxietySensation.name)",
            actionDescription: "Schedule a brief grounding or breathing step when this body cue appears.",
            actionCategory: "Nourishing"
        ))
    }

    for trend in moodTrends.sorted(by: { $0.windowDays < $1.windowDays }) {
        cards.append(PlainLanguagePatternInsight(
            title: "\(trend.windowDays)D Mood Trend",
            message: legacyTrendMessage(for: trend),
            iconName: "chart.line.uptrend.xyaxis",
            occurrenceCount: trend.daysWithData,
            actionTitle: trend.direction == .lower ? "Add one steadying step" : "Protect one helpful routine",
            actionDescription: "A small plan based on the recent \(trend.windowDays)-day mood trend.",
            actionCategory: "Nourishing"
        ))
    }

    if checkInConsistency.totalCheckInDays > 0 {
        cards.append(PlainLanguagePatternInsight(
            title: "Check-In Consistency",
            message: "You checked in on \(checkInConsistency.daysCheckedInLast7) of the last 7 days and \(checkInConsistency.daysCheckedInLast30) of the last 30 days.",
            iconName: "calendar.badge.checkmark",
            occurrenceCount: checkInConsistency.daysCheckedInLast7,
            actionTitle: "Set a check-in moment",
            actionDescription: "Schedule a small reminder activity to keep the check-in rhythm easy.",
            actionCategory: "Mastery"
        ))
    }

    return cards
}

private func legacyTrendMessage(for trend: MoodTrendInsight) -> String {
    switch trend.direction {
    case .higher:
        return "Over \(trend.windowDays)D, mood tends to be higher lately."
    case .lower:
        return "Over \(trend.windowDays)D, mood tends to be lower lately."
    case .steady:
        return "Over \(trend.windowDays)D, mood has stayed fairly steady."
    }
}

private func dailyMoodAverages(
    from moodScores: [MoodScoreSnapshot],
    calendar: Calendar
) -> [(date: Date, average: Double)] {
    Dictionary(grouping: moodScores) { calendar.startOfDay(for: $0.createdAt) }
        .map { day, entries in
            (date: day, average: Double(entries.map(\.moodScore).reduce(0, +)) / Double(entries.count))
        }
        .sorted { $0.date < $1.date }
}

private func currentStreak(in sortedDays: [Date], calendar: Calendar, today: Date) -> Int {
    guard !sortedDays.isEmpty,
          let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
          let lastDay = sortedDays.last,
          lastDay >= yesterday
    else {
        return 0
    }

    var streak = 1
    guard sortedDays.count > 1 else { return streak }

    for index in (0..<(sortedDays.count - 1)).reversed() {
        let previous = sortedDays[index]
        let current = sortedDays[index + 1]
        let daysDiff = calendar.dateComponents([.day], from: previous, to: current).day ?? 0

        if daysDiff == 1 {
            streak += 1
        } else if daysDiff > 1 {
            break
        }
    }

    return streak
}

private func longestStreak(in sortedDays: [Date], calendar: Calendar) -> Int {
    guard !sortedDays.isEmpty else { return 0 }
    var current = 1
    var longest = 1

    for index in 1..<sortedDays.count {
        let previous = sortedDays[index - 1]
        let day = sortedDays[index]
        let daysDiff = calendar.dateComponents([.day], from: previous, to: day).day ?? 0

        if daysDiff == 1 {
            current += 1
            longest = max(longest, current)
        } else if daysDiff > 1 {
            current = 1
        }
    }

    return longest
}

private func isAnxietyRelated(_ mood: MoodSnapshot) -> Bool {
    uniqueNormalizedItems(mood.emotions, style: .lower).contains { emotion in
        emotion.key.contains("anxi") ||
        emotion.key.contains("stress") ||
        emotion.key.contains("panic") ||
        emotion.key.contains("worr") ||
        emotion.key.contains("nervous") ||
        emotion.key.contains("overwhelm") ||
        emotion.key.contains("tense")
    }
}

private func uniqueNormalizedItems(
    _ values: [String],
    style: InsightNameStyle
) -> [(key: String, displayName: String)] {
    var seen = Set<String>()
    var items: [(key: String, displayName: String)] = []

    for value in values {
        guard let item = normalizedItem(value, style: style), seen.insert(item.key).inserted else {
            continue
        }
        items.append(item)
    }

    return items
}

private func normalizedItem(
    _ value: String,
    style: InsightNameStyle
) -> (key: String, displayName: String)? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let key = trimmed
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        .lowercased()
    let displayName: String

    switch style {
    case .title:
        displayName = trimmed.capitalized
    case .lower:
        displayName = trimmed.lowercased()
    }

    return (key: key, displayName: displayName)
}

private func average(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
}

private func formatMood(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1)))
}

private func joinedNames<S: Sequence>(_ values: S) -> String where S.Element == String {
    let names = Array(values)

    switch names.count {
    case 0:
        return ""
    case 1:
        return names[0]
    case 2:
        return "\(names[0]) and \(names[1])"
    default:
        return "\(names.dropLast().joined(separator: ", ")), and \(names[names.count - 1])"
    }
}

private func makePatternSummary(
    moods: [MoodSnapshot],
    moodScores: [MoodScoreSnapshot],
    exercises: [ExerciseSnapshot],
    calendar: Calendar,
    now: Date
) -> InsightsPatternSummary {
    let activityMoodAverages = makeActivityMoodAverages(from: moods)
    let lowMoodActivityTags = makeActivityFrequencies(
        from: moods,
        moodScores: moodScores,
        calendar: calendar,
        matchingDailyAverage: { $0 <= 4.0 }
    )
    let highMoodActivityTags = makeActivityFrequencies(
        from: moods,
        moodScores: moodScores,
        calendar: calendar,
        matchingDailyAverage: { $0 >= 7.0 }
    )
    let triggerEmotionPatterns = makeTriggerEmotionPatterns(from: moods)
    let anxietySensations = makeAnxietySensationCounts(from: moods)
    let moodTrends = makeMoodTrendInsights(
        from: moodScores,
        calendar: calendar,
        now: now
    )
    let checkInConsistency = makeCheckInConsistency(
        from: moodScores,
        calendar: calendar,
        now: now
    )
    let adaptiveModeUsage = makeAdaptiveModeUsage(from: exercises)
    let calendarPatterns = CalendarMoodPatternCalculator.summary(
        moods: moods.map {
            CalendarMoodPatternMoodEvent(
                createdAt: $0.createdAt,
                moodScore: $0.moodScore,
                stressScore: $0.anxietyStressScore,
                sleepQualityScore: $0.sleepQualityScore,
                triggers: $0.triggers
            )
        },
        exerciseCompletions: exercises.map {
            CalendarMoodPatternExerciseEvent(createdAt: $0.createdAt)
        },
        calendar: calendar
    )
    let insightCards = makePlainLanguagePatternCards(
        triggerPatternCards: makeTriggerPatternCards(
            from: moods,
            calendar: calendar,
            now: now
        ),
        activityMoodAverages: activityMoodAverages,
        lowMoodActivityTags: lowMoodActivityTags,
        highMoodActivityTags: highMoodActivityTags,
        triggerEmotionPatterns: triggerEmotionPatterns,
        anxietySensations: anxietySensations,
        moodTrends: moodTrends,
        checkInConsistency: checkInConsistency,
        calendarPatterns: calendarPatterns,
        overallMoodAverage: moodScores.isEmpty ? nil : Double(moodScores.map(\.moodScore).reduce(0, +)) / Double(moodScores.count)
    )

    return InsightsPatternSummary(
        activityMoodAverages: activityMoodAverages,
        lowMoodActivityTags: lowMoodActivityTags,
        highMoodActivityTags: highMoodActivityTags,
        triggerEmotionPatterns: triggerEmotionPatterns,
        anxietySensations: anxietySensations,
        moodTrends: moodTrends,
        checkInConsistency: checkInConsistency,
        adaptiveModeUsage: adaptiveModeUsage,
        calendarPatterns: calendarPatterns,
        insightCards: insightCards,
        personalCopingPlan: makePersonalCopingPlan(from: moods, calendar: calendar)
    )
}

private func makeAdaptiveModeUsage(from exercises: [ExerciseSnapshot]) -> [AdaptiveModeUsageCount] {
    let counts = Dictionary(grouping: exercises) { exercise in
        DailyPlanMode(rawValue: exercise.adaptiveMode) ?? .full
    }

    return counts.map { mode, items in
        AdaptiveModeUsageCount(mode: mode, count: items.count)
    }
    .sorted {
        if $0.count == $1.count {
            return $0.mode.title < $1.mode.title
        }
        return $0.count > $1.count
    }
}

private func makePersonalCopingPlan(
    from moods: [MoodSnapshot],
    calendar: Calendar
) -> [PersonalCopingPlanItem] {
    var items: [PersonalCopingPlanItem] = []
    let lowMoodIsolationMatches = moods.filter { mood in
        mood.moodScore <= 4 && mood.containsAnyLabel(matching: [
            "alone", "isolat", "withdraw", "lonel", "avoid", "staying in", "no one", "social"
        ])
    }

    if lowMoodIsolationMatches.count >= 2 {
        items.append(
            PersonalCopingPlanItem(
                title: "Low Mood + Isolation",
                whenText: "When low mood comes with pulling away",
                tryText: "Text one safe person or send a simple check-in.",
                reason: "This pattern appears in \(lowMoodIsolationMatches.count) check-ins.",
                iconName: "message",
                matchCount: lowMoodIsolationMatches.count
            )
        )
    }

    let anxiousBodyMatches = moods.filter { mood in
        isAnxietyRelated(mood) && !uniqueLabels(from: mood.sensations).isEmpty
    }

    if anxiousBodyMatches.count >= 2 {
        let topSensations = topLabels(
            from: anxiousBodyMatches.flatMap(\.sensations),
            limit: 2
        )
        let cue = topSensations.isEmpty ? "body symptoms" : joinedNames(topSensations.map(\.name).map { $0.lowercased() })

        items.append(
            PersonalCopingPlanItem(
                title: "Anxiety + Body Cues",
                whenText: "When anxiety shows up as \(cue)",
                tryText: "Try a one-minute breathing reset before deciding what comes next.",
                reason: "This pattern appears in \(anxiousBodyMatches.count) check-ins.",
                iconName: "wind",
                matchCount: anxiousBodyMatches.count
            )
        )
    }

    let bedtimeRuminationMatches = moods.filter { mood in
        let hour = calendar.component(.hour, from: mood.createdAt)
        let isBedtimeWindow = hour >= 20 || hour <= 3
        let hasSleepCue = mood.sleepQualityScore.map { $0 <= 4 } == true || mood.containsAnyLabel(matching: [
            "sleep", "bed", "tired", "ruminat", "worr", "overthink", "awake", "insomnia"
        ])

        return isBedtimeWindow && hasSleepCue
    }

    if bedtimeRuminationMatches.count >= 2 {
        items.append(
            PersonalCopingPlanItem(
                title: "Bedtime Rumination",
                whenText: "When your mind starts replaying the day at bedtime",
                tryText: "Use a wind-down journal: write the loop, one next step, and what can wait.",
                reason: "This pattern appears in \(bedtimeRuminationMatches.count) check-ins.",
                iconName: "moon.zzz",
                matchCount: bedtimeRuminationMatches.count
            )
        )
    }

    return items
        .sorted { first, second in
            if first.matchCount == second.matchCount {
                return first.title < second.title
            }
            return first.matchCount > second.matchCount
        }
        .prefix(3)
        .map { $0 }
}

private func makeActivityMoodAverages(from moods: [MoodSnapshot]) -> [ActivityMoodAverage] {
    let grouped = Dictionary(grouping: moods.flatMap { mood in
        mood.activityTags.compactMap { tag -> (key: String, name: String, moodScore: Int)? in
            guard let normalized = normalizedLabel(from: tag) else { return nil }
            return (normalized.key, normalized.name, mood.moodScore)
        }
    }) { $0.key }

    return grouped.compactMap { _, values -> ActivityMoodAverage? in
        guard !values.isEmpty else { return nil }
        let average = Double(values.map(\.moodScore).reduce(0, +)) / Double(values.count)
        return ActivityMoodAverage(
            name: values.first?.name ?? "",
            entryCount: values.count,
            averageMood: average
        )
    }
    .sorted { first, second in
        if first.averageMood == second.averageMood {
            if first.entryCount == second.entryCount {
                return first.name < second.name
            }
            return first.entryCount > second.entryCount
        }
        return first.averageMood > second.averageMood
    }
    .prefix(5)
    .map { $0 }
}

private func makeActivityFrequencies(
    from moods: [MoodSnapshot],
    moodScores: [MoodScoreSnapshot],
    calendar: Calendar,
    matchingDailyAverage dailyAverageMatches: (Double) -> Bool
) -> [ActivityTagFrequency] {
    let matchingDays = Set(
        dailyMoodAverages(from: moodScores, calendar: calendar)
            .filter { dailyAverageMatches($0.average) }
            .map(\.date)
    )
    var daysByActivity: [String: Set<Date>] = [:]
    var displayNames: [String: String] = [:]
    let moodEntriesByDay = Dictionary(grouping: moods) { calendar.startOfDay(for: $0.createdAt) }

    for day in matchingDays {
        guard let entries = moodEntriesByDay[day] else { continue }
        var tagsForDay: [(key: String, name: String)] = []
        var seenKeys = Set<String>()

        for entry in entries {
            for tag in entry.activityTags {
                guard let normalized = normalizedLabel(from: tag), seenKeys.insert(normalized.key).inserted else {
                    continue
                }
                tagsForDay.append(normalized)
            }
        }

        for tag in tagsForDay {
            displayNames[tag.key] = tag.name
            daysByActivity[tag.key, default: []].insert(day)
        }
    }

    return daysByActivity.map { key, days in
        ActivityTagFrequency(
            name: displayNames[key] ?? key.capitalized,
            dayCount: days.count
        )
    }
    .sorted { first, second in
        if first.dayCount == second.dayCount {
            return first.name < second.name
        }
        return first.dayCount > second.dayCount
    }
    .prefix(5)
    .map { $0 }
}

private func makeTriggerEmotionPatterns(from moods: [MoodSnapshot]) -> [TriggerEmotionPattern] {
    var pairCounts: [String: Int] = [:]
    var displayNames: [String: (trigger: String, emotion: String)] = [:]

    for mood in moods {
        let triggers = uniqueLabels(from: mood.triggers)
            .filter { $0.key != "nothing specific" }
        let emotions = uniqueLabels(from: mood.emotions)

        for trigger in triggers {
            for emotion in emotions {
                let key = "\(trigger.key)|\(emotion.key)"
                displayNames[key] = (trigger.name, emotion.name)
                pairCounts[key, default: 0] += 1
            }
        }
    }

    let pairs = pairCounts.compactMap { key, count -> TriggerEmotionPattern? in
        guard let names = displayNames[key] else { return nil }
        return TriggerEmotionPattern(
            trigger: names.trigger,
            emotion: names.emotion,
            count: count
        )
    }

    return Dictionary(grouping: pairs, by: \.trigger)
        .compactMap { _, values in
            values.sorted { first, second in
                if first.count == second.count {
                    return first.emotion < second.emotion
                }
                return first.count > second.count
            }
            .first
        }
        .sorted { first, second in
            if first.count == second.count {
                return first.trigger < second.trigger
            }
            return first.count > second.count
        }
        .prefix(5)
        .map { $0 }
}

private func makeAnxietySensationCounts(from moods: [MoodSnapshot]) -> [SensationCount] {
    var sensationCounts: [String: Int] = [:]
    var displayNames: [String: String] = [:]

    for mood in moods {
        let hasAnxietyEmotion = mood.emotions
            .compactMap { normalizedLabel(from: $0)?.key }
            .contains { emotion in
                emotion.contains("anxi") ||
                emotion.contains("stress") ||
                emotion.contains("panic") ||
                emotion.contains("worr") ||
                emotion.contains("nervous") ||
                emotion.contains("overwhelm") ||
                emotion.contains("tense")
            }

        guard hasAnxietyEmotion else { continue }

        for sensation in uniqueLabels(from: mood.sensations) {
            displayNames[sensation.key] = sensation.name
            sensationCounts[sensation.key, default: 0] += 1
        }
    }

    return sensationCounts.map { key, count in
        SensationCount(name: displayNames[key] ?? key.capitalized, count: count)
    }
    .sorted { first, second in
        if first.count == second.count {
            return first.name < second.name
        }
        return first.count > second.count
    }
    .prefix(5)
    .map { $0 }
}

private func makeMoodTrendInsights(
    from moodScores: [MoodScoreSnapshot],
    calendar: Calendar,
    now: Date
) -> [MoodTrendInsight] {
    [7, 30].compactMap { windowDays in
        guard
            let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: now),
            let midpoint = calendar.date(byAdding: .day, value: -(windowDays / 2), to: now)
        else {
            return nil
        }

        let dailyAverages = dailyMoodAverages(
            from: moodScores.filter { $0.createdAt >= windowStart && $0.createdAt <= now },
            calendar: calendar
        )
        guard dailyAverages.count >= 2 else { return nil }

        let midpointDay = calendar.startOfDay(for: midpoint)
        let earlierScores = dailyAverages.filter { $0.date < midpointDay }
        let recentScores = dailyAverages.filter { $0.date >= midpointDay }
        guard !recentScores.isEmpty, !earlierScores.isEmpty else { return nil }

        let recentAverage = average(recentScores.map(\.average))
        let earlierAverage = average(earlierScores.map(\.average))
        let delta = recentAverage - earlierAverage
        let direction: MoodTrendDirection

        if delta > 0.25 {
            direction = .higher
        } else if delta < -0.25 {
            direction = .lower
        } else {
            direction = .steady
        }

        return MoodTrendInsight(
            windowDays: windowDays,
            direction: direction,
            delta: delta,
            earlierAverage: earlierAverage,
            recentAverage: recentAverage,
            daysWithData: dailyAverages.count
        )
    }
}

private func makeCheckInConsistency(
    from moodScores: [MoodScoreSnapshot],
    calendar: Calendar,
    now: Date
) -> CheckInConsistencyInsight {
    let allDays = Set(moodScores.map { calendar.startOfDay(for: $0.createdAt) })
    let today = calendar.startOfDay(for: now)
    let last7Start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
    let last30Start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
    let streaks = makeStreakCounts(from: allDays, calendar: calendar, today: today)

    return CheckInConsistencyInsight(
        daysCheckedInLast7: allDays.filter { $0 >= last7Start && $0 <= today }.count,
        daysCheckedInLast30: allDays.filter { $0 >= last30Start && $0 <= today }.count,
        currentStreak: streaks.current,
        longestStreak: streaks.longest,
        totalCheckInDays: allDays.count
    )
}

private func makeStreakCounts(
    from days: Set<Date>,
    calendar: Calendar,
    today: Date
) -> (current: Int, longest: Int) {
    let sortedDays = days.sorted()
    guard !sortedDays.isEmpty else { return (0, 0) }

    var longest = 1
    var chain = 1

    for index in 1..<sortedDays.count {
        let previous = sortedDays[index - 1]
        let current = sortedDays[index]
        let dayDifference = calendar.dateComponents([.day], from: previous, to: current).day ?? 0

        if dayDifference == 1 {
            chain += 1
        } else if dayDifference > 1 {
            chain = 1
        }

        longest = max(longest, chain)
    }

    let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
    guard let lastActiveDay = sortedDays.last, lastActiveDay >= yesterday else {
        return (0, longest)
    }

    var currentStreak = 1
    if sortedDays.count > 1 {
        for index in (0..<(sortedDays.count - 1)).reversed() {
            let previous = sortedDays[index]
            let current = sortedDays[index + 1]
            let dayDifference = calendar.dateComponents([.day], from: previous, to: current).day ?? 0

            if dayDifference == 1 {
                currentStreak += 1
            } else {
                break
            }
        }
    }

    return (currentStreak, longest)
}

private func makePlainLanguagePatternCards(
    triggerPatternCards: [PlainLanguagePatternInsight] = [],
    activityMoodAverages: [ActivityMoodAverage],
    lowMoodActivityTags: [ActivityTagFrequency],
    highMoodActivityTags: [ActivityTagFrequency],
    triggerEmotionPatterns: [TriggerEmotionPattern],
    anxietySensations: [SensationCount],
    moodTrends: [MoodTrendInsight],
    checkInConsistency: CheckInConsistencyInsight,
    calendarPatterns: CalendarMoodPatternSummary,
    overallMoodAverage: Double?
) -> [PlainLanguagePatternInsight] {
    var cards: [PlainLanguagePatternInsight] = triggerPatternCards

    if let highestActivity = activityMoodAverages.first {
        let message: String

        if let overallMoodAverage, highestActivity.entryCount >= 2, highestActivity.averageMood >= overallMoodAverage + 0.25 {
            message = "Your mood tends to be higher on days with \(highestActivity.name)."
        } else if highestActivity.entryCount >= 2 {
            message = "\(highestActivity.name) often shows up with an average mood of \(formatMood(highestActivity.averageMood))/10."
        } else {
            message = "So far, \(highestActivity.name) appears with an average mood of \(formatMood(highestActivity.averageMood))/10."
        }

        cards.append(
            PlainLanguagePatternInsight(
                title: "Activity Mood",
                message: message,
                iconName: "chart.xyaxis.line",
                occurrenceCount: highestActivity.entryCount,
                actionTitle: "Add \(highestActivity.name) to my week",
                actionDescription: "A small plan based on an activity pattern from recent check-ins.",
                actionCategory: "Nourishing"
            )
        )
    }

    if let lowMoodTag = lowMoodActivityTags.first {
        cards.append(
            PlainLanguagePatternInsight(
                title: "Low Mood Tags",
                message: "Low mood days often include \(joinedNames(lowMoodActivityTags.prefix(2).map(\.name))).",
                iconName: "exclamationmark.magnifyingglass",
                occurrenceCount: lowMoodTag.dayCount,
                actionTitle: "Make \(lowMoodTag.name) easier",
                actionDescription: "Choose one tiny support step before or after this low-mood pattern.",
                actionCategory: "Mastery"
            )
        )
    }

    if let highMoodTag = highMoodActivityTags.first {
        cards.append(
            PlainLanguagePatternInsight(
                title: "High Mood Tags",
                message: "High mood days often include \(joinedNames(highMoodActivityTags.prefix(2).map(\.name))).",
                iconName: "sparkles",
                occurrenceCount: highMoodTag.dayCount,
                actionTitle: "Repeat \(highMoodTag.name)",
                actionDescription: "Make a small plan to repeat a pattern that has been linked with steadier mood.",
                actionCategory: "Nourishing"
            )
        )
    }

    if let pair = triggerEmotionPatterns.first {
        cards.append(
            PlainLanguagePatternInsight(
                title: "Triggers And Emotions",
                message: "\(pair.trigger) appears often with \(pair.emotion.lowercased()) emotions.",
                iconName: "arrow.triangle.branch",
                occurrenceCount: pair.count,
                actionTitle: "Plan support for \(pair.trigger)",
                actionDescription: "Pick one small, doable support step for when this trigger shows up.",
                actionCategory: "Nourishing"
            )
        )
    }

    if let anxietySensation = anxietySensations.first {
        cards.append(
            PlainLanguagePatternInsight(
                title: "Anxiety Body Cues",
                message: "Anxiety-related entries often show \(joinedNames(anxietySensations.prefix(2).map { $0.name.lowercased() })).",
                iconName: "waveform.path.ecg",
                occurrenceCount: anxietySensation.count,
                actionTitle: "Body cue reset: \(anxietySensation.name)",
                actionDescription: "Schedule a brief grounding or breathing step when this body cue appears.",
                actionCategory: "Nourishing"
            )
        )
    }

    for trend in moodTrends.sorted(by: { $0.windowDays < $1.windowDays }) {
        cards.append(
            PlainLanguagePatternInsight(
                title: "\(trend.windowDays)D Mood Trend",
                message: trendMessage(for: trend),
                iconName: "chart.line.uptrend.xyaxis",
                occurrenceCount: trend.daysWithData,
                actionTitle: trend.direction == .lower ? "Add one steadying step" : "Protect one helpful routine",
                actionDescription: "A small plan based on the recent \(trend.windowDays)-day mood trend.",
                actionCategory: "Nourishing"
            )
        )
    }

    if checkInConsistency.totalCheckInDays > 0 {
        cards.append(
            PlainLanguagePatternInsight(
                title: "Check-In Consistency",
                message: "You checked in on \(checkInConsistency.daysCheckedInLast7) of the last 7 days and \(checkInConsistency.daysCheckedInLast30) of the last 30 days.",
                iconName: "calendar.badge.checkmark",
                occurrenceCount: checkInConsistency.daysCheckedInLast7,
                actionTitle: "Set a check-in moment",
                actionDescription: "Schedule a small reminder activity to keep the check-in rhythm easy.",
                actionCategory: "Mastery"
            )
        )
    }

    cards.append(contentsOf: makeCalendarPatternCards(from: calendarPatterns))

    return cards
}

private func makeCalendarPatternCards(
    from calendarPatterns: CalendarMoodPatternSummary
) -> [PlainLanguagePatternInsight] {
    var cards: [PlainLanguagePatternInsight] = []

    if let weekdayMood = calendarPatterns.moodByWeekday.max(by: { $0.averageScore < $1.averageScore }),
       weekdayMood.entryCount >= 2 {
        cards.append(
            PlainLanguagePatternInsight(
                title: "Mood By Weekday",
                message: "\(weekdayMood.label) entries averaged \(formatMood(weekdayMood.averageScore))/10 mood.",
                iconName: "calendar",
                occurrenceCount: weekdayMood.entryCount,
                actionTitle: "Protect \(weekdayMood.label) support",
                actionDescription: "Add one small supportive activity on \(weekdayMood.label) so the helpful pattern has room to repeat.",
                actionCategory: "Nourishing"
            )
        )
    }

    if let weekdayStress = calendarPatterns.stressByWeekday.max(by: { $0.averageScore < $1.averageScore }),
       weekdayStress.entryCount >= 2 {
        cards.append(
            PlainLanguagePatternInsight(
                title: "Stress By Weekday",
                message: "\(weekdayStress.label) entries averaged \(formatMood(weekdayStress.averageScore))/10 stress.",
                iconName: "calendar.badge.exclamationmark",
                occurrenceCount: weekdayStress.entryCount,
                actionTitle: "\(weekdayStress.label) stress reset",
                actionDescription: "Try a 60-second breathing reset or one tiny prep step before the hardest part of \(weekdayStress.label).",
                actionCategory: "Mastery"
            )
        )
    }

    if let timePattern = calendarPatterns.moodByTimeOfDay.max(by: { $0.averageMood < $1.averageMood }),
       timePattern.entryCount >= 2 {
        cards.append(
            PlainLanguagePatternInsight(
                title: "Mood By Time",
                message: "\(timePattern.bucket.displayName) check-ins averaged \(formatMood(timePattern.averageMood))/10 mood.",
                iconName: "clock",
                occurrenceCount: timePattern.entryCount,
                actionTitle: "\(timePattern.bucket.displayName) steadying step",
                actionDescription: "Place one short reset or nourishing pause near this time of day.",
                actionCategory: "Nourishing"
            )
        )
    }

    if let triggerPattern = calendarPatterns.triggerFrequencyByDayType.first,
       triggerPattern.totalCount >= 2 {
        let dayType = triggerPattern.weekendCount > triggerPattern.weekdayCount ? "weekends" : "weekdays"
        cards.append(
            PlainLanguagePatternInsight(
                title: "Trigger Timing",
                message: "\(triggerPattern.trigger) appears more often on \(dayType) in your check-ins.",
                iconName: "calendar.day.timeline.leading",
                occurrenceCount: triggerPattern.totalCount,
                actionTitle: "Prepare for \(triggerPattern.trigger)",
                actionDescription: "Before \(dayType), choose one small support step for when \(triggerPattern.trigger.lowercased()) shows up.",
                actionCategory: "Mastery"
            )
        )
    }

    if let sleepPattern = calendarPatterns.sleepQualityVsMood.max(by: { $0.averageMood < $1.averageMood }),
       sleepPattern.entryCount >= 2 {
        cards.append(
            PlainLanguagePatternInsight(
                title: "Sleep And Mood",
                message: "\(sleepPattern.label) entries averaged \(formatMood(sleepPattern.averageMood))/10 mood.",
                iconName: "bed.double",
                occurrenceCount: sleepPattern.entryCount,
                actionTitle: "Tonight's wind-down reset",
                actionDescription: "Write one worry, one next step, and one thing that can wait before getting into bed.",
                actionCategory: "Nourishing"
            )
        )
    }

    let exercisePattern = calendarPatterns.exerciseMoodAfterCompletion
    if let average = exercisePattern.averageMoodAfterCompletion,
       exercisePattern.matchedMoodCount >= 2 {
        cards.append(
            PlainLanguagePatternInsight(
                title: "After Exercises",
                message: "Mood entries within 24 hours after completed exercises averaged \(formatMood(average))/10.",
                iconName: "figure.walk",
                occurrenceCount: exercisePattern.matchedMoodCount,
                actionTitle: "Repeat a short exercise",
                actionDescription: "Schedule a brief CBT exercise or reset at a low-friction time today.",
                actionCategory: "Mastery"
            )
        )
    }

    return cards
}

private func makeTriggerPatternCards(
    from moods: [MoodSnapshot],
    calendar: Calendar,
    now: Date
) -> [PlainLanguagePatternInsight] {
    guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
        return []
    }

    var triggerCounts: [String: Int] = [:]
    var displayNames: [String: String] = [:]

    for mood in moods where monthInterval.contains(mood.createdAt) {
        for trigger in uniqueLabels(from: mood.triggers) where trigger.key != "nothing specific" {
            triggerCounts[trigger.key, default: 0] += 1
            displayNames[trigger.key] = trigger.name
        }
    }

    return triggerCounts.compactMap { key, count -> PlainLanguagePatternInsight? in
        guard count >= 3 else { return nil }

        let triggerName = displayNames[key] ?? key.capitalized
        let action = copingAction(forTriggerKey: key, triggerName: triggerName)
        let subject = triggerName.localizedCaseInsensitiveContains("stress")
            ? triggerName
            : "\(triggerName) stress"

        return PlainLanguagePatternInsight(
            title: "\(triggerName) Pattern",
            message: "\(subject) has appeared \(count) times this month.",
            iconName: triggerPatternIcon(forTriggerKey: key),
            occurrenceCount: count,
            actionTitle: action.title,
            actionDescription: action.description,
            actionCategory: action.category
        )
    }
    .sorted { first, second in
        if (first.occurrenceCount ?? 0) == (second.occurrenceCount ?? 0) {
            return first.title < second.title
        }
        return (first.occurrenceCount ?? 0) > (second.occurrenceCount ?? 0)
    }
    .prefix(3)
    .map { $0 }
}

private func copingAction(
    forTriggerKey key: String,
    triggerName: String
) -> (title: String, description: String, category: String) {
    if key.contains("work") || key.contains("job") || key.contains("deadline") || key.contains("manager") {
        return (
            "Two-minute work reset",
            "Step away, unclench your shoulders, and choose the next smallest work task.",
            "Mastery"
        )
    }

    if key.contains("family") || key.contains("relationship") || key.contains("partner") {
        return (
            "Gentle boundary check",
            "Pause before replying and name one need or boundary in plain language.",
            "Nourishing"
        )
    }

    if key.contains("sleep") || key.contains("tired") || key.contains("bed") {
        return (
            "Wind-down note",
            "Write the worry, one next step, and what can safely wait until tomorrow.",
            "Nourishing"
        )
    }

    if key.contains("money") || key.contains("bill") || key.contains("finance") {
        return (
            "Money worry container",
            "Set a ten-minute window to list the concern and one practical next step.",
            "Mastery"
        )
    }

    if key.contains("health") || key.contains("body") || key.contains("pain") {
        return (
            "Body cue grounding",
            "Place both feet down, slow one breath, and decide whether support or rest is needed.",
            "Nourishing"
        )
    }

    return (
        "\(triggerName) support step",
        "Pause, name what is happening, and choose one small action that lowers the load.",
        "Nourishing"
    )
}

private func triggerPatternIcon(forTriggerKey key: String) -> String {
    if key.contains("work") || key.contains("job") || key.contains("deadline") || key.contains("manager") {
        return "briefcase.fill"
    }

    if key.contains("family") || key.contains("relationship") || key.contains("partner") {
        return "heart.text.square.fill"
    }

    if key.contains("sleep") || key.contains("tired") || key.contains("bed") {
        return "moon.zzz.fill"
    }

    if key.contains("money") || key.contains("bill") || key.contains("finance") {
        return "dollarsign.circle.fill"
    }

    if key.contains("health") || key.contains("body") || key.contains("pain") {
        return "cross.case.fill"
    }

    return "bolt.heart.fill"
}

private func trendMessage(for trend: MoodTrendInsight) -> String {
    switch trend.direction {
    case .higher:
        return "Over \(trend.windowDays)D, mood tends to be higher lately."
    case .lower:
        return "Over \(trend.windowDays)D, mood tends to be lower lately."
    case .steady:
        return "Over \(trend.windowDays)D, mood has stayed fairly steady."
    }
}

private func normalizedLabel(from value: String) -> (key: String, name: String)? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let key = trimmed
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        .lowercased()
    return (key, trimmed.capitalized)
}

private func uniqueLabels(from values: [String]) -> [(key: String, name: String)] {
    var seen = Set<String>()
    var labels: [(key: String, name: String)] = []

    for value in values {
        guard let label = normalizedLabel(from: value), seen.insert(label.key).inserted else {
            continue
        }
        labels.append(label)
    }

    return labels
}

private func topLabels(
    from values: [String],
    limit: Int
) -> [(key: String, name: String)] {
    var counts: [String: Int] = [:]
    var displayNames: [String: String] = [:]

    for value in values {
        guard let label = normalizedLabel(from: value) else { continue }
        counts[label.key, default: 0] += 1
        displayNames[label.key] = label.name
    }

    return counts.map { key, count in
        (key: key, name: displayNames[key] ?? key.capitalized, count: count)
    }
    .sorted { first, second in
        if first.count == second.count {
            return first.name < second.name
        }
        return first.count > second.count
    }
    .prefix(limit)
    .map { (key: $0.key, name: $0.name) }
}

private extension MoodSnapshot {
    func containsAnyLabel(matching fragments: [String]) -> Bool {
        let labels = emotions + triggers + sensations + contextTags + activityTags + [notes].compactMap { $0 }
        let normalizedLabels = labels.compactMap { normalizedLabel(from: $0)?.key }

        return normalizedLabels.contains { label in
            fragments.contains { label.contains($0) }
        }
    }
}
