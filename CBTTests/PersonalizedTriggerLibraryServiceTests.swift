import XCTest
@testable import CBT

final class PersonalizedTriggerLibraryServiceTests: XCTestCase {
    func testAggregatesCommonTriggersAcrossWindows() throws {
        let now = Self.date(2026, 6, 2, 12)
        let events = [
            TriggerSourceEvent(
                date: Self.date(2026, 6, 2, 9),
                sourceKind: .checkIn,
                explicitTags: ["Work"],
                text: "deadline pressure",
                moodScore: 4,
                stressScore: 8
            ),
            TriggerSourceEvent(
                date: Self.date(2026, 5, 30, 9),
                sourceKind: .thoughtRecord,
                text: "My manager seemed brief in a meeting.",
                stressScore: 7
            ),
            TriggerSourceEvent(
                date: Self.date(2026, 5, 20, 9),
                sourceKind: .journal,
                text: "A work project is taking a lot of energy.",
                moodScore: 5,
                stressScore: 6
            ),
            TriggerSourceEvent(
                date: Self.date(2026, 4, 1, 9),
                sourceKind: .journal,
                text: "Work was stressful again.",
                moodScore: 6,
                stressScore: 5
            )
        ]

        let snapshot = PersonalizedTriggerLibraryService.snapshot(
            events: events,
            completedToolIDs: [],
            referenceDate: now,
            calendar: Self.calendar
        )

        let work = try XCTUnwrap(snapshot.summaries.first { $0.category == .work })
        XCTAssertEqual(work.sevenDayCount, 2)
        XCTAssertEqual(work.thirtyDayCount, 3)
        XCTAssertEqual(work.allTimeCount, 4)
        XCTAssertEqual(try XCTUnwrap(work.averageMood), 5, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(work.averageStress), 6.5, accuracy: 0.01)
        XCTAssertEqual(snapshot.commonTriggers(for: .sevenDays).first?.category, .work)
    }

    func testRecommendationMappingIncludesRelevantToolKindsAndCompletedTools() throws {
        let recommendations = PersonalizedTriggerLibraryService.recommendations(for: .sleep)

        XCTAssertTrue(recommendations.contains { $0.kind == .exercise && $0.destinationID == "exercise_016" })
        XCTAssertTrue(recommendations.contains { $0.kind == .exercise && $0.destinationID == "exercise_028" })
        XCTAssertTrue(recommendations.contains { $0.kind == .cbtPath && $0.destinationID == "skill_path_sleep_worry" })

        let snapshot = PersonalizedTriggerLibraryService.snapshot(
            events: [
                TriggerSourceEvent(
                    date: Self.date(2026, 6, 2, 21),
                    sourceKind: .journal,
                    text: "Sleep worry was loud tonight."
                )
            ],
            completedToolIDs: ["exercise_016"],
            referenceDate: Self.date(2026, 6, 2, 22),
            calendar: Self.calendar
        )

        let sleep = try XCTUnwrap(snapshot.summaries.first { $0.category == .sleep })
        XCTAssertEqual(sleep.completedTools.map(\.destinationID), ["exercise_016"])
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
