import Foundation

final class ExerciseLoader {
    static let shared = ExerciseLoader()

    let exercises: [Exercise]

    private init() {
        self.exercises = Self.loadExercises()
    }

    private static func loadExercises() -> [Exercise] {
        guard let url = Bundle.main.url(forResource: "Exercises", withExtension: "json") else {
            print("Could not find Exercises.json in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([Exercise].self, from: data)
        } catch {
            print("Failed to load or decode Exercises.json: \(error)")
            return []
        }
    }
}
