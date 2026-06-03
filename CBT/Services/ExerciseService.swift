import Foundation

@MainActor
final class ExerciseService {
    static let shared = ExerciseService()

    let exercises: [Exercise]
    private let exercisesByID: [String: Exercise]

    private init() {
        let loadedExercises = LibraryService.shared.bundledExercises
        self.exercises = loadedExercises
        self.exercisesByID = loadedExercises.reduce(into: [:]) { result, exercise in
            result[exercise.id] = result[exercise.id] ?? exercise
        }
    }

    func exercise(withID id: String) -> Exercise? {
        exercisesByID[id]
    }

    func exercises(forCategory category: String) -> [Exercise] {
        exercises.filter { $0.category == category }
    }

    func approaches() -> [String] {
        exercises.reduce(into: [String]()) { result, exercise in
            for approach in exercise.displayApproaches where !result.contains(approach) {
                result.append(approach)
            }
        }
    }

    func categories() -> [String] {
        exercises.reduce(into: [String]()) { result, exercise in
            if !result.contains(exercise.category) {
                result.append(exercise.category)
            }
        }
    }
}
