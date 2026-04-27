import Foundation
import OSLog

final class ExerciseLoader {
    static let shared = ExerciseLoader()
    private static let logger = AppLogger.make(category: "ExerciseLoader")

    let exercises: [Exercise]

    private init() {
        self.exercises = Self.loadExercises()
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
}
