import Foundation
import SwiftData

nonisolated enum FirstSevenDaysJourneyAction: String, CaseIterable, Sendable {
    case welcomeCheckIn
    case identifyThought
    case reframeThought
    case grounding
    case behavioralActivation
    case triggerPattern
    case weeklyReview
}

nonisolated enum FirstSevenDaysJourneyState: Equatable, Sendable {
    case empty
    case active
    case missedDay(Int)
    case completed
}

nonisolated struct FirstSevenDaysJourneyStep: Identifiable, Equatable, Sendable {
    let id: String
    let day: Int
    let action: FirstSevenDaysJourneyAction
    let title: String
    let subtitle: String
    let destination: DailyRecommendationDestination
    let durationMinutes: Int
}

nonisolated struct FirstSevenDaysJourneyStatus: Equatable, Sendable {
    let state: FirstSevenDaysJourneyState
    let currentStep: FirstSevenDaysJourneyStep?
    let completedCount: Int
    let totalCount: Int

    static let empty = FirstSevenDaysJourneyStatus(
        state: .empty,
        currentStep: nil,
        completedCount: 0,
        totalCount: FirstSevenDaysJourneyService.steps.count
    )
}

@MainActor
struct FirstSevenDaysJourneyService {
    static let shared = FirstSevenDaysJourneyService()

    nonisolated static let steps: [FirstSevenDaysJourneyStep] = [
        FirstSevenDaysJourneyStep(
            id: FirstSevenDaysJourneyAction.welcomeCheckIn.rawValue,
            day: 1,
            action: .welcomeCheckIn,
            title: "Welcome Check-In",
            subtitle: "Begin with one gentle check-in and a quick CBT orientation.",
            destination: .moodCheckIn,
            durationMinutes: 1
        ),
        FirstSevenDaysJourneyStep(
            id: FirstSevenDaysJourneyAction.identifyThought.rawValue,
            day: 2,
            action: .identifyThought,
            title: "Identify One Thought",
            subtitle: "Catch one automatic thought without needing to fix it yet.",
            destination: .thoughtRecord,
            durationMinutes: 5
        ),
        FirstSevenDaysJourneyStep(
            id: FirstSevenDaysJourneyAction.reframeThought.rawValue,
            day: 3,
            action: .reframeThought,
            title: "Reframe One Thought",
            subtitle: "Practice one balanced thought that feels believable.",
            destination: .thoughtRecord,
            durationMinutes: 8
        ),
        FirstSevenDaysJourneyStep(
            id: FirstSevenDaysJourneyAction.grounding.rawValue,
            day: 4,
            action: .grounding,
            title: "Try Grounding",
            subtitle: "Use a short grounding exercise to settle attention.",
            destination: .breathingReset(durationSeconds: 60),
            durationMinutes: 1
        ),
        FirstSevenDaysJourneyStep(
            id: FirstSevenDaysJourneyAction.behavioralActivation.rawValue,
            day: 5,
            action: .behavioralActivation,
            title: "Try Behavioral Activation",
            subtitle: "Complete one small planned activity.",
            destination: .behavioralActivation,
            durationMinutes: 5
        ),
        FirstSevenDaysJourneyStep(
            id: FirstSevenDaysJourneyAction.triggerPattern.rawValue,
            day: 6,
            action: .triggerPattern,
            title: "Notice a Trigger Pattern",
            subtitle: "Log a check-in with one trigger so patterns can emerge.",
            destination: .moodCheckIn,
            durationMinutes: 1
        ),
        FirstSevenDaysJourneyStep(
            id: FirstSevenDaysJourneyAction.weeklyReview.rawValue,
            day: 7,
            action: .weeklyReview,
            title: "Complete a Weekly Review",
            subtitle: "Look back at the week and choose one focus for what comes next.",
            destination: .weeklyReview,
            durationMinutes: 4
        )
    ]

