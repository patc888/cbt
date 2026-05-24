import Foundation
import SwiftData

enum LibraryItemType: String, Codable, CaseIterable, Identifiable {
    case audio = "Audio"
    case article = "Article"
    case affirmation = "Affirmation"
    case course = "Course"
    case exercise = "Exercise"
    case journalPrompt = "Journal Prompt"

    var id: String { rawValue }

    var systemImage: String {
        Self.systemImage(for: rawValue)
    }

    static func systemImage(for format: String) -> String {
        let normalized = normalizedFormat(format)
        if normalized == audio.rawValue {
            return "headphones"
        } else if normalized == article.rawValue {
            return "doc.text"
        } else if normalized == affirmation.rawValue {
            return "quote.bubble"
        } else if normalized == course.rawValue {
            return "graduationcap.fill"
        } else if normalized == exercise.rawValue {
            return "figure.mind.and.body"
        } else if normalized == journalPrompt.rawValue {
            return "book.pages"
        }

        return "sparkles"
    }

    static func normalizedFormat(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return exercise.rawValue }

        return allCases.first { $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame }?.rawValue ?? trimmed
    }
}

enum LibraryTaxonomy {
    static let allFilterLabel = "All"
    static let defaultDifficulty = "Beginner"

    static let approachOrder = [
        "CBT",
        "DBT",
        "ACT",
        "Mindfulness",
        "Positive Psychology",
        "Behavioral Activation",
        "Self-Compassion"
    ]

    static let topicOrder = [
        "Anxiety Tools",
        "Depression Support",
        "Stress & Burnout",
        "Sleep & Wind Down",
        "Relationships",
        "Productivity / Procrastination"
    ]

    static let formatOrder = [
        LibraryItemType.exercise.rawValue,
        LibraryItemType.course.rawValue,
        LibraryItemType.journalPrompt.rawValue,
        LibraryItemType.audio.rawValue,
        LibraryItemType.affirmation.rawValue,
        LibraryItemType.article.rawValue
    ]

    static let difficultyOrder = [
        "Easy",
        "Beginner",
        "Moderate",
        "Intermediate",
        "Advanced"
    ]

    static func normalizedValues(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { result, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if !result.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                result.append(trimmed)
            }
        }
    }

    static func orderedValues(_ values: [String], preferredOrder: [String] = []) -> [String] {
        let normalized = normalizedValues(values)
        return normalized.sorted { first, second in
            let firstIndex = preferredOrder.firstIndex { $0.caseInsensitiveCompare(first) == .orderedSame }
            let secondIndex = preferredOrder.firstIndex { $0.caseInsensitiveCompare(second) == .orderedSame }

            switch (firstIndex, secondIndex) {
            case let (firstIndex?, secondIndex?):
                return firstIndex < secondIndex
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return first.localizedCaseInsensitiveCompare(second) == .orderedAscending
            }
        }
    }

    static func defaultApproaches(forLegacyCategory category: String) -> [String] {
        switch normalizedLegacyCategory(category) {
        case "Anxiety Reset":
            return ["Mindfulness", "CBT"]
        case "Behavioral Activation":
            return ["Behavioral Activation"]
        case "Cognitive Distortions", "Exposure Practice", "Thought Reframing":
            return ["CBT"]
        case "Acceptance", "Committed Action", "Defusion", "Self-as-Context", "Values":
            return ["ACT"]
        case "Distress Tolerance", "Emotion Regulation", "Self-Soothing", "Wellness Basics":
            return ["DBT"]
        case "Gratitude", "Positive Psychology":
            return ["Positive Psychology"]
        case "Grounding", "Mindfulness":
            return ["Mindfulness"]
        case "Self Compassion", "Self-Compassion":
            return ["Self-Compassion"]
        default:
            return ["CBT"]
        }
    }

    static func defaultTopics(forLegacyCategory category: String) -> [String] {
        switch normalizedLegacyCategory(category) {
        case "Anxiety Reset", "Distress Tolerance", "Exposure Practice", "Grounding", "Mindfulness", "Self-Soothing":
            return ["Anxiety Tools", "Stress & Burnout"]
        case "Acceptance", "Defusion", "Self-as-Context":
            return ["Anxiety Tools", "Stress & Burnout"]
        case "Behavioral Activation":
            return ["Depression Support", "Productivity / Procrastination"]
        case "Committed Action", "Values":
            return ["Productivity / Procrastination", "Relationships"]
        case "Cognitive Distortions", "Thought Reframing":
            return ["Anxiety Tools", "Depression Support"]
        case "Emotion Regulation":
            return ["Stress & Burnout", "Relationships"]
        case "Gratitude", "Positive Psychology":
            return ["Stress & Burnout", "Relationships"]
        case "Self Compassion", "Self-Compassion":
            return ["Depression Support", "Stress & Burnout"]
        case "Wellness Basics":
            return ["Sleep & Wind Down", "Stress & Burnout"]
        default:
            return normalizedValues([category])
        }
    }

    static func defaultDifficulty(forDuration duration: Int) -> String {
        switch duration {
        case ..<8:
            return "Beginner"
        case 8...12:
            return "Intermediate"
        default:
            return "Advanced"
        }
    }

    static func highestDifficulty(in values: [String]) -> String {
        orderedValues(values, preferredOrder: difficultyOrder).last ?? defaultDifficulty
    }

    static func normalizedLegacyCategory(_ category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "Self-Compassion" ? "Self Compassion" : trimmed
    }
}

