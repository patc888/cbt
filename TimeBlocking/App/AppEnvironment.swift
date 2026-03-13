import Foundation
import Observation
import SwiftData

enum AppBootstrapState: String {
    case empty
    case sample
}

@MainActor
@Observable
final class AppEnvironment {
    let persistenceController: PersistenceController
    let preferencesStore: AppPreferencesStore
    let scheduleRepository: ScheduleRepository
    let timeCalendarManager: TimeCalendarManager
    let timeNotificationManager: TimeNotificationManager
    let widgetSnapshotManager: TimeWidgetSnapshotManager
    let subscriptionStore: TimeSubscriptionStore
    let appState: TimeAppState

    private let bootstrapStateKey = "timeblocking.bootstrap-state"
    private var hasPreparedPersistentState = false

    init(
        persistenceController: PersistenceController? = nil,
        preferencesStore: AppPreferencesStore? = nil,
        scheduleRepository: ScheduleRepository? = nil,
        timeCalendarManager: TimeCalendarManager? = nil,
        timeNotificationManager: TimeNotificationManager? = nil,
        widgetSnapshotManager: TimeWidgetSnapshotManager? = nil,
        subscriptionStore: TimeSubscriptionStore? = nil,
        appState: TimeAppState? = nil
    ) {
        let resolvedScheduleRepository = scheduleRepository ?? ScheduleRepository()

        self.persistenceController = persistenceController ?? .shared
        self.preferencesStore = preferencesStore ?? AppPreferencesStore()
        self.scheduleRepository = resolvedScheduleRepository
        self.timeCalendarManager = timeCalendarManager ?? TimeCalendarManager()
        self.timeNotificationManager = timeNotificationManager ?? TimeNotificationManager()
        self.widgetSnapshotManager = widgetSnapshotManager ?? TimeWidgetSnapshotManager(
            repository: resolvedScheduleRepository
        )
        self.subscriptionStore = subscriptionStore ?? TimeSubscriptionStore(config: .time)
        self.appState = appState ?? TimeAppState()
    }

    func prepareIfNeeded(using modelContext: ModelContext) {
        guard !hasPreparedPersistentState else {
            return
        }

        do {
            let preferences = try preferencesStore.fetchOrCreate(in: modelContext)
            try seedSampleDataOnFirstLaunchIfNeeded(using: preferences, modelContext: modelContext)
            refreshWidgets(using: modelContext)
            hasPreparedPersistentState = true
            Task {
                await resyncNotifications(using: modelContext, preferences: preferences)
            }
        } catch {
            assertionFailure("Failed to prepare app foundation: \(error)")
        }
    }

    func resetAllDataToEmpty(using modelContext: ModelContext) throws {
        let preferences = try preferencesStore.fetchOrCreate(in: modelContext)
        try deleteAllScheduleData(in: modelContext)
        applyDefaultPreferences(to: preferences)
        try preferencesStore.save(preferences, in: modelContext)
        storeBootstrapState(.empty)
        refreshWidgets(using: modelContext)

        Task {
            await resyncNotifications(using: modelContext, preferences: preferences)
        }
    }

    func resetAllDataToSample(using modelContext: ModelContext) throws {
        let preferences = try preferencesStore.fetchOrCreate(in: modelContext)
        try deleteAllScheduleData(in: modelContext)
        try seedSampleData(using: preferences, modelContext: modelContext)
        storeBootstrapState(.sample)
        refreshWidgets(using: modelContext)

        Task {
            await resyncNotifications(using: modelContext, preferences: preferences)
        }
    }

    func generateScheduleIfNeeded(for date: Date, using modelContext: ModelContext) {
        do {
            try scheduleRepository.generateBlocksIfNeeded(for: date, in: modelContext)
            refreshWidgets(using: modelContext)
            Task {
                await resyncNotifications(using: modelContext)
            }
        } catch {
            assertionFailure("Failed to generate schedule blocks: \(error)")
        }
    }

    func syncReminder(for block: TimeBlock, using modelContext: ModelContext) async {
        guard let preferences = try? preferencesStore.fetchOrCreate(in: modelContext) else {
            refreshWidgets(using: modelContext)
            return
        }

        await timeNotificationManager.scheduleReminder(for: block, preferences: preferences)
        refreshWidgets(using: modelContext)
    }

