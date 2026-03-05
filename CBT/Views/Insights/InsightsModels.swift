import Foundation

struct EmotionCount: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

struct DistortionCount: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

struct DailyMoodAverage: Identifiable {
    let id = UUID()
    let date: Date
    let averageScore: Double
}
