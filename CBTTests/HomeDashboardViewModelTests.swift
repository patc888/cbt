import XCTest
@testable import CBT

final class HomeDashboardViewModelTests: XCTestCase {
    func testDailyPlanLoopStateForNewUserUsesStarterPlan() {
        let state = makeState(
            snapshot: HomePersonalizedSnapshot(hasCheckInToday: false),
            activeDates: [],
            completion: .empty,
            recommendations: []
        )

        XCTAssertTrue(state.isNewUser)
        XCTAssertEqual(state.primaryNextStep.type, DailyRecommendationType.moodCheckIn)
        XCTAssertTrue(state.whyExplanation.contains("no local Daily Plan history"))
        XCTAssertTrue(state.completedWins.isEmpty)
        XCTAssertTrue(state.tomorrowSubtitle.contains("After one check-in"))
    }

    func testDailyPlanLoopStateWhenCheckInIsMissingPrioritizesCheckIn() {
        let state = makeState(
            snapshot: HomePersonalizedSnapshot(hasCheckInToday: false),
            activeDates: [Self.yesterday],
            completion: .empty,
            recommendations: [
                Self.recommendation(type: .moodCheckIn, title: "Daily Check-In", itemCompleted: false),
                Self.recommendation(type: .thoughtRecord, title: "Thought Record", itemCompleted: false)
            ]
        )

        XCTAssertFalse(state.isNewUser)
        XCTAssertEqual(state.primaryNextStep.type, DailyRecommendationType.moodCheckIn)
        XCTAssertTrue(state.whyExplanation.contains("check-in is still open"))
    }

    func testDailyPlanLoopStateForPartiallyCompletedPlanShowsTodayWinsAndNextStep() {
        let state = makeState(
            snapshot: HomePersonalizedSnapshot(hasCheckInToday: true, completedTodayCount: 1),
            activeDates: [Self.today],
            completion: Self.snapshot([
                .moodCheckIn: .completed,
                .thoughtRecord: .incomplete,
                .breathingReset: .incomplete
            ]),
            recommendations: [
                Self.recommendation(type: .moodCheckIn, title: "Daily Check-In", itemCompleted: false),
                Self.recommendation(type: .thoughtRecord, title: "Thought Record", itemCompleted: false),
                Self.recommendation(type: .breathingReset, title: "Breathing Reset", itemCompleted: false)
            ]
        )

        XCTAssertFalse(state.isPlanComplete)
        XCTAssertEqual(state.completedWins.map { $0.item }, [DailyPlanItem.moodCheckIn])
        XCTAssertEqual(state.primaryNextStep.type, DailyRecommendationType.thoughtRecord)
    }

    func testDailyPlanLoopStateForFullyCompletedPlanOffersTinyOptionalAction() {
        let state = makeState(
            snapshot: HomePersonalizedSnapshot(hasCheckInToday: true, completedTodayCount: 3),
            activeDates: [Self.today],
            completion: Self.snapshot([
                .moodCheckIn: .completed,
                .thoughtRecord: .completed,
                .breathingReset: .completed
            ]),
            recommendations: [
                Self.recommendation(type: .moodCheckIn, title: "Daily Check-In", itemCompleted: true),
                Self.recommendation(type: .thoughtRecord, title: "Thought Record", itemCompleted: true),
                Self.recommendation(type: .breathingReset, title: "Breathing Reset", itemCompleted: true)
            ]
        )

        XCTAssertTrue(state.isPlanComplete)
        XCTAssertNotNil(state.optionalTinyAction)
        XCTAssertTrue(state.tomorrowTitle.contains("Tomorrow"))
        XCTAssertTrue(state.tomorrowSubtitle.contains("fresh check-in"))
    }

    func testDailyPlanLoopStateAfterMissedDaysUsesGentleRecoveryCopy() {
        let state = makeState(
            snapshot: HomePersonalizedSnapshot(hasCheckInToday: false, missedDayCount: 4),
            activeDates: [Self.fiveDaysAgo],
            completion: .empty,
            recommendations: [
                Self.recommendation(type: .moodCheckIn, title: "Gentle Restart", itemCompleted: false)
            ]
        )

        XCTAssertNotNil(state.recoveryMessage)
        XCTAssertTrue(state.recoveryMessage?.contains("do not need to catch up") == true)
        XCTAssertTrue(state.tomorrowSubtitle.contains("not from what you missed"))
    }

    private func makeState(
        snapshot: HomePersonalizedSnapshot,
        activeDates: Set<Date>,
        completion: DailyPlanCompletionSnapshot,
        recommendations: [DailyRecommendation]
    ) -> HomeDailyPlanLoopState {
        HomeDashboardViewModel.makeDailyPlanLoopState(
            snapshot: snapshot,
            activeDates: activeDates,
            completion: completion,
            recommendations: recommendations,
            selectedDate: Self.today,
            calendar: Self.calendar
        )
    }

    private static func snapshot(_ overrides: [DailyPlanItem: PlanCardCompletionState]) -> DailyPlanCompletionSnapshot {
        var entries = DailyPlanCompletionSnapshot.empty.entries
        overrides.forEach { entries[$0.key] = $0.value }
        return DailyPlanCompletionSnapshot(entries: entries)
    }

    private static func recommendation(
        type: DailyRecommendationType,
        title: String,
        itemCompleted: Bool
    ) -> DailyRecommendation {
        DailyRecommendation(
            id: title.lowercased().replacingOccurrences(of: " ", with: "-"),
            type: type,
            title: title,
            subtitle: "A short step.",
            reason: "Because local activity suggests this step.",
            destination: destination(for: type),
            priority: 80,
            estimatedDurationMinutes: 1,
            isCompletedToday: itemCompleted,
            mode: .full
        )
    }

    private static func destination(for type: DailyRecommendationType) -> DailyRecommendationDestination {
        switch type {
        case .moodCheckIn:
            return .moodCheckIn
        case .thoughtRecord:
            return .thoughtRecord
        case .breathingReset, .sleepWindDown:
            return .breathingReset(durationSeconds: 60)
        case .behavioralActivation:
            return .behavioralActivation
        case .libraryExercise:
            return .libraryExercise(exerciseID: "grounding")
        case .courseLesson:
            return .introToCBT
        case .guidedJournal:
            return .guidedJournal(kind: "daily")
        case .safetySupport:
            return .safetySupport
        }
    }

    private static let calendar = Calendar(identifier: .gregorian)
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let today = calendar.startOfDay(for: now)
    private static let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    private static let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: today)!
}