@Model
final class LibraryItem {
    var id: String = ""
    var title: String = ""
    var category: String = ""
    var contentData: Data = Data()
    var typeRawValue: String = LibraryItemType.exercise.rawValue
    var duration: Int = 0
    var approachesStorage: String = "[]"
    var topicsStorage: String = "[]"
    var difficulty: String = LibraryTaxonomy.defaultDifficulty

    var type: LibraryItemType {
        get { LibraryItemType(rawValue: format) ?? .exercise }
        set { format = newValue.rawValue }
    }

    var format: String {
        get { LibraryItemType.normalizedFormat(typeRawValue) }
        set { typeRawValue = LibraryItemType.normalizedFormat(newValue) }
    }

    var approaches: [String] {
        get {
            let stored = LibraryTaxonomy.normalizedValues(StringArrayStorage.decode(approachesStorage))
            return stored.isEmpty ? LibraryTaxonomy.defaultApproaches(forLegacyCategory: category) : stored
        }
        set { approachesStorage = StringArrayStorage.encode(LibraryTaxonomy.normalizedValues(newValue)) }
    }

    var topics: [String] {
        get {
            let stored = LibraryTaxonomy.normalizedValues(StringArrayStorage.decode(topicsStorage))
            return stored.isEmpty ? LibraryTaxonomy.defaultTopics(forLegacyCategory: category) : stored
        }
        set { topicsStorage = StringArrayStorage.encode(LibraryTaxonomy.normalizedValues(newValue)) }
    }

    var displayDifficulty: String {
        let trimmed = difficulty.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? LibraryTaxonomy.defaultDifficulty(forDuration: duration) : trimmed
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        category: String,
        contentData: Data = Data(),
        type: LibraryItemType,
        duration: Int,
        approaches: [String] = [],
        topics: [String] = [],
        difficulty: String = LibraryTaxonomy.defaultDifficulty
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.contentData = contentData
        self.typeRawValue = LibraryItemType.normalizedFormat(type.rawValue)
        self.duration = duration
        self.approachesStorage = StringArrayStorage.encode(LibraryTaxonomy.normalizedValues(approaches))
        self.topicsStorage = StringArrayStorage.encode(LibraryTaxonomy.normalizedValues(topics))
        self.difficulty = difficulty
    }
}
