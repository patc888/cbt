import Foundation
import OSLog
import SwiftData

@MainActor
final class LibraryService {
    static let shared = LibraryService()
    private static let logger = AppLogger.make(category: "LibraryService")

    let bundledItems: [LibraryItem]
    let bundledExercises: [Exercise]

    private let exercisesByID: [String: Exercise]

    private init() {
        let exercises = Self.loadExercises()
        self.bundledExercises = exercises
        self.bundledItems = exercises.compactMap(Self.makeLibraryItem)
        self.exercisesByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    func exercise(withID id: String) -> Exercise? {
        exercisesByID[id]
    }

    func exercise(for item: LibraryItem) -> Exercise? {
        guard item.type == .exercise else { return nil }

        if let exercise = try? JSONDecoder().decode(Exercise.self, from: item.contentData) {
            return exercise
        }

        return exercise(withID: item.id)
    }

    func categories(for items: [LibraryItem]) -> [String] {
        items.reduce(into: [String]()) { result, item in
            if !result.contains(item.category) {
                result.append(item.category)
            }
        }
    }

    @MainActor
    func seedLibraryIfNeeded(in modelContext: ModelContext) throws {
        let currentItems = try modelContext.fetch(FetchDescriptor<LibraryItem>())
        for seed in bundledItems {
            let matches = currentItems.filter { $0.id == seed.id }
            if let existing = matches.first {
                existing.title = seed.title
                existing.category = seed.category
                existing.contentData = seed.contentData
                existing.type = seed.type
                existing.duration = seed.duration
                for duplicate in matches.dropFirst() {
                    modelContext.delete(duplicate)
                }
            } else {
                modelContext.insert(
                    LibraryItem(
                        id: seed.id,
                        title: seed.title,
                        category: seed.category,
                        contentData: seed.contentData,
                        type: seed.type,
                        duration: seed.duration
                    )
                )
            }
        }

        let currentCourses = try modelContext.fetch(FetchDescriptor<Course>())
        for seed in Self.defaultCourses(from: bundledItems) {
            let matches = currentCourses.filter { $0.id == seed.id }
            if let existing = matches.first {
                existing.title = seed.title
                existing.itemIDs = seed.itemIDs
                for duplicate in matches.dropFirst() {
                    modelContext.delete(duplicate)
                }
            } else {
                modelContext.insert(seed)
            }
        }

        try modelContext.save()
    }

    private static func loadExercises() -> [Exercise] {
        guard let url = Bundle.main.url(forResource: "Exercises", withExtension: "json") else {
            logger.error("Could not find Exercises.json in the main bundle.")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Exercise].self, from: data)
        } catch {
            logger.error("Failed to load or decode Exercises.json: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private static func makeLibraryItem(from exercise: Exercise) -> LibraryItem? {
        guard let contentData = try? JSONEncoder().encode(exercise) else {
            logger.error("Failed to encode exercise content for \(exercise.id, privacy: .public)")
            return nil
        }

        return LibraryItem(
            id: exercise.id,
            title: exercise.title,
            category: exercise.category,
            contentData: contentData,
            type: .exercise,
            duration: exercise.duration
        )
    }

    private static func defaultCourses(from items: [LibraryItem]) -> [Course] {
        let thoughtPath = items
            .filter { ["Thought Reframing", "Cognitive Distortions", "Self-Compassion"].contains($0.category) }
            .prefix(5)
            .map(\.id)

        let resetPath = items
            .filter { ["Grounding", "Anxiety Reset", "Gratitude"].contains($0.category) }
            .prefix(5)
            .map(\.id)

        return [
            Course(id: "course_thought_reframing_foundations", title: "Thought Reframing Foundations", itemIDs: Array(thoughtPath)),
            Course(id: "course_calm_reset_path", title: "Calm Reset Path", itemIDs: Array(resetPath))
        ]
        .filter { !$0.itemIDs.isEmpty }
    }
}
