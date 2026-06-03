import XCTest
import SwiftData
@testable import CBT

@MainActor
final class FirstSevenDaysJourneyServiceTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testNewUserAutoStartsWithActiveDayOne() throws {
        let context = try makeContext()
        let now = date(2026, 6, 1, 9)

        let journey = FirstSevenDaysJourneyService.shared.ensureStartedForNewUserIfNeeded(in: context, now: now)
        let status = FirstSevenDaysJourneyService.shared.status(from: context, now: now, calendar: calendar)

        XCTAssertNotNil(journey)
        XCTAssertEqual(status.state, .active)
        XCTAssertEqual(status.currentStep?.day, 1)
        XCTAssertEqual(status.completedCount, 0)
    }

    func testExistingUserDoesNotAutoStart() throws {
        let context = try makeContext()
        context.insert(MoodCheckIn(createdAt: date(2026, 5, 30, 9)))
        try context.save()

        let journey = FirstSevenDaysJourneyService.shared.ensureStartedForNewUserIfNeeded(
            in: context,
            now: date(2026, 6, 1, 9)
        )

        XCTAssertNil(journey)
        XCTAssertEqual(
            FirstSevenDaysJourneyService.shared.status(from: context, now: date(2026, 6, 1, 9), calendar: calendar).state,
            .empty
        )
    }

    func testMissedDayKeepsSameStepWithGentleContinuation() throws {
        let context = try makeContext()
        let start = date(2026, 6, 1, 9)
        _ = FirstSevenDaysJourneyService.shared.optIn(in: context, now: start)

        let status = FirstSevenDaysJourneyService.shared.status(
            from: context,
            now: date(2026, 6, 3, 10),
            calendar: calendar
        )
        let recommendation = try XCTUnwrap(FirstSevenDaysJourneyService.shared.recommendation(for: status))

        XCTAssertEqual(status.state, .missedDay(2))
        XCTAssertEqual(status.currentStep?.day, 1)
        XCTAssertTrue(recommendation.reason.contains("No catching up needed"))
    }

    func testProgressesWithoutConsecutiveDaysWhenEvidenceAppears() throws {
        let context = try makeContext()
        let start = date(2026, 6, 1, 9)
        _ = FirstSevenDaysJourneyService.shared.optIn(in: context, now: start)

        context.insert(MoodCheckIn(createdAt: date(2026, 6, 4, 9)))
        try context.save()

        let dayTwo = FirstSevenDaysJourneyService.shared.status(
            from: context,
            now: date(2026, 6, 4, 10),
            calendar: calendar
        )

        XCTAssertEqual(dayTwo.state, .active)
        XCTAssertEqual(dayTwo.completedCount, 1)
        XCTAssertEqual(dayTwo.currentStep?.day, 2)
    }

    func testCompletesStepsInOrderFromRelatedActions() throws {
        let context = try makeContext()
        let start = date(2026, 6, 1, 9)
        _ = FirstSevenDaysJourneyService.shared.optIn(in: context, now: start)

        context.insert(MoodCheckIn(createdAt: date(2026, 6, 1, 10)))
        context.insert(ThoughtRecord(
            createdAt: date(2026, 6, 2, 10),
            automaticThought: "I am behind.",
            balancedThought: "I can do the next small step.",
            intensityBefore: 70,
            intensityAfter: 40
        ))
        context.insert(BreathingSession(createdAt: date(2026, 6, 4, 10), durationSeconds: 60))
        context.insert(PlannedActivity(
            title: "Short walk",
            scheduledDate: date(2026, 6, 5, 10),
            isCompleted: true,
            completedAt: date(2026, 6, 5, 11)
        ))
        let triggerEntry = MoodEntry(createdAt: date(2026, 6, 6, 10), moodScore: 5, emotions: [], triggers: ["Work"], notes: nil, intensity: 50)
        context.insert(triggerEntry)
        try context.save()

        var status = FirstSevenDaysJourneyService.shared.status(
            from: context,
            now: date(2026, 6, 6, 12),
            calendar: calendar
        )

        XCTAssertEqual(status.completedCount, 6)
        XCTAssertEqual(status.currentStep?.day, 7)

        FirstSevenDaysJourneyService.shared.mark(.weeklyReview, in: context, at: date(2026, 6, 7, 12))
        status = FirstSevenDaysJourneyService.shared.status(
            from: context,
            now: date(2026, 6, 7, 13),
            calendar: calendar
        )

        XCTAssertEqual(status.state, .completed)
        XCTAssertEqual(status.completedCount, 7)
        XCTAssertNil(status.currentStep)
    }

    private func makeContext() throws -> ModelContext {
        try ModelContext(SharedPersistence.makeInMemoryModelContainer())
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
