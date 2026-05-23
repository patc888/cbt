import Foundation
import SwiftData

@Model
final class MoodCheckIn: SoftDeletableRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var moodScore: Int = 5
    var notes: String?
    var isDeleted: Bool = false

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        moodScore: Int = 5,
        notes: String? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.moodScore = moodScore
        self.notes = notes
        self.isDeleted = isDeleted
    }
}
