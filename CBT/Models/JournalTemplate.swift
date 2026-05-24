import Foundation
import SwiftUI

struct JournalPromptStep: Codable, Hashable, Identifiable {
    let id: String
    let title: String?
    let prompt: String
    let helperText: String?
    let placeholder: String?

    var text: String { prompt }

    init(
        id: String,
        title: String? = nil,
        prompt: String,
        helperText: String? = nil,
        placeholder: String? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.helperText = helperText
        self.placeholder = placeholder
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case prompt
        case text
        case helperText
        case placeholder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedPrompt = try container.decodeIfPresent(String.self, forKey: .prompt)
            ?? container.decode(String.self, forKey: .text)

        prompt = decodedPrompt
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? Self.makeID(from: decodedPrompt)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        helperText = try container.decodeIfPresent(String.self, forKey: .helperText)
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(prompt, forKey: .prompt)
        try container.encodeIfPresent(helperText, forKey: .helperText)
        try container.encodeIfPresent(placeholder, forKey: .placeholder)
    }

    private static func makeID(from prompt: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let words = prompt
            .lowercased()
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
            .prefix(6)
        return words.joined(separator: "_")
    }
}

typealias JournalPrompt = JournalPromptStep

struct JournalTemplate: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let category: String
    let approach: String
    let estimatedDurationMinutes: Int
    let promptSteps: [JournalPromptStep]
    let helperText: String?
    let moodEmotionTags: [String]
    let completionReflection: String
    let iconName: String
    let colorHexes: [String]
    let isRecommended: Bool
    let legacyTemplateTypes: [String]

    var name: String { title }
    var prompts: [JournalPromptStep] { promptSteps }
    var completionMessage: String { completionReflection }
    var tags: [String] { moodEmotionTags }
    var storageKey: String { id }
    var icon: String { iconName }
    var durationLabel: String { "\(estimatedDurationMinutes) min" }

    var gradientColors: [Color] {
        let colors = colorHexes.map(Color.init(hex:))
        return colors.isEmpty ? [Color.accentColor, Color.blue] : colors
    }

    init(
        id: String,
        title: String,
        description: String,
        category: String,
        approach: String,
        estimatedDurationMinutes: Int,
        promptSteps: [JournalPromptStep],
        helperText: String? = nil,
        moodEmotionTags: [String] = [],
        completionReflection: String,
        iconName: String = "pencil.and.list.clipboard",
        colorHexes: [String] = ["#0EA5E9", "#14B8A6"],
        isRecommended: Bool = false,
        legacyTemplateTypes: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.approach = approach
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.promptSteps = promptSteps
        self.helperText = helperText
        self.moodEmotionTags = moodEmotionTags
        self.completionReflection = completionReflection
        self.iconName = iconName
        self.colorHexes = colorHexes
        self.isRecommended = isRecommended
        self.legacyTemplateTypes = legacyTemplateTypes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case category
        case approach
        case estimatedDurationMinutes
        case promptSteps
        case prompts
        case helperText
        case moodEmotionTags
        case tags
        case completionReflection
        case completionMessage
        case icon
        case iconName
        case colorHexes
        case isRecommended
        case legacyTemplateTypes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decode(String.self, forKey: .category)
        approach = try container.decode(String.self, forKey: .approach)
        estimatedDurationMinutes = try container.decode(Int.self, forKey: .estimatedDurationMinutes)
        promptSteps = try container.decodeIfPresent([JournalPromptStep].self, forKey: .promptSteps)
            ?? container.decode([JournalPromptStep].self, forKey: .prompts)
        helperText = try container.decodeIfPresent(String.self, forKey: .helperText)
        moodEmotionTags = try container.decodeIfPresent([String].self, forKey: .moodEmotionTags)
            ?? container.decodeIfPresent([String].self, forKey: .tags)
            ?? []
        completionReflection = try container.decodeIfPresent(String.self, forKey: .completionReflection)
            ?? container.decode(String.self, forKey: .completionMessage)
        iconName = try container.decodeIfPresent(String.self, forKey: .icon)
            ?? container.decodeIfPresent(String.self, forKey: .iconName)
            ?? Self.defaultIcon(for: category)
        colorHexes = try container.decodeIfPresent([String].self, forKey: .colorHexes)
            ?? Self.defaultColorHexes(for: category)
        isRecommended = try container.decodeIfPresent(Bool.self, forKey: .isRecommended) ?? false
        legacyTemplateTypes = try container.decodeIfPresent([String].self, forKey: .legacyTemplateTypes) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(category, forKey: .category)
        try container.encode(approach, forKey: .approach)
        try container.encode(estimatedDurationMinutes, forKey: .estimatedDurationMinutes)
        try container.encode(promptSteps, forKey: .promptSteps)
        try container.encodeIfPresent(helperText, forKey: .helperText)
        try container.encode(moodEmotionTags, forKey: .moodEmotionTags)
        try container.encode(completionReflection, forKey: .completionReflection)
        try container.encode(iconName, forKey: .icon)
        try container.encode(colorHexes, forKey: .colorHexes)
        try container.encode(isRecommended, forKey: .isRecommended)
        try container.encode(legacyTemplateTypes, forKey: .legacyTemplateTypes)
    }

    func matches(storedTemplateType: String) -> Bool {
        let storedKey = Self.normalizedKey(storedTemplateType)
        guard !storedKey.isEmpty else { return false }

        let knownKeys = [id, title] + legacyTemplateTypes
        return knownKeys.contains { Self.normalizedKey($0) == storedKey }
    }

    static let categoryOrder = [
        "Anxiety",
        "Low Mood",
        "Self-Esteem",
        "Self-Compassion",
        "Relationships",
        "Productivity",
        "Sleep",
        "Stress & Burnout",
        "Values",
        "Mindfulness",
        "Gratitude"
    ]

    static let allTemplates: [JournalTemplate] = JournalTemplateCatalog.load()

    static let preview = JournalTemplate(
        id: "preview_reflection",
        title: "Preview Reflection",
        description: "A short sample reflection for previews.",
        category: "Mindfulness",
        approach: "Mindfulness",
        estimatedDurationMinutes: 5,
        promptSteps: [
            JournalPromptStep(
                id: "notice",
                prompt: "What are you noticing right now?",
                helperText: "A few words are enough.",
                placeholder: "Right now I notice..."
            )
        ],
        completionReflection: "Your reflection has been saved.",
        iconName: "leaf.fill",
        colorHexes: ["#22C55E", "#14B8A6"],
        legacyTemplateTypes: ["Preview Reflection"]
    )

    static var gratitude: JournalTemplate {
        template(id: "gratitude_reflection") ?? JournalTemplateCatalog.fallbackGratitude
    }

    static var impostorSyndrome: JournalTemplate {
        template(id: "impostor_syndrome_unpacker") ?? JournalTemplateCatalog.fallbackImpostorSyndrome
    }

    static func template(id: String) -> JournalTemplate? {
        allTemplates.first { $0.id == id }
    }

    static func template(matching storedTemplateType: String) -> JournalTemplate? {
        allTemplates.first { $0.matches(storedTemplateType: storedTemplateType) }
    }

    static func normalizedKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func defaultIcon(for category: String) -> String {
        switch category {
        case "Anxiety":
            return "wind"
        case "Low Mood":
            return "cloud.sun.fill"
        case "Self-Esteem", "Self-Compassion":
            return "sparkles"
        case "Relationships":
            return "person.2.fill"
        case "Productivity":
            return "checkmark.circle.fill"
        case "Sleep":
            return "moon.fill"
        case "Stress & Burnout":
            return "flame.fill"
        case "Values":
            return "star.circle.fill"
        case "Mindfulness":
            return "leaf.fill"
        case "Gratitude":
            return "sun.max.fill"
        default:
            return "doc.text.fill"
        }
    }

    private static func defaultColorHexes(for category: String) -> [String] {
        switch category {
        case "Anxiety":
            return ["#14B8A6", "#2563EB"]
        case "Low Mood":
            return ["#06B6D4", "#4F46E5"]
        case "Self-Esteem", "Self-Compassion":
            return ["#EC4899", "#F97316"]
        case "Relationships":
            return ["#34D399", "#16A34A"]
        case "Productivity":
            return ["#2563EB", "#16A34A"]
        case "Sleep":
            return ["#4F46E5", "#9333EA"]
        case "Stress & Burnout":
            return ["#DC2626", "#F97316"]
        case "Values":
            return ["#16A34A", "#14B8A6"]
        case "Mindfulness":
            return ["#22C55E", "#34D399"]
        case "Gratitude":
            return ["#F97316", "#FACC15"]
        default:
            return ["#0EA5E9", "#14B8A6"]
        }
    }
}

