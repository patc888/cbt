import Foundation
import SwiftData

struct CourseLesson: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var title: String
    var shortEducationalText: String
    var keyTakeaway: String
    var reflectionPrompt: String?
    var linkedExerciseID: String?
    var estimatedDuration: Int

    init(
        id: String = UUID().uuidString,
        title: String,
        shortEducationalText: String,
        keyTakeaway: String,
        reflectionPrompt: String? = nil,
        linkedExerciseID: String? = nil,
        estimatedDuration: Int
    ) {
        self.id = id
        self.title = title
        self.shortEducationalText = shortEducationalText
        self.keyTakeaway = keyTakeaway
        self.reflectionPrompt = reflectionPrompt
        self.linkedExerciseID = linkedExerciseID
        self.estimatedDuration = max(0, estimatedDuration)
    }

    var completionID: String {
        guard let linkedExerciseID, !linkedExerciseID.isEmpty else { return id }
        return linkedExerciseID
    }
}

@Model
final class Course {
    var id: String = ""
    var title: String = ""
    var subtitle: String = ""
    var descriptionText: String = ""
    var approach: String = ""
    var category: String = ""
    var difficulty: String = ""
    var approachesStorage: String = "[]"
    var topicsStorage: String = "[]"
    var format: String = LibraryItemType.course.rawValue
    var estimatedTotalDuration: Int = 0
    var lessonCount: Int = 0
    var lessonsData: Data = Data()
    var linkedExerciseIDsStorage: String = "[]"
    var linkedGuidedJournalIDsStorage: String = "[]"
    var finalReflectionPrompt: String?
    var completionMessage: String = ""
    var finalReflectionResponse: String?
    var isPremium: Bool = false
    var itemIDsStorage: String = "[]"
    var completedItemIDsStorage: String = "[]"
    var isCompleted: Bool = false
    var completedAt: Date?

    var courseDescription: String {
        get { descriptionText }
        set { descriptionText = newValue }
    }

