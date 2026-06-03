import Foundation
import SwiftData

enum HelpfulnessActivityKind: String, CaseIterable, Sendable {
    case breathing
    case activityPlanning
    case guidedJournal
    case thoughtRecord
}

enum HelpfulnessResponse: String, CaseIterable, Identifiable, Sendable {
    case helped
    case somewhat
    case didNotHelp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .helped:
            return "Yes"
        case .somewhat:
            return "A little"
        case .didNotHelp:
            return "No"
        }
    }

    var score: Double {
        switch self {
        case .helped:
            return 1
        case .somewhat:
            return 0.35
        case .didNotHelp:
            return -1
        }
    }
}

@Model
final class HelpfulnessFeedback: SoftDeletableRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var activityKindRawValue: String = HelpfulnessActivityKind.breathing.rawValue
    var responseRawValue: String = HelpfulnessResponse.somewhat.rawValue
    var itemID: String?
    var note: String?
    var sourceScreen: String?
    var isDeleted: Bool = false

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        activityKind: HelpfulnessActivityKind,
        response: HelpfulnessResponse,
        itemID: String? = nil,
        note: String? = nil,
        sourceScreen: String? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.activityKindRawValue = activityKind.rawValue
        self.responseRawValue = response.rawValue
        self.itemID = Self.normalizedOptionalText(itemID)
        self.note = Self.normalizedOptionalText(note)
        self.sourceScreen = Self.normalizedOptionalText(sourceScreen)
        self.isDeleted = isDeleted
    }

    var activityKind: HelpfulnessActivityKind {
        get { HelpfulnessActivityKind(rawValue: activityKindRawValue) ?? .breathing }
        set { activityKindRawValue = newValue.rawValue }
    }

    var response: HelpfulnessResponse {
        get { HelpfulnessResponse(rawValue: responseRawValue) ?? .somewhat }
        set { responseRawValue = newValue.rawValue }
    }

    private static func normalizedOptionalText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }
}
