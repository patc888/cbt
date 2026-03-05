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
