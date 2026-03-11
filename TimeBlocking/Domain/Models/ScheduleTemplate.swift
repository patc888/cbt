import Foundation
import SwiftData

@Model
final class ScheduleTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String?
    var defaultStartHour: Int = 8
    var defaultDurationMinutes: Int = 60
    var weekdayMask: Int = 0
    var category: TimeBlockCategory = TimeBlockCategory.routine
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \TimeBlock.template)
    var generatedBlocks: [TimeBlock]? = []

    init(
        id: UUID = UUID(),
        name: String,
        notes: String? = nil,
        defaultStartHour: Int = 8,
        defaultDurationMinutes: Int = 60,
        weekdayMask: Int = 0,
        category: TimeBlockCategory = .routine,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.defaultStartHour = defaultStartHour
        self.defaultDurationMinutes = defaultDurationMinutes
        self.weekdayMask = weekdayMask
        self.category = category
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.generatedBlocks = []
    }
}
