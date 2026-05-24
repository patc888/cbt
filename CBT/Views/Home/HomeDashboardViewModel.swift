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
    case activityPlanner
}

nonisolated struct DailyPlanCompletionSnapshot: Sendable {
    let entries: [DailyPlanItem: PlanCardCompletionState]
    
    static let empty = DailyPlanCompletionSnapshot(entries: [
        .moodCheckIn: .incomplete,
        .thoughtRecord: .incomplete,
        .exercises: .incomplete,
        .breathingReset: .incomplete,
        .tipOfTheDay: .notTracked,
        .activityPlanner: .incomplete
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
    var recommendations = [DailyRecommendation]()
    
    // Manual completion tracking (persisted only for current session here, naturally)
    var manualCompletions: [Date: Set<DailyPlanItem>] = [:]

    private var updateTaskID = UUID()

    @MainActor
    func apply(
        snapshot: HomeDashboardSnapshot,
        selectedDate: Date,
        recommendations: [DailyRecommendation]
    ) async {
        let currentTaskID = UUID()
        self.updateTaskID = currentTaskID

        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let manualForDay = manualCompletions[selectedDay] ?? []

        let completion = await Task.detached(priority: .userInitiated) {
            var entries = snapshot.completionSnapshot.entries
            if manualForDay.contains(.breathingReset) {
                entries[.breathingReset] = .completed
            }
            entries[.tipOfTheDay] = manualForDay.contains(.tipOfTheDay) ? .completed : .notTracked
            return DailyPlanCompletionSnapshot(entries: entries)
        }.value
        
        guard !Task.isCancelled, self.updateTaskID == currentTaskID else { return }
        
        self.activeDates = snapshot.activeDates
        self.completionSnapshot = completion
        self.recommendations = Array(recommendations.prefix(3))
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
