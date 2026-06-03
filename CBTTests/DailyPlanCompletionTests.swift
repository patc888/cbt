import SwiftData
import XCTest
@testable import CBT

@MainActor
final class DailyPlanCompletionTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testCreatesCompletion() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = container.mainContext
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 9)))

        let completion = try DailyPlanCompletionService.shared.complete(
            itemType: .breathingReset,
            title: "Breathing reset",
            on: date,
            sourceScreen: "Home",
            durationSeconds: 60,
            in: context,
            calendar: calendar
        )

        XCTAssertEqual(completion.type, .breathingReset)
        XCTAssertEqual(completion.title, "Breathing reset")
        XCTAssertEqual(completion.durationSeconds, 60)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailyPlanCompletion>()).count, 1)
    }

    func testAvoidsDuplicateCompletionForSameDayItem() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = container.mainContext
        let morning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 9)))
        let afternoon = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 15)))

        let first = try DailyPlanCompletionService.shared.complete(
            itemType: .tipOfTheDay,
            title: "Tip of the day",
            on: morning,
            in: context,
            calendar: calendar
        )
        let second = try DailyPlanCompletionService.shared.complete(
            itemType: .tipOfTheDay,
            title: "Tip of the day",
            on: afternoon,
            in: context,
            calendar: calendar
        )

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailyPlanCompletion>()).count, 1)
    }

    func testFetchesTodayCompletions() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = container.mainContext
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 9)))
        let yesterday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9)))

        try DailyPlanCompletionService.shared.complete(itemType: .breathingReset, title: "Breathing", on: today, in: context, calendar: calendar)
        try DailyPlanCompletionService.shared.complete(itemType: .tipOfTheDay, title: "Tip", on: today, in: context, calendar: calendar)
        try DailyPlanCompletionService.shared.complete(itemType: .thoughtRecord, title: "Thought", on: yesterday, in: context, calendar: calendar)

        let completions = try DailyPlanCompletionService.shared.completionsForToday(
            in: context,
            now: today,
            calendar: calendar
        )

        XCTAssertEqual(completions.count, 2)
        XCTAssertEqual(Set(completions.map(\.type)), [.breathingReset, .tipOfTheDay])
    }

    func testPersistsAcrossModelContainerRestart() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DailyPlanCompletionTests-\(UUID().uuidString)")
            .appendingPathComponent("default.store")
        var container: ModelContainer? = try SharedPersistence.makeModelContainer(storeURL: storeURL, cloudKitEnabled: false)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 9)))

        try DailyPlanCompletionService.shared.complete(
            itemType: .breathingReset,
            title: "Breathing reset",
            on: date,
            in: try XCTUnwrap(container).mainContext,
            calendar: calendar
        )
        container = nil

        let reopened = try SharedPersistence.makeModelContainer(storeURL: storeURL, cloudKitEnabled: false)
        let completions = try DailyPlanCompletionService.shared.completionsForToday(
            in: reopened.mainContext,
            now: date,
            calendar: calendar
        )

        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.type, .breathingReset)
    }

    func testRecommendationsReadDailyPlanCompletions() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = container.mainContext
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 9)))

        try DailyPlanCompletionService.shared.complete(itemType: .moodCheckIn, title: "Mood check-in", on: date, in: context, calendar: calendar)
        try DailyPlanCompletionService.shared.complete(itemType: .breathingReset, title: "Breathing reset", on: date, in: context, calendar: calendar)

        let recommendations = DailyRecommendationService.shared.recommendations(
            for: date,
            in: context,
            now: date,
            calendar: calendar
        )

        XCTAssertFalse(recommendations.contains { $0.type == .moodCheckIn && !$0.isCompletedToday })
        XCTAssertFalse(recommendations.contains { ($0.type == .breathingReset || $0.type == .sleepWindDown) && !$0.isCompletedToday })
    }
}
