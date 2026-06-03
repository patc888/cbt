import XCTest
@testable import CBT

final class DailyPlanRecommendationEngineTests: XCTestCase {
    private let engine = DailyPlanRecommendationEngine()

    func testNoDataReturnsOnboardingStarterPlan() {
        let recommendations = engine.recommendations(from: input(hasAnyUserData: false))

        XCTAssertEqual(recommendations.map(\.type), [.moodCheckIn, .breathingReset, .courseLesson])
        XCTAssertTrue(recommendations.first?.reason.contains("no Daily Plan history") == true)
        XCTAssertTrue((2...4).contains(recommendations.count))
    }

    func testHighStressSuggestsBreathingOrGroundingWithReason() {
        let recommendations = engine.recommendations(from: input(
            moodSamples: [
                Self.moodSample(daysAgo: 1, moodScore: 5, intensity: 8, emotions: ["Stressed"])
            ],
            hasBreathingToday: false
        ))

        XCTAssertEqual(recommendations.first?.type, .breathingReset)
        XCTAssertTrue(recommendations.contains { $0.destination == DailyRecommendationDestination.libraryExercise(exerciseID: "grounding") })
        XCTAssertTrue(recommendations.first?.reason.contains("stress was high yesterday") == true)
    }

    func testLowMoodSuggestsBehavioralActivationOrTinyWin() {
        let recommendations = engine.recommendations(from: input(
            moodSamples: [
                Self.moodSample(daysAgo: 0, moodScore: 3),
                Self.moodSample(daysAgo: 1, moodScore: 3),
                Self.moodSample(daysAgo: 2, moodScore: 4)
            ]
        ))

        let activation = recommendations.first { $0.type == DailyRecommendationType.behavioralActivation }
        XCTAssertEqual(activation?.title, "Tiny Win")
        XCTAssertTrue(activation?.reason.contains("recent mood has been low") == true)
    }

    func testRepeatedTriggerSuggestsRelatedCBTExercise() {
        let recommendations = engine.recommendations(from: input(
            moodSamples: [
                Self.moodSample(daysAgo: 0, moodScore: 5, triggers: ["Work"]),
                Self.moodSample(daysAgo: 1, moodScore: 6, triggers: ["Work"])
            ]
        ))

        let relatedExercise = recommendations.first { $0.destination == DailyRecommendationDestination.libraryExercise(exerciseID: "thought") }
        XCTAssertNotNil(relatedExercise)
        XCTAssertTrue(relatedExercise?.reason.contains("Work has shown up repeatedly") == true)
    }

    func testMissedTwoDaysSuggestsGentleRestart() {
        let recommendations = engine.recommendations(from: input(missedDays: 2))

        XCTAssertEqual(recommendations.first?.title, "Gentle Restart")
        XCTAssertTrue(recommendations.first?.reason.contains("2 days") == true)
    }

    func testMissedYesterdaySuggestsRestartGently() {
        let recommendations = engine.recommendations(from: input(missedDays: 1))

        XCTAssertEqual(recommendations.first?.title, "Restart Gently")
        XCTAssertTrue(recommendations.first?.reason.contains("only missed yesterday") == true)
    }

    func testCurrentStreakSuggestsCheckInWhenTodayIsOpen() {
        let recommendations = engine.recommendations(from: input(
            currentStreak: 4,
            hasMoodToday: false
        ))

        let streakRecommendation = recommendations.first { $0.title == "Keep Your Streak Going" }
        XCTAssertNotNil(streakRecommendation)
        XCTAssertTrue(streakRecommendation?.reason.contains("4 days") == true)
    }

    func testIncompleteExercisePrioritizesContinueWhereLeftOff() {
        let unfinished = Self.exercise(
            id: "unfinished",
            title: "Half-Finished Practice",
            category: "Grounding"
        )

        let recommendations = engine.recommendations(from: input(incompleteExercise: unfinished))

        XCTAssertEqual(recommendations.first?.title, "Continue Where You Left Off")
        XCTAssertEqual(recommendations.first?.destination, DailyRecommendationDestination.libraryExercise(exerciseID: "unfinished"))
    }