    var approaches: [String] {
        get {
            let stored = LibraryTaxonomy.normalizedValues(StringArrayStorage.decode(approachesStorage))
            if !stored.isEmpty { return stored }
            let legacy = LibraryTaxonomy.normalizedValues([approach])
            return legacy.isEmpty ? LibraryTaxonomy.defaultApproaches(forLegacyCategory: category) : legacy
        }
        set {
            let normalized = LibraryTaxonomy.normalizedValues(newValue)
            approachesStorage = StringArrayStorage.encode(normalized)
            if approach.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                approach = normalized.first ?? ""
            }
        }
    }

    var topics: [String] {
        get {
            let stored = LibraryTaxonomy.normalizedValues(StringArrayStorage.decode(topicsStorage))
            if !stored.isEmpty { return stored }
            let legacy = LibraryTaxonomy.normalizedValues([category])
            return legacy.isEmpty ? LibraryTaxonomy.defaultTopics(forLegacyCategory: category) : legacy
        }
        set {
            let normalized = LibraryTaxonomy.normalizedValues(newValue)
            topicsStorage = StringArrayStorage.encode(normalized)
            if category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                category = normalized.first ?? ""
            }
        }
    }

    var displayFormat: String {
        LibraryItemType.normalizedFormat(format.isEmpty ? LibraryItemType.course.rawValue : format)
    }

    var displayDifficulty: String {
        let trimmed = difficulty.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? LibraryTaxonomy.defaultDifficulty(forDuration: estimatedTotalDuration) : trimmed
    }

    var lessons: [CourseLesson] {
        get { CourseLessonStorage.decode(lessonsData) }
        set {
            lessonsData = CourseLessonStorage.encode(newValue)
            syncLessonDerivedMetadata()
            updateCompletionState()
        }
    }

    var linkedExerciseIDs: [String] {
        get { StringArrayStorage.decode(linkedExerciseIDsStorage) }
        set { linkedExerciseIDsStorage = StringArrayStorage.encode(newValue) }
    }

    var linkedGuidedJournalIDs: [String] {
        get { StringArrayStorage.decode(linkedGuidedJournalIDsStorage) }
        set { linkedGuidedJournalIDsStorage = StringArrayStorage.encode(newValue) }
    }

    var itemIDs: [String] {
        get { StringArrayStorage.decode(itemIDsStorage) }
        set {
            itemIDsStorage = StringArrayStorage.encode(newValue)
            updateCompletionState()
        }
    }

    var completedItemIDs: [String] {
        get { StringArrayStorage.decode(completedItemIDsStorage) }
        set {
            completedItemIDsStorage = StringArrayStorage.encode(newValue)
            updateCompletionState()
        }
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String = "",
        description: String = "",
        approach: String = "",
        approaches: [String] = [],
        category: String = "",
        topics: [String] = [],
        difficulty: String = "",
        format: String = LibraryItemType.course.rawValue,
        estimatedTotalDuration: Int = 0,
        lessonCount: Int = 0,
        lessons: [CourseLesson] = [],
        linkedExerciseIDs: [String]? = nil,
        linkedGuidedJournalIDs: [String] = [],
        finalReflectionPrompt: String? = nil,
        completionMessage: String = "",
        finalReflectionResponse: String? = nil,
        isPremium: Bool = false,
        itemIDs: [String],
        completedItemIDs: [String] = [],
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        let normalizedApproaches = LibraryTaxonomy.normalizedValues(approaches)
        let normalizedTopics = LibraryTaxonomy.normalizedValues(topics)

        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.descriptionText = description
        self.approach = approach.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? normalizedApproaches.first ?? "" : approach
        self.category = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? normalizedTopics.first ?? "" : category
        self.difficulty = difficulty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? LibraryTaxonomy.defaultDifficulty(forDuration: estimatedTotalDuration) : difficulty
        self.approachesStorage = StringArrayStorage.encode(normalizedApproaches)
        self.topicsStorage = StringArrayStorage.encode(normalizedTopics)
        self.format = LibraryItemType.normalizedFormat(format)
        self.estimatedTotalDuration = estimatedTotalDuration
        self.lessonCount = lessonCount
        self.lessonsData = CourseLessonStorage.encode(lessons)
        self.linkedExerciseIDsStorage = StringArrayStorage.encode(linkedExerciseIDs ?? itemIDs)
        self.linkedGuidedJournalIDsStorage = StringArrayStorage.encode(linkedGuidedJournalIDs)
        self.finalReflectionPrompt = finalReflectionPrompt
        self.completionMessage = completionMessage
        self.finalReflectionResponse = finalReflectionResponse
        self.isPremium = isPremium
        self.itemIDsStorage = StringArrayStorage.encode(itemIDs)
        self.completedItemIDsStorage = StringArrayStorage.encode(completedItemIDs)
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        syncLessonDerivedMetadata()
        updateCompletionState()
    }

    func markCompleted(itemID: String, completedAt completionDate: Date = Date()) {
        guard completionIDs.contains(itemID) || itemIDs.contains(itemID) else { return }
        let wasCompleted = isCompleted
        var updated = completedItemIDs
        if !updated.contains(itemID) {
            updated.append(itemID)
        }
        completedItemIDs = updated
        if !wasCompleted && isCompleted {
            completedAt = completionDate
        }
    }

    func markCompleted(lesson: CourseLesson, completedAt completionDate: Date = Date()) {
        markCompleted(itemID: lesson.completionID, completedAt: completionDate)
    }

    func isLessonCompleted(_ lesson: CourseLesson) -> Bool {
        completedItemIDs.contains(lesson.completionID)
    }

    func orderedItems(from libraryItems: [LibraryItem]) -> [LibraryItem] {
        let itemsByID = Self.libraryItemsByID(libraryItems)
        return itemIDs.compactMap { itemsByID[$0] }
    }

    func linkedItems(from libraryItems: [LibraryItem]) -> [LibraryItem] {
        let itemsByID = Self.libraryItemsByID(libraryItems)
        return linkedExerciseIDs.compactMap { itemsByID[$0] }
    }

    func progressIndex(in libraryItems: [LibraryItem]) -> Int {
        let orderedIDs = completionIDs.isEmpty ? orderedItems(from: libraryItems).map(\.id) : completionIDs
        return orderedIDs.firstIndex { !completedItemIDs.contains($0) } ?? max(orderedIDs.count - 1, 0)
    }

    var completedLessonCount: Int {
        completionIDs.filter { completedItemIDs.contains($0) }.count
    }

    var progressTotal: Int {
        completionIDs.count
    }

    var progressFraction: Double {
        guard progressTotal > 0 else { return 0 }
        return Double(completedLessonCount) / Double(progressTotal)
    }

    func applyContent(from seed: Course) {
        title = seed.title
        subtitle = seed.subtitle
        descriptionText = seed.descriptionText
        approach = seed.approach
        category = seed.category
        difficulty = seed.difficulty
        approachesStorage = seed.approachesStorage
        topicsStorage = seed.topicsStorage
        format = seed.format
        estimatedTotalDuration = seed.estimatedTotalDuration
        lessonCount = seed.lessonCount
        lessonsData = seed.lessonsData
        linkedExerciseIDsStorage = seed.linkedExerciseIDsStorage
        linkedGuidedJournalIDsStorage = seed.linkedGuidedJournalIDsStorage
        finalReflectionPrompt = seed.finalReflectionPrompt
        completionMessage = seed.completionMessage
        isPremium = seed.isPremium
        itemIDs = seed.itemIDs
        syncLessonDerivedMetadata()
        updateCompletionState()
    }

    private var completionIDs: [String] {
        let lessonIDs = lessons.map(\.completionID)
        return lessonIDs.isEmpty ? itemIDs : lessonIDs
    }

    private func updateCompletionState() {
        let ids = completionIDs
        isCompleted = !ids.isEmpty && ids.allSatisfy { completedItemIDs.contains($0) }
        if !isCompleted {
            completedAt = nil
        }
    }

    private func syncLessonDerivedMetadata() {
        let currentLessons = lessons
        if !currentLessons.isEmpty {
            let exerciseIDs = currentLessons.compactMap(\.linkedExerciseID)
            linkedExerciseIDsStorage = StringArrayStorage.encode(exerciseIDs)
            itemIDsStorage = StringArrayStorage.encode(exerciseIDs)
            estimatedTotalDuration = currentLessons.reduce(0) { $0 + $1.estimatedDuration }
            lessonCount = currentLessons.count
        } else {
            linkedExerciseIDsStorage = StringArrayStorage.encode(linkedExerciseIDs.isEmpty ? itemIDs : linkedExerciseIDs)
            lessonCount = max(lessonCount, itemIDs.count)
        }
    }

    private static func libraryItemsByID(_ libraryItems: [LibraryItem]) -> [String: LibraryItem] {
        libraryItems.reduce(into: [:]) { result, item in
            if result[item.id] == nil {
                result[item.id] = item
            }
        }
    }
}

private enum CourseLessonStorage {
    static func encode(_ lessons: [CourseLesson]) -> Data {
        (try? JSONEncoder().encode(lessons)) ?? Data()
    }

    static func decode(_ data: Data) -> [CourseLesson] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([CourseLesson].self, from: data)) ?? []
    }
}
