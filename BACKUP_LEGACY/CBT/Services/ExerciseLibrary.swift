import Foundation

final class ExerciseLibrary {
    static let shared = ExerciseLibrary()

    let exercises: [Exercise]
    private let exercisesByID: [String: Exercise]

    private init(loader: ExerciseLoader = .shared) {
        let loadedExercises = loader.exercises
        self.exercises = loadedExercises
        self.exercisesByID = Dictionary(uniqueKeysWithValues: loadedExercises.map { ($0.id, $0) })
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