    func testThoughtGoalPreferenceCanLiftThoughtRecord() {
        let recommendations = engine.recommendations(from: input(
            preferences: DailyPlanUserPreferences(
                goals: [DailyPlanGoal.understandThoughts.rawValue],
                interests: []
            )
        ))

        let thoughtRecord = recommendations.first { $0.type == .thoughtRecord }
        XCTAssertNotNil(thoughtRecord)
        XCTAssertTrue(thoughtRecord?.reason.contains("Daily Plan goals") == true)
    }

    func testHelpfulInterventionPreferenceCanLiftBreathing() {
        let recommendations = engine.recommendations(from: input(
            hasBreathingToday: false,
            preferences: DailyPlanUserPreferences(
                goals: [],
                interests: [],
                helpfulInterventions: [DailyPlanHelpfulIntervention.breathing.rawValue]
            )
        ))

        XCTAssertEqual(recommendations.first?.type, .breathingReset)
        XCTAssertTrue(recommendations.first?.reason.contains("supports that helps you") == true)
    }

    func testQuickSessionPreferenceLimitsPlanDepth() {
        let recommendations = engine.recommendations(from: input(
            hasMoodToday: false,
            hasBreathingToday: false,
            preferences: DailyPlanUserPreferences(
                goals: [],
                interests: [],
                preferredSessionLength: DailyPlanSessionLength.quick.rawValue
            )
        ))

        XCTAssertLessThanOrEqual(recommendations.count, 2)
        XCTAssertTrue(recommendations.allSatisfy { $0.estimatedDurationMinutes <= 3 })
    }

    func testCommonTriggerPreferenceSuggestsRelatedExercise() {
        let recommendations = engine.recommendations(from: input(
            preferences: DailyPlanUserPreferences(
                goals: [],
                interests: [],
                commonTriggers: [DailyPlanCommonTrigger.work.rawValue]
            )
        ))

        let triggerRecommendation = recommendations.first {
            $0.reason.contains("work or school is a common trigger")
        }
        XCTAssertNotNil(triggerRecommendation)
        XCTAssertEqual(triggerRecommendation?.destination, DailyRecommendationDestination.libraryExercise(exerciseID: "thought"))
    }

    func testRecentDistortionSuggestsThoughtRecord() {
        let recommendations = engine.recommendations(from: input(
            thoughtRecordDistortions: ["Catastrophizing", "Catastrophizing"]
        ))

        let thoughtRecord = recommendations.first { $0.type == .thoughtRecord }
        XCTAssertNotNil(thoughtRecord)
        XCTAssertTrue(thoughtRecord?.reason.contains("Catastrophizing") == true)
    }

    func testLowEnergySignalsSelectLowEnergyVariantsUnderOneMinute() {
        let recommendations = engine.recommendations(from: input(
            moodSamples: [
                Self.moodSample(daysAgo: 0, moodScore: 5, energyScore: 2, stressScore: 8)
            ],
            hasBreathingToday: false
        ))

        XCTAssertTrue(recommendations.allSatisfy { $0.mode == .lowEnergy })
        XCTAssertTrue(recommendations.allSatisfy { $0.estimatedDurationMinutes == 1 })
        XCTAssertTrue(recommendations.contains { $0.durationLabel == "Under 1 min" })
    }

    func testModerateStressSelectsQuickMode() {
        let mode = engine.selectedMode(from: input(
            moodSamples: [
                Self.moodSample(daysAgo: 0, moodScore: 6, energyScore: 5, stressScore: 6)
            ],
            recentEngagementCount: 4
        ))

        XCTAssertEqual(mode, .quick)
    }

    func testGoodSignalsAndRecentEngagementSelectFullMode() {
        let mode = engine.selectedMode(from: input(
            moodSamples: [
                Self.moodSample(daysAgo: 0, moodScore: 7, energyScore: 8, stressScore: 2)
            ],
            recentEngagementCount: 5
        ))

        XCTAssertEqual(mode, .full)
    }