    func cancelReminder(for block: TimeBlock, using modelContext: ModelContext) async {
        timeNotificationManager.cancelReminder(for: block)
        refreshWidgets(using: modelContext)
    }

    func cancelReminder(forBlockID blockID: UUID, using modelContext: ModelContext) async {
        timeNotificationManager.cancelReminder(forBlockID: blockID)
        refreshWidgets(using: modelContext)
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
        refreshWidgets(using: modelContext)
    }

    func refreshWidgets(using modelContext: ModelContext) {
        do {
            try widgetSnapshotManager.refresh(using: modelContext)
        } catch {
            assertionFailure("Failed to refresh widget snapshot: \(error)")
        }
    }

    private func seedSampleDataOnFirstLaunchIfNeeded(
        using preferences: AppPreferences,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        guard try isEffectivelyEmpty(modelContext: modelContext) else {
            return
        }

        guard bootstrapState == nil else {
            return
        }

        try seedSampleData(using: preferences, modelContext: modelContext, calendar: calendar)
        storeBootstrapState(.sample)
    }

    private func isEffectivelyEmpty(modelContext: ModelContext) throws -> Bool {
        var templateDescriptor = FetchDescriptor<ScheduleTemplate>()
        templateDescriptor.fetchLimit = 1

        var blockDescriptor = FetchDescriptor<TimeBlock>()
        blockDescriptor.fetchLimit = 1

        let hasTemplates = try !modelContext.fetch(templateDescriptor).isEmpty
        let hasBlocks = try !modelContext.fetch(blockDescriptor).isEmpty
        return !hasTemplates && !hasBlocks
    }

    private func seedSampleData(
        using preferences: AppPreferences,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        applySamplePreferences(to: preferences)
        try preferencesStore.save(preferences, in: modelContext)

        let today = calendar.startOfDay(for: .now)
        let weekdayMask = weekdayMask(for: [.monday, .tuesday, .wednesday, .thursday, .friday])

        _ = try scheduleRepository.createTemplate(
            name: "Morning Planning",
            notes: "Reusable weekday routine that can be regenerated onto future days.",
            defaultStartTime: time(hour: 8, minute: 30, on: today, calendar: calendar),
            durationMinutes: 30,
            weekdayMask: weekdayMask,
            category: .routine,
            in: modelContext,
            calendar: calendar
        )

        try scheduleRepository.generateBlocksIfNeeded(for: today, in: modelContext, calendar: calendar)

        _ = try scheduleRepository.createBlock(
            title: "Focus Sprint: Project Proposal",
            notes: "A realistic focused work block you can drag to another time if the day changes.",
            date: today,
            startTime: time(hour: 9, minute: 30, on: today, calendar: calendar),
            durationMinutes: 90,
            category: .focus,
            in: modelContext,
            calendar: calendar
        )

        let prepBlock = try scheduleRepository.createBlock(
            title: "Prep for Team Check-In",
            notes: "Example block with a checklist so the day view demonstrates step-by-step progress.",
            date: today,
            startTime: time(hour: 11, minute: 30, on: today, calendar: calendar),
            durationMinutes: 30,
            category: .admin,
            checklistItemTitles: [
                "Review agenda",
                "Update blockers",
                "Capture next actions"
            ],
            in: modelContext,
            calendar: calendar
        )

        if let firstChecklistItem = prepBlock.checklistItems?.sorted(by: { $0.sortOrder < $1.sortOrder }).first {
            firstChecklistItem.isCompleted = true
            firstChecklistItem.updatedAt = .now
        }

        let walkBlock = try scheduleRepository.createBlock(
            title: "Lunch Walk",
            notes: "Completed example block to show progress and finished work in the schedule.",
            date: today,
            startTime: time(hour: 13, minute: 0, on: today, calendar: calendar),
            durationMinutes: 30,
            category: .personal,
            in: modelContext,
            calendar: calendar
        )
        try scheduleRepository.setBlockStatus(walkBlock, to: .completed, in: modelContext)
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
        preferences.selectedColorTheme = .purple
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
        preferences.selectedColorTheme = .purple
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
