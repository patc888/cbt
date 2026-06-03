import XCTest
import SwiftData
import PDFKit
import SwiftUI
@testable import CBT

final class CBTTests: XCTestCase {
    private func isolatedDefaults(named name: String = #function) throws -> UserDefaults {
        let suiteName = "com.melichan.CBTTests.\(name).\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @MainActor
    func testNewUserSeesFirstSessionWinFlow() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let defaults = try isolatedDefaults()

        let shouldPresent = FirstSessionWinService.shouldPresentAfterExistingUserCheck(
            modelContext: context,
            defaults: defaults,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertTrue(shouldPresent)
        XCTAssertFalse(defaults.bool(forKey: FirstSessionWinService.completedKey))
    }

    @MainActor
    func testExistingUserDoesNotSeeFirstSessionWinFlow() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let defaults = try isolatedDefaults()
        context.insert(MoodCheckIn(createdAt: Date(timeIntervalSince1970: 1_800_000_000), moodScore: 7))
        try context.save()

        let shouldPresent = FirstSessionWinService.shouldPresentAfterExistingUserCheck(
            modelContext: context,
            defaults: defaults,
            now: Date(timeIntervalSince1970: 1_800_000_100)
        )

        XCTAssertFalse(shouldPresent)
        XCTAssertTrue(defaults.bool(forKey: FirstSessionWinService.completedKey))
        XCTAssertEqual(FirstSessionWinService.completedKind(defaults: defaults), .existingActivity)
    }

    @MainActor
    func testCompletedFirstSessionWinPersists() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let defaults = try isolatedDefaults()
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        try FirstSessionWinService.complete(
            kind: .breathing,
            modelContext: context,
            defaults: defaults,
            now: now
        )

        XCTAssertTrue(defaults.bool(forKey: FirstSessionWinService.completedKey))
        XCTAssertEqual(FirstSessionWinService.completedKind(defaults: defaults), .breathing)
        XCTAssertEqual(defaults.double(forKey: FirstSessionWinService.completedAtKey), now.timeIntervalSince1970)
        XCTAssertEqual(LocalEventLog.read(defaults: defaults).last?.name, "first_session_win_completed")

