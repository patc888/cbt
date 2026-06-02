import Foundation

@MainActor
struct LibraryFilter {
    let metadataFilter: LibraryMetadataFilter
    let metadataValue: String

    var hasActiveMetadataFilter: Bool {
        metadataFilter != .all && metadataValue != LibraryTaxonomy.allFilterLabel
    }

    func matches(item: LibraryItem) -> Bool {
        matches(
            approaches: item.approaches,
            topics: item.topics,
            format: item.format,
            difficulty: item.displayDifficulty
        )
    }

    func matches(course: Course) -> Bool {
        matches(
            approaches: course.approaches,
            topics: course.topics,
            format: course.displayFormat,
            difficulty: course.displayDifficulty
        )
    }

    func matches(
        approaches: [String],
        topics: [String],
        format: String,
        difficulty: String
    ) -> Bool {
        guard hasActiveMetadataFilter else { return true }

        switch metadataFilter {
        case .all:
            return true
        case .approach:
            return approaches.contains { $0.caseInsensitiveCompare(metadataValue) == .orderedSame }
        case .topic:
            return topics.contains { $0.caseInsensitiveCompare(metadataValue) == .orderedSame }
        case .format:
            return format.caseInsensitiveCompare(metadataValue) == .orderedSame
        case .difficulty:
            return difficulty.caseInsensitiveCompare(metadataValue) == .orderedSame
        }
    }

    func matchesAffirmationSection(query: String) -> Bool {
        let formatMatches = metadataFilter != .format ||
            metadataValue == LibraryTaxonomy.allFilterLabel ||
            metadataValue == LibraryItemType.affirmation.rawValue
        guard formatMatches else { return false }

        guard matches(
            approaches: ["Positive Psychology", "Self-Compassion"],
            topics: ["Anxiety Tools", "Depression Support", "Sleep & Wind Down", "Stress & Burnout"],
            format: LibraryItemType.affirmation.rawValue,
            difficulty: "Beginner"
        ) else {
            return false
        }

        guard !query.isBlankSearchQuery else { return true }

        let fields = [
            "Affirmation Practice",
            "Affirmations",
            "Positive Psychology",
            "Self-Compassion",
            "Anxiety Tools",
            "Depression Support",
            "Sleep & Wind Down"
        ]
        return Self.matchesSearchTerms(in: query, fields: fields)
    }

    func matchesProcrastinationCourse(query: String) -> Bool {
        guard matches(
            approaches: ["Behavioral Activation", "CBT"],
            topics: ["Productivity / Procrastination", "Depression Support"],
            format: LibraryItemType.course.rawValue,
            difficulty: "Beginner"
        ) else {
            return false
        }

        guard !query.isBlankSearchQuery else { return true }

        let fields = [
            "Tackling Procrastination",
            "Productivity / Procrastination",
            "Behavioral Activation",
            "CBT",
            "Course",
            "Beginner",
            "avoidance emotion regulation momentum"
        ]
        return Self.matchesSearchTerms(in: query, fields: fields)
    }

    static func itemMatchesSearch(_ item: LibraryItem, query: String) -> Bool {
        let terms = searchTerms(in: query)
        guard !terms.isEmpty else { return true }

        var fields = [
            item.title,
            item.category,
            item.format,
            item.displayDifficulty,
            "\(item.duration) minutes"
        ]
        fields.append(contentsOf: item.approaches)
        fields.append(contentsOf: item.topics)

        if let exercise = LibraryService.shared.exercise(for: item) {
            fields.append(exercise.description)
            fields.append(contentsOf: exercise.steps)
            fields.append(contentsOf: exercise.displayApproaches)
            fields.append(contentsOf: exercise.displayTopics)
            fields.append(exercise.displayDifficulty)
            fields.append(exercise.displayFormat)
            fields.appendIfPresent(exercise.completionSummary)
            fields.appendIfPresent(exercise.journalReflection)
            fields.append(contentsOf: exercise.tags ?? [])
        }

        if let audioContent = LibraryService.shared.audioContent(for: item) {
            fields.append(audioContent.description)
            fields.append(audioContent.type.displayName)
            fields.append(audioContent.localAssetFilename)
            fields.append(audioContent.transcript)
            fields.append(contentsOf: audioContent.displayTags)
            fields.append(audioContent.isPremium ? "premium" : "free")
        }

        return matchesSearchTerms(terms, fields: fields)
    }

    static func courseMatchesSearch(_ course: Course, query: String) -> Bool {
        let terms = searchTerms(in: query)
        guard !terms.isEmpty else { return true }

        var fields = [
            course.title,
            course.subtitle,
            course.courseDescription,
            course.approach,
            course.category,
            course.displayFormat,
            course.displayDifficulty,
            course.completionMessage,
            "\(course.estimatedTotalDuration) minutes"
        ]
        fields.append(contentsOf: course.approaches)
        fields.append(contentsOf: course.topics)
        fields.append(contentsOf: course.lessons.flatMap { lesson in
            [
                lesson.title,
                lesson.shortEducationalText,
                lesson.keyTakeaway,
                lesson.reflectionPrompt ?? ""
            ]
        })

        return matchesSearchTerms(terms, fields: fields)
    }

    static func searchTerms(in query: String) -> [String] {
        query
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    private static func matchesSearchTerms(in query: String, fields: [String]) -> Bool {
        matchesSearchTerms(searchTerms(in: query), fields: fields)
    }

    private static func matchesSearchTerms(_ terms: [String], fields: [String]) -> Bool {
        let haystack = fields.joined(separator: " ").lowercased()
        return terms.allSatisfy { haystack.contains($0) }
    }
}

private extension String {
    var isBlankSearchQuery: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private extension Array where Element == String {
    mutating func appendIfPresent(_ value: String?) {
        guard let value, !value.isEmpty else { return }
        append(value)
    }
}
