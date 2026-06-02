import Foundation
import SwiftData

enum AudioContentType: String, Codable, CaseIterable, Identifiable, Sendable {
    case meditation
    case breathwork
    case soundscape
    case sleep
    case grounding

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .meditation:
            return "Meditation"
        case .breathwork:
            return "Breathwork"
        case .soundscape:
            return "Soundscape"
        case .sleep:
            return "Sleep"
        case .grounding:
            return "Grounding"
        }
    }

    var systemImage: String {
        switch self {
        case .meditation:
            return "sparkles"
        case .breathwork:
            return "wind"
        case .soundscape:
            return "waveform"
        case .sleep:
            return "moon.zzz.fill"
        case .grounding:
            return "leaf.fill"
        }
    }
}

struct AudioContentSeed: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let category: String
    let approaches: [String]?
    let topics: [String]?
    let format: String?
    let duration: Int
    let difficulty: String?
    let tags: [String]?
    let type: AudioContentType
    let localAssetFilename: String
    let transcript: String
    let isPremium: Bool

    var displayApproaches: [String] {
        let explicit = LibraryTaxonomy.normalizedValues(approaches ?? [])
        return explicit.isEmpty ? LibraryTaxonomy.defaultApproaches(forLegacyCategory: category) : explicit
    }

    var displayTopics: [String] {
        let explicit = LibraryTaxonomy.normalizedValues(topics ?? [])
        return explicit.isEmpty ? LibraryTaxonomy.defaultTopics(forLegacyCategory: category) : explicit
    }

    var displayFormat: String {
        LibraryItemType.normalizedFormat(format ?? LibraryItemType.audio.rawValue)
    }

    var displayDifficulty: String {
        let trimmed = difficulty?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? LibraryTaxonomy.defaultDifficulty(forDuration: duration) : trimmed
    }

    var displayTags: [String] {
        LibraryTaxonomy.normalizedValues(tags ?? [])
    }
}

@Model
final class AudioContent {
    var id: String = ""
    var title: String = ""
    var contentDescription: String = ""
    var category: String = ""
    var duration: Int = 0
    var typeRawValue: String = AudioContentType.meditation.rawValue
    var localAssetFilename: String = ""
    var transcript: String = ""
    var isPremium: Bool = false
    var isCompleted: Bool = false
    var completedAt: Date?
    var isFavorite: Bool = false

    var type: AudioContentType {
        get { AudioContentType(rawValue: typeRawValue) ?? .meditation }
        set { typeRawValue = newValue.rawValue }
    }

    var description: String {
        get { contentDescription }
        set { contentDescription = newValue }
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        category: String,
        duration: Int,
        type: AudioContentType,
        localAssetFilename: String,
        transcript: String,
        isPremium: Bool = false,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.contentDescription = description
        self.category = category
        self.duration = duration
        self.typeRawValue = type.rawValue
        self.localAssetFilename = localAssetFilename
        self.transcript = transcript
        self.isPremium = isPremium
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.isFavorite = isFavorite
    }

    convenience init(seed: AudioContentSeed) {
        self.init(
            id: seed.id,
            title: seed.title,
            description: seed.description,
            category: seed.category,
            duration: seed.duration,
            type: seed.type,
            localAssetFilename: seed.localAssetFilename,
            transcript: seed.transcript,
            isPremium: seed.isPremium
        )
    }

    func updateCatalogFields(from seed: AudioContentSeed) {
        title = seed.title
        contentDescription = seed.description
        category = seed.category
        duration = seed.duration
        type = seed.type
        localAssetFilename = seed.localAssetFilename
        transcript = seed.transcript
        isPremium = seed.isPremium
    }

    func toggleFavorite() {
        isFavorite.toggle()
    }

    func markCompleted(at date: Date = Date()) {
        isCompleted = true
        completedAt = date
    }

    func resetCompletion() {
        isCompleted = false
        completedAt = nil
    }
}
