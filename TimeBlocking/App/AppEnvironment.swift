import Foundation
import Observation
import os
import SwiftData

private let logger = Logger(subsystem: "com.melichan.TimeBlocking", category: "AppEnvironment")

enum AppBootstrapState: String {
    case empty
    case sample
}

@MainActor
@Observable
final class AppEnvironment {
    private(set) var persistenceController: PersistenceController?
    private(set) var isReady = false

    let preferencesStore: AppPreferencesStore
    let scheduleRepository: ScheduleRepository
    let timeCalendarManager: TimeCalendarManager
    let timeNotificationManager: TimeNotificationManager
    let appState: TimeAppState

    var isFallback: Bool {
        persistenceController?.isFallback ?? false
    }

    private let bootstrapStateKey = "timeblocking.bootstrap-state"
    private var isInitializing = false

    init(
        persistenceController: PersistenceController? = nil,
        preferencesStore: AppPreferencesStore? = nil,
        scheduleRepository: ScheduleRepository? = nil,
        timeCalendarManager: TimeCalendarManager? = nil,
        timeNotificationManager: TimeNotificationManager? = nil,
        appState: TimeAppState? = nil
    ) {
        let resolvedScheduleRepository = scheduleRepository ?? ScheduleRepository()

        self.persistenceController = persistenceController
        self.preferencesStore = preferencesStore ?? AppPreferencesStore()
        self.scheduleRepository = resolvedScheduleRepository
        self.timeCalendarManager = timeCalendarManager ?? TimeCalendarManager()
        self.timeNotificationManager = timeNotificationManager ?? TimeNotificationManager()
        self.appState = appState ?? TimeAppState()

        // If a controller was provided (e.g. preview), we're immediately ready
        if persistenceController != nil {
            self.isReady = true
        }
    }

    func initialize() async {
        guard !isReady, !isInitializing else { return }
        isInitializing = true

        defer {
            isInitializing = false
        }

        do {
            logger.info("Starting async app environment initialization...")
            let controller = try await PersistenceController.createAsync()
            self.persistenceController = controller

            // Background bootstrap tasks
            let bootstrapActor = BootstrapActor(modelContainer: controller.container)
            try await bootstrapActor.prepareAppFoundation(
                preferencesStore: preferencesStore,
                scheduleRepository: scheduleRepository,
                notificationManager: timeNotificationManager
            )

            self.isReady = true
            syncPreferencesToUserDefaults(using: controller.container.mainContext)
            logger.info("App environment initialization finished successfully.")

        } catch {
            logger.error("Failed to initialize app environment: \(error)")
            // Fallback to a guaranteed (in-memory) state if even createAsync fails catastrophically
            if persistenceController == nil {
                self.persistenceController = .shared // This is the old sync fallback
                self.isReady = true
            }
        }
    }

    func prepareIfNeeded(using modelContext: ModelContext) async throws {
        let bootstrapActor = BootstrapActor(modelContainer: modelContext.container)
        try await bootstrapActor.prepareAppFoundation(
            preferencesStore: preferencesStore,
            scheduleRepository: scheduleRepository,
            notificationManager: timeNotificationManager
        )
        syncPreferencesToUserDefaults(using: modelContext)
    }

    func resetAllDataToEmpty(using modelContext: ModelContext) async throws {
        let preferences = try preferencesStore.fetchOrCreate(in: modelContext)
        try deleteAllScheduleData(in: modelContext)
        applyDefaultPreferences(to: preferences)
        try preferencesStore.save(preferences, in: modelContext)
        storeBootstrapState(.empty)

        await resyncNotifications(using: modelContext, preferences: preferences)
    }

    func resetAllDataToSample(using modelContext: ModelContext) async throws {
        let preferences = try preferencesStore.fetchOrCreate(in: modelContext)
        try deleteAllScheduleData(in: modelContext)

        let actor = BootstrapActor(modelContainer: modelContext.container)
        try await actor.seedSampleData(preferences: preferences, scheduleRepository: scheduleRepository)

        storeBootstrapState(.sample)

        await resyncNotifications(using: modelContext, preferences: preferences)
    }

