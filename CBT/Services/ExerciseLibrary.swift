import Foundation

class ExerciseLibrary {
    static let shared = ExerciseLibrary()
    
    private(set) var exercises: [Exercise] = []
    
    private init() {
        loadExercises()
    }
    
    private func loadExercises() {
        guard let url = Bundle.main.url(forResource: "Exercises", withExtension: "json") else {
            print("Failed to locate Exercises.json in bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            exercises = try decoder.decode([Exercise].self, from: data)
        } catch {
            print("Failed to decode Exercises.json: \(error)")
        }
    }
    
    func exercises(forCategory category: String) -> [Exercise] {
        return exercises.filter { $0.category == category }
    }
    
    func categories() -> [String] {
        let allCategories = exercises.map { $0.category }
        var uniqueCategories = [String]()
        for cat in allCategories {
            if !uniqueCategories.contains(cat) {
                uniqueCategories.append(cat)
            }
        }
        return uniqueCategories
    }
}