enum JournalTemplateCatalog {
    private static let resourceName = "GuidedJournalTemplates"

    static let fallbackGratitude = JournalTemplate(
        id: "gratitude_reflection",
        title: "Gratitude Reflection",
        description: "Focus on the positive aspects of your day.",
        category: "Gratitude",
        approach: "Positive Psychology",
        estimatedDurationMinutes: 4,
        promptSteps: [
            JournalPromptStep(
                id: "smile",
                title: "Notice",
                prompt: "What made you smile today?",
                helperText: "Small moments count here.",
                placeholder: "A moment that lifted me was..."
            ),
            JournalPromptStep(
                id: "person",
                title: "Appreciate",
                prompt: "Name a person you are thankful for.",
                helperText: "You can write about what they did, how they show up, or what they mean to you.",
                placeholder: "I am thankful for..."
            )
        ],
        helperText: "Let this be specific and ordinary. Gratitude works best when it has texture.",
        moodEmotionTags: ["Grateful", "Content", "Hopeful"],
        completionReflection: "Your gratitude reflection has been saved.",
        iconName: "sun.max.fill",
        colorHexes: ["#F97316", "#FACC15"],
        isRecommended: true,
        legacyTemplateTypes: ["Gratitude Reflection", "gratitude"]
    )

    static let fallbackImpostorSyndrome = JournalTemplate(
        id: "impostor_syndrome_unpacker",
        title: "Impostor Syndrome Unpacker",
        description: "Examine self-doubt with objective facts.",
        category: "Self-Compassion",
        approach: "CBT",
        estimatedDurationMinutes: 5,
        promptSteps: [
            JournalPromptStep(
                id: "achievement",
                title: "Name It",
                prompt: "What achievement are you downplaying right now?",
                helperText: "Pick one specific thing, even if part of you wants to dismiss it.",
                placeholder: "Something I earned or contributed to was..."
            ),
            JournalPromptStep(
                id: "evidence",
                title: "Check the Facts",
                prompt: "What objective, factual evidence proves you earned it?",
                helperText: "Look for observable actions, preparation, feedback, effort, or outcomes.",
                placeholder: "The facts that support me are..."
            )
        ],
        helperText: "Treat the impostor thought as a hypothesis, then check what the evidence actually says.",
        moodEmotionTags: ["Self-Doubt", "Anxious", "Proud"],
        completionReflection: "Your evidence-based reflection has been saved.",
        iconName: "brain.head.profile",
        colorHexes: ["#A855F7", "#4F46E5"],
        isRecommended: true,
        legacyTemplateTypes: ["Impostor Syndrome Unpacker", "impostor_syndrome"]
    )

    static func load() -> [JournalTemplate] {
        guard let url = resourceURL() else {
            return fallbackTemplates
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([JournalTemplate].self, from: data)
            let validTemplates = uniqueValidTemplates(from: decoded)
            return validTemplates.isEmpty ? fallbackTemplates : validTemplates
        } catch {
            return fallbackTemplates
        }
    }

    private static var fallbackTemplates: [JournalTemplate] {
        [fallbackGratitude, fallbackImpostorSyndrome]
    }

    private static func resourceURL() -> URL? {
        let directBundles = [Bundle.main, Bundle(for: BundleToken.self)]

        if let url = directBundles.compactMap({ $0.url(forResource: resourceName, withExtension: "json") }).first {
            return url
        }

        return Bundle.allBundles
            .compactMap { $0.url(forResource: resourceName, withExtension: "json") }
            .first
    }

    private static func uniqueValidTemplates(from templates: [JournalTemplate]) -> [JournalTemplate] {
        var seenIDs = Set<String>()

        return templates.filter { template in
            let id = template.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, !template.title.isEmpty, !template.promptSteps.isEmpty else {
                return false
            }
            return seenIDs.insert(id).inserted
        }
    }
}

private final class BundleToken {}
