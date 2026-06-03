import Foundation
import OSLog
import os
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
    case tinyWin
    case valueAction

    var completionItemType: DailyPlanCompletionItemType {
        switch self {
        case .moodCheckIn:
            return .moodCheckIn
        case .thoughtRecord:
            return .thoughtRecord
        case .exercises:
            return .exercise
        case .breathingReset:
            return .breathingReset
        case .tipOfTheDay:
            return .tipOfTheDay
        case .activityPlanner:
            return .activityPlanner
        case .tinyWin:
            return .tinyWin
        case .valueAction:
            return .quickAction
        }
    }

    var completionTitle: String {
        switch self {
        case .moodCheckIn:
            return "Daily mood check-in"
        case .thoughtRecord:
            return "Thought record"
        case .exercises:
            return "Exercise"
        case .breathingReset:
            return "Breathing reset"
        case .tipOfTheDay:
            return "Tip of the day"
        case .activityPlanner:
            return "Quick action"
        case .tinyWin:
            return "Tiny win"
        case .valueAction:
            return "Value action"
        }
    }
}

nonisolated struct DailyPlanCompletionSnapshot: Sendable {
    let entries: [DailyPlanItem: PlanCardCompletionState]
    
    static let empty = DailyPlanCompletionSnapshot(entries: [
        .moodCheckIn: .incomplete,
        .thoughtRecord: .incomplete,
        .exercises: .incomplete,
        .breathingReset: .incomplete,
        .tipOfTheDay: .notTracked,
        .activityPlanner: .incomplete,
        .tinyWin: .incomplete,
        .valueAction: .incomplete
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
    case insights
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

nonisolated struct HomeDailyPlanWin: Identifiable, Hashable, Sendable {
    let item: DailyPlanItem
    let title: String
    let systemImage: String

    var id: DailyPlanItem { item }
}

nonisolated struct HomeDailyPlanLoopState: Hashable, Sendable {
    let primaryNextStep: DailyRecommendation
    let whyExplanation: String
    let completedWins: [HomeDailyPlanWin]
    let continueItem: HomeContinueItem?
    let tomorrowTitle: String
    let tomorrowSubtitle: String
    let recoveryMessage: String?
    let isNewUser: Bool
    let isPlanComplete: Bool
    let optionalTinyAction: DailyRecommendation?

    var completedCount: Int { completedWins.count }
}

nonisolated struct HomePersonalizedSnapshot: Sendable {
    var hasCheckInToday = false
    var missedDayCount = 0
    var completedTodayCount = 0
    var weeklyActivityCount = 0
    var shouldShowLowEnergyMode = false
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
        case lowEnergyMode
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

nonisolated enum WelcomeBackRecoveryAction: Hashable, Sendable {
    case resumePreviousPlan
    case startFreshToday
    case restartMomentum
}

nonisolated struct WelcomeBackRecoveryState: Equatable, Sendable {
    static let missedDayThreshold = 3
    static let completionDefaultsKey = "cbt_welcome_back_recovery_completed_day"

    let missedDays: Int
    let dayKey: String
    let streakWasBroken: Bool

    var tinyActionSuggestion: String {
        "Take one minute to check in with today."
    }

    var gentleStreakMessage: String? {
        guard streakWasBroken else { return nil }
        return "The earlier run can rest. Today can simply be a fresh start."
    }

    static func make(
        missedDays: Int,
        selectedDate: Date,
        activeDates: Set<Date>,
        completedDayKey: String,
        calendar: Calendar = .current
    ) -> WelcomeBackRecoveryState? {
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let key = dayKey(for: selectedDay, calendar: calendar)
        guard missedDays >= missedDayThreshold, completedDayKey != key else {
            return nil
        }

        return WelcomeBackRecoveryState(
            missedDays: missedDays,
            dayKey: key,
            streakWasBroken: currentStreak(from: activeDates, today: selectedDay, calendar: calendar) == 0
        )
    }

    static func completedDayKey(after action: WelcomeBackRecoveryAction, on date: Date, calendar: Calendar = .current) -> String {
        dayKey(for: date, calendar: calendar)
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: date))
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private static func currentStreak(from activeDates: Set<Date>, today: Date, calendar: Calendar) -> Int {
        let normalizedDays = Set(activeDates.map { calendar.startOfDay(for: $0) })
        guard !normalizedDays.isEmpty else { return 0 }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        guard let lastActiveDay = normalizedDays.max() else { return 0 }
        guard lastActiveDay == today || lastActiveDay == yesterday else { return 0 }

        var streak = 1
        var cursor = lastActiveDay
        while let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor),
              normalizedDays.contains(previousDay) {
            streak += 1
            cursor = previousDay
        }
        return streak
    }
}

@Observable
final class HomeDashboardViewModel {
    var isInitialized = false
    var activeDates = Set<Date>()
    var completionSnapshot: DailyPlanCompletionSnapshot = .empty
    var recommendations = [DailyRecommendation]()
    var dailyPlanLoopState = HomeDailyPlanLoopState.starter
    var personalizedCards = [HomePersonalizedCard]()
    var badDayContext: BadDayModeContext = .inactive
    
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
        let completion = await Task.detached(priority: .userInitiated) {
            snapshot.completionSnapshot
        }.value

        let personalizedCards = Self.makePersonalizedCards(
            snapshot: snapshot.personalization,
            completion: completion,
            recommendations: recommendations
        )
        let loopState = Self.makeDailyPlanLoopState(
            snapshot: snapshot.personalization,
            activeDates: snapshot.activeDates,
            completion: completion,
            recommendations: recommendations,
            selectedDate: selectedDate,
            calendar: calendar
        )
        
        guard !Task.isCancelled, self.updateTaskID == currentTaskID else { return }
        
        self.activeDates = snapshot.activeDates
        self.completionSnapshot = completion
        self.recommendations = Array(Self.effectiveRecommendations(recommendations, isNewUser: loopState.isNewUser).prefix(3))
        self.dailyPlanLoopState = loopState
        self.personalizedCards = personalizedCards
        self.badDayContext = BadDayModeService.context(
            activeDays: snapshot.activeDates,
            latestMoodScore: snapshot.latestMoodScore,
            latestMoodDate: snapshot.latestMoodDate,
            today: selectedDate,
            calendar: calendar
        )
        self.isInitialized = true
    }

    @MainActor
    func markItemAsDone(
        _ item: DailyPlanItem,
        for date: Date,
        in modelContext: ModelContext,
        sourceScreen: String = "Home",
        itemID: String? = nil,
        durationSeconds: Int? = nil,
        wasRecommended: Bool = false,
        recommendationReason: String? = nil
    ) {
        do {
            _ = try DailyPlanCompletionService.shared.complete(
                itemType: item.completionItemType,
                itemID: itemID,
                title: item.completionTitle,
                on: date,
                sourceScreen: sourceScreen,
                durationSeconds: durationSeconds,
                wasRecommended: wasRecommended,
                recommendationReason: recommendationReason,
                in: modelContext
            )
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                updateLocalSnapshot(for: item, state: .completed)
            }
        } catch {
            AppLogger.make(category: "HomeDashboardViewModel").error(
                "Failed to persist Daily Plan completion: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    private func updateLocalSnapshot(for item: DailyPlanItem, state: PlanCardCompletionState) {
        var currentEntries = completionSnapshot.entries
        currentEntries[item] = state
        completionSnapshot = DailyPlanCompletionSnapshot(entries: currentEntries)
        dailyPlanLoopState = Self.makeDailyPlanLoopState(
            snapshot: HomePersonalizedSnapshot(
                hasCheckInToday: completionSnapshot.state(for: .moodCheckIn).isCompleted,
                missedDayCount: badDayContext.missedDays,
                completedTodayCount: completionSnapshot.entries.values.filter(\.isCompleted).count,
                weeklyActivityCount: activeDates.count,
                shouldShowLowEnergyMode: false,
                continueItem: dailyPlanLoopState.continueItem,
                insight: nil
            ),
            activeDates: activeDates,
            completion: completionSnapshot,
            recommendations: recommendations,
            selectedDate: Date()
        )
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

        if snapshot.missedDayCount == 1 {
            cards.append(HomePersonalizedCard(
                id: .restart,
                title: String(localized: "Missed Yesterday?"),
                subtitle: String(localized: "Nothing is broken. One gentle check-in restarts the rhythm."),
                detail: nil,
                systemImage: "leaf.circle.fill",
                actionTitle: String(localized: "Restart gently"),
                action: .moodCheckIn,
                isPriority: !snapshot.hasCheckInToday
            ))
        } else if snapshot.missedDayCount > 1 {
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
                title: recommendation.mode == .full
                    ? String(localized: "Recommended Next Step")
                    : String(localized: "\(recommendation.mode.title) Next Step"),
                subtitle: recommendation.title,
                detail: recommendation.why,
                systemImage: recommendation.icon,
                actionTitle: String(localized: "Open"),
                action: .recommendation(recommendation.destination),
                isPriority: false
            ))
        }

        if snapshot.shouldShowLowEnergyMode {
            cards.append(HomePersonalizedCard(
                id: .lowEnergyMode,
                title: String(localized: "Low Energy Mode"),
                subtitle: String(localized: "A softer version of the plan for right now."),
                detail: String(localized: "Under 60 seconds"),
                systemImage: "moon.zzz.fill",
                actionTitle: String(localized: "Start gently"),
                action: .breathingReset,
                isPriority: true
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
            action: .insights,
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

    static func makeDailyPlanLoopState(
        snapshot: HomePersonalizedSnapshot,
        activeDates: Set<Date>,
        completion: DailyPlanCompletionSnapshot,
        recommendations: [DailyRecommendation],
        selectedDate: Date,
        calendar: Calendar = .current
    ) -> HomeDailyPlanLoopState {
        let completedWins = completedWins(from: completion)
        let isNewUser = activeDates.isEmpty && completedWins.isEmpty && !snapshot.hasCheckInToday
        let effective = effectiveRecommendations(recommendations, isNewUser: isNewUser)
        let firstIncomplete = effective.first { recommendation in
            !completionState(for: recommendation, completion: completion).isCompleted
        }
        let trackedRecommendations = effective.filter { $0.completionItem != nil || $0.isCompletedToday }
        let isPlanComplete = !trackedRecommendations.isEmpty
            && trackedRecommendations.allSatisfy { completionState(for: $0, completion: completion).isCompleted }
        let primary = firstIncomplete ?? optionalCompletionAction(completion: completion) ?? effective[0]
        let optionalTinyAction = isPlanComplete ? optionalCompletionAction(completion: completion) : nil

        return HomeDailyPlanLoopState(
            primaryNextStep: primary,
            whyExplanation: whyExplanation(
                recommendation: primary,
                snapshot: snapshot,
                isNewUser: isNewUser,
                completion: completion
            ),
            completedWins: completedWins,
            continueItem: snapshot.continueItem,
            tomorrowTitle: tomorrowTitle(
                isPlanComplete: isPlanComplete,
                missedDayCount: snapshot.missedDayCount,
                calendar: calendar,
                selectedDate: selectedDate
            ),
            tomorrowSubtitle: tomorrowSubtitle(
                primary: primary,
                isPlanComplete: isPlanComplete,
                isNewUser: isNewUser,
                missedDayCount: snapshot.missedDayCount
            ),
            recoveryMessage: recoveryMessage(missedDayCount: snapshot.missedDayCount),
            isNewUser: isNewUser,
            isPlanComplete: isPlanComplete,
            optionalTinyAction: optionalTinyAction
        )
    }

    static func effectiveRecommendations(
        _ recommendations: [DailyRecommendation],
        isNewUser: Bool
    ) -> [DailyRecommendation] {
        guard recommendations.isEmpty else { return recommendations }
        return starterRecommendations(isNewUser: isNewUser)
    }

    private static func completedWins(from completion: DailyPlanCompletionSnapshot) -> [HomeDailyPlanWin] {
        [
            (.moodCheckIn, String(localized: "Checked in"), "face.smiling"),
            (.thoughtRecord, String(localized: "Thought record"), "brain.head.profile"),
            (.exercises, String(localized: "Practice"), "figure.mind.and.body"),
            (.breathingReset, String(localized: "Breathing reset"), "wind"),
            (.activityPlanner, String(localized: "Activity planned"), "calendar.badge.clock"),
            (.tinyWin, String(localized: "Tiny Win"), "checkmark.seal.fill")
        ].compactMap { item, title, image in
            completion.state(for: item).isCompleted
                ? HomeDailyPlanWin(item: item, title: title, systemImage: image)
                : nil
        }
    }

    private static func completionState(
        for recommendation: DailyRecommendation,
        completion: DailyPlanCompletionSnapshot
    ) -> PlanCardCompletionState {
        if recommendation.isCompletedToday {
            return .completed
        }
        guard let item = recommendation.completionItem else { return .notTracked }
        return completion.state(for: item)
    }

    private static func whyExplanation(
        recommendation: DailyRecommendation,
        snapshot: HomePersonalizedSnapshot,
        isNewUser: Bool,
        completion: DailyPlanCompletionSnapshot
    ) -> String {
        if isNewUser {
            return String(localized: "This starter step appears because there is no local Daily Plan history yet.")
        }
        if !snapshot.hasCheckInToday, recommendation.completionItem == .moodCheckIn {
            return String(localized: "This appears first because today's check-in is still open.")
        }
        if snapshot.missedDayCount > 0 {
            return String(localized: "This is a small restart based on local activity dates. No catch-up needed.")
        }
        if let item = recommendation.completionItem, completion.state(for: item).isCompleted {
            return String(localized: "This is already counted for today, based on saved activity.")
        }
        return recommendation.why
    }

    private static func tomorrowTitle(
        isPlanComplete: Bool,
        missedDayCount: Int,
        calendar: Calendar,
        selectedDate: Date
    ) -> String {
        if isPlanComplete {
            return String(localized: "Tomorrow: keep it light")
        }
        if missedDayCount > 0 {
            return String(localized: "Tomorrow: one fresh step")
        }
        if calendar.isDateInToday(selectedDate) {
            return String(localized: "Tomorrow Preview")
        }
        return String(localized: "Next Return")
    }

    private static func tomorrowSubtitle(
        primary: DailyRecommendation,
        isPlanComplete: Bool,
        isNewUser: Bool,
        missedDayCount: Int
    ) -> String {
        if isPlanComplete {
            return String(localized: "Come back for a fresh check-in and a new recommendation from your local progress.")
        }
        if isNewUser {
            return String(localized: "After one check-in, tomorrow's plan can feel more personal.")
        }
        if missedDayCount > 0 {
            return String(localized: "Coming back tomorrow starts from tomorrow, not from what you missed.")
        }
        return String(localized: "If you come back tomorrow, Daily Plan will adjust after \(primary.title).")
    }

    private static func recoveryMessage(missedDayCount: Int) -> String? {
        guard missedDayCount > 0 else { return nil }
        if missedDayCount == 1 {
            return String(localized: "Welcome back. Yesterday can stay yesterday; one small step is enough today.")
        }
        return String(localized: "Welcome back. You do not need to catch up on \(missedDayCount) days; start with one gentle step.")
    }

    private static func optionalCompletionAction(completion: DailyPlanCompletionSnapshot) -> DailyRecommendation? {
        if !completion.state(for: .breathingReset).isCompleted {
            return DailyRecommendation(
                id: "optional-breathing-reset",
                type: .breathingReset,
                title: String(localized: "One-Minute Reset"),
                subtitle: String(localized: "A tiny optional pause for your body."),
                reason: String(localized: "Because your main plan is done, this stays optional and small."),
                destination: .breathingReset(durationSeconds: 60),
                priority: 20,
                estimatedDurationMinutes: 1,
                isCompletedToday: false,
                mode: .quick
            )
        }
        return DailyRecommendation(
            id: "optional-thought-record",
            type: .thoughtRecord,
            title: String(localized: "Capture One Thought"),
            subtitle: String(localized: "Optional: write one thought before it gets fuzzy."),
            reason: String(localized: "Because your main plan is done, this is only a small extra."),
            destination: .thoughtRecord,
            priority: 20,
            estimatedDurationMinutes: 3,
            isCompletedToday: false,
            mode: .quick
        )
    }

    private static func starterRecommendations(isNewUser: Bool) -> [DailyRecommendation] {
        [
            DailyRecommendation(
                id: "starter-mood-check-in",
                type: .moodCheckIn,
                title: String(localized: "Daily Check-In"),
                subtitle: String(localized: "Log how today feels in about a minute."),
                reason: isNewUser
                    ? String(localized: "Because there is no local Daily Plan history yet.")
                    : String(localized: "Because a check-in gives today a clear starting point."),
                destination: .moodCheckIn,
                priority: 90,
                estimatedDurationMinutes: 1,
                isCompletedToday: false,
                mode: .full
            ),
            DailyRecommendation(
                id: "starter-breathing-reset",
                type: .breathingReset,
                title: String(localized: "Breathing Reset"),
                subtitle: String(localized: "Take one minute to settle your body."),
                reason: String(localized: "Because a short reset works even without prior app history."),
                destination: .breathingReset(durationSeconds: 60),
                priority: 60,
                estimatedDurationMinutes: 1,
                isCompletedToday: false,
                mode: .quick
            ),
            DailyRecommendation(
                id: "starter-intro",
                type: .courseLesson,
                title: String(localized: "Learn the CBT Basics"),
                subtitle: String(localized: "Start with a short introduction."),
                reason: String(localized: "Because starter plans need one simple learning step."),
                destination: .introToCBT,
                priority: 40,
                estimatedDurationMinutes: 4,
                isCompletedToday: false,
                mode: .full
            )
        ]
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

extension HomeDailyPlanLoopState {
    static let starter = HomeDashboardViewModel.makeDailyPlanLoopState(
        snapshot: .empty,
        activeDates: [],
        completion: .empty,
        recommendations: [],
        selectedDate: Date()
    )
}
