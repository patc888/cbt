import Foundation

final class CognitiveDistortionsLibrary {
    static let shared = CognitiveDistortionsLibrary()
    let examples: [CognitiveDistortionExample]
    
    // Cache for optimized lookups
    private let groupedExamples: [String: [CognitiveDistortionExample]]
    private let distortionNames: [String]
    
    private init() {
        if let url = Bundle.main.url(forResource: "CognitiveDistortions", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([CognitiveDistortionExample].self, from: data) {
            self.examples = decoded
        } else {
            self.examples = []
        }
        
        // Setup cache
        self.groupedExamples = Dictionary(grouping: self.examples, by: { $0.distortion })
        self.distortionNames = Array(groupedExamples.keys).sorted()
    }
    
    func examples(for distortion: String) -> [CognitiveDistortionExample] {
        return groupedExamples[distortion] ?? []
    }
    
    func allDistortionNames() -> [String] {
        return distortionNames
    }
    
    func randomExample(distortion: String? = nil) -> CognitiveDistortionExample? {
        let pool: [CognitiveDistortionExample]
        if let d = distortion {
            pool = examples(for: d)
        } else {
            pool = examples
        }
        return pool.randomElement()
    }
}
