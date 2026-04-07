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

        let moods = moodEntries.filter { !$0.isDeleted }
        let thoughts = thoughtRecords.filter { !$0.isDeleted }
        let exercises = exerciseCompletions.filter { !$0.isDeleted }
        let journals = journalEntries.filter { !$0.isDeleted }
        let calendar = Calendar.current
        var items: [TimelineItem] = []
        items.reserveCapacity(moods.count + thoughts.count + exercises.count + journals.count)

        for mood in moods {
            items.append(.mood(mood))
        }
        for thought in thoughts {
            items.append(.thought(thought))
        }
        for exercise in exercises {
            items.append(.exercise(exercise))
        }
        for journal in journals {
            items.append(.journal(journal))
        }

        items.sort { $0.date > $1.date }
        let groupedItems = Dictionary(grouping: items) { calendar.startOfDay(for: $0.date) }
            .sorted { $0.key > $1.key }

        guard !Task.isCancelled, updateTaskID == currentTaskID else { return }

        self.groupedItems = groupedItems
        self.isInitialized = true
    }
}