    func testHelpfulThoughtRecordFeedbackLiftsThoughtRecordRecommendation() {
        let recommendations = engine.recommendations(from: input(
            hasBreathingToday: false,
            hasThoughtRecordToday: false,
            helpfulnessScores: [.thoughtRecord: 1]
        ))

        XCTAssertEqual(recommendations.first?.type, .thoughtRecord)
    }

    func testUnhelpfulBreathingFeedbackSoftensBreathingRecommendation() {
        let recommendations = engine.recommendations(from: input(
            hasBreathingToday: false,
            hasThoughtRecordToday: false,
            helpfulnessScores: [.breathingReset: -1]
        ))

        XCTAssertEqual(recommendations.first?.type, .thoughtRecord)
    }

    private func input(
        moodSamples: [DailyPlanMoodSample]? = nil,
        thoughtRecordDistortions: [String] = [],
        missedDays: Int? = nil,
        currentStreak: Int = 0,
        hasMoodToday: Bool = true,
        hasThoughtRecordToday: Bool = false,
        hasBreathingToday: Bool = true,
        hasActivityCompletedToday: Bool = true,
        incompleteExercise: DailyPlanExerciseSummary? = nil,
        completedExerciseIDs: Set<String> = [],
        preferences: DailyPlanUserPreferences = .empty,
        hasAnyUserData: Bool = true,
        recentEngagementCount: Int = 3,
        helpfulnessScores: [DailyRecommendationType: Double] = [:]
    ) -> DailyPlanRecommendationInput {
        DailyPlanRecommendationInput(
            today: Self.today,
            now: Self.now,
            moodSamples: moodSamples ?? [Self.moodSample(daysAgo: 0, moodScore: 6)],
            thoughtRecordDistortions: thoughtRecordDistortions,
            missedDays: missedDays,
            currentStreak: currentStreak,
            hasMoodToday: hasMoodToday,
            hasThoughtRecordToday: hasThoughtRecordToday,
            hasBreathingToday: hasBreathingToday,
            hasActivityCompletedToday: hasActivityCompletedToday,
            incompleteExercise: incompleteExercise,
            completedExerciseIDs: completedExerciseIDs,
            exercises: [
                Self.exercise(id: "grounding", title: "Grounding Exercise", category: "Grounding"),
                Self.exercise(id: "thought", title: "Thought Reframe", category: "Thought Reframing"),
                Self.exercise(id: "activation", title: "Small Activity", category: "Behavioral Activation")
            ],
            preferences: preferences,
            hasAnyUserData: hasAnyUserData,
            recentEngagementCount: recentEngagementCount,
            helpfulnessScores: helpfulnessScores
        )
    }

    private static func moodSample(
        daysAgo: Int,
        moodScore: Int,
        intensity: Int? = nil,
        energyScore: Int? = nil,
        stressScore: Int? = nil,
        emotions: [String] = [],
        triggers: [String] = [],
        sensations: [String] = [],
        contextTags: [String] = []
    ) -> DailyPlanMoodSample {
        DailyPlanMoodSample(
            createdAt: now.addingTimeInterval(Double(-daysAgo * 86_400)),
            moodScore: moodScore,
            intensity: intensity,
            energyScore: energyScore,
            stressScore: stressScore,
            emotions: emotions,
            triggers: triggers,
            sensations: sensations,
            contextTags: contextTags
        )
    }

    private static func exercise(
        id: String,
        title: String,
        category: String,
        isCompletedToday: Bool = false
    ) -> DailyPlanExerciseSummary {
        DailyPlanExerciseSummary(
            id: id,
            title: title,
            category: category,
            duration: 5,
            description: "A short practice.",
            isCompletedToday: isCompletedToday
        )
    }

    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let today = Calendar(identifier: .gregorian).startOfDay(for: now)
}
