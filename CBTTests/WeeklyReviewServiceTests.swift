import SwiftData
import XCTest
@testable import CBT

@MainActor
final class WeeklyReviewServiceTests: XCTestCase {
    func testWeeklyReviewAggregatesCheckInsMoodStressTriggersAndCompletions() throws {
        let calendar = Self.utcCalendar()
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let monday = Self.date(calendar, 2026, 6, 1, 9)

        let moodOne = MoodEntry(
            createdAt: monday,
            moodScore: 4,
            emotions: ["Anxious"],
            triggers: ["Work", "Sleep"],
            intensity: 8
        )
        let moodTwo = MoodEntry(
            createdAt: Self.date(calendar, 2026, 6, 3, 10),
            moodScore: 6,
            emotions: ["stressed"],
            triggers: ["work"],
            intensity: 6
        )
        let duplicateLegacyCheckIn = MoodCheckIn(
            createdAt: monday.addingTimeInterval(60),
            moodScore: 4
        )
        let separateCheckIn = MoodCheckIn(
            createdAt: Self.date(calendar, 2026, 6, 4, 12),
            moodScore: 8
        )
        let oldMood = MoodEntry(
            createdAt: Self.date(calendar, 2026, 5, 25, 9),
            moodScore: 1,
            emotions: ["Anxious"],
            triggers: ["Work"],
            intensity: 10
        )
        let exercise = ExerciseCompletion(
            createdAt: Self.date(calendar, 2026, 6, 5, 9),
            exerciseID: "Grounding"
        )
        let tinyWin = TinyWinCompletion(
            createdAt: Self.date(calendar, 2026, 6, 2, 18),
            winID: "three_slow_breaths"
        )
        let breathing = BreathingSession(
            createdAt: Self.date(calendar, 2026, 6, 2, 20),
            durationSeconds: 60
        )

        context.insert(moodOne)
        context.insert(moodTwo)
        context.insert(duplicateLegacyCheckIn)
        context.insert(separateCheckIn)
        context.insert(oldMood)
        context.insert(exercise)
        context.insert(tinyWin)
        context.insert(breathing)
        try context.save()

        let review = try WeeklyReviewService(
            calendar: calendar,
            now: { Self.date(calendar, 2026, 6, 6, 12) }
        )
        .generateReview(forWeekContaining: monday, from: context)

        XCTAssertEqual(review.checkInCount, 3)
        XCTAssertEqual(try XCTUnwrap(review.averageMood), 6, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(review.averageAnxietyStress), 7, accuracy: 0.001)
        XCTAssertEqual(review.mostCommonTriggers.map(\.label), ["Work", "Sleep"])
        XCTAssertEqual(review.mostCommonTriggers.map(\.count), [2, 1])
        XCTAssertEqual(review.completedExercises.map(\.label), ["Grounding"])
        XCTAssertEqual(review.completedTinyWins.map(\.label), ["Take 3 Slow Breaths"])
        XCTAssertEqual(review.ritualIntention, "")
        XCTAssertEqual(review.ritualLearning, "")
        XCTAssertEqual(review.activityDayCount, 5)
        XCTAssertEqual(review.progressLetter, "You showed up 5 days this week and used breathing once. That is real continuity: not perfection, just returning to what helps.")
        XCTAssertEqual(review.bestPatternRecap.patternText, "Work appeared most often this week, showing up 2 times.")
        XCTAssertEqual(review.bestPatternRecap.recommendedNextAction, "Choose one small response for work moments before the week begins.")
        XCTAssertEqual(review.whatHelpedMost, "Breathing Reset was logged this week. Notice whether it felt supportive, and keep what worked.")
        XCTAssertTrue(review.suggestedFocusForNextWeek.contains("work"))
        XCTAssertTrue(review.hasAnyData)
    }

    func testWeeklyReviewHandlesEmptyWeekGracefully() throws {
        let calendar = Self.utcCalendar()
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let selectedDate = Self.date(calendar, 2026, 6, 1, 9)

        let review = try WeeklyReviewService(calendar: calendar)
            .generateReview(forWeekContaining: selectedDate, from: context)

        XCTAssertFalse(review.hasAnyData)
        XCTAssertEqual(review.checkInCount, 0)
        XCTAssertNil(review.averageMood)
        XCTAssertNil(review.averageAnxietyStress)
        XCTAssertTrue(review.completedExercises.isEmpty)
        XCTAssertTrue(review.completedTinyWins.isEmpty)
        XCTAssertEqual(review.bestPatternRecap.patternText, "No clear weekly pattern has enough data yet.")
        XCTAssertEqual(review.bestPatternRecap.recommendedNextAction, "Start with two gentle check-ins next week so the review has something steady to compare.")
        XCTAssertEqual(review.suggestedFocusForNextWeek, "Try two gentle check-ins next week so your review has a steadier baseline.")
        XCTAssertFalse(review.lowDataMessages.isEmpty)
    }

