import Foundation
import SwiftData

nonisolated struct OutcomeGoalSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let kind: OutcomeGoalKind
    let status: OutcomeGoalStatus
    let checkInPrompt: String
    let createdAt: Date

    var dailyPlanFocus: String {
        title.isEmpty ? kind.dailyPlanFocus : title
    }
}

nonisolated struct OutcomeGoalProgressSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
    let kind: OutcomeGoalKind
    let progress: Double
    let completedSupportActions: Int
    let signalCount: Int
    let lastActivityDate: Date?

    var clampedProgress: Double {
        min(1, max(0, progress))
    }
}

nonisolated struct OutcomeGoalActivityEvent: Hashable, Sendable {
    let date: Date
    let itemType: DailyPlanCompletionItemType?
    let text: String

    init(date: Date, itemType: DailyPlanCompletionItemType? = nil, text: String = "") {
        self.date = date
        self.itemType = itemType
        self.text = text
    }
}

@MainActor
struct OutcomeGoalService {
    static let shared = OutcomeGoalService()

    func ensureStarterGoals(in context: ModelContext) {
        let descriptor = FetchDescriptor<OutcomeGoal>(
            predicate: #Predicate<OutcomeGoal> { $0.isDeleted == false }
        )
        guard (try? context.fetchCount(descriptor)) == 0 else { return }

        for kind in OutcomeGoalKind.allCases where kind != .custom {
            context.insert(OutcomeGoal(title: kind.title, kind: kind))
        }
        try? context.save()
    }

    func activeGoalSnapshots(in context: ModelContext) -> [OutcomeGoalSnapshot] {
        ensureStarterGoals(in: context)
        let activeStatus = OutcomeGoalStatus.active.rawValue
        let descriptor = FetchDescriptor<OutcomeGoal>(
            predicate: #Predicate<OutcomeGoal> {
                $0.isDeleted == false && $0.statusStorage == activeStatus
            },
            sortBy: [SortDescriptor(\OutcomeGoal.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.map(Self.snapshot(for:)) ?? []
    }

    static func snapshot(for goal: OutcomeGoal) -> OutcomeGoalSnapshot {
        OutcomeGoalSnapshot(
            id: goal.id,
            title: goal.title,
            kind: goal.kind,
            status: goal.status,
            checkInPrompt: goal.checkInPrompt,
            createdAt: goal.createdAt
        )
    }

    nonisolated static func progress(
        for goals: [OutcomeGoalSnapshot],
        events: [OutcomeGoalActivityEvent],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [OutcomeGoalProgressSnapshot] {
        let cutoff = calendar.date(byAdding: .day, value: -14, to: referenceDate) ?? referenceDate
        let recentEvents = events.filter { $0.date >= cutoff }

        return goals.map { goal in
            let supportActions = recentEvents.filter { event in
                guard let type = event.itemType else { return false }
                return goal.kind.supportedCompletionTypes.contains(type)
            }
            let signals = recentEvents.filter { event in
                goal.kind.matches(text: event.text)
            }
            let total = supportActions.count + min(signals.count, 4)
            let progress = min(1, Double(total) / 6.0)
            let lastActivity = (supportActions + signals).map(\.date).max()
            let subtitle = supportActions.isEmpty && signals.isEmpty
                ? "No recent signals yet"
                : "\(supportActions.count) helpful actions, \(signals.count) related signals"

            return OutcomeGoalProgressSnapshot(
                id: goal.id,
                title: goal.title,
                subtitle: subtitle,
                kind: goal.kind,
                progress: progress,
                completedSupportActions: supportActions.count,
                signalCount: signals.count,
                lastActivityDate: lastActivity
            )
        }
        .sorted {
            if $0.clampedProgress == $1.clampedProgress {
                return $0.title < $1.title
            }
            return $0.clampedProgress > $1.clampedProgress
        }
    }
}

private extension OutcomeGoalKind {
    var supportedCompletionTypes: Set<DailyPlanCompletionItemType> {
        switch self {
        case .meetingAvoidance:
            return [.activityPlanner, .quickAction, .thoughtRecord]
        case .sleepRoutine:
            return [.breathingReset, .journalPrompt, .quickAction]
        case .panicCoping:
            return [.breathingReset, .thoughtRecord, .exercise]
        case .selfCriticism:
            return [.thoughtRecord, .journalPrompt, .exercise]
        case .custom:
            return [.moodCheckIn, .thoughtRecord, .breathingReset, .exercise, .quickAction]
        }
    }

    func matches(text: String) -> Bool {
        let normalized = text.lowercased()
        guard !normalized.isEmpty else { return false }

        switch self {
        case .meetingAvoidance:
            return normalized.containsAny(["meeting", "avoid", "avoiding", "work", "deadline", "email", "message"])
        case .sleepRoutine:
            return normalized.containsAny(["sleep", "bed", "tired", "insomnia", "rest", "night"])
        case .panicCoping:
            return normalized.containsAny(["panic", "anxiety", "anxious", "fear", "racing heart", "tight chest"])
        case .selfCriticism:
            return normalized.containsAny(["self-critical", "criticism", "not good enough", "failure", "should", "shame"])
        case .custom:
            return false
        }
    }
}

private extension String {
    func containsAny(_ needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}
