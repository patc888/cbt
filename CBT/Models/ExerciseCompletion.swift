import Foundation
import SwiftData

@Model
final class ExerciseCompletion: SoftDeletableRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var exerciseID: String = ""
    var notes: String?
    var isDeleted: Bool = false

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        exerciseID: String,
        notes: String? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.exerciseID = exerciseID
        self.notes = notes
        self.isDeleted = isDeleted
    }
}
