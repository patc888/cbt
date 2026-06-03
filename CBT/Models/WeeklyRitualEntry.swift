import Foundation
import SwiftData

@Model
final class WeeklyRitualEntry: SoftDeletableRecord {
    var id: UUID = UUID()
    var weekStart: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var intention: String = ""
    var learning: String = ""
    var valueReflection: String = ""
    var isDeleted: Bool = false

    init(
        id: UUID = UUID(),
        weekStart: Date,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        intention: String = "",
        learning: String = "",
        valueReflection: String = "",
        isDeleted: Bool = false
    ) {
        self.id = id
        self.weekStart = weekStart
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.intention = intention
        self.learning = learning
        self.valueReflection = valueReflection
        self.isDeleted = isDeleted
    }
}
