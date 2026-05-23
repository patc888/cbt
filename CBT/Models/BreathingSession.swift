import Foundation
import SwiftData

@Model
final class BreathingSession: SoftDeletableRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var durationSeconds: Int = 60
    var isDeleted: Bool = false

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        durationSeconds: Int = 60,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.isDeleted = isDeleted
    }
}
