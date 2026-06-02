import Foundation
import SwiftData
import SwiftUI
import Observation

nonisolated enum DailyPlanItem: Hashable, Sendable {
    case moodCheckIn
    case thoughtRecord
    case exercises
    case breathingReset
    case tipOfTheDay
    case activityPlanner
}

nonisolated struct DailyPlanCompletionSnapshot: Sendable {
    let entries: [DailyPlanItem: PlanCardCompletionState]
    
    static let empty = DailyPlanCompletionSnapshot(entries: [
        .moodCheckIn: .incomplete,
        .thoughtRecord: .incomplete,
        .exercises: .incomplete,
        .breathingReset: .incomplete,
        .tipOfTheDay: .notTracked,
        .activityPlanner: .incomplete
    ])
    
    func state(for item: DailyPlanItem) -> PlanCardCompletionState {
        entries[item] ?? .incomplete
    }
}

nonisolated enum HomePersonalizedCardAction: Hashable, Sendable {
    case moodCheckIn
    case thoughtRecord
    case breathingReset
    case journal
    case exercises
    case assessments
    case recommendation(DailyRecommendationDestination)
}

nonisolated struct HomeContinueItem: Hashable, Sendable {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: HomePersonalizedCardAction
}

nonisolated struct HomeInsightPreview: Hashable, Sendable {
    let title: String
    let subtitle: String
    let value: String
}

nonisolated struct HomePersonalizedSnapshot: Sendable {
    var hasCheckInToday = false
    var missedDayCount = 0
    var completedTodayCount = 0
    var weeklyActivityCount = 0
    var continueItem: HomeContinueItem?
    var insight: HomeInsightPreview?

    static let empty = HomePersonalizedSnapshot()
}

nonisolated struct HomePersonalizedCard: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case checkIn
        case restart
        case continueItem
        case recommendation
        case tinyWin
        case weeklyProgress
        case badDayMode
    }

    let id: Kind
    let title: String
    let subtitle: String
    let detail: String?
    let systemImage: String
    let actionTitle: String
    let action: HomePersonalizedCardAction
    let isPriority: Bool
}

@Observable
final class HomeDashboardViewModel {
    var isInitialized = false
    var activeDates = Set<Date>()
    var completionSnapshot: DailyPlanCompletionSnapshot = .empty
    var recommendations = [DailyRecommendation]()
    var personalizedCards = [HomePersonalizedCard]()
    
    // Manual completion tracking (persisted only for current session here, naturally)
    var manualCompletions: [Date: Set<DailyPlanItem>] = [:]

    private var updateTaskID = UUID()

    @MainActor
    func apply(
        snapshot: HomeDashboardSnapshot,
        selectedDate: Date,
        recommendations: [DailyRecommendation]
    ) async {
        let currentTaskID = UUID()
        self.updateTaskID = currentTaskID

        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let manualForDay = manualCompletions[selectedDay] ?? []

        let completion = await Task.detached(priority: .userInitiated) {
            var entries = snapshot.completionSnapshot.entries
            if manualForDay.contains(.breathingReset) {
                entries[.breathingReset] = .completed
            }
            entries[.tipOfTheDay] = manualForDay.contains(.tipOfTheDay) ? .completed : .notTracked
            return DailyPlanCompletionSnapshot(entries: entries)
        }.value

        let personalizedCards = Self.makePersonalizedCards(
            snapshot: snapshot.personalization,
            completion: completion,
            recommendations: recommendations
        )
        
        guard !Task.isCancelled, self.updateTaskID == currentTaskID else { return }
        
        self.activeDates = snapshot.activeDates
        self.completionSnapshot = completion
        self.recommendations = Array(recommendations.prefix(3))
        self.personalizedCards = personalizedCards
        self.isInitialized = true
    }