    func generateScheduleIfNeeded(for date: Date, using modelContext: ModelContext) {
        do {
            try scheduleRepository.generateBlocksIfNeeded(for: date, in: modelContext)
            Task {
                await resyncNotifications(using: modelContext)
            }
        } catch {
            logger.error("Failed to generate schedule blocks: \(error)")
        }
    }

    func syncPreferencesToUserDefaults(using modelContext: ModelContext) {
        guard let prefs = try? preferencesStore.fetchOrCreate(in: modelContext) else { return }

        UserDefaults.standard.set(prefs.selectedColorTheme?.rawValue, forKey: "appColorTheme")
        UserDefaults.standard.set(prefs.isImmersive ?? true, forKey: "appThemeImmersive")
        UserDefaults.standard.set(prefs.appTheme?.rawValue, forKey: "userTheme")
        UserDefaults.standard.set(prefs.hapticsEnabled ?? true, forKey: "hapticsEnabled")
    }


    func syncReminder(for block: TimeBlock, using modelContext: ModelContext) async {
        guard let preferences = try? preferencesStore.fetchOrCreate(in: modelContext) else {
            return
        }

        await timeNotificationManager.scheduleReminder(for: block, preferences: preferences)
    }

    func cancelReminder(for block: TimeBlock, using modelContext: ModelContext) async {
        timeNotificationManager.cancelReminder(for: block)
    }

    func cancelReminder(forBlockID blockID: UUID, using modelContext: ModelContext) async {
        timeNotificationManager.cancelReminder(forBlockID: blockID)
    }

    func resyncNotifications(
        using modelContext: ModelContext,
        preferences: AppPreferences? = nil
    ) async {
        let resolvedPreferences: AppPreferences
        if let preferences {
            resolvedPreferences = preferences
        } else if let fetchedPreferences = try? preferencesStore.fetchOrCreate(in: modelContext) {
            resolvedPreferences = fetchedPreferences
        } else {
            return
        }

        await timeNotificationManager.resyncUpcomingReminders(
            in: modelContext,
            preferences: resolvedPreferences
        )
    }



    private func deleteAllScheduleData(in modelContext: ModelContext) throws {
        try modelContext.delete(model: TimeBlock.self)
        try modelContext.delete(model: ScheduleTemplate.self)
        try modelContext.delete(model: BlockChecklistItem.self)
        try modelContext.save()
    }

    private func applyDefaultPreferences(to preferences: AppPreferences) {
        preferences.defaultBlockDurationMinutes = 60
        preferences.dayStartHour = 6
        preferences.firstWeekday = .monday
        preferences.notificationsEnabled = false
        preferences.notificationLeadTimeMinutes = 0
        preferences.showsCompletedBlocks = true
        preferences.appTheme = .system
        preferences.selectedColorTheme = .red
        preferences.isImmersive = true
        preferences.hapticsEnabled = true
    }

    private func applySamplePreferences(to preferences: AppPreferences) {
        preferences.notificationsEnabled = false
        preferences.notificationLeadTimeMinutes = 0
        preferences.defaultBlockDurationMinutes = 45
        preferences.dayStartHour = 7
        preferences.firstWeekday = .monday
        preferences.showsCompletedBlocks = false
        preferences.appTheme = .system
        preferences.selectedColorTheme = .red
        preferences.isImmersive = true
        preferences.hapticsEnabled = true
    }

    private var bootstrapState: AppBootstrapState? {
        guard let rawValue = UserDefaults.standard.string(forKey: bootstrapStateKey) else {
            return nil
        }

        return AppBootstrapState(rawValue: rawValue)
    }

    private func storeBootstrapState(_ state: AppBootstrapState) {
        UserDefaults.standard.set(state.rawValue, forKey: bootstrapStateKey)
    }

    private func weekdayMask(for weekdays: [Weekday]) -> Int {
        weekdays.reduce(into: 0) { partialResult, weekday in
            partialResult |= 1 << (weekday.rawValue - 1)
        }
    }

    private func time(hour: Int, minute: Int, on date: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }
}
