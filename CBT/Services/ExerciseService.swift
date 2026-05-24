import Foundation

@MainActor
final class ExerciseService {
    static let shared = ExerciseService()

    let exercises: [Exercise]
    private let exercisesByID: [String: Exercise]

    private init() {
        let loadedExercises = LibraryService.shared.bundledExercises
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
