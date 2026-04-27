import Foundation

struct Affirmation: Codable, Identifiable, Hashable {
    let id: String
    let category: String
    let text: String
}