    func status(
        from context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FirstSevenDaysJourneyStatus {
        guard let journey = fetchJourney(from: context) else {
            return .empty
        }

        advanceJourney(journey, in: context, now: now)

        let completed = Set(journey.completedStepIDs)
        if completed.count >= Self.steps.count {
            if journey.completedAt == nil {
                journey.completedAt = now
                journey.updatedAt = now
                try? context.save()
            }
            return FirstSevenDaysJourneyStatus(
                state: .completed,
                currentStep: nil,
                completedCount: Self.steps.count,
                totalCount: Self.steps.count
            )
        }

        guard let currentStep = Self.steps.first(where: { !completed.contains($0.id) }) else {
            return .empty
        }

        let missedDays = missedDayCount(for: journey, now: now, calendar: calendar)
        return FirstSevenDaysJourneyStatus(
            state: missedDays > 0 ? .missedDay(missedDays) : .active,
            currentStep: currentStep,
            completedCount: completed.count,
            totalCount: Self.steps.count
        )
    }

    @discardableResult
    func ensureStartedForNewUserIfNeeded(
        in context: ModelContext,
        now: Date = Date()
    ) -> FirstSevenDaysJourney? {
        if let existing = fetchJourney(from: context) {
            return existing
        }
        guard hasAnyPracticeData(in: context) == false else {
            return nil
        }
        return startJourney(in: context, isOptIn: false, now: now)
    }

    @discardableResult
    func optIn(in context: ModelContext, now: Date = Date()) -> FirstSevenDaysJourney {
        if let existing = fetchJourney(from: context) {
            existing.isOptIn = true
            existing.completedAt = nil
            existing.updatedAt = now
            try? context.save()
            return existing
        }
        return startJourney(in: context, isOptIn: true, now: now)
    }

    func mark(_ action: FirstSevenDaysJourneyAction, in context: ModelContext, at date: Date = Date()) {
        guard let journey = fetchJourney(from: context), journey.completedAt == nil else { return }
        complete(action.rawValue, in: journey, at: date)
        try? context.save()
    }

    func recommendation(for status: FirstSevenDaysJourneyStatus) -> DailyRecommendation? {
        guard let step = status.currentStep else { return nil }

        let reason: String
        switch status.state {
        case .missedDay:
            reason = "No catching up needed. Continue with the next starter step when you are ready."
        case .active:
            reason = "Because this is day \(step.day) of your starter journey."
        case .empty, .completed:
            return nil
        }

        return DailyRecommendation(
            id: "first-seven-days-\(step.id)",
            type: recommendationType(for: step),
            title: "Day \(step.day): \(step.title)",
            subtitle: step.subtitle,
            reason: reason,
            destination: step.destination,
            priority: 120,
            estimatedDurationMinutes: step.durationMinutes,
            isCompletedToday: false,
            mode: .full
        )
    }

    private func startJourney(
        in context: ModelContext,
        isOptIn: Bool,
        now: Date
    ) -> FirstSevenDaysJourney {
        let journey = FirstSevenDaysJourney(startedAt: now, updatedAt: now, isOptIn: isOptIn)
        context.insert(journey)
        try? context.save()
        return journey
    }

    private func fetchJourney(from context: ModelContext) -> FirstSevenDaysJourney? {
        let descriptor = FetchDescriptor<FirstSevenDaysJourney>(
            sortBy: [SortDescriptor(\FirstSevenDaysJourney.startedAt, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }

    private func advanceJourney(_ journey: FirstSevenDaysJourney, in context: ModelContext, now: Date) {
        guard journey.completedAt == nil else { return }
        var completed = Set(journey.completedStepIDs)
        var changed = false

        for step in Self.steps where !completed.contains(step.id) {
            guard hasEvidence(for: step.action, journey: journey, in: context) else {
                break
            }
            completed.insert(step.id)
            journey.completedStepIDs = Self.steps.filter { completed.contains($0.id) }.map(\.id)
            journey.updatedAt = now
            changed = true
        }

        if completed.count >= Self.steps.count {
            journey.completedAt = now
        }

        if changed {
            try? context.save()
        }
    }

    private func complete(_ stepID: String, in journey: FirstSevenDaysJourney, at date: Date) {
        var completed = Set(journey.completedStepIDs)
        guard completed.insert(stepID).inserted else { return }
        journey.completedStepIDs = Self.steps.filter { completed.contains($0.id) }.map(\.id)
        journey.updatedAt = date
        if completed.count >= Self.steps.count {
            journey.completedAt = date
        }
    }

    private func missedDayCount(for journey: FirstSevenDaysJourney, now: Date, calendar: Calendar) -> Int {
        let anchor = journey.updatedAt > journey.startedAt ? journey.updatedAt : journey.startedAt
        let anchorDay = calendar.startOfDay(for: anchor)
        let today = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: anchorDay, to: today).day ?? 0)
    }

    private func recommendationType(for step: FirstSevenDaysJourneyStep) -> DailyRecommendationType {
        switch step.action {
        case .welcomeCheckIn, .triggerPattern:
            return .moodCheckIn
        case .identifyThought, .reframeThought:
            return .thoughtRecord
        case .grounding:
            return .breathingReset
        case .behavioralActivation:
            return .behavioralActivation
        case .weeklyReview:
            return .guidedJournal
        }
    }

    private func hasEvidence(
        for action: FirstSevenDaysJourneyAction,
        journey: FirstSevenDaysJourney,
        in context: ModelContext
    ) -> Bool {
        switch action {
        case .welcomeCheckIn:
            return fetchMoodCheckIns(from: context).contains { $0.createdAt >= journey.startedAt }
                || fetchMoodEntries(from: context).contains { $0.createdAt >= journey.startedAt }
        case .identifyThought:
            return fetchThoughtRecords(from: context).contains {
                $0.createdAt >= journey.startedAt &&
                !$0.automaticThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        case .reframeThought:
            return fetchThoughtRecords(from: context).contains {
                $0.createdAt >= journey.startedAt &&
                !$0.balancedThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        case .grounding:
            return fetchBreathingSessions(from: context).contains { $0.createdAt >= journey.startedAt }
                || fetchExerciseCompletions(from: context).contains { completion in
                    completion.createdAt >= journey.startedAt && isGroundingExercise(completion.exerciseID)
                }
        case .behavioralActivation:
            return fetchPlannedActivities(from: context).contains { activity in
                activity.isCompleted && (activity.completedAt ?? activity.createdAt) >= journey.startedAt
            }
        case .triggerPattern:
            return fetchMoodEntries(from: context).contains { entry in
                entry.createdAt >= journey.startedAt && !entry.triggers.isEmpty
            }
        case .weeklyReview:
            return false
        }
    }

    private func isGroundingExercise(_ exerciseID: String) -> Bool {
        guard let exercise = ExerciseService.shared.exercise(withID: exerciseID) else {
            return false
        }
        let searchable = ([exercise.title, exercise.category] + (exercise.tags ?? []))
            .joined(separator: " ")
            .lowercased()
        return searchable.contains("grounding") || searchable.contains("breathing")
    }

    private func hasAnyPracticeData(in context: ModelContext) -> Bool {
        !fetchMoodEntries(from: context).isEmpty ||
            !fetchMoodCheckIns(from: context).isEmpty ||
            !fetchThoughtRecords(from: context).isEmpty ||
            !fetchExerciseCompletions(from: context).isEmpty ||
            !fetchBreathingSessions(from: context).isEmpty ||
            !fetchPlannedActivities(from: context).isEmpty
    }

    private func fetchMoodEntries(from context: ModelContext) -> [MoodEntry] {
        (try? context.fetch(FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { $0.isDeleted == false }
        ))) ?? []
    }

    private func fetchMoodCheckIns(from context: ModelContext) -> [MoodCheckIn] {
        (try? context.fetch(FetchDescriptor<MoodCheckIn>(
            predicate: #Predicate<MoodCheckIn> { $0.isDeleted == false }
        ))) ?? []
    }

    private func fetchThoughtRecords(from context: ModelContext) -> [ThoughtRecord] {
        (try? context.fetch(FetchDescriptor<ThoughtRecord>(
            predicate: #Predicate<ThoughtRecord> { $0.isDeleted == false }
        ))) ?? []
    }

    private func fetchExerciseCompletions(from context: ModelContext) -> [ExerciseCompletion] {
        (try? context.fetch(FetchDescriptor<ExerciseCompletion>(
            predicate: #Predicate<ExerciseCompletion> { $0.isDeleted == false }
        ))) ?? []
    }

    private func fetchBreathingSessions(from context: ModelContext) -> [BreathingSession] {
        (try? context.fetch(FetchDescriptor<BreathingSession>(
            predicate: #Predicate<BreathingSession> { $0.isDeleted == false }
        ))) ?? []
    }

    private func fetchPlannedActivities(from context: ModelContext) -> [PlannedActivity] {
        (try? context.fetch(FetchDescriptor<PlannedActivity>(
            predicate: #Predicate<PlannedActivity> { $0.isDeleted == false }
        ))) ?? []
    }
}
