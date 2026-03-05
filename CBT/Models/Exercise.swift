import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let duration: Int
    let description: String
    let steps: [String]
}