    func testWeeklyReviewProgressLetterNamesShowingUpReturningAndBreathing() throws {
        let calendar = Self.utcCalendar()
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let monday = Self.date(calendar, 2026, 6, 1, 9)

        context.insert(MoodCheckIn(
            createdAt: monday,
            moodScore: 6
        ))
        context.insert(BreathingSession(
            createdAt: Self.date(calendar, 2026, 6, 2, 9),
            durationSeconds: 60
        ))
        context.insert(MoodCheckIn(
            createdAt: Self.date(calendar, 2026, 6, 4, 9),
            moodScore: 7
        ))
        context.insert(BreathingSession(
            createdAt: Self.date(calendar, 2026, 6, 5, 9),
            durationSeconds: 60
        ))
        try context.save()

        let review = try WeeklyReviewService(calendar: calendar)
            .generateReview(forWeekContaining: monday, from: context)

        XCTAssertEqual(review.activityDayCount, 4)
        XCTAssertEqual(
            review.progressLetter,
            "You showed up 4 days this week, returned after 1 missed day, and used breathing twice. That is real continuity: not perfection, just returning to what helps."
        )
    }

    func testWeeklyReviewBreathingOnlyWeekStillCountsAsProgress() throws {
        let calendar = Self.utcCalendar()
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let monday = Self.date(calendar, 2026, 6, 1, 9)

        context.insert(BreathingSession(
            createdAt: Self.date(calendar, 2026, 6, 2, 9),
            durationSeconds: 60
        ))
        try context.save()

        let review = try WeeklyReviewService(calendar: calendar)
            .generateReview(forWeekContaining: monday, from: context)

        XCTAssertTrue(review.hasAnyData)
        XCTAssertEqual(review.activityDayCount, 1)
        XCTAssertEqual(review.progressLetter, "You showed up 1 day this week and used breathing once. That is real continuity: not perfection, just returning to what helps.")
    }

    func testWeeklyReviewBestPatternUsesRepeatedSupportWhenNoTriggerRepeats() throws {
        let calendar = Self.utcCalendar()
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let selectedDate = Self.date(calendar, 2026, 6, 1, 9)

        context.insert(MoodEntry(
            createdAt: selectedDate,
            moodScore: 7,
            emotions: ["calm"],
            triggers: ["Work"]
        ))
        context.insert(ExerciseCompletion(
            createdAt: Self.date(calendar, 2026, 6, 2, 9),
            exerciseID: "grounding"
        ))
        context.insert(ExerciseCompletion(
            createdAt: Self.date(calendar, 2026, 6, 4, 9),
            exerciseID: "grounding"
        ))
        try context.save()

        let review = try WeeklyReviewService(calendar: calendar)
            .generateReview(forWeekContaining: selectedDate, from: context)

        XCTAssertEqual(review.bestPatternRecap.patternText, "Grounding was the support you returned to most often this week.")
        XCTAssertEqual(review.bestPatternRecap.recommendedNextAction, "Put grounding within easy reach once next week, especially on a demanding day.")
    }

    func testWeeklyReviewTieBreaksFrequenciesAlphabetically() throws {
        let calendar = Self.utcCalendar()
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let selectedDate = Self.date(calendar, 2026, 6, 1, 9)

        context.insert(MoodEntry(
            createdAt: selectedDate,
            moodScore: 5,
            emotions: ["calm"],
            triggers: ["Zeta", "Alpha"]
        ))
        try context.save()

        let review = try WeeklyReviewService(calendar: calendar)
            .generateReview(forWeekContaining: selectedDate, from: context)

        XCTAssertEqual(review.mostCommonTriggers.map(\.label), ["Alpha", "Zeta"])
    }

    func testWeeklyReviewSavesRitualForSelectedWeek() throws {
        let calendar = Self.utcCalendar()
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let selectedDate = Self.date(calendar, 2026, 6, 3, 9)
        let service = WeeklyReviewService(
            calendar: calendar,
            now: { Self.date(calendar, 2026, 6, 3, 12) }
        )

        try service.saveRitual(
            forWeekContaining: selectedDate,
            intention: "  Pause before answering  ",
            learning: "  Sleep changes the whole day  ",
            valueReflection: "  Carry courage into one conversation  ",
            in: context
        )

        let review = try service.generateReview(forWeekContaining: selectedDate, from: context)
        let nextWeek = try service.generateReview(
            forWeekContaining: Self.date(calendar, 2026, 6, 10, 9),
            from: context
        )

        XCTAssertEqual(review.ritualIntention, "Pause before answering")
        XCTAssertEqual(review.ritualLearning, "Sleep changes the whole day")
        XCTAssertEqual(review.ritualValueReflection, "Carry courage into one conversation")
        XCTAssertEqual(nextWeek.ritualIntention, "")
        XCTAssertEqual(nextWeek.ritualLearning, "")
        XCTAssertEqual(nextWeek.ritualValueReflection, "")
    }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private static func date(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }
}
