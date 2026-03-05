import Foundation

struct CognitiveDistortionExample: Codable, Identifiable, Hashable {
    let id: String
    let distortion: String
    let thought: String
    let explanation: String
    let balancedThought: String
}
