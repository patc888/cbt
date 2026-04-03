import Foundation
import SwiftData

enum TimelineItemKind {
    case mood
    case thought
    case exercise
    case journal
}

enum TimelineRoute: Hashable {
    case mood(MoodEntry)
    case thought(ThoughtRecord)
    case exercise(exerciseID: String)
    case journal(JournalEntry)
}

struct TimelineItem: Identifiable {
    let id: String
    let kind: TimelineItemKind
    let date: Date
    let title: String
    let subtitle: String?
    let chips: [String]
    let route: TimelineRoute?
}

extension TimelineItem {
    static func mood(_ entry: MoodEntry) -> TimelineItem {
        TimelineItem(
            id: "mood-\(entry.id)",
            kind: .mood,
            date: entry.createdAt,
            title: "Mood Check-in",
            subtitle: entry.notes?.isEmpty == false ? entry.notes : "Score: \(entry.moodScore)/10",
            chips: entry.emotions,
            route: .mood(entry)
        )
    }

    static func thought(_ record: ThoughtRecord) -> TimelineItem {
        TimelineItem(
            id: "thought-\(record.id)",
            kind: .thought,
            date: record.createdAt,
            title: "Thought Record",
            subtitle: record.situation.isEmpty ? "No situation recorded" : record.situation,
            chips: record.emotions + record.distortions,
            route: .thought(record)
        )
    }

    static func exercise(_ completion: ExerciseCompletion) -> TimelineItem {
        let exercise = ExerciseLibrary.shared.exercise(withID: completion.exerciseID)

        return TimelineItem(
            id: "ex-\(completion.id)",
            kind: .exercise,
            date: completion.createdAt,
            title: exercise?.title ?? "Exercise",
            subtitle: completion.notes?.isEmpty == false ? completion.notes : nil,
            chips: [],
            route: .exercise(exerciseID: completion.exerciseID)
        )
    }

    static func journal(_ entry: JournalEntry) -> TimelineItem {
        return TimelineItem(
            id: "journal-\(entry.id)",
            kind: .journal,
            date: entry.createdAt,
            title: entry.title,
            subtitle: entry.sessionMetadataLine,
            chips: [],
            route: .journal(entry)
        )
    }
}
