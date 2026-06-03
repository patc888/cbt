import Foundation
import os
import SwiftData

enum RetentionEventName: String, CaseIterable, Sendable {
    case appOpened = "app_opened"
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
    case onboardingSkipped = "onboarding_skipped"
    case firstMoodCheckInCompleted = "first_mood_check_in_completed"
    case firstDailyPlanItemCompleted = "first_daily_plan_item_completed"
    case dailyPlanCompleted = "daily_plan_completed"
    case reminderPromptShown = "reminder_prompt_shown"
    case notificationPermissionRequested = "notification_permission_requested"
    case notificationPermissionGranted = "notification_permission_granted"
    case notificationPermissionDenied = "notification_permission_denied"
    case weeklyReportViewed = "weekly_report_viewed"
    case streakStarted = "streak_started"
    case streakBroken = "streak_broken"
    case streakRecovered = "streak_recovered"
    case welcomeBackRecoveryViewed = "welcome_back_recovery_viewed"
    case welcomeBackRecoveryCompleted = "welcome_back_recovery_completed"
    case achievementUnlocked = "achievement_unlocked"
    case paywallShown = "paywall_shown"
    case purchaseCompleted = "purchase_completed"
    case purchaseRestored = "purchase_restored"
}

struct RetentionAggregationSnapshot: Equatable, Sendable {
    let eventCount: Int
    let onboardingStarted: Int
    let onboardingCompleted: Int
    let onboardingSkipped: Int
    let firstSessionActivated: Bool
    let firstMoodCheckInCompleted: Bool
    let returnedD1: Bool
    let returnedD3: Bool
    let returnedD7: Bool
    let notificationPromptShown: Int
    let notificationPermissionRequested: Int
    let notificationPermissionGranted: Int
    let notificationPermissionDenied: Int
    let firstDailyPlanItemCompleted: Int
    let dailyPlanCompleted: Int
    let weeklyReportViewed: Int
    let streakStarted: Int
    let streakBroken: Int
    let streakRecovered: Int
    let achievementsUnlocked: Int
    let paywallShown: Int
    let purchaseCompleted: Int
    let purchaseRestored: Int
}

struct LocalRetentionEventStore {
    static let shared = LocalRetentionEventStore()

    nonisolated private static let storeFileName = "local-retention.store"
    private let container: ModelContainer?
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    init(
        containerProvider: @escaping @Sendable () throws -> ModelContainer = LocalRetentionEventStore.makeContainer,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        do {
            self.container = try containerProvider()
        } catch {
            AppLogger.make(category: "Retention").error("Failed to initialize ModelContainer: \(error.localizedDescription, privacy: .private)")
            self.container = nil
        }
        self.calendar = calendar
        self.now = now
    }

