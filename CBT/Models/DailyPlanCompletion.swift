import Foundation
import SwiftData

enum DailyPlanCompletionItemType: String, CaseIterable, Sendable {
    case moodCheckIn
    case breathingReset
    case journalPrompt
    case thoughtRecord
    case tipOfTheDay
    case quickAction
    case exercise
    case weeklyReview
    case activityPlanner
    case tinyWin
    case custom
}

@Model
final class DailyPlanCompletion: SoftDeletableRecord {
    var id: UUID = UUID()
    var date: Date = Date()
    var itemType: String = DailyPlanCompletionItemType.custom.rawValue
    var itemID: String?
    var title: String = ""
    var completedAt: Date = Date()
    var sourceScreen: String?
    var durationSeconds: Int?
    var wasRecommended: Bool = false
    var recommendationReason: String?
    var isDeleted: Bool = false

    init(
        id: UUID = UUID(),
        date: Date,
        itemType: DailyPlanCompletionItemType,
        itemID: String? = nil,
        title: String,
        completedAt: Date = Date(),
        sourceScreen: String? = nil,
        durationSeconds: Int? = nil,
        wasRecommended: Bool = false,
        recommendationReason: String? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.date = date
        self.itemType = itemType.rawValue
        self.itemID = itemID
        self.title = title
        self.completedAt = completedAt
        self.sourceScreen = sourceScreen
        self.durationSeconds = durationSeconds
        self.wasRecommended = wasRecommended
        self.recommendationReason = recommendationReason
        self.isDeleted = isDeleted
    }

    var type: DailyPlanCompletionItemType {
        get { DailyPlanCompletionItemType(rawValue: itemType) ?? .custom }
        set { itemType = newValue.rawValue }
    }
}
