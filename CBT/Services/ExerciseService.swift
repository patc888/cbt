import Foundation
import OSLog

final class ExerciseService: Sendable {
    static let shared = ExerciseService()
    private static let logger = AppLogger.make(category: "ExerciseService")

    let exercises: [Exercise]
    private let exercisesByID: [String: Exercise]

    private init() {
        let loadedExercises = Self.loadExercises()
        self.exercises = loadedExercises
        self.exercisesByID = Dictionary(uniqueKeysWithValues: loadedExercises.map { ($0.id, $0) })
    }

    private static func loadExercises() -> [Exercise] {
        guard let url = Bundle.main.url(forResource: "Exercises", withExtension: "json") else {
            logger.error("Could not find Exercises.json in the main bundle.")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([Exercise].self, from: data)
        } catch {
            logger.error("Failed to load or decode Exercises.json: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func exercise(withID id: String) -> Exercise? {
        exercisesByID[id]
    }

    func exercises(forCategory category: String) -> [Exercise] {
        exercises.filter { $0.category == category }
    }

    func categories() -> [String] {
        exercises.reduce(into: [String]()) { result, exercise in
            if !result.contains(exercise.category) {
                result.append(exercise.category)
            }
        }
    }
}
