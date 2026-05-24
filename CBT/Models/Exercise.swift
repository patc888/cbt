import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let approach: String?
    let approaches: [String]?
    let category: String
    let topics: [String]?
    let format: String?
    let duration: Int
    let difficulty: String?
    let description: String
    let steps: [String]
    let completionSummary: String?
    let journalReflection: String?
    let tags: [String]?
    let breathingPattern: BreathingPattern?

    var displayApproach: String {
        let trimmed = approach?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return displayApproaches.first ?? "CBT"
    }

    var displayApproaches: [String] {
        let explicit = LibraryTaxonomy.normalizedValues(approaches ?? [])
        if !explicit.isEmpty { return explicit }

        let legacy = LibraryTaxonomy.normalizedValues([approach ?? ""])
        if !legacy.isEmpty { return legacy }

        return LibraryTaxonomy.defaultApproaches(forLegacyCategory: category)
    }

    var displayTopics: [String] {
        let explicit = LibraryTaxonomy.normalizedValues(topics ?? [])
        return explicit.isEmpty ? LibraryTaxonomy.defaultTopics(forLegacyCategory: category) : explicit
    }

    var displayFormat: String {
        LibraryItemType.normalizedFormat(format ?? LibraryItemType.exercise.rawValue)
    }

    var displayDifficulty: String {
        let trimmed = difficulty?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? LibraryTaxonomy.defaultDifficulty(forDuration: duration) : trimmed
    }
}
