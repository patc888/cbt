import Foundation
import SwiftData

@Model
final class PlannedActivity: SoftDeletableRecord {
    nonisolated static let categories = ["Nourishing", "Mastery", "Social", "Physical"]
    nonisolated static let supportedValues = ValuesService.defaultValues.map(\.name)

    var id: UUID = UUID()
    var createdAt: Date = Date()
    var isDeleted: Bool = false
    
    var title: String = ""
    var activityDescription: String = ""
    var category: String = "Nourishing"
    var scheduledDate: Date = Date()
    var supportedValue: String?
    var predictedEnjoyment: Int = 5 // 0-10
    var actualEnjoyment: Int? // 0-10
    var isCompleted: Bool = false
    var completedAt: Date?
    var adaptiveMode: String = DailyPlanMode.full.rawValue
    var notes: String?
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        isDeleted: Bool = false,
        title: String,
        activityDescription: String = "",
        category: String = "Nourishing",
        scheduledDate: Date = Date(),
        supportedValue: String? = nil,
        predictedEnjoyment: Int = 5,
        actualEnjoyment: Int? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        adaptiveMode: String = DailyPlanMode.full.rawValue,
        notes: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.isDeleted = isDeleted
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.activityDescription = activityDescription
        self.category = Self.normalizedCategory(category)
        self.scheduledDate = scheduledDate
        self.supportedValue = Self.normalizedSupportedValue(supportedValue)
        self.predictedEnjoyment = Self.clampRating(predictedEnjoyment)
        self.actualEnjoyment = actualEnjoyment.map(Self.clampRating)
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.adaptiveMode = ExerciseCompletion.normalizedAdaptiveMode(adaptiveMode)
        self.notes = notes
    }

    nonisolated static func clampRating(_ value: Int) -> Int {
        min(10, max(0, value))
    }

    nonisolated static func normalizedCategory(_ value: String) -> String {
        categories.contains(value) ? value : "Nourishing"
    }

    nonisolated static func normalizedSupportedValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }

        return supportedValues.first { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
    }
}
