import XCTest
@testable import CBT

final class CalendarMoodPatternCalculatorTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
    }

    func testMoodByDayOfWeekAveragesMoodScores() {
        let moods = [
            mood(2026, 6, 1, 9, moodScore: 4),
            mood(2026, 6, 1, 18, moodScore: 8),
            mood(2026, 6, 2, 9, moodScore: 7)
        ]

        let result = CalendarMoodPatternCalculator.moodByWeekday(
            moods: moods,
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.label), ["Mon", "Tue"])
        XCTAssertEqual(result[0].entryCount, 2)
        XCTAssertEqual(result[0].averageScore, 6.0, accuracy: 0.001)
        XCTAssertEqual(result[1].averageScore, 7.0, accuracy: 0.001)
    }

    func testStressByDayOfWeekUsesOnlyStressScores() {
        let moods = [
            mood(2026, 6, 1, 9, moodScore: 6, stressScore: 8),
            mood(2026, 6, 1, 18, moodScore: 7, stressScore: 4),
            mood(2026, 6, 2, 9, moodScore: 5),
            mood(2026, 6, 3, 9, moodScore: 6, stressScore: 3)
        ]

        let result = CalendarMoodPatternCalculator.stressByWeekday(
            moods: moods,
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.label), ["Mon", "Wed"])
        XCTAssertEqual(result[0].averageScore, 6.0, accuracy: 0.001)
        XCTAssertEqual(result[0].entryCount, 2)
        XCTAssertEqual(result[1].averageScore, 3.0, accuracy: 0.001)
    }

    func testMoodByTimeOfDayIgnoresDateOnlyMidnightEntries() throws {
        let moods = [
            mood(2026, 6, 1, 0, moodScore: 2),
            mood(2026, 6, 1, 8, moodScore: 6),
            mood(2026, 6, 1, 14, moodScore: 8),
            mood(2026, 6, 1, 19, moodScore: 4),
            mood(2026, 6, 1, 22, moodScore: 5)
        ]

        let result = CalendarMoodPatternCalculator.moodByTimeOfDay(
            moods: moods,
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.bucket), [.morning, .afternoon, .evening, .night])
        XCTAssertEqual(try XCTUnwrap(result.first { $0.bucket == .morning }?.averageMood), 6.0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(result.first { $0.bucket == .night }?.averageMood), 5.0, accuracy: 0.001)
    }

    func testTriggerFrequencyByWeekdayAndWeekendCountsUniqueTriggersPerEntry() {
        let moods = [
            mood(2026, 6, 1, 9, moodScore: 5, triggers: ["Work", "work"]),
            mood(2026, 6, 3, 9, moodScore: 5, triggers: ["Work"]),
            mood(2026, 6, 6, 9, moodScore: 5, triggers: ["Work", "Family"]),
            mood(2026, 6, 7, 9, moodScore: 5, triggers: ["Family"])
        ]

        let result = CalendarMoodPatternCalculator.triggerFrequencyByDayType(
            moods: moods,
            calendar: calendar
        )

        let work = result.first { $0.trigger == "Work" }
        let family = result.first { $0.trigger == "Family" }
        XCTAssertEqual(work?.weekdayCount, 2)
        XCTAssertEqual(work?.weekendCount, 1)
        XCTAssertEqual(family?.weekdayCount, 0)
        XCTAssertEqual(family?.weekendCount, 2)
    }

    func testSleepQualityVsMoodBucketsMoodAverages() {
        let moods = [
            mood(2026, 6, 1, 9, moodScore: 4, sleepQualityScore: 2),
            mood(2026, 6, 2, 9, moodScore: 6, sleepQualityScore: 6),
            mood(2026, 6, 3, 9, moodScore: 8, sleepQualityScore: 9),
            mood(2026, 6, 4, 9, moodScore: 10, sleepQualityScore: 10)
        ]

        let result = CalendarMoodPatternCalculator.sleepQualityVsMood(moods: moods)

        XCTAssertEqual(result.map(\.label), ["Low sleep", "Okay sleep", "Restful sleep"])
        XCTAssertEqual(result[0].averageMood, 4.0, accuracy: 0.001)
        XCTAssertEqual(result[1].averageMood, 6.0, accuracy: 0.001)
        XCTAssertEqual(result[2].averageMood, 9.0, accuracy: 0.001)
        XCTAssertEqual(result[2].entryCount, 2)
    }

    func testExerciseMoodAfterCompletionMatchesFirstMoodWithinTwentyFourHours() throws {
        let moods = [
            mood(2026, 6, 1, 8, moodScore: 4),
            mood(2026, 6, 1, 12, moodScore: 7),
            mood(2026, 6, 2, 15, moodScore: 9),
            mood(2026, 6, 4, 9, moodScore: 5)
        ]
        let exercises = [
            CalendarMoodPatternExerciseEvent(createdAt: date(2026, 6, 1, 10)),
            CalendarMoodPatternExerciseEvent(createdAt: date(2026, 6, 2, 12)),
            CalendarMoodPatternExerciseEvent(createdAt: date(2026, 6, 5, 12))
        ]

        let result = CalendarMoodPatternCalculator.exerciseMoodAfterCompletion(
            moods: moods,
            exerciseCompletions: exercises,
            calendar: calendar
        )

        XCTAssertEqual(result.completionCount, 3)
        XCTAssertEqual(result.matchedMoodCount, 2)
        XCTAssertEqual(try XCTUnwrap(result.averageMoodAfterCompletion), 8.0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(result.averageMoodWithoutRecentExercise), 4.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(result.deltaFromOtherMoodEntries), 3.5, accuracy: 0.001)
    }

    func testSummaryHandlesLowDataWithoutInventingPatterns() {
        let summary = CalendarMoodPatternCalculator.summary(
            moods: [],
            exerciseCompletions: [],
            calendar: calendar
        )

        XCTAssertTrue(summary.moodByWeekday.isEmpty)
        XCTAssertTrue(summary.stressByWeekday.isEmpty)
        XCTAssertTrue(summary.moodByTimeOfDay.isEmpty)
        XCTAssertTrue(summary.triggerFrequencyByDayType.isEmpty)
        XCTAssertTrue(summary.sleepQualityVsMood.isEmpty)
        XCTAssertNil(summary.exerciseMoodAfterCompletion.averageMoodAfterCompletion)
    }

    private func mood(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        moodScore: Int,
        stressScore: Int? = nil,
        sleepQualityScore: Int? = nil,
        triggers: [String] = []
    ) -> CalendarMoodPatternMoodEvent {
        CalendarMoodPatternMoodEvent(
            createdAt: date(year, month, day, hour),
            moodScore: moodScore,
            stressScore: stressScore,
            sleepQualityScore: sleepQualityScore,
            triggers: triggers
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }
}
