import SwiftData
import SwiftUI

struct TimelineRouteDestinationView: View {
    let route: TimelineRoute

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        switch route {
        case .mood(let id):
            if let entry = modelContext.model(for: id) as? MoodEntry {
                MoodDetailView(entry: entry)
            } else {
                missingContent(title: "Mood Entry Not Found", systemImage: "face.smiling")
            }
        case .thought(let id):
            if let record = modelContext.model(for: id) as? ThoughtRecord {
                ThoughtRecordDetailView(record: record)
            } else {
                missingContent(title: "Thought Record Not Found", systemImage: "brain")
            }
        case .exercise(let exerciseID):
            if let exercise = ExerciseLibrary.shared.exercise(withID: exerciseID) {
                ExerciseDetailView(exercise: exercise)
            } else {
                missingContent(title: "Exercise Not Found", systemImage: "exclamationmark.triangle")
            }
        case .journal(let id):
            if let entry = modelContext.model(for: id) as? JournalEntry {
                JournalEntryDetailView(entry: entry)
            } else {
                missingContent(title: "Journal Entry Not Found", systemImage: "book.pages")
            }
        }
    }

    @ViewBuilder
    private func missingContent(title: LocalizedStringKey, systemImage: String) -> some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text("This item may have been deleted or is no longer available.")
        )
    }
}