    @MainActor
    private func getContext() throws -> ModelContext {
        guard let container = container else {
            throw NSError(domain: "LocalRetentionEventStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "ModelContainer not initialized"])
        }
        return container.mainContext
    }

    @MainActor
    func record(
        _ eventName: RetentionEventName,
        sourceScreen: String? = nil,
        metadata: [String: String] = [:],
        timestamp: Date? = nil
    ) {
        do {
            let context = try getContext()
            context.insert(RetentionEvent(
                eventName: eventName.rawValue,
                timestamp: timestamp ?? now(),
                metadata: sanitized(metadata),
                sourceScreen: sourceScreen
            ))
            try context.save()
        } catch {
            AppLogger.make(category: "Retention").error("Failed to record local retention event: \(error.localizedDescription, privacy: .private)")
        }
    }

    @MainActor
    func recordOnce(
        _ eventName: RetentionEventName,
        sourceScreen: String? = nil,
        metadata: [String: String] = [:],
        timestamp: Date? = nil
    ) {
        do {
            let context = try getContext()
            let rawName = eventName.rawValue
            var descriptor = FetchDescriptor<RetentionEvent>(
                predicate: #Predicate { $0.eventName == rawName }
            )
            descriptor.fetchLimit = 1
            guard try context.fetch(descriptor).isEmpty else { return }
            context.insert(RetentionEvent(
                eventName: rawName,
                timestamp: timestamp ?? now(),
                metadata: sanitized(metadata),
                sourceScreen: sourceScreen
            ))
            try context.save()
        } catch {
            AppLogger.make(category: "Retention").error("Failed to record one-time local retention event: \(error.localizedDescription, privacy: .private)")
        }
    }

    @MainActor
    func recordOncePerDay(
        _ eventName: RetentionEventName,
        sourceScreen: String? = nil,
        metadata: [String: String] = [:],
        timestamp: Date? = nil
    ) {
        do {
            let context = try getContext()
            let date = timestamp ?? now()
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
            let rawName = eventName.rawValue
            var descriptor = FetchDescriptor<RetentionEvent>(
                predicate: #Predicate {
                    $0.eventName == rawName &&
                    $0.timestamp >= dayStart &&
                    $0.timestamp < dayEnd
                }
            )
            descriptor.fetchLimit = 1
            guard try context.fetch(descriptor).isEmpty else { return }
            context.insert(RetentionEvent(
                eventName: rawName,
                timestamp: date,
                metadata: sanitized(metadata),
                sourceScreen: sourceScreen
            ))
            try context.save()
        } catch {
            AppLogger.make(category: "Retention").error("Failed to record daily local retention event: \(error.localizedDescription, privacy: .private)")
        }
    }

    @MainActor
    func events() throws -> [RetentionEvent] {
        let context = try getContext()
        return try context.fetch(FetchDescriptor<RetentionEvent>(sortBy: [
            SortDescriptor(\.timestamp, order: .reverse)
        ]))
    }

    @MainActor
    func clearAll() throws {
        let context = try getContext()
        try context.delete(model: RetentionEvent.self)
        try context.save()
    }