        let count = try context.fetchCount(FetchDescriptor<BreathingSession>())
        XCTAssertEqual(count, 1)
    }

    @MainActor
    func testCompletedFirstSessionWinAppearsOnHome() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let defaults = try isolatedDefaults()
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        try FirstSessionWinService.complete(
            kind: .todaysPlan,
            modelContext: context,
            planTitle: "Take a short walk",
            defaults: defaults,
            now: now
        )

        let snapshot = LaunchSafeFetch.homeDashboardSnapshot(
            selectedDate: now,
            visibleDates: [now],
            from: context
        )

        XCTAssertEqual(snapshot.completionSnapshot.state(for: .activityPlanner), .completed)
        XCTAssertTrue(snapshot.activeDates.contains(Calendar.current.startOfDay(for: now)))
    }

    func testContinueResolverPrefersRecentUnfinishedItemsOverStaleHigherPriorityItems() {
        let resolver = ContinueItemResolver()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let stale = ContinueItem(
            title: "Old Course",
            subtitle: "A high-priority older item.",
            destination: .course(courseID: "old"),
            updatedAt: now.addingTimeInterval(-(10 * 24 * 60 * 60)),
            priority: 100
        )
        let recent = ContinueItem(
            title: "Recent Activity",
            subtitle: "A lower-priority recent item.",
            destination: .activityPlanner,
            updatedAt: now.addingTimeInterval(-(2 * 24 * 60 * 60)),
            priority: 60
        )

        let item = resolver.bestItem(from: [stale, recent], fallbackRecommendations: [], now: now)

        XCTAssertEqual(item, recent)
    }

    func testContinueResolverDeduplicatesDestinationsUsingBestCandidate() {
        let resolver = ContinueItemResolver()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let lowerPriority = ContinueItem(
            title: "Activity",
            subtitle: "Older copy.",
            destination: .activityPlanner,
            updatedAt: now,
            priority: 50
        )
        let higherPriority = ContinueItem(
            title: "Activity",
            subtitle: "Better copy.",
            destination: .activityPlanner,
            updatedAt: now.addingTimeInterval(-60),
            priority: 80
        )

        let deduped = resolver.dedupe([lowerPriority, higherPriority])

        XCTAssertEqual(deduped.count, 1)
        XCTAssertEqual(deduped.first, higherPriority)
    }

    func testContinueResolverFallsBackToHighestPriorityIncompleteDailyPlanItem() {
        let resolver = ContinueItemResolver()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let completed = DailyRecommendation(
            id: "completed",
            type: .moodCheckIn,
            title: "Mood Check-In",
            subtitle: "Already done.",
            reason: "Done today.",
            destination: .moodCheckIn,
            priority: 100,
            estimatedDurationMinutes: 1,
            isCompletedToday: true,
            mode: .full
        )
        let incomplete = DailyRecommendation(
            id: "incomplete",
            type: .breathingReset,
            title: "Breathing Reset",
            subtitle: "Take one steady minute.",
            reason: "A helpful next step.",
            destination: .breathingReset(durationSeconds: 60),
            priority: 70,
            estimatedDurationMinutes: 1,
            isCompletedToday: false,
            mode: .quick
        )

        let item = resolver.bestItem(
            from: [],
            fallbackRecommendations: [completed, incomplete],
            now: now
        )

        XCTAssertEqual(item?.title, incomplete.title)
        XCTAssertEqual(item?.destination, .dailyPlan(incomplete.destination))
        XCTAssertEqual(item?.updatedAt, now)
    }

    func testAppConfigurationUsesExpectedCloudContainer() {
        XCTAssertEqual(AppConfiguration.cloudKitContainerIdentifier, "iCloud.com.melichan.CBT")
        XCTAssertEqual(AppConfiguration.appGroupIdentifier, "group.com.melichan.CBT")
    }

    func testCurrentMigrationSchemaCoversAllPersistedModels() {
        let currentModels = Set(CBTVersionedSchemaV12.models.map { String(reflecting: $0) })
        let latestModels = Set(CBTVersionedSchemaV13.models.map { String(reflecting: $0) })
        let expectedModels = Set([
            UserSettings.self,
            MoodEntry.self,
            ThoughtRecord.self,
            ExerciseCompletion.self,
            JournalEntry.self,
            PlannedActivity.self,
            AssessmentLog.self,
            PersonalityAssessmentLog.self,
            ProgramProgress.self,
            ChallengeSession.self,
            FlexibleJournalEntry.self,
            MoodCheckIn.self,
            BreathingSession.self,
            SafetyPlan.self,
            LibraryItem.self,
            Course.self,
            Achievement.self,
            AudioContent.self,
            TinyWinCompletion.self,
            WeeklyRitualEntry.self,
            PersonalValue.self,
            ValueActionCompletion.self,
            DailyPlanCompletion.self,
            FirstSevenDaysJourney.self,
            HelpfulnessFeedback.self
        ].map { String(reflecting: $0) })
        let v12Models = expectedModels.subtracting([String(reflecting: HelpfulnessFeedback.self)])

        XCTAssertEqual(currentModels, v12Models)
        XCTAssertEqual(latestModels, expectedModels)
        XCTAssertEqual(CBTModelMigrationPlan.schemas.count, 13)
        XCTAssertEqual(CBTModelMigrationPlan.stages.count, 12)
    }

    @MainActor
    func testValueSelectionAddsDefaultAndCustomValues() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let courage = try XCTUnwrap(ValuesService.defaultValues.first { $0.id == "courage" })

        let selected = try ValuesService.selectDefaultValue(courage, in: context)
        let custom = try XCTUnwrap(ValuesService.addCustomValue(named: "  Playfulness  ", in: context))
        let duplicate = try ValuesService.selectDefaultValue(courage, in: context)
        let values = try context.fetch(FetchDescriptor<PersonalValue>())

        XCTAssertEqual(selected.id, duplicate.id)
        XCTAssertEqual(custom.name, "Playfulness")
        XCTAssertEqual(custom.valueID, "playfulness")
        XCTAssertEqual(values.filter { !$0.isDeleted }.count, 2)
    }

    @MainActor
    func testValueActionCompletionTracksOneCompletionPerValuePerDayAndCountsAsActivity() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let day = Self.date(calendar, 2026, 6, 1, 9)
        let sameDayLater = Self.date(calendar, 2026, 6, 1, 21)
        let connection = try XCTUnwrap(ValuesService.defaultValues.first { $0.id == "connection" })
        let selected = try ValuesService.selectDefaultValue(connection, in: context, createdAt: day)
        let action = try XCTUnwrap(ValuesService.action(for: day, selectedValues: [selected], calendar: calendar))

        let firstCompletion = try ValuesService.complete(action: action, on: day, in: context, calendar: calendar)
        let secondCompletion = try ValuesService.complete(action: action, on: sameDayLater, in: context, calendar: calendar)
        let completions = try context.fetch(FetchDescriptor<ValueActionCompletion>())

        XCTAssertEqual(firstCompletion.id, secondCompletion.id)
        XCTAssertEqual(completions.count, 1)
        XCTAssertTrue(ValuesService.isCompleted(action: action, on: sameDayLater, completions: completions, calendar: calendar))
        XCTAssertEqual(ValuesService.weeklySummary(completions: completions, now: day, calendar: calendar).first?.valueName, "Connection")

        let snapshot = LaunchSafeFetch.homeDashboardSnapshot(
            selectedDate: day,
            visibleDates: [day],
            from: context
        )
        XCTAssertEqual(snapshot.completionSnapshot.state(for: .valueAction), .completed)
        XCTAssertTrue(snapshot.activeDates.contains(calendar.startOfDay(for: day)))
    }

    func testTinyWinDailySelectionIsStableAndRotatesByDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let wins = [
            TinyWin(id: "one", title: "One", prompt: "One", actionTitle: "Done", durationSeconds: 30, systemImage: "1.circle"),
            TinyWin(id: "two", title: "Two", prompt: "Two", actionTitle: "Done", durationSeconds: 30, systemImage: "2.circle"),
            TinyWin(id: "three", title: "Three", prompt: "Three", actionTitle: "Done", durationSeconds: 30, systemImage: "3.circle")
        ]
        let day = Self.date(calendar, 2026, 6, 1, 9)
        let sameDayLater = Self.date(calendar, 2026, 6, 1, 21)
        let nextDay = Self.date(calendar, 2026, 6, 2, 9)

        let selected = TinyWinService.win(for: day, calendar: calendar, wins: wins)

        XCTAssertEqual(TinyWinService.win(for: sameDayLater, calendar: calendar, wins: wins), selected)
        XCTAssertNotEqual(TinyWinService.win(for: nextDay, calendar: calendar, wins: wins), selected)
        XCTAssertNil(TinyWinService.win(for: day, calendar: calendar, wins: []))
    }

    func testPlannedActivityNormalizesSupportedValues() {
        XCTAssertEqual(ValuesService.defaultValues.map(\.id), [
            "connection",
            "health",
            "creativity",
            "rest",
            "courage"
        ])
        XCTAssertEqual(PlannedActivity.normalizedSupportedValue(" courage "), "Courage")
        XCTAssertNil(PlannedActivity.normalizedSupportedValue("novelty"))
        XCTAssertNil(PlannedActivity.normalizedSupportedValue(" "))

        let activity = PlannedActivity(title: "Ask for help", supportedValue: " connection ")

        XCTAssertEqual(activity.supportedValue, "Connection")
    }

    @MainActor
    func testTinyWinCompletionTracksOneCompletionPerDayAndCountsAsActivity() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let day = Self.date(calendar, 2026, 6, 1, 9)
        let sameDayLater = Self.date(calendar, 2026, 6, 1, 21)
        let win = try XCTUnwrap(TinyWinService.win(for: day, calendar: calendar))

        let firstCompletion = try TinyWinService.complete(win: win, on: day, in: context, calendar: calendar)
        let secondCompletion = try TinyWinService.complete(win: win, on: sameDayLater, in: context, calendar: calendar)
        let completions = try context.fetch(FetchDescriptor<TinyWinCompletion>())

        XCTAssertEqual(firstCompletion.id, secondCompletion.id)
        XCTAssertEqual(completions.count, 1)
        XCTAssertTrue(TinyWinService.isCompleted(on: sameDayLater, completions: completions, calendar: calendar))
        XCTAssertEqual(TinyWinService.state(for: day, completions: completions, now: sameDayLater, calendar: calendar), .completed(win))

        let snapshot = LaunchSafeFetch.homeDashboardSnapshot(
            selectedDate: day,
            visibleDates: [day],
            from: context
        )
        XCTAssertEqual(snapshot.completionSnapshot.state(for: .tinyWin), .completed)
        XCTAssertTrue(snapshot.activeDates.contains(calendar.startOfDay(for: day)))
    }

    func testTinyWinStateReportsEmptyAvailableAndMissed() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = Self.date(calendar, 2026, 6, 2, 9)
        let yesterday = Self.date(calendar, 2026, 6, 1, 9)
        let win = TinyWin(id: "one", title: "One", prompt: "One", actionTitle: "Done", durationSeconds: 30, systemImage: "1.circle")

        XCTAssertEqual(TinyWinService.state(for: today, completions: [], now: today, calendar: calendar, wins: []), .empty)
        XCTAssertEqual(TinyWinService.state(for: today, completions: [], now: today, calendar: calendar, wins: [win]), .available(win))
        XCTAssertEqual(TinyWinService.state(for: yesterday, completions: [], now: today, calendar: calendar, wins: [win]), .missed(win))
    }

    func testRegisteredDefaultsShowStreakInToolbarOnForFirstLaunch() throws {
        let suiteName = "CBTTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AppConfiguration.registerUserDefaults(defaults)

        XCTAssertTrue(defaults.bool(forKey: AppConfiguration.showStreakInToolbarKey))
    }

    func testRegisteredDefaultsPreserveSavedStreakToolbarPreference() throws {
        let suiteName = "CBTTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: AppConfiguration.showStreakInToolbarKey)

        AppConfiguration.registerUserDefaults(defaults)

        XCTAssertFalse(defaults.bool(forKey: AppConfiguration.showStreakInToolbarKey))
    }

    func testStreakReengagementDailyCheckRunsOnlyOncePerDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Self.date(calendar, 2026, 6, 1, 12)
        let sameDay = Self.date(calendar, 2026, 6, 1, 8)
        let previousDay = Self.date(calendar, 2026, 5, 31, 23)

        XCTAssertTrue(StreakReengagementNotificationService.shouldRunDailyCheck(lastCheck: nil, now: now, calendar: calendar))
        XCTAssertFalse(StreakReengagementNotificationService.shouldRunDailyCheck(lastCheck: sameDay, now: now, calendar: calendar))
        XCTAssertTrue(StreakReengagementNotificationService.shouldRunDailyCheck(lastCheck: previousDay, now: now, calendar: calendar))
    }

    func testStreakReengagementThresholdAndNotificationBodies() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        XCTAssertFalse(StreakReengagementNotificationService.hasBeenAwayFor48Hours(
            lastLogin: now.addingTimeInterval(-(48 * 60 * 60) + 1),
            now: now
        ))
        XCTAssertTrue(StreakReengagementNotificationService.hasBeenAwayFor48Hours(
            lastLogin: now.addingTimeInterval(-(48 * 60 * 60)),
            now: now
        ))
        XCTAssertEqual(
            StreakReengagementNotificationService.nextReengagementDate(from: now),
            now.addingTimeInterval(48 * 60 * 60)
        )
        XCTAssertEqual(
            StreakReengagementNotificationService.notificationBody(streakCount: 4),
            "Your 4-day streak is waiting for you! Take 30 seconds to log your mood."
        )
        XCTAssertEqual(
            StreakReengagementNotificationService.notificationBody(streakCount: 0),
            "Checking in takes only 30 seconds. How are you doing today?"
        )
    }

    func testDailyMoodCheckInNotificationBodyUsesTomorrowAnchorWhenSaved() {
        let defaults = UserDefaults(suiteName: "testDailyMoodCheckInNotificationBodyUsesTomorrowAnchorWhenSaved")!
        defaults.removePersistentDomain(forName: "testDailyMoodCheckInNotificationBodyUsesTomorrowAnchorWhenSaved")

        XCTAssertEqual(
            PersonalizedReminderType.dailyMoodCheckInNotificationBody(defaults: defaults),
            "Take a moment to name your mood, intensity, and context. A quick check-in can make patterns easier to see over time."
        )

        defaults.set(TomorrowAnchor.breathing.rawValue, forKey: TomorrowAnchor.defaultsKey)

        XCTAssertEqual(
            PersonalizedReminderType.dailyMoodCheckInNotificationBody(defaults: defaults),
            "Your anchor today is reset: Start with one minute of breathing."
        )
    }

    func testSmartReminderTimingSuggestsUsualMoodCheckInTime() {
        let samples = [
            (21 * 60) + 35,
            (21 * 60) + 40,
            (21 * 60) + 42,
            (21 * 60) + 45,
            (21 * 60) + 39
        ]

        let suggestion = SmartReminderTiming.suggestion(
            samples: samples,
            currentMinuteOfDay: 9 * 60
        )

        XCTAssertEqual(suggestion?.hour, 21)
        XCTAssertEqual(suggestion?.minute, 40)
        XCTAssertEqual(suggestion?.sampleCount, 5)
    }

    func testSmartReminderTimingWaitsForEnoughConsistentHistory() {
        XCTAssertNil(SmartReminderTiming.suggestion(
            samples: [(21 * 60) + 40, (21 * 60) + 45, (21 * 60) + 42],
            currentMinuteOfDay: 9 * 60
        ))
        XCTAssertNil(SmartReminderTiming.suggestion(
            samples: [7 * 60, 12 * 60, 18 * 60, 23 * 60],
            currentMinuteOfDay: 9 * 60
        ))
    }

    @MainActor
    func testReminderOptInPromptEligibilityRequiresValueMomentAndAvailablePermission() {
        let defaults = makeReminderOptInDefaults(named: #function)
        let service = ReminderOptInService(defaults: defaults)

        XCTAssertFalse(service.isEligible(
            for: .firstMoodCheckIn,
            hasReachedMoment: false,
            notificationStatus: .notDetermined
        ))
        XCTAssertTrue(service.isEligible(
            for: .firstMoodCheckIn,
            hasReachedMoment: true,
            notificationStatus: .notDetermined
        ))
        XCTAssertFalse(service.isEligible(
            for: .firstMoodCheckIn,
            hasReachedMoment: true,
            notificationStatus: .denied
        ))

        defaults.set(true, forKey: PersonalizedReminderType.dailyMoodCheckIn.enabledDefaultsKey)
        XCTAssertFalse(service.isEligible(
            for: .firstMoodCheckIn,
            hasReachedMoment: true,
            notificationStatus: .authorized
        ))
    }

    @MainActor
    func testReminderOptInPromptDismissedStopsFuturePrompts() {
        let defaults = makeReminderOptInDefaults(named: #function)
        let service = ReminderOptInService(defaults: defaults)

        service.dismiss(.firstPlannedActivityCompletion)

        XCTAssertEqual(service.state(for: .firstPlannedActivityCompletion), .dismissed)
        XCTAssertFalse(service.isEligible(
            for: .firstPlannedActivityCompletion,
            hasReachedMoment: true,
            notificationStatus: .authorized
        ))
    }

    @MainActor
    func testReminderOptInPromptAcceptedStoresStateAndEnablesReminder() async {
        let defaults = makeReminderOptInDefaults(named: #function)
        var scheduledTypes: [PersonalizedReminderType] = []
        let service = ReminderOptInService(
            defaults: defaults,
            notificationStatusProvider: { .authorized },
            notificationPermissionRequester: { .authorized },
            reminderScheduler: { type in
                scheduledTypes.append(type)
                return true
            }
        )

        let didAccept = await service.accept(.firstMoodCheckIn)

        XCTAssertTrue(didAccept)
        XCTAssertEqual(service.state(for: .firstMoodCheckIn), .accepted)
        XCTAssertTrue(defaults.bool(forKey: PersonalizedReminderType.dailyMoodCheckIn.enabledDefaultsKey))
        XCTAssertEqual(scheduledTypes, [.dailyMoodCheckIn])
    }

    @MainActor
    func testReminderOptInPermissionDeniedStoresDeniedStateWithoutScheduling() async {
        let defaults = makeReminderOptInDefaults(named: #function)
        var didSchedule = false
        let service = ReminderOptInService(
            defaults: defaults,
            notificationStatusProvider: { .notDetermined },
            notificationPermissionRequester: { .denied },
            reminderScheduler: { _ in
                didSchedule = true
                return true
            }
        )

        let didAccept = await service.accept(.firstWeeklyInsightViewed)

        XCTAssertFalse(didAccept)
        XCTAssertEqual(service.state(for: .firstWeeklyInsightViewed), .permissionDenied)
        XCTAssertFalse(defaults.bool(forKey: PersonalizedReminderType.weeklyReport.enabledDefaultsKey))
        XCTAssertFalse(didSchedule)
    }

    @MainActor
    func testReminderOptInSchedulesTargetReminderAfterOptIn() async {
        let defaults = makeReminderOptInDefaults(named: #function)
        var scheduledTypes: [PersonalizedReminderType] = []
        let service = ReminderOptInService(
            defaults: defaults,
            notificationStatusProvider: { .authorized },
            notificationPermissionRequester: { .authorized },
            reminderScheduler: { type in
                scheduledTypes.append(type)
                return true
            }
        )

        _ = await service.accept(.firstPlannedActivityCompletion)

        XCTAssertEqual(scheduledTypes, [.plannedActivity])
        XCTAssertTrue(defaults.bool(forKey: PersonalizedReminderType.plannedActivity.enabledDefaultsKey))
    }

    func testStreakReengagementCurrentStreakMatchesMoodCheckInDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.startOfDay(for: Self.date(calendar, 2026, 6, 1, 12))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let staleDay = calendar.date(byAdding: .day, value: -5, to: today)!

        XCTAssertEqual(
            StreakReengagementNotificationService.currentStreak(
                from: [today, yesterday, twoDaysAgo, staleDay],
                calendar: calendar,
                today: today
            ),
            3
        )
        XCTAssertEqual(
            StreakReengagementNotificationService.currentStreak(
                from: [staleDay],
                calendar: calendar,
                today: today
            ),
            0
        )
    }

    func testBadDayModeTriggersAfterTwoMissedDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.startOfDay(for: Self.date(calendar, 2026, 6, 1, 12))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        XCTAssertFalse(BadDayModeService.context(
            activeDays: [yesterday],
            latestMoodScore: nil,
            today: today,
            calendar: calendar
        ).shouldShow)

        let context = BadDayModeService.context(
            activeDays: [threeDaysAgo],
            latestMoodScore: nil,
            today: today,
            calendar: calendar
        )

        XCTAssertTrue(context.shouldShow)
        XCTAssertEqual(context.trigger, .missedDays(2))
        XCTAssertEqual(context.missedDays, 2)
    }

    func testBadDayModeTriggersForVeryLowMoodLoggedTodayOnly() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.startOfDay(for: Self.date(calendar, 2026, 6, 1, 12))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let todayContext = BadDayModeService.context(
            activeDays: [today],
            latestMoodScore: 2,
            latestMoodDate: today.addingTimeInterval(60 * 60),
            today: today,
            calendar: calendar
        )

        XCTAssertTrue(todayContext.shouldShow)
        XCTAssertEqual(todayContext.trigger, .veryLowMood(2))

        let staleContext = BadDayModeService.context(
            activeDays: [today],
            latestMoodScore: 2,
            latestMoodDate: yesterday,
            today: today,
            calendar: calendar
        )

        XCTAssertFalse(staleContext.shouldShow)
    }

    func testBadDayModeManualTriggerAndRestartRuleDoNotBackfillStreakDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.startOfDay(for: Self.date(calendar, 2026, 6, 1, 12))

        let context = BadDayModeService.context(
            activeDays: [],
            latestMoodScore: nil,
            today: today,
            calendar: calendar,
            manual: true
        )

        XCTAssertTrue(context.shouldShow)
        XCTAssertEqual(context.trigger, .manual)
        XCTAssertTrue(BadDayModeService.allowsRestartToday(hasActivityToday: false))
        XCTAssertFalse(BadDayModeService.allowsRestartToday(hasActivityToday: true))
        XCTAssertEqual(BadDayModeService.restartTodayMoodScore, 5)
    }

    func testThemeModeMapsToExpectedColorScheme() {
        XCTAssertNil(AppTheme.system.colorScheme)
        XCTAssertEqual(AppTheme.light.colorScheme, .light)
        XCTAssertEqual(AppTheme.dark.colorScheme, .dark)
    }

    func testPersonalGrowthCalculatorAggregatesConsistencyMilestonesAndEmotionTags() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceDate = Self.date(calendar, 2026, 6, 1, 12)

        let events = try (0..<20).map { index -> PersonalGrowthActivityEvent in
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: -index, to: referenceDate))
            let emotions: [String]
            if index < 8 {
                emotions = ["calm"]
            } else if index < 13 {
                emotions = ["anxious"]
            } else if index < 16 {
                emotions = ["hopeful"]
            } else {
                emotions = ["tired"]
            }
            return PersonalGrowthActivityEvent(date: date, emotionTags: emotions)
        }

        let snapshot = PersonalGrowthCalculator.snapshot(
            events: events,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.entriesLastThreeMonths, 20)
        XCTAssertEqual(snapshot.consistencyScore, 29)
        XCTAssertEqual(snapshot.milestones.filter(\.isAchieved).map(\.badgeID), ["growth.entries.5", "growth.entries.20"])
        XCTAssertEqual(UserMilestoneSchema.badgeID(forExactEntryCount: 50), "growth.entries.50")
        XCTAssertEqual(snapshot.topEmotionTags.map(\.name), ["Calm", "Anxious", "Tired"])
        XCTAssertEqual(snapshot.topEmotionTags.map(\.count), [8, 5, 4])
    }

    func testRetentionInsightsCalculateProgressCardsFromLocalEvents() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let referenceDate = Self.date(calendar, 2026, 6, 3, 12)

        let snapshot = RetentionInsightsService.snapshot(
            moods: [
                RetentionMoodEvent(createdAt: Self.date(calendar, 2026, 6, 1, 9), moodScore: 5, triggers: ["Work"]),
                RetentionMoodEvent(createdAt: Self.date(calendar, 2026, 6, 2, 9), moodScore: 6, triggers: ["Work", "Sleep"]),
                RetentionMoodEvent(createdAt: Self.date(calendar, 2026, 5, 28, 9), moodScore: 4, triggers: ["Sleep"])
            ],
            checkIns: [
                RetentionDatedEvent(createdAt: Self.date(calendar, 2026, 6, 3, 8))
            ],
            thoughts: [
                RetentionThoughtEvent(createdAt: Self.date(calendar, 2026, 6, 1, 18), intensityBefore: 70, intensityAfter: 40),
                RetentionThoughtEvent(createdAt: Self.date(calendar, 2026, 6, 2, 18), intensityBefore: 60, intensityAfter: 30)
            ],
            exerciseCompletions: [
                RetentionDatedEvent(createdAt: Self.date(calendar, 2026, 6, 1, 13)),
                RetentionDatedEvent(createdAt: Self.date(calendar, 2026, 6, 3, 13))
            ],
            journalEntries: [
                RetentionDatedEvent(createdAt: Self.date(calendar, 2026, 5, 28, 20))
            ],
            flexibleJournalEntries: [],
            breathingSessions: [
                RetentionDatedEvent(createdAt: Self.date(calendar, 2026, 6, 2, 10)),
                RetentionDatedEvent(createdAt: Self.date(calendar, 2026, 6, 3, 10))
            ],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertNil(snapshot.emptyStateMessage)
        XCTAssertEqual(snapshot.cards.map(\.id), [
            "weekly-check-ins",
            "common-trigger",
            "breathing-days",
            "thought-record-intensity",
            "monthly-exercises",
            "returned-after-missed-day"
        ])
        XCTAssertEqual(snapshot.cards.first { $0.id == "weekly-check-ins" }?.message, "You checked in 3 days this week.")
        XCTAssertEqual(snapshot.cards.first { $0.id == "common-trigger" }?.message, "Your most common trigger was Work.")
        XCTAssertEqual(snapshot.cards.first { $0.id == "breathing-days" }?.message, "Breathing was part of 2 days this week.")
        XCTAssertEqual(snapshot.cards.first { $0.id == "thought-record-intensity" }?.detail, "Average before 65, average after 35.")
        XCTAssertEqual(snapshot.cards.first { $0.id == "monthly-exercises" }?.message, "You completed 2 exercises this month.")
        XCTAssertEqual(snapshot.cards.first { $0.id == "returned-after-missed-day" }?.message, "You returned after a missed day.")
        XCTAssertEqual(snapshot.patternUnlocks.map(\.id), ["trigger-repetition", "next-pattern-5"])
        XCTAssertEqual(snapshot.patternUnlocks.first?.message, "Work has shown up in 2 check-ins.")
        XCTAssertFalse(snapshot.patternUnlocks.last?.isUnlocked ?? true)
    }

    func testRetentionInsightsUnlockPersonalPatternsProgressively() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let referenceDate = Self.date(calendar, 2026, 6, 7, 12)

        let snapshot = RetentionInsightsService.snapshot(
            moods: [
                RetentionMoodEvent(createdAt: Self.date(calendar, 2026, 5, 31, 9), moodScore: 5, triggers: ["Work"], energyScore: 3),
                RetentionMoodEvent(createdAt: Self.date(calendar, 2026, 6, 1, 9), moodScore: 4, triggers: ["Work"], energyScore: 3),
                RetentionMoodEvent(createdAt: Self.date(calendar, 2026, 6, 1, 18), moodScore: 6, triggers: ["Work"], energyScore: 5),
                RetentionMoodEvent(createdAt: Self.date(calendar, 2026, 6, 2, 9), moodScore: 5, triggers: ["Sleep"], energyScore: 6),
                RetentionMoodEvent(createdAt: Self.date(calendar, 2026, 6, 3, 9), moodScore: 5, triggers: ["Errands"], energyScore: 6),
                RetentionMoodEvent(createdAt: Self.date(calendar, 2026, 6, 4, 9), moodScore: 3, triggers: ["Work"], energyScore: 2),
                RetentionMoodEvent(createdAt: Self.date(calendar, 2026, 6, 4, 18), moodScore: 5, triggers: ["Work"], energyScore: 4),
                RetentionMoodEvent(createdAt: Self.date(calendar, 2026, 6, 5, 9), moodScore: 6, triggers: ["Family"], energyScore: 5),
                RetentionMoodEvent(createdAt: Self.date(calendar, 2026, 6, 6, 9), moodScore: 7, triggers: ["Rest"], energyScore: 6),
                RetentionMoodEvent(createdAt: Self.date(calendar, 2026, 6, 7, 9), moodScore: 6, triggers: ["Planning"], energyScore: 5)
            ],
            checkIns: [],
            thoughts: [],
            exerciseCompletions: [],
            journalEntries: [
                RetentionDatedEvent(createdAt: Self.date(calendar, 2026, 6, 1, 13)),
                RetentionDatedEvent(createdAt: Self.date(calendar, 2026, 6, 4, 13))
            ],
            flexibleJournalEntries: [],
            breathingSessions: [
                RetentionDatedEvent(createdAt: Self.date(calendar, 2026, 6, 2, 10)),
                RetentionDatedEvent(createdAt: Self.date(calendar, 2026, 6, 3, 10))
            ],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.patternUnlocks.map(\.id), [
            "trigger-repetition",
            "low-energy-trigger",
            "breathing-return",
            "journal-mood-lift"
        ])
        XCTAssertEqual(snapshot.patternUnlocks.map(\.isUnlocked), [true, true, true, true])
        XCTAssertEqual(snapshot.patternUnlocks.first { $0.id == "low-energy-trigger" }?.message, "Work shows up often on low-energy days.")
        XCTAssertEqual(snapshot.patternUnlocks.first { $0.id == "breathing-return" }?.message, "Breathing helped you return twice this week.")
        XCTAssertEqual(snapshot.patternUnlocks.first { $0.id == "journal-mood-lift" }?.message, "Your mood tends to lift after journaling.")
    }

    func testRetentionInsightsShowsLowDataStateWithoutOverstatingPatterns() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2

        let snapshot = RetentionInsightsService.snapshot(
            moods: [
                RetentionMoodEvent(createdAt: Self.date(calendar, 2026, 6, 1, 9), moodScore: 6, triggers: [])
            ],
            checkIns: [],
            thoughts: [
                RetentionThoughtEvent(createdAt: Self.date(calendar, 2026, 6, 1, 18), intensityBefore: 40, intensityAfter: 35)
            ],
            exerciseCompletions: [],
            journalEntries: [],
            flexibleJournalEntries: [],
            breathingSessions: [],
            referenceDate: Self.date(calendar, 2026, 6, 3, 12),
            calendar: calendar
        )

        XCTAssertEqual(snapshot.cards.map(\.id), ["weekly-check-ins"])
        XCTAssertEqual(snapshot.cards.first?.message, "You checked in 1 day this week.")
        XCTAssertEqual(snapshot.patternUnlocks.map(\.id), ["first-pattern"])
        XCTAssertFalse(snapshot.patternUnlocks.first?.isUnlocked ?? true)

        let emptySnapshot = RetentionInsightsService.snapshot(
            moods: [],
            checkIns: [],
            thoughts: [],
            exerciseCompletions: [],
            journalEntries: [],
            flexibleJournalEntries: [],
            breathingSessions: [],
            referenceDate: Self.date(calendar, 2026, 6, 3, 12),
            calendar: calendar
        )

        XCTAssertTrue(emptySnapshot.cards.isEmpty)
        XCTAssertEqual(emptySnapshot.patternUnlocks.map(\.id), ["first-pattern"])
        XCTAssertEqual(emptySnapshot.emptyStateMessage, RetentionInsightsSnapshot.empty.emptyStateMessage)
    }

    @MainActor
    func testCBTDataStoreSavesMoodAndThoughtRecords() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)

        let mood = try context.cbtStore.insertMoodEntry(
            createdAt: createdAt,
            moodScore: 6,
            emotions: ["Calm"],
            triggers: ["Work"],
            sensations: ["Steady"],
            contextTags: ["Home"],
            activityTags: ["Walking"],
            notes: "Saved mood",
            intensity: 4
        )
        let thought = try context.cbtStore.insertThoughtRecord(
            createdAt: createdAt.addingTimeInterval(60),
            situation: "A hard meeting",
            automaticThought: "I will mess it up",
            emotions: ["Anxious"],
            distortions: ["Catastrophizing"],
            evidenceFor: "It is important",
            evidenceAgainst: "I have prepared",
            balancedThought: "I can handle one step",
            intensityBefore: 70,
            intensityAfter: 35
        )

        let savedMood = try XCTUnwrap(try context.fetch(FetchDescriptor<MoodEntry>()).first { $0.id == mood.id })
        XCTAssertEqual(savedMood.notes, "Saved mood")
        XCTAssertEqual(savedMood.activityTags, ["Walking"])

        let savedThought = try XCTUnwrap(try context.fetch(FetchDescriptor<ThoughtRecord>()).first { $0.id == thought.id })
        XCTAssertEqual(savedThought.balancedThought, "I can handle one step")
        XCTAssertEqual(savedThought.intensityAfter, 35)

        let unlockedTitles = Set(try context.fetch(FetchDescriptor<Achievement>())
            .filter(\.isUnlocked)
            .map(\.title))
        XCTAssertTrue(unlockedTitles.contains("Mood Noted"))
        XCTAssertTrue(unlockedTitles.contains("Thought Catcher"))
    }

    @MainActor
    func testThoughtRecordDraftAutoSaveUpdatesExistingDraft() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let viewModel = NewThoughtRecordViewModel()

        viewModel.mode = .quick
        viewModel.situation = "Before a presentation"
        viewModel.automaticThought = "I will blank"
        viewModel.saveDraft(context: context)

        viewModel.automaticThought = "I might blank for a second"
        viewModel.balancedThought = "I can pause and use my notes"
        viewModel.saveDraft(context: context)

        let records = try context.fetch(FetchDescriptor<ThoughtRecord>())
        XCTAssertEqual(records.count, 1)
        let draft = try XCTUnwrap(records.first)
        XCTAssertTrue(draft.isDraft)
        XCTAssertFalse(draft.isComplete)
        XCTAssertEqual(draft.automaticThought, "I might blank for a second")
        XCTAssertEqual(draft.mode, .quick)
    }

    @MainActor
    func testThoughtRecordCompletionReusesDraftAndSavesReframe() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let viewModel = NewThoughtRecordViewModel()

        viewModel.situation = "A difficult message"
        viewModel.automaticThought = "They are upset with me"
        viewModel.distortions = ["Mind Reading"]
        viewModel.balancedThought = "I can ask before assuming"
        viewModel.intensityBefore = 80
        viewModel.intensityAfter = 45
        viewModel.saveDraft(context: context)
        let draftID = try XCTUnwrap(viewModel.draftRecord?.id)

        viewModel.saveReframe = true
        viewModel.favoriteReframe = true
        let completed = try XCTUnwrap(viewModel.saveRecord(context: context))

        let records = try context.fetch(FetchDescriptor<ThoughtRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(completed.id, draftID)
        XCTAssertFalse(completed.isDraft)
        XCTAssertTrue(completed.isComplete)
        XCTAssertTrue(completed.isSavedReframe)
        XCTAssertTrue(completed.isFavoriteReframe)
        XCTAssertNotNil(completed.completedAt)
        XCTAssertEqual(completed.savedReframeAt, completed.completedAt)
        XCTAssertNil(completed.lastReviewedAt)
    }

    @MainActor
    func testSavedReframeFollowUpIsDueOneDayLaterUntilReviewed() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let savedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let record = ThoughtRecord(
            createdAt: savedAt,
            balancedThought: "I can ask before assuming.",
            intensityBefore: 80,
            intensityAfter: 45,
            isSavedReframe: true,
            savedReframeAt: savedAt,
            completedAt: savedAt
        )
        context.insert(record)
        try context.save()

        XCTAssertFalse(record.isReframeFollowUpDue(now: savedAt.addingTimeInterval(86_399)))
        XCTAssertTrue(record.isReframeFollowUpDue(now: savedAt.addingTimeInterval(86_400)))

        try context.cbtStore.updateSavedReframe(
            record,
            isSaved: true,
            reviewedAt: savedAt.addingTimeInterval(86_500)
        )

        XCTAssertFalse(record.isReframeFollowUpDue(now: savedAt.addingTimeInterval(172_800)))
    }

    @MainActor
    func testThoughtRecordInsightAggregationCountsCompletionAndRecurringDistortions() async throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let now = Date()

        context.insert(ThoughtRecord(
            createdAt: now.addingTimeInterval(-3_600),
            distortions: ["Catastrophizing"],
            balancedThought: "One step is enough",
            intensityBefore: 80,
            intensityAfter: 50,
            isSavedReframe: true,
            isFavoriteReframe: true,
            completedAt: now.addingTimeInterval(-3_500)
        ))
        context.insert(ThoughtRecord(
            createdAt: now.addingTimeInterval(-1_800),
            distortions: ["Catastrophizing"],
            balancedThought: "I can check the facts",
            intensityBefore: 60,
            intensityAfter: 40,
            completedAt: now.addingTimeInterval(-1_700)
        ))
        context.insert(ThoughtRecord(
            createdAt: now.addingTimeInterval(-900),
            situation: "Started and paused",
            intensityBefore: 50,
            intensityAfter: 50,
            isDraft: true,
            mode: .quick
        ))
        try context.save()

        let viewModel = InsightsViewModel()
        await viewModel.recalculate(
            timeRangeDays: 7,
            moodEntries: [],
            moodCheckIns: [],
            thoughtRecords: try context.fetch(FetchDescriptor<ThoughtRecord>()),
            exerciseCompletions: [],
            journalEntries: [],
            flexibleJournalEntries: [],
            breathingSessions: [],
            moodGoalValue: 7
        )

        let stats = viewModel.dashboardSnapshot.thoughtRecordStats
        XCTAssertEqual(stats.completedCount, 2)
        XCTAssertEqual(stats.draftCount, 1)
        XCTAssertEqual(stats.savedReframeCount, 1)
        XCTAssertEqual(stats.favoriteReframeCount, 1)
        XCTAssertEqual(stats.averageIntensityChange, 25)
        XCTAssertEqual(stats.recurringDistortions.first?.name, "Catastrophizing")
        XCTAssertEqual(stats.recurringDistortions.first?.count, 2)
    }

    func testBundledGuidedJournalTemplatesAreValid() {
        let templates = JournalTemplate.allTemplates
        let expectedTitles: Set<String> = [
            "Worry Unpacker",
            "What Am I Predicting?",
            "Uncertainty Practice",
            "Panic Reflection",
            "Safety Behavior Audit",
            "One Small Step",
            "Low Mood Reflection",
            "Energy vs Mood",
            "Self-Criticism Reframe",
            "Hope Inventory",
            "Inner Critic Dialogue",
            "Strengths Evidence Log",
            "Shame Unpacking",
            "Comparison Detox",
            "Compassionate Letter",
            "Boundary Builder",
            "Conflict Reflection",
            "Needs & Requests",
            "Relationship Trigger Reflection",
            "Repair Conversation Prep",
            "Avoidance Map",
            "Procrastination Unpacker",
            "Task Breakdown",
            "Perfectionism Reframe",
            "Decision Journal",
            "Values Check-In",
            "Control vs Influence",
            "Sleep Wind-Down Reflection",
            "Gentle Evening Closeout",
            "Burnout Check-In",
            "Three Good Things"
        ]

        let bundledTitles = Set(templates.map(\.title))
        let addedTemplates = templates.filter { expectedTitles.contains($0.title) }

        XCTAssertEqual(addedTemplates.count, 31)
        XCTAssertTrue(bundledTitles.isSuperset(of: expectedTitles))
        XCTAssertEqual(Set(templates.map(\.id)).count, templates.count)

        let requestedCategories = [
            "Anxiety",
            "Low Mood",
            "Self-Esteem",
            "Relationships",
            "Productivity",
            "Sleep",
            "Stress & Burnout",
            "Values",
            "Mindfulness",
            "Gratitude"
        ]
        let categories = Set(addedTemplates.map(\.category))
        for category in requestedCategories {
            XCTAssertTrue(categories.contains(category), "Missing category: \(category)")
        }

        for template in addedTemplates {
            XCTAssertFalse(template.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, template.title)
            XCTAssertFalse(template.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, template.title)
            XCTAssertFalse(template.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, template.title)
            XCTAssertFalse(template.approach.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, template.title)
            XCTAssertGreaterThan(template.estimatedDurationMinutes, 0, template.title)
            XCTAssertTrue((3...7).contains(template.prompts.count), template.title)
            XCTAssertFalse(template.completionMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, template.title)
            XCTAssertFalse(template.tags.isEmpty, template.title)

            for prompt in template.prompts {
                XCTAssertFalse(prompt.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, template.title)
                XCTAssertFalse(prompt.helperText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, template.title)
            }
        }
    }

    @MainActor
    func testBundledCrashCoursesAreSeededWithRequiredContent() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        try LibraryService.shared.seedLibraryIfNeeded(in: context)

        let courses = try context.fetch(FetchDescriptor<Course>())
        let crashCourses = courses.filter { $0.approach == "Crash Course" }
        let expectedTitles: Set<String> = [
            "Introduction to CBT",
            "Understanding Thoughts, Feelings, and Behaviors",
            "Cognitive Distortions",
            "Thought Reframing Foundations",
            "Anxiety Basics",
            "Panic Attack Toolkit",
            "Depression and Low Mood Basics",
            "Behavioral Activation",
            "Exposure Practice Basics",
            "Social Anxiety Support",
            "Procrastination and Avoidance",
            "Perfectionism",
            "Self-Compassion Basics",
            "Sleep and Worry",
            "Stress and Burnout",
            "Healthy Boundaries",
            "Values and Motivation",
            "Mindfulness Basics",
            "DBT Distress Tolerance Basics",
            "ACT Defusion Basics"
        ]

        XCTAssertEqual(crashCourses.count, 20)
        XCTAssertEqual(Set(crashCourses.map(\.title)), expectedTitles)

        for course in crashCourses {
            XCTAssertEqual(course.lessons.count, 5, course.title)
            XCTAssertEqual(course.lessonCount, 5, course.title)
            XCTAssertGreaterThan(course.estimatedTotalDuration, 0, course.title)
            XCTAssertFalse(course.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, course.title)
            XCTAssertFalse(course.approaches.isEmpty, course.title)
            XCTAssertFalse(course.completionMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, course.title)
            XCTAssertFalse(course.finalReflectionPrompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, course.title)
            XCTAssertFalse(course.linkedExerciseIDs.isEmpty && course.linkedGuidedJournalIDs.isEmpty, course.title)

            for lesson in course.lessons {
                XCTAssertFalse(lesson.shortEducationalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, course.title)
                XCTAssertTrue(lesson.shortEducationalText.contains("Example:"), "\(course.title): \(lesson.title)")
                XCTAssertFalse(lesson.keyTakeaway.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, course.title)
                XCTAssertFalse(lesson.reflectionPrompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, course.title)
                XCTAssertGreaterThan(lesson.estimatedDuration, 0, course.title)
            }
        }
    }

    func testCourseProgressPercentageUsesOrderedLessonCompletions() {
        let lessons = [
            CourseLesson(
                id: "step_1",
                title: "Step 1",
                shortEducationalText: "Start.",
                keyTakeaway: "Start small.",
                linkedExerciseID: "exercise_001",
                estimatedDuration: 4
            ),
            CourseLesson(
                id: "step_2",
                title: "Step 2",
                shortEducationalText: "Continue.",
                keyTakeaway: "Keep going.",
                linkedExerciseID: "exercise_002",
                estimatedDuration: 4
            ),
            CourseLesson(
                id: "step_3",
                title: "Step 3",
                shortEducationalText: "Finish.",
                keyTakeaway: "Close the loop.",
                linkedExerciseID: "exercise_003",
                estimatedDuration: 4
            )
        ]
        let course = Course(
            id: "skill_path_test",
            title: "Progress Test Path",
            approach: "Skill Path",
            lessons: lessons,
            itemIDs: lessons.compactMap(\.linkedExerciseID)
        )

        XCTAssertTrue(course.isSkillPath)
        XCTAssertEqual(course.progressTotal, 3)
        XCTAssertEqual(course.completedLessonCount, 0)
        XCTAssertEqual(course.progressPercentage, 0)
        XCTAssertFalse(course.isCompleted)

        course.markCompleted(lesson: lessons[0])

        XCTAssertEqual(course.completedLessonCount, 1)
        XCTAssertEqual(course.progressPercentage, 33)
        XCTAssertFalse(course.isCompleted)

        course.markCompleted(lesson: lessons[1])
        course.markCompleted(lesson: lessons[2])

        XCTAssertEqual(course.completedLessonCount, 3)
        XCTAssertEqual(course.progressPercentage, 100)
        XCTAssertTrue(course.isCompleted)
    }

    @MainActor
    func testBundledSkillPathsAreSeededAndPreserveProgress() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        context.insert(Course(
            id: "skill_path_anxiety_reset",
            title: "Old Anxiety Reset",
            approach: "Skill Path",
            itemIDs: ["exercise_003", "exercise_004"],
            completedItemIDs: ["exercise_003"]
        ))

        try LibraryService.shared.seedLibraryIfNeeded(in: context)

        let paths = try context.fetch(FetchDescriptor<Course>()).filter(\.isSkillPath)
        let expectedTitles: Set<String> = [
            "Anxiety Reset",
            "Overthinking",
            "Low Mood Support",
            "Self-Esteem",
            "Stress at Work",
            "Sleep & Worry",
            "Social Anxiety",
            "Panic Support"
        ]

        XCTAssertEqual(paths.count, 8)
        XCTAssertEqual(Set(paths.map(\.title)), expectedTitles)

        for path in paths {
            XCTAssertEqual(path.approach, "Skill Path")
            XCTAssertEqual(path.lessons.count, 5, path.title)
            XCTAssertEqual(path.lessonCount, 5, path.title)
            XCTAssertGreaterThan(path.progressTotal, 0, path.title)
            XCTAssertFalse(path.linkedExerciseIDs.isEmpty, path.title)
            XCTAssertFalse(path.linkedGuidedJournalIDs.isEmpty, path.title)
            XCTAssertFalse(path.courseDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, path.title)
        }

        let anxietyReset = try XCTUnwrap(paths.first { $0.id == "skill_path_anxiety_reset" })
        XCTAssertEqual(anxietyReset.completedItemIDs, ["exercise_003"])
        XCTAssertEqual(anxietyReset.completedLessonCount, 1)
        XCTAssertEqual(anxietyReset.progressPercentage, 20)
        XCTAssertFalse(anxietyReset.isCompleted)
    }

    @MainActor
    func testDataExportIncludesDailyPlanAndGuidedJournalModels() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        context.insert(ProgramProgress(programID: "test_program", completedDays: 2))
        context.insert(FlexibleJournalEntry(templateType: "gratitude", responses: ["One", "Two"]))
        context.insert(MoodCheckIn(moodScore: 7, notes: "Settled"))
        context.insert(MoodEntry(
            moodScore: 6,
            sensations: ["tight chest"],
            contextTags: ["Work"],
            activityTags: ["Sleep", "Exercise"]
        ))
        context.insert(BreathingSession(durationSeconds: 180))
        context.insert(PlannedActivity(
            title: "Text Maya",
            category: "Social",
            scheduledDate: Date(timeIntervalSince1970: 1_800_000_050),
            supportedValue: "Connection",
            predictedEnjoyment: 6
        ))
        context.insert(SafetyPlan(
            emergencyContacts: [EmergencyContact(name: "Alex", relationship: "Friend")],
            personalWarningSigns: ["Withdrawing"],
            copingStrategies: ["Step outside"],
            groundingSteps: ["Name five things I can see"],
            safePlaces: ["Kitchen table"],
            reminders: ["This feeling can pass"],
            makesItWorse: ["Doomscrolling"],
            privacySafeDisplayEnabled: true
        ))
        let settings = UserSettings(hapticsEnabled: false, appLockEnabled: true, isPremium: true)
        settings.currentIcon = "calm"
        context.insert(settings)
        context.insert(Course(
            id: "course_export",
            title: "Export Course",
            itemIDs: ["lesson_1"],
            completedItemIDs: ["lesson_1"],
            completedAt: Date(timeIntervalSince1970: 1_800_000_000)
        ))
        context.insert(AudioContent(
            id: "audio_export",
            title: "Export Audio",
            description: "A placeholder",
            category: "Grounding",
            duration: 120,
            type: .grounding,
            localAssetFilename: "missing.mp3",
            transcript: "Breathe.",
            isCompleted: true,
            completedAt: Date(timeIntervalSince1970: 1_800_000_100),
            isFavorite: true
        ))
        context.insert(Achievement(
            title: "Export Badge",
            description: "Unlocked in export",
            imageName: "star",
            isUnlocked: true,
            unlockCondition: .moodCheckInCount,
            unlockedAt: Date(timeIntervalSince1970: 1_800_000_200)
        ))
        try context.save()

        let payload = try DataExportService().makePayload(from: context)

        XCTAssertEqual(payload.moodEntries.first?.sensations, ["tight chest"])
        XCTAssertEqual(payload.moodEntries.first?.contextTags, ["Work"])
        XCTAssertEqual(payload.moodEntries.first?.activityTags, ["Sleep", "Exercise"])
        XCTAssertEqual(payload.programProgresses?.count, 1)
        XCTAssertEqual(payload.flexibleJournalEntries?.count, 1)
        XCTAssertEqual(payload.moodCheckIns?.count, 1)
        XCTAssertEqual(payload.breathingSessions?.count, 1)
        XCTAssertEqual(payload.plannedActivities?.first?.supportedValue, "Connection")
        XCTAssertEqual(payload.safetyPlans?.count, 1)
        XCTAssertEqual(payload.safetyPlans?.first?.groundingSteps, ["Name five things I can see"])
        XCTAssertEqual(payload.safetyPlans?.first?.safePlaces, ["Kitchen table"])
        XCTAssertEqual(payload.safetyPlans?.first?.reminders, ["This feeling can pass"])
        XCTAssertEqual(payload.safetyPlans?.first?.makesItWorse, ["Doomscrolling"])
        XCTAssertEqual(payload.safetyPlans?.first?.privacySafeDisplayEnabled, true)
        XCTAssertEqual(payload.userSettings?.first?.appLockEnabled, true)
        XCTAssertEqual(payload.courses?.first?.completedItemIDs, ["lesson_1"])
        XCTAssertEqual(payload.audioContents?.first?.isFavorite, true)
        XCTAssertEqual(payload.achievements?.first?.isUnlocked, true)
    }

    @MainActor
    func testCopingPlanSavesAllSectionsLocally() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let plan = SafetyPlan(
            emergencyContacts: [EmergencyContact(name: "Sam", relationship: "Sibling", phoneNumber: "555-0100")],
            personalWarningSigns: ["  racing thoughts  ", ""],
            copingStrategies: ["Cold water"],
            groundingSteps: ["Feet on floor"],
            safePlaces: ["Library"],
            reminders: ["I can take this one minute at a time"],
            makesItWorse: ["Skipping meals"],
            privacySafeDisplayEnabled: true
        )

        context.insert(plan)
        try context.save()

        let savedPlan = try XCTUnwrap(try context.fetch(FetchDescriptor<SafetyPlan>()).first)
        XCTAssertEqual(savedPlan.supportivePeople.first?.name, "Sam")
        XCTAssertEqual(savedPlan.personalWarningSigns, ["racing thoughts"])
        XCTAssertEqual(savedPlan.copingStrategies, ["Cold water"])
        XCTAssertEqual(savedPlan.groundingSteps, ["Feet on floor"])
        XCTAssertEqual(savedPlan.safePlaces, ["Library"])
        XCTAssertEqual(savedPlan.reminders, ["I can take this one minute at a time"])
        XCTAssertEqual(savedPlan.makesItWorse, ["Skipping meals"])
        XCTAssertTrue(savedPlan.privacySafeDisplayEnabled)
    }

    @MainActor
    func testCopingPlanUpdatesPersistLocally() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let originalDate = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = SafetyPlan(
            createdAt: originalDate,
            updatedAt: originalDate,
            personalWarningSigns: ["Withdrawing"],
            copingStrategies: ["Walk"]
        )
        context.insert(plan)
        try context.save()

        let savedPlan = try XCTUnwrap(try context.fetch(FetchDescriptor<SafetyPlan>()).first)
        savedPlan.personalWarningSigns = ["Snapping at people"]
        savedPlan.copingStrategies = ["Text a friend"]
        savedPlan.groundingSteps = ["Notice breath"]
        savedPlan.safePlaces = ["Porch"]
        savedPlan.reminders = ["Use the plan before deciding the whole day is ruined"]
        savedPlan.makesItWorse = ["Arguing online"]
        savedPlan.privacySafeDisplayEnabled = false
        try context.save()

        let updatedPlan = try XCTUnwrap(try context.fetch(FetchDescriptor<SafetyPlan>()).first)
        XCTAssertEqual(updatedPlan.personalWarningSigns, ["Snapping at people"])
        XCTAssertEqual(updatedPlan.copingStrategies, ["Text a friend"])
        XCTAssertEqual(updatedPlan.groundingSteps, ["Notice breath"])
        XCTAssertEqual(updatedPlan.safePlaces, ["Porch"])
        XCTAssertEqual(updatedPlan.reminders, ["Use the plan before deciding the whole day is ruined"])
        XCTAssertEqual(updatedPlan.makesItWorse, ["Arguing online"])
        XCTAssertFalse(updatedPlan.privacySafeDisplayEnabled)
        XCTAssertGreaterThan(updatedPlan.updatedAt, originalDate)
    }

    @MainActor
    func testDataImportRestoresExpandedUserStateModels() throws {
        let sourceContainer = try SharedPersistence.makeInMemoryModelContainer()
        let sourceContext = ModelContext(sourceContainer)
        let completedAt = Date(timeIntervalSince1970: 1_800_001_000)

        let settings = UserSettings(hapticsEnabled: false, appLockEnabled: true, isPremium: true)
        settings.currentIcon = "calm"
        sourceContext.insert(settings)
        sourceContext.insert(Course(
            id: "course_roundtrip",
            title: "Roundtrip Course",
            itemIDs: ["lesson_1", "lesson_2"],
            completedItemIDs: ["lesson_1", "lesson_2"],
            completedAt: completedAt
        ))
        sourceContext.insert(AudioContent(
            id: "audio_roundtrip",
            title: "Roundtrip Audio",
            description: "A placeholder",
            category: "Grounding",
            duration: 120,
            type: .grounding,
            localAssetFilename: "missing.mp3",
            transcript: "Breathe.",
            isCompleted: true,
            completedAt: completedAt,
            isFavorite: true
        ))
        sourceContext.insert(PlannedActivity(
            title: "Rest with tea",
            category: "Nourishing",
            scheduledDate: completedAt,
            supportedValue: "Rest",
            predictedEnjoyment: 4
        ))
        sourceContext.insert(Achievement(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Roundtrip Badge",
            description: "Unlocked in import",
            imageName: "star",
            isUnlocked: true,
            unlockCondition: .breathingSessionCount,
            createdAt: completedAt,
            unlockedAt: completedAt
        ))
        try sourceContext.save()

        let exportURL = try DataExportService().exportDataFileURL(from: sourceContext)
        let targetContainer = try SharedPersistence.makeInMemoryModelContainer()
        let targetContext = ModelContext(targetContainer)

        try DataImportService().importData(from: exportURL, into: targetContext)

        let importedSettings = try XCTUnwrap(try UserSettings.reconcileSingleton(in: targetContext))
        XCTAssertEqual(importedSettings.appLockEnabled, true)
        XCTAssertEqual(importedSettings.currentIcon, "calm")

        let importedCourse = try XCTUnwrap(try targetContext.fetch(FetchDescriptor<Course>()).first)
        XCTAssertEqual(importedCourse.id, "course_roundtrip")
        XCTAssertTrue(importedCourse.isCompleted)
        XCTAssertEqual(importedCourse.completedAt, completedAt)

        let importedAudio = try XCTUnwrap(try targetContext.fetch(FetchDescriptor<AudioContent>()).first)
        XCTAssertEqual(importedAudio.id, "audio_roundtrip")
        XCTAssertTrue(importedAudio.isFavorite)
        XCTAssertTrue(importedAudio.isCompleted)

        let importedActivity = try XCTUnwrap(try targetContext.fetch(FetchDescriptor<PlannedActivity>()).first)
        XCTAssertEqual(importedActivity.title, "Rest with tea")
        XCTAssertEqual(importedActivity.supportedValue, "Rest")

        let importedAchievement = try XCTUnwrap(try targetContext.fetch(FetchDescriptor<Achievement>()).first)
        XCTAssertEqual(importedAchievement.title, "Roundtrip Badge")
        XCTAssertTrue(importedAchievement.isUnlocked)
    }

    @MainActor
    func testMissingAudioPlaceholderReportsErrorWithoutCrashing() {
        AudioPlayerService.shared.stop()
        let didStartPlayback = AudioPlayerService.shared.playMP3(named: "definitely_missing_audio_placeholder.mp3")

        XCTAssertFalse(didStartPlayback)
        XCTAssertNotNil(AudioPlayerService.shared.errorMessage)
        XCTAssertFalse(AudioPlayerService.shared.isPlaying)
        XCTAssertNil(AudioPlayerService.shared.currentFileName)
    }

    @MainActor
    func testClinicalReportAggregatesRecentProgress() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)

        context.insert(MoodEntry(createdAt: calendar.date(byAdding: .day, value: -80, to: now)!, moodScore: 4, intensity: 70))
        context.insert(MoodEntry(createdAt: calendar.date(byAdding: .day, value: -20, to: now)!, moodScore: 8, intensity: 30))
        context.insert(ThoughtRecord(createdAt: calendar.date(byAdding: .day, value: -10, to: now)!, distortions: ["Catastrophizing", "Mind Reading"], intensityBefore: 80, intensityAfter: 35))
        context.insert(ThoughtRecord(createdAt: calendar.date(byAdding: .day, value: -5, to: now)!, distortions: ["Catastrophizing"], intensityBefore: 60, intensityAfter: 30))
        context.insert(AssessmentLog(date: calendar.date(byAdding: .day, value: -70, to: now)!, assessmentType: "PHQ-9", score: 12))
        context.insert(AssessmentLog(date: calendar.date(byAdding: .day, value: -2, to: now)!, assessmentType: "PHQ-9", score: 7))
        try context.save()

        let report = try ClinicalReportGenerator(calendar: calendar).generateReport(from: context)

        XCTAssertEqual(report.windows.count, 3)
        XCTAssertEqual(report.windows.first(where: { $0.days == 30 })?.moodEntryCount, 1)
        XCTAssertEqual(report.windows.first(where: { $0.days == 90 })?.moodEntryCount, 2)
        XCTAssertEqual(report.distortionFrequencies.first?.label, "Catastrophizing")
        XCTAssertEqual(report.distortionFrequencies.first?.count, 2)
        XCTAssertEqual(report.assessmentSummaries.first?.assessmentType, "PHQ-9")
        XCTAssertEqual(report.assessmentSummaries.first?.change, -5)
        XCTAssertEqual(report.moodTrend.lowestScore, 4)
        XCTAssertEqual(report.moodTrend.highestScore, 8)
    }

    @MainActor
    func testDailyRecommendationsPrioritizeVeryLowMoodGrounding() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        context.insert(MoodEntry(
            createdAt: now.addingTimeInterval(-1_800),
            moodScore: 2,
            emotions: ["Anxious"],
            triggers: ["Work"],
            sensations: ["Tight chest"],
            intensity: 9
        ))
        try context.save()

        let recommendations = DailyRecommendationService().recommendations(
            for: now,
            in: context,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(recommendations.first?.type, .breathingReset)
        XCTAssertTrue(recommendations.contains { $0.type == .libraryExercise })
        XCTAssertTrue(recommendations.contains { $0.type == .safetySupport })
        XCTAssertTrue((3...5).contains(recommendations.count))
        XCTAssertTrue(recommendations.allSatisfy { !$0.reason.isEmpty && !$0.destination.deepLink.isEmpty })
    }

    @MainActor
    func testInsightsGeneratePersonalCopingPlanFromRepeatedMoodPatterns() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstDay = Self.date(calendar, 2026, 5, 25, 21)
        let moods = [
            MoodEntry(
                createdAt: firstDay,
                moodScore: 3,
                emotions: ["Sad"],
                triggers: ["Isolation"],
                notes: "Stayed alone after work"
            ),
            MoodEntry(
                createdAt: Self.date(calendar, 2026, 5, 26, 20),
                moodScore: 4,
                emotions: ["Low"],
                contextTags: ["Withdrawing"],
                notes: "Avoided texting anyone"
            ),
            MoodEntry(
                createdAt: Self.date(calendar, 2026, 5, 27, 14),
                moodScore: 5,
                emotions: ["Anxious"],
                sensations: ["Tight chest"]
            ),
            MoodEntry(
                createdAt: Self.date(calendar, 2026, 5, 28, 15),
                moodScore: 5,
                emotions: ["Worried"],
                sensations: ["Racing heart"]
            ),
            MoodEntry(
                createdAt: Self.date(calendar, 2026, 5, 29, 22),
                moodScore: 5,
                emotions: ["Worried"],
                triggers: ["Sleep"],
                notes: "Rumination at bedtime",
                sleepQualityScore: 3
            ),
            MoodEntry(
                createdAt: Self.date(calendar, 2026, 5, 30, 23),
                moodScore: 5,
                notes: "Overthinking in bed",
                sleepQualityScore: 4
            )
        ]
        let viewModel = InsightsViewModel()

        await viewModel.recalculate(
            timeRangeDays: 30,
            moodEntries: moods,
            moodCheckIns: [],
            thoughtRecords: [],
            exerciseCompletions: [],
            journalEntries: [],
            flexibleJournalEntries: [],
            breathingSessions: [],
            moodGoalValue: 7
        )

        let planTitles = viewModel.patternSummary.personalCopingPlan.map(\.title)
        XCTAssertTrue(planTitles.contains("Low Mood + Isolation"))
        XCTAssertTrue(planTitles.contains("Anxiety + Body Cues"))
        XCTAssertTrue(planTitles.contains("Bedtime Rumination"))
        XCTAssertEqual(viewModel.patternSummary.personalCopingPlan.count, 3)
    }

    @MainActor
    func testInsightsGenerateTriggerPatternCardsForRepeatedMonthlyTriggers() async {
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        let moods = (0..<4).map { index in
            MoodEntry(
                createdAt: monthStart.addingTimeInterval(Double(index + 9) * 3_600),
                moodScore: 4,
                emotions: ["Stressed"],
                triggers: index == 0 ? ["Work", "work"] : ["Work"]
            )
        } + [
            MoodEntry(
                createdAt: monthStart.addingTimeInterval(14 * 3_600),
                moodScore: 6,
                triggers: ["Family"]
            )
        ]
        let viewModel = InsightsViewModel()

        await viewModel.recalculate(
            timeRangeDays: 30,
            moodEntries: moods,
            moodCheckIns: [],
            thoughtRecords: [],
            exerciseCompletions: [],
            journalEntries: [],
            flexibleJournalEntries: [],
            breathingSessions: [],
            moodGoalValue: 7
        )

        guard let card = viewModel.patternSummary.insightCards.first(where: { $0.title == "Work Pattern" }) else {
            XCTFail("Expected a repeated work trigger card.")
            return
        }

        XCTAssertEqual(card.message, "Work stress has appeared 4 times this month.")
        XCTAssertEqual(card.occurrenceCount, 4)
        XCTAssertEqual(card.actionTitle, "Two-minute work reset")
        XCTAssertTrue(card.canCreatePlan)
        XCTAssertFalse(viewModel.patternSummary.insightCards.contains { $0.title == "Family Pattern" })
    }

    @MainActor
    func testLowMoodSafetyRecommendationIsAvailableWhenUsageGateIsClosed() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        for index in 0..<UsageGate.trialLimit {
            context.insert(MoodEntry(createdAt: Date(timeIntervalSince1970: Double(index)), moodScore: 5))
        }
        try context.save()

        XCTAssertFalse(UsageGate.canCreateNewItem(in: context))

        let plan = DailyRecommendationService().nextStepsAfterMoodCheckIn(for: MoodCheckInRecommendationInput(
            moodScore: 1,
            intensity: 9,
            emotions: ["Hopeless"],
            triggers: [],
            activityTags: [],
            sensations: [],
            contextTags: [],
            notes: nil
        ))

        let safetyStep = try XCTUnwrap(plan.recommendations.first { $0.destination == .safetySupport })
        XCTAssertEqual(safetyStep.type, .safetySupport)
        XCTAssertEqual(safetyStep.destination.deepLink, "cbt://safety-plan")
        XCTAssertNil(safetyStep.completionItem)
    }

    @MainActor
    func testWeeklyReportServiceAggregatesSelectedWeek() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let selectedWeekDate = Self.date(calendar, 2026, 5, 20, 12)

        let firstMoodDate = Self.date(calendar, 2026, 5, 18, 9)
        let secondMoodDate = Self.date(calendar, 2026, 5, 20, 18)
        context.insert(MoodEntry(
            createdAt: firstMoodDate,
            moodScore: 6,
            emotions: ["Calm", "Focused"],
            triggers: ["Work"],
            contextTags: ["Work"],
            activityTags: ["Walking"]
        ))
        context.insert(MoodCheckIn(createdAt: firstMoodDate.addingTimeInterval(30), moodScore: 6))
        context.insert(MoodEntry(
            createdAt: secondMoodDate,
            moodScore: 8,
            emotions: ["Calm"],
            triggers: ["Sleep"],
            activityTags: ["Walking"]
        ))
        context.insert(MoodCheckIn(createdAt: Self.date(calendar, 2026, 5, 22, 8), moodScore: 7))
        context.insert(MoodEntry(createdAt: Self.date(calendar, 2026, 5, 12, 10), moodScore: 5))

        context.insert(ThoughtRecord(
            createdAt: Self.date(calendar, 2026, 5, 19, 13),
            emotions: ["Anxious"],
            distortions: ["Catastrophizing"],
            intensityBefore: 70,
            intensityAfter: 40
        ))
        context.insert(ThoughtRecord(
            createdAt: Self.date(calendar, 2026, 5, 21, 16),
            distortions: ["Catastrophizing", "Mind Reading"],
            intensityBefore: 60,
            intensityAfter: 30
        ))
        context.insert(ExerciseCompletion(createdAt: Self.date(calendar, 2026, 5, 18, 12), exerciseID: "box_breathing"))
        context.insert(ExerciseCompletion(createdAt: Self.date(calendar, 2026, 5, 23, 12), exerciseID: "thought_record"))
        context.insert(BreathingSession(createdAt: Self.date(calendar, 2026, 5, 18, 20), durationSeconds: 180))
        context.insert(FlexibleJournalEntry(date: Self.date(calendar, 2026, 5, 20, 21), templateType: "gratitude", responses: ["One"]))
        context.insert(FlexibleJournalEntry(date: Self.date(calendar, 2026, 5, 22, 21), templateType: "values", responses: ["Two"]))
        context.insert(PlannedActivity(
            createdAt: Self.date(calendar, 2026, 5, 18, 8),
            title: "Walk",
            category: "Physical",
            scheduledDate: Self.date(calendar, 2026, 5, 21, 9),
            isCompleted: true,
            completedAt: Self.date(calendar, 2026, 5, 21, 10)
        ))
        context.insert(PlannedActivity(
            createdAt: Self.date(calendar, 2026, 5, 18, 8),
            title: "Read",
            scheduledDate: Self.date(calendar, 2026, 5, 22, 9),
            isCompleted: false
        ))
        context.insert(AssessmentLog(date: Self.date(calendar, 2026, 5, 1, 9), assessmentType: "PHQ-9", score: 10))
        context.insert(AssessmentLog(date: Self.date(calendar, 2026, 5, 19, 9), assessmentType: "PHQ-9", score: 8))
        context.insert(Achievement(
            title: "Thought Catcher",
            description: "Completed thought records",
            imageName: "brain.head.profile",
            isUnlocked: true,
            unlockCondition: .thoughtRecordsCount,
            unlockedAt: Self.date(calendar, 2026, 5, 20, 10)
        ))
        try context.save()

        let report = try WeeklyReportService(
            calendar: calendar,
            now: { Self.date(calendar, 2026, 5, 24, 12) }
        )
        .generateReport(forWeekContaining: selectedWeekDate, from: context)

        XCTAssertEqual(report.weekStart, Self.date(calendar, 2026, 5, 18, 0))
        XCTAssertEqual(report.weekEnd, Self.date(calendar, 2026, 5, 25, 0))
        XCTAssertEqual(report.moodCheckInCount, 3)
        XCTAssertEqual(report.averageMood ?? 0, 7.0, accuracy: 0.001)
        XCTAssertEqual(report.moodTrend.direction, .higher)
        XCTAssertEqual(report.moodTrend.change ?? 0, 2.0, accuracy: 0.001)
        XCTAssertEqual(report.mostCommonEmotions.first?.label, "Calm")
        XCTAssertEqual(report.mostCommonEmotions.first?.count, 2)
        XCTAssertEqual(report.mostCommonTriggers.first?.label, "Sleep")
        XCTAssertEqual(report.mostCommonActivityTags.first?.label, "Walking")
        XCTAssertEqual(report.mostCommonActivityTags.first?.count, 2)
        XCTAssertEqual(report.thoughtRecordCount, 2)
        XCTAssertEqual(report.mostCommonCognitiveDistortions.first?.label, "Catastrophizing")
        XCTAssertEqual(report.mostCommonCognitiveDistortions.first?.count, 2)
        XCTAssertEqual(report.exercisesCompleted, 2)
        XCTAssertEqual(report.breathingSessionsCompleted, 1)
        XCTAssertEqual(report.guidedJournalsCompleted, 2)
        XCTAssertEqual(report.plannedActivitiesCompleted, 1)
        XCTAssertEqual(report.assessmentChanges.first?.assessmentType, "PHQ-9")
        XCTAssertEqual(report.assessmentChanges.first?.change ?? 0, -2.0, accuracy: 0.001)
        XCTAssertEqual(report.achievementsUnlocked.first?.title, "Thought Catcher")
    }

    @MainActor
    func testWeeklyReportServiceHandlesInsufficientDataGracefully() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar

        let report = try WeeklyReportService(
            calendar: calendar,
            now: { Self.date(calendar, 2026, 5, 24, 12) }
        )
        .generateReport(forWeekContaining: Self.date(calendar, 2026, 5, 20, 12), from: context)

        XCTAssertFalse(report.hasAnyData)
        XCTAssertNil(report.averageMood)
        XCTAssertEqual(report.moodTrend.direction, .unavailable)
        XCTAssertEqual(report.moodCheckInCount, 0)
        XCTAssertTrue(report.insufficientDataMessages.contains("No mood check-ins were recorded for this week."))
        XCTAssertTrue(report.suggestedFocusForNextWeek.contains("mood check-ins"))
    }

    @MainActor
    func testWeeklyPDFReportDefaultsToSummaryOnlyWithoutPrivateExcerpts() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let weekStart = Self.date(calendar, 2026, 5, 18, 0)

        try seedWeeklyPDFReportData(in: context, calendar: calendar, weekStart: weekStart)

        let report = try WeeklyReportGenerator(calendar: calendar).generateReport(
            from: context,
            weekStart: weekStart,
            includeExcerpts: false
        )

        XCTAssertFalse(report.includesExcerpts)
        XCTAssertEqual(report.moodSummary.recordCount, 2)
        XCTAssertEqual(report.triggerSummary.first?.label, "Work")
        XCTAssertEqual(report.activityPatternSummary.activityTagSummary.first?.label, "Walking")
        XCTAssertEqual(report.thoughtRecordSummary.recordCount, 1)
        XCTAssertEqual(report.breathingJournalSummary.breathingSessionCount, 1)
        XCTAssertEqual(report.breathingJournalSummary.journalEntryCount, 1)
        XCTAssertEqual(report.activityPatternSummary.completedPlannedActivities, 1)
        XCTAssertTrue(report.thoughtExcerpts.isEmpty)
        XCTAssertTrue(report.journalExcerpts.isEmpty)
    }

    @MainActor
    func testWeeklyPDFReportIncludesJournalAndThoughtExcerptsWhenExplicitlyRequested() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let weekStart = Self.date(calendar, 2026, 5, 18, 0)

        try seedWeeklyPDFReportData(in: context, calendar: calendar, weekStart: weekStart)

        let report = try WeeklyReportGenerator(calendar: calendar).generateReport(
            from: context,
            weekStart: weekStart,
            includeExcerpts: true
        )

        XCTAssertTrue(report.includesExcerpts)
        XCTAssertTrue(report.thoughtExcerpts.contains { $0.body.contains("private automatic thought") })
        XCTAssertTrue(report.journalExcerpts.contains { $0.body.contains("private journal body") })
    }

    @MainActor
    func testWeeklyPDFExportWritesEmptyAndPopulatedReports() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let generator = WeeklyReportGenerator(calendar: calendar)
        let emptyWeekStart = Self.date(calendar, 2026, 5, 18, 0)
        let populatedWeekStart = Self.date(calendar, 2026, 5, 25, 0)

        let emptyURL = try generator.generatePDFURL(from: context, weekStart: emptyWeekStart)
        defer { try? FileManager.default.removeItem(at: emptyURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: emptyURL.path))
        XCTAssertGreaterThan((try Data(contentsOf: emptyURL)).count, 0)
        XCTAssertGreaterThan(PDFDocument(url: emptyURL)?.pageCount ?? 0, 0)

        try seedWeeklyPDFReportData(in: context, calendar: calendar, weekStart: populatedWeekStart)

        let populatedURL = try generator.generatePDFURL(from: context, weekStart: populatedWeekStart)
        defer { try? FileManager.default.removeItem(at: populatedURL) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: populatedURL.path))
        XCTAssertGreaterThan((try Data(contentsOf: populatedURL)).count, 0)
        XCTAssertGreaterThan(PDFDocument(url: populatedURL)?.pageCount ?? 0, 0)
    }

    @MainActor
    func testMonthlyBadgeProgressAggregatesCurrentMonth() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar

        let checkInDates = [
            Self.date(calendar, 2026, 5, 1, 9),
            Self.date(calendar, 2026, 5, 4, 9),
            Self.date(calendar, 2026, 5, 11, 9),
            Self.date(calendar, 2026, 5, 18, 9),
            Self.date(calendar, 2026, 5, 25, 9)
        ]
        for date in checkInDates {
            context.insert(MoodEntry(createdAt: date, moodScore: 6))
        }
        context.insert(MoodCheckIn(createdAt: checkInDates[0].addingTimeInterval(30), moodScore: 6))

        context.insert(ThoughtRecord(createdAt: Self.date(calendar, 2026, 5, 6, 10), distortions: ["Catastrophizing"], intensityBefore: 70, intensityAfter: 30))
        context.insert(ThoughtRecord(createdAt: Self.date(calendar, 2026, 5, 7, 10), distortions: ["Mind Reading"], intensityBefore: 60, intensityAfter: 35))
        context.insert(ExerciseCompletion(createdAt: Self.date(calendar, 2026, 5, 8, 12), exerciseID: "thought_record"))
        context.insert(JournalEntry(createdAt: Self.date(calendar, 2026, 5, 9, 20), title: "Reflection", body: "A note"))
        context.insert(BreathingSession(createdAt: Self.date(calendar, 2026, 5, 10, 8), durationSeconds: 180))
        context.insert(Course(
            title: "Practice Path",
            itemIDs: ["lesson-1"],
            completedItemIDs: ["lesson-1"],
            completedAt: Self.date(calendar, 2026, 5, 20, 14)
        ))
        context.insert(MoodEntry(createdAt: Self.date(calendar, 2026, 4, 30, 9), moodScore: 5))
        try context.save()

        let progress = try AchievementService.shared.monthlyBadgeProgress(
            in: context,
            for: Self.date(calendar, 2026, 5, 31, 12),
            calendar: calendar
        )

        let weekly = try XCTUnwrap(progress.badges.first { $0.kind == .weeklyCheckIns })
        XCTAssertEqual(weekly.currentValue, 5)
        XCTAssertEqual(weekly.targetValue, 5)
        XCTAssertTrue(weekly.isComplete)

        let activities = try XCTUnwrap(progress.badges.first { $0.kind == .wellnessActivities })
        XCTAssertEqual(activities.currentValue, 10)
        XCTAssertTrue(activities.isComplete)

        let course = try XCTUnwrap(progress.badges.first { $0.kind == .courseCompletion })
        XCTAssertEqual(course.currentValue, 1)
        XCTAssertTrue(course.isComplete)

        let tools = try XCTUnwrap(progress.badges.first { $0.kind == .toolVariety })
        XCTAssertEqual(tools.currentValue, 5)
        XCTAssertTrue(tools.isComplete)
    }

    func testCourseCompletionTimestampIsSetWhenFinalItemCompletes() {
        let calendar = Self.weeklyReportCalendar
        let completedAt = Self.date(calendar, 2026, 5, 20, 14)
        let later = Self.date(calendar, 2026, 5, 21, 14)
        let course = Course(title: "Practice Path", itemIDs: ["lesson-1", "lesson-2"], completedItemIDs: ["lesson-1"])

        XCTAssertFalse(course.isCompleted)
        XCTAssertNil(course.completedAt)

        course.markCompleted(itemID: "lesson-2", completedAt: completedAt)

        XCTAssertTrue(course.isCompleted)
        XCTAssertEqual(course.completedAt, completedAt)

        course.markCompleted(itemID: "lesson-2", completedAt: later)
        XCTAssertEqual(course.completedAt, completedAt)
    }

    @MainActor
    func testLibrarySeedIsIdempotentAndDeduplicatesCatalogContent() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        try LibraryService.shared.seedLibraryIfNeeded(in: context)
        let firstItemCount = try context.fetch(FetchDescriptor<CBT.LibraryItem>()).count
        let firstCourseCount = try context.fetch(FetchDescriptor<Course>()).count
        let firstAudioCount = try context.fetch(FetchDescriptor<AudioContent>()).count

        try LibraryService.shared.seedLibraryIfNeeded(in: context)
        let items = try context.fetch(FetchDescriptor<CBT.LibraryItem>())
        let courses = try context.fetch(FetchDescriptor<Course>())
        let audio = try context.fetch(FetchDescriptor<AudioContent>())

        XCTAssertEqual(items.count, firstItemCount)
        XCTAssertEqual(courses.count, firstCourseCount)
        XCTAssertEqual(audio.count, firstAudioCount)
        XCTAssertEqual(Set(items.map(\.id)).count, items.count)
        XCTAssertEqual(Set(courses.map(\.id)).count, courses.count)
        XCTAssertEqual(Set(audio.map(\.id)).count, audio.count)
    }

    @MainActor
    func testBundledAudioCatalogOnlyIncludesPlayableAssets() throws {
        for audio in LibraryService.shared.bundledAudioContent {
            XCTAssertTrue(
                LibraryService.shared.audioAssetIsBundled(named: audio.localAssetFilename),
                "Bundled audio catalog exposed unavailable asset: \(audio.localAssetFilename)"
            )
            XCTAssertFalse(audio.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, audio.title)
            XCTAssertFalse(audio.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, audio.title)
            XCTAssertFalse(audio.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, audio.title)
            XCTAssertFalse(audio.displayTags.isEmpty, audio.title)
        }

        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        try LibraryService.shared.seedLibraryIfNeeded(in: context)

        let audioItems = try context.fetch(FetchDescriptor<CBT.LibraryItem>())
            .filter { $0.type == .audio }
        XCTAssertEqual(audioItems.count, LibraryService.shared.bundledAudioContent.count)
    }

    @MainActor
    func testDeleteAllDataClearsExpandedModelSet() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        context.insert(MoodEntry(moodScore: 5))
        context.insert(ThoughtRecord(situation: "test", intensityBefore: 50, intensityAfter: 30))
        context.insert(ExerciseCompletion(exerciseID: "exercise_001"))
        context.insert(JournalEntry(title: "Journal", body: "Body"))
        context.insert(PlannedActivity(title: "Walk", scheduledDate: Date()))
        context.insert(AssessmentLog(assessmentType: "PHQ-8", score: 6))
        context.insert(PersonalityAssessmentLog(opennessScore: 1, conscientiousnessScore: 1, extraversionScore: 1, agreeablenessScore: 1, neuroticismScore: 1))
        context.insert(ProgramProgress(programID: "program", completedDays: 1))
        context.insert(FlexibleJournalEntry(templateType: "gratitude", responses: ["One"]))
        context.insert(MoodCheckIn(moodScore: 5))
        context.insert(BreathingSession(durationSeconds: 60))
        context.insert(SafetyPlan(personalWarningSigns: ["Withdrawing"]))
        context.insert(Achievement(title: "Badge", description: "Desc", imageName: "star", unlockCondition: .moodCheckInCount))
        context.insert(CBT.LibraryItem(id: "item", title: "Item", category: "CBT", type: .exercise, duration: 1))
        context.insert(Course(id: "course", title: "Course", itemIDs: ["lesson"]))
        context.insert(AudioContent(id: "audio", title: "Audio", description: "Desc", category: "Grounding", duration: 1, type: .grounding, localAssetFilename: "missing.mp3", transcript: ""))
        context.insert(UserSettings(hapticsEnabled: false, appLockEnabled: true, isPremium: true))
        try context.save()

        AdvancedDataSettingsViewModel().deleteAllData(mode: .deleteOnly, modelContext: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<MoodEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ThoughtRecord>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ExerciseCompletion>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlannedActivity>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AssessmentLog>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PersonalityAssessmentLog>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProgramProgress>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FlexibleJournalEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MoodCheckIn>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<BreathingSession>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SafetyPlan>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Achievement>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CBT.LibraryItem>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AudioContent>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserSettings>()).count, 0)
    }

    func testResetLocalPreferencesClearsUserDefaultsBackedState() throws {
        let suiteName = "CBTTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let keys = [
            "cbt_onboardingCompleted",
            "cbt_dailyPlanGoalIDs",
            "appColorTheme",
            "appLockEnabled",
            "cbt_moodReminderEnabled",
            "cbt_moodReminderHour",
            "cbt_home_lastOpenedAt",
            "cbt.achievements.weeklyReportViewed",
            "cbt.achievements.badDayModeUsed",
            "affirmation_favorites_v1",
            AppConfiguration.showStreakInToolbarKey
        ]

        for key in keys {
            defaults.set("saved", forKey: key)
        }

        DataResetManager.shared.resetLocalPreferences(defaults)

        for key in keys {
            XCTAssertNil(defaults.object(forKey: key), "Expected reset to clear \(key)")
        }
    }

    @MainActor
    func testAchievementServiceSeedsRequiredRewards() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        AchievementService.shared.evaluateAchievements(in: context)

        let achievements = try context.fetch(FetchDescriptor<Achievement>())
        let titles = Set(achievements.map(\.title))
        let requiredTitles: Set<String> = [
            "First Step",
            "Practice Builder",
            "First Check-In",
            "Returned After a Missed Day",
            "Gentle Restart",
            "You Came Back",
            "Return Streak",
            "Recovery Week",
            "Daily Plan Complete",
            "Thought Catcher",
            "Completed 3 Thought Records",
            "Pattern Spotter",
            "Three-Day Flame",
            "Steady Week",
            "Mood Noted",
            "Completed 3 Check-Ins",
            "Mood Mapper",
            "Mood Explorer",
            "First Reflection",
            "Logged 7 Reflections",
            "Reflection Rhythm",
            "First Reset",
            "Breath Companion",
            "Course Opener",
            "Finished a CBT Path",
            "Learning Path",
            "Week in View",
            "Completed a Weekly Review",
            "Tried 3 Coping Tools",
            "Intentional Action",
            "Activity Explorer",
            "Self-Check",
            "Four-Week Anchor",
            "Skill Sampler",
            "Used Bad Day Mode"
        ]

        XCTAssertTrue(titles.isSuperset(of: requiredTitles))
    }

    @MainActor
    func testAchievementServiceUnlocksRequiredRewardsFromProgress() throws {
        UserDefaults.standard.removeObject(forKey: "cbt.achievements.weeklyReportViewed")
        UserDefaults.standard.removeObject(forKey: "cbt.achievements.badDayModeUsed")
        defer {
            UserDefaults.standard.removeObject(forKey: "cbt.achievements.weeklyReportViewed")
            UserDefaults.standard.removeObject(forKey: "cbt.achievements.badDayModeUsed")
        }
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let baseDate = Self.date(calendar, 2026, 5, 24, 9)

        for offset in 0..<30 {
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: -offset, to: baseDate))
            context.insert(MoodEntry(createdAt: date, moodScore: 6))
        }

        for index in 0..<10 {
            let date = try XCTUnwrap(calendar.date(byAdding: .hour, value: index, to: baseDate))
            context.insert(FlexibleJournalEntry(date: date, templateType: "gratitude", responses: ["One thing"]))
            context.insert(BreathingSession(createdAt: date, durationSeconds: 120))
            context.insert(PlannedActivity(
                createdAt: date,
                title: "Activity \(index)",
                scheduledDate: date,
                isCompleted: true,
                completedAt: date
            ))
        }

        for index in 0..<5 {
            let lessonID = "lesson-\(index)"
            context.insert(Course(
                title: "Course \(index)",
                itemIDs: [lessonID],
                completedItemIDs: [lessonID],
                completedAt: baseDate
            ))
        }

        context.insert(AssessmentLog(date: baseDate, assessmentType: "PHQ-9", score: 8))
        context.insert(WeeklyRitualEntry(
            weekStart: baseDate,
            createdAt: baseDate,
            updatedAt: baseDate,
            intention: "Keep one small practice nearby.",
            learning: ""
        ))

        for exerciseID in ["exercise_001", "exercise_dbt_001", "exercise_act_001", "exercise_mindfulness_001"] {
            context.insert(ExerciseCompletion(createdAt: baseDate, exerciseID: exerciseID))
        }

        try context.save()
        AchievementService.shared.recordWeeklyReportViewed(in: context)
        AchievementService.shared.recordBadDayModeUsed(in: context)
        AchievementService.shared.evaluateAchievements(in: context)

        let achievements = try context.fetch(FetchDescriptor<Achievement>())
        let unlockedTitles = Set(achievements.filter(\.isUnlocked).map(\.title))
        let expectedUnlocked: Set<String> = [
            "First Check-In",
            "Mood Noted",
            "Completed 3 Check-Ins",
            "Mood Mapper",
            "Mood Explorer",
            "Daily Plan Complete",
            "First Reflection",
            "Logged 7 Reflections",
            "Reflection Rhythm",
            "First Reset",
            "Breath Companion",
            "Course Opener",
            "Finished a CBT Path",
            "Learning Path",
            "Week in View",
            "Completed a Weekly Review",
            "Gentle Restart",
            "Intentional Action",
            "Activity Explorer",
            "Self-Check",
            "Four-Week Anchor",
            "Skill Sampler",
            "Used Bad Day Mode"
        ]

        XCTAssertTrue(unlockedTitles.isSuperset(of: expectedUnlocked))

        let progress = AchievementService.shared.progressSnapshots(in: context)
        XCTAssertEqual(progress["Mood Explorer"]?.completedValue, 30)
        XCTAssertEqual(progress["Skill Sampler"]?.completedValue, 4)
        XCTAssertEqual(progress["Logged 7 Reflections"]?.completedValue, 7)
    }

    @MainActor
    func testAchievementServiceAwardsGentleMilestonesAndPreventsDuplicates() throws {
        UserDefaults.standard.removeObject(forKey: "cbt.achievements.weeklyReportViewed")
        UserDefaults.standard.removeObject(forKey: "cbt.achievements.badDayModeUsed")
        defer {
            UserDefaults.standard.removeObject(forKey: "cbt.achievements.weeklyReportViewed")
            UserDefaults.standard.removeObject(forKey: "cbt.achievements.badDayModeUsed")
        }
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let firstDate = Self.date(calendar, 2026, 5, 1, 9)
        let returnDate = Self.date(calendar, 2026, 5, 3, 9)

        context.insert(MoodCheckIn(createdAt: firstDate, moodScore: 5))
        for offset in 0..<3 {
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: returnDate))
            context.insert(MoodCheckIn(createdAt: date, moodScore: 6))
        }

        for index in 0..<3 {
            let date = try XCTUnwrap(calendar.date(byAdding: .hour, value: index, to: returnDate))
            context.insert(ThoughtRecord(createdAt: date, situation: "Moment \(index)", intensityBefore: 70, intensityAfter: 45))
        }

        for exerciseID in ["exercise_dbt_002", "exercise_dbt_007", "exercise_mindfulness_003"] {
            context.insert(ExerciseCompletion(createdAt: returnDate, exerciseID: exerciseID))
        }

        for index in 0..<7 {
            let date = try XCTUnwrap(calendar.date(byAdding: .hour, value: index, to: firstDate))
            context.insert(FlexibleJournalEntry(date: date, templateType: "reflection", responses: ["A note"]))
        }

        context.insert(Course(title: "CBT Path", itemIDs: ["lesson"], completedItemIDs: ["lesson"], completedAt: returnDate))
        context.insert(WeeklyRitualEntry(
            weekStart: returnDate,
            createdAt: returnDate,
            updatedAt: returnDate,
            intention: "",
            learning: "A small return helped."
        ))
        try context.save()

        AchievementService.shared.recordWeeklyReportViewed(in: context)
        AchievementService.shared.recordBadDayModeUsed(in: context)
        AchievementService.shared.evaluateAchievements(in: context)
        AchievementService.shared.evaluateAchievements(in: context)

        let achievements = try context.fetch(FetchDescriptor<Achievement>())
        let unlockedTitles = Set(achievements.filter(\.isUnlocked).map(\.title))
        let expectedUnlocked: Set<String> = [
            "First Check-In",
            "Returned After a Missed Day",
            "Gentle Restart",
            "You Came Back",
            "Return Streak",
            "Completed 3 Thought Records",
            "Tried 3 Coping Tools",
            "Completed a Weekly Review",
            "Finished a CBT Path",
            "Logged 7 Reflections",
            "Used Bad Day Mode"
        ]

        XCTAssertTrue(unlockedTitles.isSuperset(of: expectedUnlocked))
        for title in expectedUnlocked {
            XCTAssertEqual(achievements.filter { $0.title == title }.count, 1, "Expected one seeded achievement for \(title)")
        }
    }

    @MainActor
    func testAchievementMilestoneDetectionForDailyPlanAndCheckIns() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let day = Self.date(calendar, 2026, 5, 12, 9)

        context.insert(MoodCheckIn(createdAt: day, moodScore: 6))
        context.insert(MoodCheckIn(createdAt: day.addingTimeInterval(60), moodScore: 6))
        context.insert(MoodCheckIn(createdAt: day.addingTimeInterval(120), moodScore: 7))
        context.insert(ThoughtRecord(createdAt: day.addingTimeInterval(180), situation: "Work", intensityBefore: 60, intensityAfter: 40))
        context.insert(BreathingSession(createdAt: day.addingTimeInterval(240), durationSeconds: 60))
        try context.save()

        let unlocked = AchievementService.shared.evaluateAchievements(in: context).map(\.title)

        XCTAssertTrue(unlocked.contains("Daily Plan Complete"))
        XCTAssertTrue(unlocked.contains("Completed 3 Check-Ins"))
    }

    @MainActor
    func testAchievementDuplicatePreventionReturnsOnlyNewAwards() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        context.insert(MoodCheckIn(createdAt: Date(), moodScore: 6))
        try context.save()

        let firstUnlock = AchievementService.shared.evaluateAchievements(in: context)
        let secondUnlock = AchievementService.shared.evaluateAchievements(in: context)
        let achievements = try context.fetch(FetchDescriptor<Achievement>())

        XCTAssertTrue(firstUnlock.contains { $0.title == "First Check-In" })
        XCTAssertTrue(secondUnlock.isEmpty)
        XCTAssertEqual(achievements.filter { $0.title == "First Check-In" }.count, 1)
    }

    @MainActor
    func testReturnedAfterBreakAchievementUnlocksFromMissedDays() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let firstDate = Self.date(calendar, 2026, 5, 1, 9)
        let returnDate = Self.date(calendar, 2026, 5, 5, 9)

        context.insert(MoodCheckIn(createdAt: firstDate, moodScore: 5))
        context.insert(MoodCheckIn(createdAt: returnDate, moodScore: 6))
        try context.save()

        AchievementService.shared.evaluateAchievements(in: context)

        let achievements = try context.fetch(FetchDescriptor<Achievement>())
        let returned = try XCTUnwrap(achievements.first { $0.title == "Returned After a Missed Day" })
        let restart = try XCTUnwrap(achievements.first { $0.title == "Gentle Restart" })
        let cameBack = try XCTUnwrap(achievements.first { $0.title == "You Came Back" })

        XCTAssertTrue(returned.isUnlocked)
        XCTAssertTrue(restart.isUnlocked)
        XCTAssertTrue(cameBack.isUnlocked)
    }

    @MainActor
    func testAchievementPersistenceAcrossContexts() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)

        context.insert(BreathingSession(createdAt: Date(), durationSeconds: 60))
        try context.save()
        AchievementService.shared.evaluateAchievements(in: context)

        let reloadedContext = ModelContext(container)
        let achievements = try reloadedContext.fetch(FetchDescriptor<Achievement>())
        let firstReset = try XCTUnwrap(achievements.first { $0.title == "First Reset" })

        XCTAssertTrue(firstReset.isUnlocked)
        XCTAssertNotNil(firstReset.unlockedAt)
    }

    @MainActor
    func testAchievementMoodProgressDeduplicatesCurrentCheckInPairAndCountsLegacyEntries() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let legacyDate = Date(timeIntervalSince1970: 1_800_000_000)
        let pairedDate = legacyDate.addingTimeInterval(86_400)

        context.insert(MoodEntry(createdAt: legacyDate, moodScore: 5))
        context.insert(MoodEntry(createdAt: pairedDate, moodScore: 6))
        context.insert(MoodCheckIn(createdAt: pairedDate, moodScore: 6))
        try context.save()

        AchievementService.shared.evaluateAchievements(in: context)

        let progress = AchievementService.shared.progressSnapshots(in: context)
        XCTAssertEqual(progress["Mood Mapper"]?.completedValue, 2)
    }

    @MainActor
    func testAchievementStreakProgressUsesHistoricalBestRun() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let calendar = Self.weeklyReportCalendar
        let oldDate = Self.date(calendar, 2026, 1, 6, 9)

        for offset in 0..<3 {
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: oldDate))
            context.insert(BreathingSession(createdAt: date, durationSeconds: 120))
        }
        try context.save()

        AchievementService.shared.evaluateAchievements(in: context)

        let achievements = try context.fetch(FetchDescriptor<Achievement>())
        let threeDay = try XCTUnwrap(achievements.first { $0.title == "Three-Day Flame" })
        XCTAssertTrue(threeDay.isUnlocked)

        let progress = AchievementService.shared.progressSnapshots(in: context)
        XCTAssertEqual(progress["Steady Week"]?.completedValue, 3)
    }

    @MainActor
    func testOnboardingCompletedWithFirstWinSavesMoodCheckIn() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "onboarding-first-win-complete"))
        defaults.removePersistentDomain(forName: "onboarding-first-win-complete")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Self.date(calendar, 2026, 6, 2, 9)

        try FirstSessionWinService.complete(
            kind: .moodCheckIn,
            modelContext: context,
            moodScore: 7,
            defaults: defaults,
            now: now
        )

        XCTAssertTrue(defaults.bool(forKey: FirstSessionWinService.completedKey))
        XCTAssertEqual(defaults.string(forKey: FirstSessionWinService.completedKindKey), FirstSessionWinKind.moodCheckIn.rawValue)
        let checkIns = try context.fetch(FetchDescriptor<MoodCheckIn>())
        XCTAssertEqual(checkIns.count, 1)
        XCTAssertEqual(checkIns.first?.moodScore, 7)
        XCTAssertEqual(checkIns.first?.createdAt, now)
    }

    @MainActor
    func testOnboardingSkippedWithoutFirstWinDoesNotPersistActionRecords() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "onboarding-first-win-skip"))
        defaults.removePersistentDomain(forName: "onboarding-first-win-skip")

        FirstSessionWinService.skip(defaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: FirstSessionWinService.completedKey))
        XCTAssertNil(defaults.string(forKey: FirstSessionWinService.completedKindKey))
        XCTAssertEqual(try context.fetch(FetchDescriptor<MoodCheckIn>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<BreathingSession>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlannedActivity>()).count, 0)
    }

    @MainActor
    func testOnboardingFirstWinPersistenceCoversBreathingAndDailyPlan() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "onboarding-first-win-persistence"))
        defaults.removePersistentDomain(forName: "onboarding-first-win-persistence")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Self.date(calendar, 2026, 6, 2, 10)

        try FirstSessionWinService.complete(
            kind: .breathing,
            modelContext: context,
            defaults: defaults,
            now: now
        )
        try FirstSessionWinService.complete(
            kind: .todaysPlan,
            modelContext: context,
            planTitle: "Step outside for a minute",
            defaults: defaults,
            now: now.addingTimeInterval(60)
        )

        let breathingSessions = try context.fetch(FetchDescriptor<BreathingSession>())
        XCTAssertEqual(breathingSessions.count, 1)
        XCTAssertEqual(breathingSessions.first?.durationSeconds, 60)
        XCTAssertEqual(breathingSessions.first?.createdAt, now)

        let activities = try context.fetch(FetchDescriptor<PlannedActivity>())
        XCTAssertEqual(activities.count, 1)
        XCTAssertEqual(activities.first?.title, "Step outside for a minute")
        XCTAssertTrue((activities.first?.notes ?? "").contains(FirstSessionWinService.dailyPlanMarker))
    }

    @MainActor
    func testOnboardingMoodCheckInDoesNotDuplicateTodayCheckIn() throws {
        let container = try SharedPersistence.makeInMemoryModelContainer()
        let context = ModelContext(container)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "onboarding-first-win-no-duplicate"))
        defaults.removePersistentDomain(forName: "onboarding-first-win-no-duplicate")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let existingDate = Self.date(calendar, 2026, 6, 2, 8)
        let refreshedDate = Self.date(calendar, 2026, 6, 2, 18)
        context.insert(MoodCheckIn(createdAt: existingDate, moodScore: 4, notes: "Morning"))
        try context.save()

        try FirstSessionWinService.complete(
            kind: .moodCheckIn,
            modelContext: context,
            moodScore: 8,
            defaults: defaults,
            now: refreshedDate
        )

        let checkIns = try context.fetch(FetchDescriptor<MoodCheckIn>())
        XCTAssertEqual(checkIns.count, 1)
        XCTAssertEqual(checkIns.first?.moodScore, 8)
        XCTAssertEqual(checkIns.first?.createdAt, refreshedDate)
        XCTAssertEqual(checkIns.first?.notes, "Morning")
    }

    func testWelcomeBackRecoveryDoesNotShowUnderThreeMissedDays() throws {
        let calendar = Self.weeklyReportCalendar
        let today = Self.date(calendar, 2026, 6, 10, 9)
        let state = WelcomeBackRecoveryState.make(
            missedDays: 2,
            selectedDate: today,
            activeDates: [],
            completedDayKey: "",
            calendar: calendar
        )

        XCTAssertNil(state)
    }

    func testWelcomeBackRecoveryShowsAfterThreeOrMoreMissedDays() throws {
        let calendar = Self.weeklyReportCalendar
        let today = Self.date(calendar, 2026, 6, 10, 9)
        let lastActiveDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -4, to: today))
        let state = WelcomeBackRecoveryState.make(
            missedDays: 3,
            selectedDate: today,
            activeDates: [lastActiveDay],
            completedDayKey: "",
            calendar: calendar
        )

        XCTAssertEqual(state?.missedDays, 3)
        XCTAssertEqual(state?.tinyActionSuggestion, "Take one minute to check in with today.")
    }

    func testWelcomeBackRecoveryCompletionHidesStateForToday() throws {
        let calendar = Self.weeklyReportCalendar
        let today = Self.date(calendar, 2026, 6, 10, 9)
        let completedKey = WelcomeBackRecoveryState.completedDayKey(
            after: .resumePreviousPlan,
            on: today,
            calendar: calendar
        )

        let state = WelcomeBackRecoveryState.make(
            missedDays: 4,
            selectedDate: today,
            activeDates: [],
            completedDayKey: completedKey,
            calendar: calendar
        )

        XCTAssertNil(state)
    }

    func testWelcomeBackRecoveryDoesNotMutateStreakInputs() throws {
        let calendar = Self.weeklyReportCalendar
        let today = Self.date(calendar, 2026, 6, 10, 9)
        let oldDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -5, to: today))
        let activeDates: Set<Date> = [oldDay]

        let state = WelcomeBackRecoveryState.make(
            missedDays: 4,
            selectedDate: today,
            activeDates: activeDates,
            completedDayKey: "",
            calendar: calendar
        )

        XCTAssertEqual(activeDates, [oldDay])
        XCTAssertTrue(state?.streakWasBroken == true)
        XCTAssertEqual(state?.gentleStreakMessage, "The earlier run can rest. Today can simply be a fresh start.")
    }

    func testWelcomeBackRecoveryStartFreshCompletesTodayOnly() throws {
        let calendar = Self.weeklyReportCalendar
        let today = Self.date(calendar, 2026, 6, 10, 9)
        let completedKey = WelcomeBackRecoveryState.completedDayKey(
            after: .startFreshToday,
            on: today,
            calendar: calendar
        )

        XCTAssertEqual(completedKey, WelcomeBackRecoveryState.dayKey(for: today, calendar: calendar))
        XCTAssertNil(WelcomeBackRecoveryState.make(
            missedDays: 5,
            selectedDate: today,
            activeDates: [],
            completedDayKey: completedKey,
            calendar: calendar
        ))
    }

    private func makeReminderOptInDefaults(named name: String) -> UserDefaults {
        let suiteName = "ReminderOptIn-\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private static var weeklyReportCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private static func date(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @MainActor
    private func seedWeeklyPDFReportData(
        in context: ModelContext,
        calendar: Calendar,
        weekStart: Date
    ) throws {
        let dayOne = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: weekStart))
        let dayTwo = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: weekStart))
        let outsideWeek = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: weekStart))

        context.insert(MoodEntry(
            createdAt: dayOne,
            moodScore: 4,
            emotions: ["Anxious"],
            triggers: ["Work"],
            activityTags: ["Walking"],
            notes: "private mood note",
            intensity: 80
        ))
        context.insert(MoodCheckIn(createdAt: dayTwo, moodScore: 6, notes: "private quick note"))
        context.insert(MoodEntry(createdAt: outsideWeek, moodScore: 1, emotions: ["Sad"], triggers: ["Outside"], intensity: 90))
        context.insert(ThoughtRecord(
            createdAt: dayOne,
            situation: "private situation",
            automaticThought: "private automatic thought",
            emotions: ["Worried"],
            distortions: ["Catastrophizing"],
            balancedThought: "private balanced thought",
            intensityBefore: 80,
            intensityAfter: 60
        ))
        context.insert(JournalEntry(
            createdAt: dayTwo,
            title: "Private Journal",
            body: "private journal body"
        ))
        context.insert(FlexibleJournalEntry(
            date: dayTwo,
            templateType: "gratitude",
            responses: ["private guided response"]
        ))
        context.insert(BreathingSession(createdAt: dayTwo, durationSeconds: 120))
        context.insert(PlannedActivity(
            createdAt: dayOne,
            title: "Walk",
            category: "Physical",
            scheduledDate: dayOne,
            actualEnjoyment: 8,
            isCompleted: true,
            completedAt: dayTwo
        ))
        try context.save()
    }
}
