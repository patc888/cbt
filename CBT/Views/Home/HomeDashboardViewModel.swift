import Foundation
import SwiftData
import SwiftUI
import Observation

nonisolated enum DailyPlanItem: Hashable, Sendable {
    case moodCheckIn
    case thoughtRecord
    case exercises
    case breathingReset
    case tipOfTheDay
}

nonisolated struct DailyPlanCompletionSnapshot: Sendable {
    let entries: [DailyPlanItem: PlanCardCompletionState]
    
    static let empty = DailyPlanCompletionSnapshot(entries: [
        .moodCheckIn: .incomplete,
        .thoughtRecord: .incomplete,
        .exercises: .incomplete,
        .breathingReset: .incomplete,
        .tipOfTheDay: .notTracked
    ])
    
    func state(for item: DailyPlanItem) -> PlanCardCompletionState {
        entries[item] ?? .incomplete
    }
}

@Observable
final class HomeDashboardViewModel {
    var isInitialized = false
    var activeDates = Set<Date>()
    var completionSnapshot: DailyPlanCompletionSnapshot = .empty
    
    // Manual completion tracking (persisted only for current session here, naturally)
    var manualCompletions: [Date: Set<DailyPlanItem>] = [:]

    private var updateTaskID = UUID()

    @MainActor
    func update(
        selectedDate: Date,
        moodEntries: [MoodEntry],
        thoughtRecords: [ThoughtRecord],
        exerciseCompletions: [ExerciseCompletion],
        journalEntries: [JournalEntry]
    ) async {
        let currentTaskID = UUID()
        self.updateTaskID = currentTaskID

        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let manualForDay = manualCompletions[selectedDay] ?? []

        // 1. Map to Sendable snapshots on the MainActor
        let moodDates = moodEntries.map { $0.createdAt }
        let thoughtDates = thoughtRecords.map { $0.createdAt }
        let exerciseDates = exerciseCompletions.map { $0.createdAt }
        let journalDates = journalEntries.filter { 
            $0.sourceKind == SessionSourceKind.breathing.rawValue 
        }.map { $0.createdAt }

        let results = await Task.detached(priority: .userInitiated) {
            let calendar = Calendar.current
            
            // 2. Calculate Active Dates in background
            var dates = Set<Date>()
            for d in moodDates { dates.insert(calendar.startOfDay(for: d)) }
            for d in thoughtDates { dates.insert(calendar.startOfDay(for: d)) }
            for d in exerciseDates { dates.insert(calendar.startOfDay(for: d)) }
            for d in journalDates { dates.insert(calendar.startOfDay(for: d)) }
            
            // 3. Calculate Completion for selected day
            let moodDone = moodDates.contains { calendar.isDate($0, inSameDayAs: selectedDay) }
            let thoughtDone = thoughtDates.contains { calendar.isDate($0, inSameDayAs: selectedDay) }
            let exerciseDone = exerciseDates.contains { calendar.isDate($0, inSameDayAs: selectedDay) }
            let breathingDone = journalDates.contains { calendar.isDate($0, inSameDayAs: selectedDay) }
            
            let completion = DailyPlanCompletionSnapshot(entries: [
                .moodCheckIn: moodDone ? .completed : .incomplete,
                .thoughtRecord: thoughtDone ? .completed : .incomplete,
                .exercises: exerciseDone ? .completed : .incomplete,
                .breathingReset: (breathingDone || manualForDay.contains(.breathingReset)) ? .completed : .incomplete,
                .tipOfTheDay: manualForDay.contains(.tipOfTheDay) ? .completed : .notTracked
            ])
            
            return (dates, completion)
        }.value
        
        guard !Task.isCancelled, self.updateTaskID == currentTaskID else { return }
        
        self.activeDates = results.0
        self.completionSnapshot = results.1
        self.isInitialized = true
    }

    @MainActor
    func markItemAsDone(_ item: DailyPlanItem, for date: Date) {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: date)
        var currentSet = manualCompletions[selectedDay] ?? []
        if !currentSet.contains(item) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentSet.insert(item)
                manualCompletions[selectedDay] = currentSet
                // Note: We don't need to await update here because the view will 
                // re-evaluate the completion snapshot via the next update pass or
                // we can manually update the snapshot if we want immediate feedback.
                // For simplicity, we manually update the snapshot.
                updateLocalSnapshot(for: item, state: .completed)
            }
        }
    }

    private func updateLocalSnapshot(for item: DailyPlanItem, state: PlanCardCompletionState) {
        var currentEntries = completionSnapshot.entries
        currentEntries[item] = state
        completionSnapshot = DailyPlanCompletionSnapshot(entries: currentEntries)
    }
}