    @MainActor
    func exportData() throws -> Data {
        let payload = try events()
            .sorted { $0.timestamp < $1.timestamp }
            .map(LocalRetentionEventExport.init(event:))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    @MainActor
    func aggregationSnapshot() throws -> RetentionAggregationSnapshot {
        try Self.aggregate(events: events(), calendar: calendar)
    }

    static func aggregate(events: [RetentionEvent], calendar: Calendar = .current) -> RetentionAggregationSnapshot {
        let sorted = events.sorted { $0.timestamp < $1.timestamp }
        let names = sorted.map(\.eventName)
        let counts = Dictionary(grouping: names, by: { $0 }).mapValues(\.count)

        let activationNames: Set<String> = [
            RetentionEventName.onboardingCompleted.rawValue,
            RetentionEventName.onboardingSkipped.rawValue,
            RetentionEventName.firstMoodCheckInCompleted.rawValue,
            RetentionEventName.firstDailyPlanItemCompleted.rawValue,
            RetentionEventName.dailyPlanCompleted.rawValue
        ]

        let firstSessionID = sorted.first?.sessionID
        let firstSessionActivated = sorted.contains { event in
            event.sessionID == firstSessionID && activationNames.contains(event.eventName)
        }

        let activeDays = Set(sorted.map { calendar.startOfDay(for: $0.timestamp) }).sorted()
        let firstDay = activeDays.first
        let streakCounts = derivedStreakCounts(from: activeDays, calendar: calendar)

        func returned(dayOffset: Int) -> Bool {
            guard let firstDay,
                  let target = calendar.date(byAdding: .day, value: dayOffset, to: firstDay) else {
                return false
            }
            return activeDays.contains(target)
        }

        return RetentionAggregationSnapshot(
            eventCount: sorted.count,
            onboardingStarted: counts[RetentionEventName.onboardingStarted.rawValue] ?? 0,
            onboardingCompleted: counts[RetentionEventName.onboardingCompleted.rawValue] ?? 0,
            onboardingSkipped: counts[RetentionEventName.onboardingSkipped.rawValue] ?? 0,
            firstSessionActivated: firstSessionActivated,
            firstMoodCheckInCompleted: (counts[RetentionEventName.firstMoodCheckInCompleted.rawValue] ?? 0) > 0,
            returnedD1: returned(dayOffset: 1),
            returnedD3: returned(dayOffset: 3),
            returnedD7: returned(dayOffset: 7),
            notificationPromptShown: counts[RetentionEventName.reminderPromptShown.rawValue] ?? 0,
            notificationPermissionRequested: counts[RetentionEventName.notificationPermissionRequested.rawValue] ?? 0,
            notificationPermissionGranted: counts[RetentionEventName.notificationPermissionGranted.rawValue] ?? 0,
            notificationPermissionDenied: counts[RetentionEventName.notificationPermissionDenied.rawValue] ?? 0,
            firstDailyPlanItemCompleted: counts[RetentionEventName.firstDailyPlanItemCompleted.rawValue] ?? 0,
            dailyPlanCompleted: counts[RetentionEventName.dailyPlanCompleted.rawValue] ?? 0,
            weeklyReportViewed: counts[RetentionEventName.weeklyReportViewed.rawValue] ?? 0,
            streakStarted: (counts[RetentionEventName.streakStarted.rawValue] ?? 0) + streakCounts.started,
            streakBroken: (counts[RetentionEventName.streakBroken.rawValue] ?? 0) + streakCounts.broken,
            streakRecovered: (counts[RetentionEventName.streakRecovered.rawValue] ?? 0) + streakCounts.recovered,
            achievementsUnlocked: counts[RetentionEventName.achievementUnlocked.rawValue] ?? 0,
            paywallShown: counts[RetentionEventName.paywallShown.rawValue] ?? 0,
            purchaseCompleted: counts[RetentionEventName.purchaseCompleted.rawValue] ?? 0,
            purchaseRestored: counts[RetentionEventName.purchaseRestored.rawValue] ?? 0
        )
    }

    private static func derivedStreakCounts(from activeDays: [Date], calendar: Calendar) -> (started: Int, broken: Int, recovered: Int) {
        guard !activeDays.isEmpty else { return (0, 0, 0) }
        var broken = 0
        var recovered = 0

        for index in 1..<activeDays.count {
            let gap = calendar.dateComponents([.day], from: activeDays[index - 1], to: activeDays[index]).day ?? 0
            if gap > 1 {
                broken += 1
                recovered += 1
            }
        }

        return (1, broken, recovered)
    }

    private func sanitized(_ metadata: [String: String]) -> [String: String] {
        metadata.reduce(into: [:]) { result, pair in
            let key = pair.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !Self.blockedMetadataKeys.contains(key.lowercased()) else { return }
            result[key] = String(pair.value.prefix(80))
        }
    }

    private static let blockedMetadataKeys: Set<String> = [
        "journal", "text", "thought", "note", "notes", "body", "entry", "content", "automaticthought", "balancedthought"
    ]

    nonisolated static func makeContainer() throws -> ModelContainer {
        let schema = Schema([RetentionEvent.self])
        let storeURL = defaultStoreURL
        if let storeURL {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }
        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(
                "LocalRetention",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                "LocalRetention",
                schema: schema,
                cloudKitDatabase: .none
            )
        }

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    nonisolated private static var defaultStoreURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConfiguration.appGroupIdentifier)?
            .appendingPathComponent(storeFileName)
    }
}

private struct LocalRetentionEventExport: Codable {
    let id: UUID
    let eventName: String
    let timestamp: Date
    let metadata: [String: String]
    let sourceScreen: String?
    let appVersion: String?
    let sessionID: String?

    init(event: RetentionEvent) {
        id = event.id
        eventName = event.eventName
        timestamp = event.timestamp
        metadata = event.metadata
        sourceScreen = event.sourceScreen
        appVersion = event.appVersion
        sessionID = event.sessionID
    }
}
