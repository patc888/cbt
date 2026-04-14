import Foundation
import Observation

@Observable
final class TimelineViewModel {
    typealias GroupedItems = [(key: Date, value: [TimelineItem])]

    var groupedItems: GroupedItems = []
    var isInitialized = false

    private var updateTaskID = UUID()

    @MainActor
    func update(
        moodEntries: [MoodEntry],
        thoughtRecords: [ThoughtRecord],
        exerciseCompletions: [ExerciseCompletion],
        journalEntries: [JournalEntry]
    ) async {
        let currentTaskID = UUID()
        updateTaskID = currentTaskID

        // 1. Map to Sendable TimelineItems on the MainActor
        let moods = moodEntries.map { TimelineItem.mood($0) }
        let thoughts = thoughtRecords.map { TimelineItem.thought($0) }
        let exercises = exerciseCompletions.map { TimelineItem.exercise($0) }
        let journals = journalEntries.map { TimelineItem.journal($0) }
        
        // 2. Offload sorting and grouping to background
        let result = await Task.detached(priority: .userInitiated) {
            let calendar = Calendar.current
            var items: [TimelineItem] = []
            items.reserveCapacity(moods.count + thoughts.count + exercises.count + journals.count)

            items.append(contentsOf: moods)
            items.append(contentsOf: thoughts)
            items.append(contentsOf: exercises)
            items.append(contentsOf: journals)

            items.sort { $0.date > $1.date }
            let grouped = Dictionary(grouping: items) { calendar.startOfDay(for: $0.date) }
                .sorted { $0.key > $1.key }
            
            return grouped
        }.value

        guard !Task.isCancelled, updateTaskID == currentTaskID else { return }

        self.groupedItems = result
        self.isInitialized = true
    }
}
