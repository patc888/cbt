import Foundation
import SwiftData
import SwiftUI

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
    
    func recalculate(
        timeRangeDays: Int, // 7 or 30
        moodEntries: [MoodEntry],
        thoughtRecords: [ThoughtRecord],
        exerciseCompletions: [ExerciseCompletion],
        journalEntries: [JournalEntry],
        moodGoalValue: Int
    ) async {
        let results = await Task.detached(priority: .userInitiated) {
            let calendar = Calendar.current
            let now = Date()
            
            // 1. Cutoffs
            let rangeCutoff = calendar.date(byAdding: .day, value: -timeRangeDays, to: now) ?? now
            let thirtyDaysCutoff = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            let eightWeeksCutoff = calendar.date(byAdding: .weekOfYear, value: -8, to: now) ?? now
            
            // 2. Filter data for the primary time range
            let filteredMoods = moodEntries.filter { $0.createdAt >= rangeCutoff }
            let filteredThoughts = thoughtRecords.filter { $0.createdAt >= rangeCutoff }
            let filteredExercises = exerciseCompletions.filter { $0.createdAt >= rangeCutoff }
            
            // 3. Active days
            let moodDays = filteredMoods.map { calendar.startOfDay(for: $0.createdAt) }
            let thoughtDays = filteredThoughts.map { calendar.startOfDay(for: $0.createdAt) }
            let exerciseDays = filteredExercises.map { calendar.startOfDay(for: $0.createdAt) }
            // Assuming Journal entries count towards streaks, though maybe range active days skips them. Let's include them.
            let journalDaysRange = journalEntries.filter { $0.createdAt >= rangeCutoff }.map { calendar.startOfDay(for: $0.createdAt) }
            
            let activeDaysCount = Set(moodDays + thoughtDays + exerciseDays + journalDaysRange).count
            
            // 4. Daily Mood Averages (for the timeRange)
            let dailyGroups = Dictionary(grouping: filteredMoods) { calendar.startOfDay(for: $0.createdAt) }
            let dailyMoodAverages = dailyGroups.map { day, entries in
                DailyMoodAverage(date: day, averageScore: Double(entries.map(\.moodScore).reduce(0, +)) / Double(entries.count))
            }.sorted { $0.date < $1.date }
            
            // 5. Overall Averages (for the timeRange)
            let averageMood = filteredMoods.isEmpty ? nil : Double(filteredMoods.map(\.moodScore).reduce(0, +)) / Double(filteredMoods.count)
            
            let validThoughts = filteredThoughts.filter { (0...100).contains($0.intensityBefore) && (0...100).contains($0.intensityAfter) }
            let averageIntensityImprovement: Int? = validThoughts.isEmpty ? nil : (validThoughts.map { $0.intensityBefore - $0.intensityAfter }.reduce(0, +) / validThoughts.count)
            
            // 6. Goals Progress
            let consistencyGoalTarget = max(3, Int((Double(timeRangeDays) * 0.7).rounded()))
            let consistencyProgress = consistencyGoalTarget > 0 ? min(1, Double(activeDaysCount) / Double(consistencyGoalTarget)) : 0
            
            let moodGoalProgress = filteredMoods.isEmpty ? 0 : Double(filteredMoods.filter { $0.moodScore >= moodGoalValue }.count) / Double(filteredMoods.count)
            
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
            
            // 8. Weekly Averages (last 8 weeks)
            let eightWeeksMoods = moodEntries.filter { $0.createdAt >= eightWeeksCutoff }
            let weeklyGroups = Dictionary(grouping: eightWeeksMoods) { entry in
                calendar.dateInterval(of: .weekOfYear, for: entry.createdAt)?.start ?? calendar.startOfDay(for: entry.createdAt)
            }
            let weeklyMoodAverages = weeklyGroups.map { weekStart, entries in
                WeeklyMoodAverage(weekStart: weekStart, averageScore: Double(entries.map(\.moodScore).reduce(0, +)) / Double(entries.count))
            }.sorted { $0.weekStart < $1.weekStart }
            
            // 9. Mood Volatility (last 30 days)
            let thirtyDaysMoods = moodEntries.filter { $0.createdAt >= thirtyDaysCutoff }
            let thirtyDailyGroups = Dictionary(grouping: thirtyDaysMoods) { calendar.startOfDay(for: $0.createdAt) }
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
            
            // 10. Streaks (across all time)
            let allMoodDays = moodEntries.map { calendar.startOfDay(for: $0.createdAt) }
            let allThoughtDays = thoughtRecords.map { calendar.startOfDay(for: $0.createdAt) }
            let allExerciseDays = exerciseCompletions.map { calendar.startOfDay(for: $0.createdAt) }
            let allJournalDays = journalEntries.map { calendar.startOfDay(for: $0.createdAt) }
            
            let allActiveDates = Set(allMoodDays + allThoughtDays + allExerciseDays + allJournalDays).sorted()
            
            var cStreak = 0
            var lStreak = 0
            let today = calendar.startOfDay(for: now)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            
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
                let lastActive = allActiveDates.last!
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
            
            return (
                activeDaysCount, dailyMoodAverages,
                averageMood, averageIntensityImprovement,
                consistencyGoalTarget, consistencyProgress,
                moodGoalProgress, thoughtGoalProgress,
                exerciseGoalTarget, exerciseProgress, milestonesCompleted,
                topEmotions, topTriggers, topDistortions,
                weeklyMoodAverages, volatility, cStreak, lStreak
            )
        }.value
        
        await MainActor.run {
            self.activeDaysCount = results.0
            self.dailyMoodAverages = results.1
            self.averageMood = results.2
            self.averageIntensityImprovement = results.3
            self.consistencyGoalTarget = results.4
            self.consistencyProgress = results.5
            self.moodGoalProgress = results.6
            self.thoughtGoalProgress = results.7
            self.exerciseGoalTarget = results.8
            self.exerciseProgress = results.9
            self.milestonesCompleted = results.10
            self.topEmotions = results.11
            self.topTriggers = results.12
            self.topDistortions = results.13
            self.weeklyMoodAverages = results.14
            self.moodVolatilityLast30Days = results.15
            self.currentStreak = results.16
            self.longestStreak = results.17
            
            self.isCalculating = false
        }
    }
}
