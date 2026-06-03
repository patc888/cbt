import Foundation
import SwiftData

enum OutcomeGoalStatus: String, CaseIterable, Codable, Hashable, Sendable {
    case active
    case paused
    case completed
}

enum OutcomeGoalKind: String, CaseIterable, Codable, Hashable, Sendable {
    case meetingAvoidance
    case sleepRoutine
    case panicCoping
    case selfCriticism
    case custom

    var title: String {
        switch self {
        case .meetingAvoidance:
            return "Reduce avoidance around meetings"
        case .sleepRoutine:
            return "Sleep routine"
        case .panicCoping:
            return "Panic coping"
        case .selfCriticism:
            return "Self-criticism"
        case .custom:
            return "Personal focus"
        }
    }

    var dailyPlanFocus: String {
        switch self {
        case .meetingAvoidance:
            return "meeting avoidance"
        case .sleepRoutine:
            return "sleep routine"
        case .panicCoping:
            return "panic coping"
        case .selfCriticism:
            return "self-criticism"
        case .custom:
            return "your current focus"
        }
    }

    var preferredRecommendationTypes: [DailyRecommendationType] {
        switch self {
        case .meetingAvoidance:
            return [.behavioralActivation, .thoughtRecord]
        case .sleepRoutine:
            return [.sleepWindDown, .breathingReset, .guidedJournal]
        case .panicCoping:
            return [.breathingReset, .libraryExercise, .thoughtRecord]
        case .selfCriticism:
            return [.thoughtRecord, .guidedJournal, .libraryExercise]
        case .custom:
            return [.moodCheckIn, .thoughtRecord, .breathingReset]
        }
    }

    var defaultCheckInPrompt: String {
        switch self {
        case .meetingAvoidance:
            return "Did I move one step toward a meeting, message, or follow-up?"
        case .sleepRoutine:
            return "Did I protect one small part of tonight's sleep routine?"
        case .panicCoping:
            return "Did I practice coping with panic or anxiety sensations?"
        case .selfCriticism:
            return "Did I answer self-critical thinking with something fairer?"
        case .custom:
            return "Did I move this focus forward today?"
        }
    }
}

@Model
final class OutcomeGoal: SoftDeletableRecord {
    var id: UUID = UUID()
    var title: String = ""
    var kindStorage: String = OutcomeGoalKind.custom.rawValue
    var statusStorage: String = OutcomeGoalStatus.active.rawValue
    var detail: String?
    var checkInPrompt: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var targetDate: Date?
    var archivedAt: Date?
    var isDeleted: Bool = false

    init(
        id: UUID = UUID(),
        title: String,
        kind: OutcomeGoalKind = .custom,
        status: OutcomeGoalStatus = .active,
        detail: String? = nil,
        checkInPrompt: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        targetDate: Date? = nil,
        archivedAt: Date? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.kindStorage = kind.rawValue
        self.statusStorage = status.rawValue
        self.detail = detail
        self.checkInPrompt = checkInPrompt ?? kind.defaultCheckInPrompt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.targetDate = targetDate
        self.archivedAt = archivedAt
        self.isDeleted = isDeleted
    }

    var kind: OutcomeGoalKind {
        get { OutcomeGoalKind(rawValue: kindStorage) ?? .custom }
        set {
            kindStorage = newValue.rawValue
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = newValue.title
            }
            if checkInPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                checkInPrompt = newValue.defaultCheckInPrompt
            }
            updatedAt = Date()
        }
    }

    var status: OutcomeGoalStatus {
        get { OutcomeGoalStatus(rawValue: statusStorage) ?? .active }
        set {
            statusStorage = newValue.rawValue
            updatedAt = Date()
            archivedAt = newValue == .active ? nil : Date()
        }
    }
}
