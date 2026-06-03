import SwiftData
import XCTest
@testable import CBT

@MainActor
final class LocalRetentionEventStoreTests: XCTestCase {
    func testAggregateSummarizesLocalRetentionEvents() {
        let calendar = Self.utcCalendar()
        let day0 = Self.date(calendar, 2026, 6, 1, 9)
        let events = [
            Self.event(.appOpened, at: day0, sessionID: "first"),
            Self.event(.onboardingStarted, at: day0.addingTimeInterval(60), sessionID: "first"),
            Self.event(.onboardingCompleted, at: day0.addingTimeInterval(120), sessionID: "first"),
            Self.event(.firstMoodCheckInCompleted, at: day0.addingTimeInterval(180), sessionID: "first"),
            Self.event(.firstDailyPlanItemCompleted, at: day0.addingTimeInterval(240), sessionID: "first"),
            Self.event(.dailyPlanCompleted, at: day0.addingTimeInterval(300), sessionID: "first"),
            Self.event(.reminderPromptShown, at: day0.addingTimeInterval(360), sessionID: "first"),
            Self.event(.notificationPermissionRequested, at: day0.addingTimeInterval(420), sessionID: "first"),
            Self.event(.notificationPermissionGranted, at: day0.addingTimeInterval(480), sessionID: "first"),
            Self.event(.weeklyReportViewed, at: day0.addingTimeInterval(540), sessionID: "first"),
            Self.event(.achievementUnlocked, at: day0.addingTimeInterval(600), sessionID: "first"),
            Self.event(.paywallShown, at: day0.addingTimeInterval(660), sessionID: "first"),
            Self.event(.purchaseCompleted, at: day0.addingTimeInterval(720), sessionID: "first"),
            Self.event(.appOpened, at: Self.date(calendar, 2026, 6, 2, 10), sessionID: "d1"),
            Self.event(.appOpened, at: Self.date(calendar, 2026, 6, 4, 10), sessionID: "d3"),
            Self.event(.appOpened, at: Self.date(calendar, 2026, 6, 8, 10), sessionID: "d7")
        ]

        let snapshot = LocalRetentionEventStore.aggregate(events: events, calendar: calendar)

        XCTAssertEqual(snapshot.eventCount, 16)
        XCTAssertEqual(snapshot.onboardingStarted, 1)
        XCTAssertEqual(snapshot.onboardingCompleted, 1)
        XCTAssertEqual(snapshot.onboardingSkipped, 0)
        XCTAssertTrue(snapshot.firstSessionActivated)
        XCTAssertTrue(snapshot.firstMoodCheckInCompleted)
        XCTAssertTrue(snapshot.returnedD1)
        XCTAssertTrue(snapshot.returnedD3)
        XCTAssertTrue(snapshot.returnedD7)
        XCTAssertEqual(snapshot.notificationPromptShown, 1)
        XCTAssertEqual(snapshot.notificationPermissionRequested, 1)
        XCTAssertEqual(snapshot.notificationPermissionGranted, 1)
        XCTAssertEqual(snapshot.notificationPermissionDenied, 0)
        XCTAssertEqual(snapshot.firstDailyPlanItemCompleted, 1)
        XCTAssertEqual(snapshot.dailyPlanCompleted, 1)
        XCTAssertEqual(snapshot.weeklyReportViewed, 1)
        XCTAssertEqual(snapshot.streakStarted, 1)
        XCTAssertEqual(snapshot.streakBroken, 2)
        XCTAssertEqual(snapshot.streakRecovered, 2)
        XCTAssertEqual(snapshot.achievementsUnlocked, 1)
        XCTAssertEqual(snapshot.paywallShown, 1)
        XCTAssertEqual(snapshot.purchaseCompleted, 1)
        XCTAssertEqual(snapshot.purchaseRestored, 0)
    }

    func testStoreSanitizesPrivateMetadataAndRecordsOncePerDay() throws {
        let calendar = Self.utcCalendar()
        let container = try ModelContainer(
            for: Schema([RetentionEvent.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let store = LocalRetentionEventStore(
            containerProvider: { container },
            calendar: calendar,
            now: { Self.date(calendar, 2026, 6, 1, 9) }
        )

        store.record(.achievementUnlocked, metadata: [
            "achievement": "First Step",
            "notes": "private note",
            "automaticThought": "private thought"
        ])
        store.recordOncePerDay(.dailyPlanCompleted)
        store.recordOncePerDay(.dailyPlanCompleted, timestamp: Self.date(calendar, 2026, 6, 1, 18))
        store.recordOncePerDay(.dailyPlanCompleted, timestamp: Self.date(calendar, 2026, 6, 2, 9))

        let events = try store.events()
        let achievement = try XCTUnwrap(events.first { $0.eventName == RetentionEventName.achievementUnlocked.rawValue })
        XCTAssertEqual(achievement.metadata["achievement"], "First Step")
        XCTAssertNil(achievement.metadata["notes"])
        XCTAssertNil(achievement.metadata["automaticThought"])

        let snapshot = try store.aggregationSnapshot()
        XCTAssertEqual(snapshot.dailyPlanCompleted, 2)

        let export = try store.exportData()
        let exportText = String(decoding: export, as: UTF8.self)
        XCTAssertFalse(exportText.contains("private note"))
        XCTAssertFalse(exportText.contains("private thought"))
    }

    private static func event(
        _ name: RetentionEventName,
        at date: Date,
        sessionID: String
    ) -> RetentionEvent {
        RetentionEvent(
            eventName: name.rawValue,
            timestamp: date,
            metadata: [:],
            sourceScreen: nil,
            appVersion: "test",
            sessionID: sessionID
        )
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
