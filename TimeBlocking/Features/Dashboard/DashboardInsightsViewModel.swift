import Foundation
import SwiftData
import SwiftUI

@Observable
final class DashboardInsightsViewModel {
    var isCalculating = true
    
    // Derived values
    var activeDaysCount: Int = 0
    var dailyCompletionRates: [DailyCompletionRate] = []
    var weeklyCompletionRates: [WeeklyCompletionRate] = []
    
    // Streaks
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    
    var averageCompletionRate: Double?
    var totalCompletedBlocks: Int = 0
    
    var consistencyGoalTarget: Int = 5
    var consistencyProgress: Double = 0
    
    var completionGoalProgress: Double = 0
    var routineGoalProgress: Double = 0
    var focusGoalProgress: Double = 0
    
    var milestonesCompleted: Int = 0
    
    var topCategories: [CategoryCount] = []
    
    struct DailyCompletionRate: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let rate: Double
    }
    
    struct WeeklyCompletionRate: Identifiable, Equatable {
        let id = UUID()
        let weekStart: Date
        let rate: Double
    }
    
    struct CategoryCount: Identifiable {
        let id = UUID()
        let name: String
        let count: Int
    }
    
    func recalculate(
        timeRangeDays: Int,
        blocks: [TimeBlock]
    ) async {
        let results = await Task.detached(priority: .userInitiated) {
            let calendar = Calendar.current
            let now = Date()
            
            // 1. Cutoffs
            let rangeCutoff = calendar.date(byAdding: .day, value: -timeRangeDays, to: now) ?? now
            let eightWeeksCutoff = calendar.date(byAdding: .weekOfYear, value: -8, to: now) ?? now
            
            // 2. Filter data
            let filteredBlocks = blocks.filter { $0.startDate >= rangeCutoff }
            
            // 3. Active days (days with at least one completed block)
            let completedBlocks = blocks.filter { $0.status == .completed }
            let completedDays = completedBlocks.map { calendar.startOfDay(for: $0.startDate) }
            let completedDaysInRange = completedBlocks.filter { $0.startDate >= rangeCutoff }.map { calendar.startOfDay(for: $0.startDate) }
            
            let activeDatesSetInRange = Set(completedDaysInRange)
            let activeDaysCount = activeDatesSetInRange.count
            
            // 4. Daily Completion Rates
            let blocksByDay = Dictionary(grouping: filteredBlocks) { calendar.startOfDay(for: $0.startDate) }
            let dailyRates = blocksByDay.map { day, dayBlocks in
                let total = dayBlocks.count
                let completed = dayBlocks.filter { $0.status == .completed }.count
                let rate = total > 0 ? Double(completed) / Double(total) : 0
                return DailyCompletionRate(date: day, rate: rate)
            }.sorted { $0.date < $1.date }
            
            // 5. Overall Stats
            let totalFilteredBlocks = filteredBlocks.count
            let totalFilteredCompleted = filteredBlocks.filter { $0.status == .completed }.count
            let averageCompletionRate = totalFilteredBlocks > 0 ? Double(totalFilteredCompleted) / Double(totalFilteredBlocks) : nil
            
            // 6. Goals Progress
            let consistencyGoalTarget = max(3, Int((Double(timeRangeDays) * 0.8).rounded()))
            let consistencyProgress = consistencyGoalTarget > 0 ? min(1, Double(activeDaysCount) / Double(consistencyGoalTarget)) : 0
            
            let completionGoalProgress = averageCompletionRate ?? 0
            
            let routines = filteredBlocks.filter { $0.category == .routine }
            let routineGoalProgress = routines.isEmpty ? 0 : min(1, Double(routines.filter { $0.status == .completed }.count) / Double(routines.count))
            
            let focusBlocks = filteredBlocks.filter { $0.category == .focus }
            let focusGoalProgress = focusBlocks.isEmpty ? 0 : min(1, Double(focusBlocks.filter { $0.status == .completed }.count) / Double(focusBlocks.count))
            
            let milestonesCompleted = [consistencyProgress, completionGoalProgress, routineGoalProgress, focusGoalProgress].filter { $0 >= 0.9 }.count
            
            // 7. Top Categories
            var categoryCounts = [TimeBlockCategory: Int]()
            for block in filteredBlocks where block.status == .completed {
                categoryCounts[block.category, default: 0] += 1
            }
            let topCategories = categoryCounts.map { CategoryCount(name: $0.key.rawValue.capitalized, count: $0.value) }
                .sorted { $0.count > $1.count }.prefix(5).map { $0 }
            
            // 8. Weekly Averages
            let eightWeeksBlocks = blocks.filter { $0.startDate >= eightWeeksCutoff }
            let weeklyGroups = Dictionary(grouping: eightWeeksBlocks) { block in
                calendar.dateInterval(of: .weekOfYear, for: block.startDate)?.start ?? calendar.startOfDay(for: block.startDate)
            }
            let weeklyRates = weeklyGroups.map { weekStart, weekBlocks in
                let total = weekBlocks.count
                let completed = weekBlocks.filter { $0.status == .completed }.count
                let rate = total > 0 ? Double(completed) / Double(total) : 0
                return WeeklyCompletionRate(weekStart: weekStart, rate: rate)
            }.sorted { $0.weekStart < $1.weekStart }
            
            // 9. Streaks
            let allActiveDates = Set(completedDays).sorted()
            var cStreak = 0
            var lStreak = 0
            
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
                
                let today = calendar.startOfDay(for: now)
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
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
                    cStreak = 0
                }
            }
            
            return (
                activeDaysCount, dailyRates, averageCompletionRate, totalFilteredCompleted,
                consistencyGoalTarget, consistencyProgress, completionGoalProgress,
                routineGoalProgress, focusGoalProgress, milestonesCompleted,
                topCategories, weeklyRates, cStreak, lStreak
            )
        }.value
        
        await MainActor.run {
            self.activeDaysCount = results.0
            self.dailyCompletionRates = results.1
            self.averageCompletionRate = results.2
            self.totalCompletedBlocks = results.3
            self.consistencyGoalTarget = results.4
            self.consistencyProgress = results.5
            self.completionGoalProgress = results.6
            self.routineGoalProgress = results.7
            self.focusGoalProgress = results.8
            self.milestonesCompleted = results.9
            self.topCategories = results.10
            self.weeklyCompletionRates = results.11
            self.currentStreak = results.12
            self.longestStreak = results.13
            
            self.isCalculating = false
        }
    }
}