    @MainActor
    func markItemAsDone(_ item: DailyPlanItem, for date: Date) {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: date)
        var currentSet = manualCompletions[selectedDay] ?? []
        if !currentSet.contains(item) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentSet.insert(item)
                manualCompletions[selectedDay] = currentSet
                // Note: We don't need to await update here because the view will 
                // re-evaluate the completion snapshot via the next update pass or
                // we can manually update the snapshot if we want immediate feedback.
                // For simplicity, we manually update the snapshot.
                updateLocalSnapshot(for: item, state: .completed)
            }
        }
    }

    private func updateLocalSnapshot(for item: DailyPlanItem, state: PlanCardCompletionState) {
        var currentEntries = completionSnapshot.entries
        currentEntries[item] = state
        completionSnapshot = DailyPlanCompletionSnapshot(entries: currentEntries)
    }

    private static func makePersonalizedCards(
        snapshot: HomePersonalizedSnapshot,
        completion: DailyPlanCompletionSnapshot,
        recommendations: [DailyRecommendation]
    ) -> [HomePersonalizedCard] {
        var cards = [HomePersonalizedCard]()

        if !snapshot.hasCheckInToday {
            cards.append(HomePersonalizedCard(
                id: .checkIn,
                title: String(localized: "Today's Check-In"),
                subtitle: snapshot.missedDayCount > 0
                    ? String(localized: "No catching up required. Just log how today feels.")
                    : String(localized: "Start with a quick read on your mood."),
                detail: String(localized: "About 1 minute"),
                systemImage: "face.smiling",
                actionTitle: String(localized: "Check in"),
                action: .moodCheckIn,
                isPriority: true
            ))
        }

        if snapshot.missedDayCount > 0 {
            cards.append(HomePersonalizedCard(
                id: .restart,
                title: String(localized: "Gentle Restart"),
                subtitle: String(localized: "It has been a few days. One small step is enough to restart."),
                detail: nil,
                systemImage: "arrow.counterclockwise.circle.fill",
                actionTitle: String(localized: "Start small"),
                action: .moodCheckIn,
                isPriority: !snapshot.hasCheckInToday
            ))
        }

        if let item = snapshot.continueItem {
            cards.append(HomePersonalizedCard(
                id: .continueItem,
                title: String(localized: "Continue Where You Left Off"),
                subtitle: item.title,
                detail: item.subtitle,
                systemImage: item.systemImage,
                actionTitle: String(localized: "Continue"),
                action: item.action,
                isPriority: false
            ))
        }

        if let recommendation = recommendations.first(where: { !$0.isCompletedToday }) ?? recommendations.first {
            cards.append(HomePersonalizedCard(
                id: .recommendation,
                title: String(localized: "Recommended Next Step"),
                subtitle: recommendation.title,
                detail: recommendation.why,
                systemImage: recommendation.icon,
                actionTitle: String(localized: "Open"),
                action: .recommendation(recommendation.destination),
                isPriority: false
            ))
        }

        cards.append(HomePersonalizedCard(
            id: .tinyWin,
            title: String(localized: "Tiny Win"),
            subtitle: tinyWinSubtitle(completedTodayCount: snapshot.completedTodayCount, completion: completion),
            detail: nil,
            systemImage: "checkmark.seal.fill",
            actionTitle: String(localized: "Take one"),
            action: completion.state(for: .breathingReset).isCompleted ? .thoughtRecord : .breathingReset,
            isPriority: false
        ))

        cards.append(HomePersonalizedCard(
            id: .weeklyProgress,
            title: String(localized: "Weekly Progress Preview"),
            subtitle: snapshot.insight?.title ?? String(localized: "\(snapshot.weeklyActivityCount) CBT moments logged this week."),
            detail: snapshot.insight.map { "\($0.value) • \($0.subtitle)" },
            systemImage: "chart.line.uptrend.xyaxis",
            actionTitle: String(localized: "View"),
            action: .assessments,
            isPriority: false
        ))

        cards.append(HomePersonalizedCard(
            id: .badDayMode,
            title: String(localized: "Bad Day Mode"),
            subtitle: String(localized: "Skip the plan. Open a calming shortcut for right now."),
            detail: String(localized: "60-second reset"),
            systemImage: "lifepreserver.fill",
            actionTitle: String(localized: "Reset"),
            action: .breathingReset,
            isPriority: false
        ))

        return cards
    }

    private static func tinyWinSubtitle(
        completedTodayCount: Int,
        completion: DailyPlanCompletionSnapshot
    ) -> String {
        if completedTodayCount > 0 {
            return String(localized: "\(completedTodayCount) helpful step logged today. Let it count.")
        }
        if completion.state(for: .breathingReset).isCompleted {
            return String(localized: "Write down one thought and give it a little room.")
        }
        return String(localized: "Take one minute to settle your body.")
    }
}
