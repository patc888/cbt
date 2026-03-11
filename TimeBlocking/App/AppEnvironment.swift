import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppEnvironment {
    let persistenceController: PersistenceController
    let preferencesStore: AppPreferencesStore
    let scheduleRepository: ScheduleRepository
    let subscriptionStore: TimeSubscriptionStore
    let appState: TimeAppState

    private var hasPreparedPersistentState = false

    init(
        persistenceController: PersistenceController? = nil,
        preferencesStore: AppPreferencesStore? = nil,
        scheduleRepository: ScheduleRepository? = nil,
        subscriptionStore: TimeSubscriptionStore? = nil,
        appState: TimeAppState? = nil
    ) {
        self.persistenceController = persistenceController ?? .shared
        self.preferencesStore = preferencesStore ?? AppPreferencesStore()
        self.scheduleRepository = scheduleRepository ?? ScheduleRepository()
        self.subscriptionStore = subscriptionStore ?? TimeSubscriptionStore(config: .time)
        self.appState = appState ?? TimeAppState()
    }

    func prepareIfNeeded(using modelContext: ModelContext) {
        guard !hasPreparedPersistentState else {
            return
        }

        do {
            let preferences = try preferencesStore.fetchOrCreate(in: modelContext)
            try seedSampleDataIfNeeded(using: preferences, modelContext: modelContext)
            hasPreparedPersistentState = true
        } catch {
            assertionFailure("Failed to prepare app foundation: \(error)")
        }
    }

    func generateScheduleIfNeeded(for date: Date, using modelContext: ModelContext) {
        do {
            try scheduleRepository.generateBlocksIfNeeded(for: date, in: modelContext)
        } catch {
            assertionFailure("Failed to generate schedule blocks: \(error)")
        }
    }

    private func seedSampleDataIfNeeded(
        using preferences: AppPreferences,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        guard try isEffectivelyEmpty(modelContext: modelContext) else {
            return
        }

        applySamplePreferences(to: preferences)
        try preferencesStore.save(preferences, in: modelContext)

        let weekdayMask = weekdayMask(for: [.monday, .tuesday, .wednesday, .thursday, .friday])
        let day = calendar.startOfDay(for: .now)

        _ = try scheduleRepository.createTemplate(
            name: "Morning Planning",
            notes: "Quick review of priorities and the day's schedule.",
            defaultStartTime: time(hour: 8, minute: 0, on: day, calendar: calendar),
            durationMinutes: 30,
            weekdayMask: weekdayMask,
            category: .routine,
            in: modelContext,
            calendar: calendar
        )
        _ = try scheduleRepository.createTemplate(
            name: "Focus Work",
            notes: "Example template: generated blocks like this come from reusable routines.",
            defaultStartTime: time(hour: 9, minute: 0, on: day, calendar: calendar),
            durationMinutes: 120,
            weekdayMask: weekdayMask,
            category: .focus,
            in: modelContext,
            calendar: calendar
        )
        _ = try scheduleRepository.createTemplate(
            name: "Lunch Break",
            notes: "A reusable midday break to keep the schedule readable.",
            defaultStartTime: time(hour: 12, minute: 30, on: day, calendar: calendar),
            durationMinutes: 60,
            weekdayMask: weekdayMask,
            category: .personal,
            in: modelContext,
            calendar: calendar
        )
        _ = try scheduleRepository.createTemplate(
            name: "Evening Wrap-Up",
            notes: "Use templates to close the day and prepare tomorrow's plan.",
            defaultStartTime: time(hour: 16, minute: 30, on: day, calendar: calendar),
            durationMinutes: 30,
            weekdayMask: weekdayMask,
            category: .admin,
            in: modelContext,
            calendar: calendar
        )

        let errandsBlock = try scheduleRepository.createBlock(
            title: "Errands",
            notes: "Example manual block: add one-off tasks that should not come from a template.",
            date: day,
            startTime: time(hour: 17, minute: 30, on: day, calendar: calendar),
            durationMinutes: 45,
            category: .personal,
            in: modelContext,
            calendar: calendar
        )

        for (index, title) in [
            "Pick up essentials",
            "Drop off return",
            "Review tomorrow's first task"
        ].enumerated() {
            modelContext.insert(
                BlockChecklistItem(
                    title: title,
                    sortOrder: index,
                    timeBlock: errandsBlock
                )
            )
        }
        try modelContext.save()

        try scheduleRepository.generateBlocksIfNeeded(for: day, in: modelContext, calendar: calendar)
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

    private func applySamplePreferences(to preferences: AppPreferences) {
        preferences.defaultBlockDurationMinutes = 45
        preferences.dayStartHour = 7
        preferences.firstWeekday = .monday
        preferences.showsCompletedBlocks = false
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
