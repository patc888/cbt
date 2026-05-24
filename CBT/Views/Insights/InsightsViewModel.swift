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
}

private struct MoodCheckInSnapshot: Sendable {
    let createdAt: Date
    let moodScore: Int
}

private struct MoodScoreSnapshot: Sendable {
    let createdAt: Date
    let moodScore: Int
}

private struct ThoughtSnapshot: Sendable {
    let createdAt: Date
    let intensityBefore: Int
    let intensityAfter: Int
    let emotions: [String]
    let distortions: [String]
}

private struct ExerciseSnapshot: Sendable {
    let createdAt: Date
}

private struct JournalSnapshot: Sendable {
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
    let contextTagCorrelations: [ContextTagMoodCorrelation]
    let weeklyMoodAverages: [WeeklyMoodAverage]
    let moodVolatilityLast30Days: Double?
    let currentStreak: Int
    let longestStreak: Int
    let patternSummary: InsightsPatternSummary
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
    var contextTagCorrelations: [ContextTagMoodCorrelation] = []
    var patternSummary: InsightsPatternSummary = .empty
    
    @MainActor
    func recalculate(
        timeRangeDays: Int, // 7 or 30
        moodEntries: [MoodEntry],
        moodCheckIns: [MoodCheckIn],
        thoughtRecords: [ThoughtRecord],
        exerciseCompletions: [ExerciseCompletion],
        journalEntries: [JournalEntry],
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
                activityTags: $0.activityTags
            )
        }
        let checkIns = moodCheckIns.map {
            MoodCheckInSnapshot(
                createdAt: $0.createdAt,
                moodScore: MoodEntry.clampMoodScore($0.moodScore)
            )
        }
        let thoughts = thoughtRecords.map {
            ThoughtSnapshot(
                createdAt: $0.createdAt,
                intensityBefore: $0.intensityBefore,
                intensityAfter: $0.intensityAfter,
                emotions: $0.emotions,
                distortions: $0.distortions
            )
        }
        let exercises = exerciseCompletions.map {
            ExerciseSnapshot(createdAt: $0.createdAt)
        }
        let journals = journalEntries.map {
            JournalSnapshot(createdAt: $0.createdAt)
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
            let filteredExercises = exercises.filter { $0.createdAt >= rangeCutoff }
            let filteredMoodScores = moodScores.filter { $0.createdAt >= rangeCutoff }
            
            // 3. Active days
            let moodDays = filteredMoodScores.map { calendar.startOfDay(for: $0.createdAt) }
            let thoughtDays = filteredThoughts.map { calendar.startOfDay(for: $0.createdAt) }
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
            
            let validThoughts = filteredThoughts.filter { (0...100).contains($0.intensityBefore) && (0...100).contains($0.intensityAfter) }
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
            for thought in filteredThoughts {
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
                calendar: calendar,
                now: now
            )
            
            // 10. Streaks (across all time)
            let allMoodDays = moodScores.map { calendar.startOfDay(for: $0.createdAt) }
            let allThoughtDays = thoughts.map { calendar.startOfDay(for: $0.createdAt) }
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
                    contextTagCorrelations: contextTagCorrelations,
                    weeklyMoodAverages: weeklyMoodAverages,
                    moodVolatilityLast30Days: volatility,
                    currentStreak: 0,
                    longestStreak: 0,
                    patternSummary: patternSummary
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
                contextTagCorrelations: contextTagCorrelations,
                weeklyMoodAverages: weeklyMoodAverages,
                moodVolatilityLast30Days: volatility,
                currentStreak: cStreak,
                longestStreak: lStreak,
                patternSummary: patternSummary
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
            self.contextTagCorrelations = results.contextTagCorrelations
            self.weeklyMoodAverages = results.weeklyMoodAverages
            self.moodVolatilityLast30Days = results.moodVolatilityLast30Days
            self.currentStreak = results.currentStreak
            self.longestStreak = results.longestStreak
            self.patternSummary = results.patternSummary
            
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
            contextTagCorrelations: contextTagCorrelations,
            patternSummary: patternSummary
        )
    }
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
        insightCards: insightCards
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
            iconName: "tag"
        ))
    }

    if !lowMoodActivityTags.isEmpty {
        cards.append(PlainLanguagePatternInsight(
            title: "Low Mood Tags",
            message: "Low mood days often include \(joinedNames(lowMoodActivityTags.prefix(2).map(\.name))).",
            iconName: "arrow.down.heart"
        ))
    }

    if !highMoodActivityTags.isEmpty {
        cards.append(PlainLanguagePatternInsight(
            title: "High Mood Tags",
            message: "High mood days often include \(joinedNames(highMoodActivityTags.prefix(2).map(\.name))).",
            iconName: "arrow.up.heart"
        ))
    }

    if let triggerEmotion = triggerEmotionPatterns.first {
        cards.append(PlainLanguagePatternInsight(
            title: "Triggers And Emotions",
            message: "\(triggerEmotion.trigger) appears often with \(triggerEmotion.emotion.lowercased()) emotions.",
            iconName: "arrow.triangle.branch"
        ))
    }

    if !anxietySensations.isEmpty {
        cards.append(PlainLanguagePatternInsight(
            title: "Anxiety Body Cues",
            message: "Anxiety-related entries often show \(joinedNames(anxietySensations.prefix(2).map(\.name))).",
            iconName: "waveform.path.ecg"
        ))
    }

    for trend in moodTrends.sorted(by: { $0.windowDays < $1.windowDays }) {
        cards.append(PlainLanguagePatternInsight(
            title: "\(trend.windowDays)D Mood Trend",
            message: legacyTrendMessage(for: trend),
            iconName: "chart.line.uptrend.xyaxis"
        ))
    }

    if checkInConsistency.totalCheckInDays > 0 {
        cards.append(PlainLanguagePatternInsight(
            title: "Check-In Consistency",
            message: "You checked in on \(checkInConsistency.daysCheckedInLast7) of the last 7 days and \(checkInConsistency.daysCheckedInLast30) of the last 30 days.",
            iconName: "calendar.badge.checkmark"
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
    let insightCards = makePlainLanguagePatternCards(
        activityMoodAverages: activityMoodAverages,
        lowMoodActivityTags: lowMoodActivityTags,
        highMoodActivityTags: highMoodActivityTags,
        triggerEmotionPatterns: triggerEmotionPatterns,
        anxietySensations: anxietySensations,
        moodTrends: moodTrends,
        checkInConsistency: checkInConsistency,
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
        insightCards: insightCards
    )
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
    activityMoodAverages: [ActivityMoodAverage],
    lowMoodActivityTags: [ActivityTagFrequency],
    highMoodActivityTags: [ActivityTagFrequency],
    triggerEmotionPatterns: [TriggerEmotionPattern],
    anxietySensations: [SensationCount],
    moodTrends: [MoodTrendInsight],
    checkInConsistency: CheckInConsistencyInsight,
    overallMoodAverage: Double?
) -> [PlainLanguagePatternInsight] {
    var cards: [PlainLanguagePatternInsight] = []

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
                iconName: "chart.xyaxis.line"
            )
        )
    }

    if !lowMoodActivityTags.isEmpty {
        cards.append(
            PlainLanguagePatternInsight(
                title: "Low Mood Tags",
                message: "Low mood days often include \(joinedNames(lowMoodActivityTags.prefix(2).map(\.name))).",
                iconName: "exclamationmark.magnifyingglass"
            )
        )
    }

    if !highMoodActivityTags.isEmpty {
        cards.append(
            PlainLanguagePatternInsight(
                title: "High Mood Tags",
                message: "High mood days often include \(joinedNames(highMoodActivityTags.prefix(2).map(\.name))).",
                iconName: "sparkles"
            )
        )
    }

    if let pair = triggerEmotionPatterns.first {
        cards.append(
            PlainLanguagePatternInsight(
                title: "Triggers And Emotions",
                message: "\(pair.trigger) appears often with \(pair.emotion.lowercased()) emotions.",
                iconName: "arrow.triangle.branch"
            )
        )
    }

    if !anxietySensations.isEmpty {
        cards.append(
            PlainLanguagePatternInsight(
                title: "Anxiety Body Cues",
                message: "Anxiety-related entries often show \(joinedNames(anxietySensations.prefix(2).map { $0.name.lowercased() })).",
                iconName: "waveform.path.ecg"
            )
        )
    }

    for trend in moodTrends.sorted(by: { $0.windowDays < $1.windowDays }) {
        cards.append(
            PlainLanguagePatternInsight(
                title: "\(trend.windowDays)D Mood Trend",
                message: trendMessage(for: trend),
                iconName: "chart.line.uptrend.xyaxis"
            )
        )
    }

    if checkInConsistency.totalCheckInDays > 0 {
        cards.append(
            PlainLanguagePatternInsight(
                title: "Check-In Consistency",
                message: "You checked in on \(checkInConsistency.daysCheckedInLast7) of the last 7 days and \(checkInConsistency.daysCheckedInLast30) of the last 30 days.",
                iconName: "calendar.badge.checkmark"
            )
        )
    }

    return cards
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
