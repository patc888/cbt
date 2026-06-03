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
    let isQuickCopingTool: Bool?
    let copingToolKind: String?
    let copingCategories: [String]?
    let breathingPattern: BreathingPattern?

    var isToolkitTool: Bool {
        isQuickCopingTool == true || !(copingCategories ?? []).isEmpty
    }

    var toolkitKind: String {
        let trimmed = copingToolKind?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? category : trimmed
    }

    var toolkitCategories: [CopingToolkitFilter] {
        var filters = (copingCategories ?? []).compactMap(CopingToolkitFilter.init(rawValue:))
        if filters.isEmpty {
            filters = Self.inferredToolkitCategories(for: self)
        } else {
            filters.appendUnique(contentsOf: Self.supportingToolkitCategories(for: self, existing: filters))
        }
        return filters
    }

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

    private static func inferredToolkitCategories(for exercise: Exercise) -> [CopingToolkitFilter] {
        let searchable = ([exercise.title, exercise.description, exercise.category] + (exercise.tags ?? []))
            .joined(separator: " ")
            .lowercased()
        var categories: [CopingToolkitFilter] = []

        func append(_ filter: CopingToolkitFilter, when condition: Bool) {
            if condition, !categories.contains(filter) {
                categories.append(filter)
            }
        }

        append(.anxiety, when: searchable.contains("anxiety") || searchable.contains("worry") || searchable.contains("grounding"))
        append(.panic, when: searchable.contains("panic") || searchable.contains("breath") || searchable.contains("grounding"))
        append(.sadness, when: searchable.contains("mood") || searchable.contains("sadness") || searchable.contains("values") || searchable.contains("compassion"))
        append(.anger, when: searchable.contains("anger") || searchable.contains("urge") || searchable.contains("emotion"))
        append(.overwhelm, when: searchable.contains("overwhelm") || searchable.contains("stress") || searchable.contains("reset") || searchable.contains("grounding") || searchable.contains("body"))
        append(.sleep, when: searchable.contains("sleep") || searchable.contains("wind down") || searchable.contains("scan"))
        append(.stress, when: searchable.contains("stress") || searchable.contains("reset") || searchable.contains("body"))
        append(.quickReset, when: exercise.duration <= 5 || searchable.contains("quick reset"))

        return categories.isEmpty ? [.stress] : categories
    }

    private static func supportingToolkitCategories(for exercise: Exercise, existing: [CopingToolkitFilter]) -> [CopingToolkitFilter] {
        var categories: [CopingToolkitFilter] = []
        let searchable = ([exercise.title, exercise.description, exercise.category] + (exercise.tags ?? []))
            .joined(separator: " ")
            .lowercased()

        if existing.contains(.stress) || existing.contains(.panic) || existing.contains(.quickReset) ||
            searchable.contains("overwhelm") || searchable.contains("grounding") || searchable.contains("reset") {
            categories.append(.overwhelm)
        }

        if searchable.contains("sadness") || existing.contains(.sadness) {
            categories.append(.sadness)
        }

        return categories
    }
}

private extension Array where Element == CopingToolkitFilter {
    mutating func appendUnique(contentsOf newElements: [CopingToolkitFilter]) {
        for element in newElements where !contains(element) {
            append(element)
        }
    }
}
