import Foundation
import SwiftData

enum TimeBlockCategory: String, CaseIterable, Codable, Identifiable {
    case focus
    case personal
    case admin
    case routine
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus:
            "Focus"
        case .personal:
            "Personal"
        case .admin:
            "Admin"
        case .routine:
            "Routine"
        case .custom:
            "Custom"
        }
    }
}

enum TimeBlockStatus: String, CaseIterable, Codable, Identifiable {
    case planned
    case completed
    case cancelled

    var id: String { rawValue }
}

@Model
final class TimeBlock {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String?
    var startDate: Date = Date.now
    var endDate: Date = Date.now
    var category: TimeBlockCategory = TimeBlockCategory.custom
    var status: TimeBlockStatus = TimeBlockStatus.planned
    var isPinned: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var template: ScheduleTemplate?
    @Relationship(deleteRule: .cascade, inverse: \BlockChecklistItem.timeBlock)
    var checklistItems: [BlockChecklistItem]? = []

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        startDate: Date,
        endDate: Date,
        category: TimeBlockCategory = .custom,
        status: TimeBlockStatus = .planned,
        isPinned: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        template: ScheduleTemplate? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.category = category
        self.status = status
        self.isPinned = isPinned
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.template = template
        self.checklistItems = []
    }
}
