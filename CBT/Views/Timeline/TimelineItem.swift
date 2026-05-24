import Foundation
import SwiftData

enum TimelineItemKind: Sendable {
    case mood
    case thought
    case exercise
    case journal
}

enum TimelineRoute: Hashable, Sendable {
    case mood(PersistentIdentifier)
    case thought(PersistentIdentifier)
    case exercise(exerciseID: String)
    case journal(PersistentIdentifier)
}

struct TimelineItem: Identifiable, Sendable {
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
            chips: entry.emotions + entry.activityTags,
            route: .mood(entry.persistentModelID)
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
            route: .thought(record.persistentModelID)
        )
    }

    static func exercise(_ completion: ExerciseCompletion) -> TimelineItem {
        let exercise = ExerciseService.shared.exercise(withID: completion.exerciseID)

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
            route: .journal(entry.persistentModelID)
        )
    }
}
