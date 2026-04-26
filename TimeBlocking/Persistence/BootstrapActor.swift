import Foundation
import SwiftData
import os

@ModelActor
final actor BootstrapActor {
    private let logger = Logger(subsystem: "com.melichan.TimeBlocking", category: "BootstrapActor")
    func prepareAppFoundation(
        preferencesStore: AppPreferencesStore,
        scheduleRepository: ScheduleRepository,
        notificationManager: TimeNotificationManager
    ) async throws {
        logger.info("Starting background bootstrap...")
        
        // 1. Fetch or create preferences
        let preferences = try await preferencesStore.fetchOrCreate(in: modelContext)
        
        // 2. Seed sample data if empty
        if try await isEffectivelyEmpty() {
            logger.info("App is empty, seeding sample data...")
            try await seedSampleData(
                preferences: preferences,
                scheduleRepository: scheduleRepository
            )
        }
        
        // 3. Resync notifications
        logger.info("Resyncing notifications from background...")
        await notificationManager.resyncUpcomingReminders(
            in: modelContext,
            preferences: preferences
        )
        
        logger.info("Background bootstrap completed.")
    }

    private func isEffectivelyEmpty() async throws -> Bool {
        var templateDescriptor = FetchDescriptor<ScheduleTemplate>()
        templateDescriptor.fetchLimit = 1

        var blockDescriptor = FetchDescriptor<TimeBlock>()
        blockDescriptor.fetchLimit = 1

        let hasTemplates = try !modelContext.fetch(templateDescriptor).isEmpty
        let hasBlocks = try !modelContext.fetch(blockDescriptor).isEmpty
        return !hasTemplates && !hasBlocks
    }

    func seedSampleData(
        preferences: AppPreferences,
        scheduleRepository: ScheduleRepository,
        calendar: Calendar = .current
    ) async throws {
        // Sample preferences
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
        
        try modelContext.save()

        let today = calendar.startOfDay(for: .now)
        let weekdays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let weekdayMask = weekdays.reduce(into: 0) { partialResult, weekday in
            partialResult |= 1 << (weekday.rawValue - 1)
        }

        _ = try await scheduleRepository.createTemplate(
            name: "Daily Strategy",
            notes: "Review priorities, clear urgent emails, and set the intention for the day.",
            defaultStartTime: time(hour: 8, minute: 30, on: today, calendar: calendar),
            durationMinutes: 30,
            weekdayMask: weekdayMask,
            category: .routine,
            in: modelContext,
            calendar: calendar
        )

        try await scheduleRepository.generateBlocksIfNeeded(for: today, in: modelContext, calendar: calendar)

        _ = try await scheduleRepository.createBlock(
            title: "Client Focus: Core Project",
            notes: "High-leverage work for my primary client. No distractions allowed.",
            date: today,
            startTime: time(hour: 9, minute: 30, on: today, calendar: calendar),
            durationMinutes: 120,
            category: .focus,
            in: modelContext,
            calendar: calendar
        )

        let adminBlock = try await scheduleRepository.createBlock(
            title: "Admin & Invoicing",
            notes: "Keep the business running smoothly. Review pending tasks and finances.",
            date: today,
            startTime: time(hour: 13, minute: 30, on: today, calendar: calendar),
            durationMinutes: 45,
            category: .admin,
            checklistItemTitles: [
                "Send weekly invoices",
                "Review expense reports",
                "Update project tracker"
            ],
            in: modelContext,
            calendar: calendar
        )

        if let firstChecklistItem = adminBlock.checklistItems?.sorted(by: { $0.sortOrder < $1.sortOrder }).first {
            firstChecklistItem.isCompleted = true
            firstChecklistItem.updatedAt = .now
        }

        let planningBlock = try await scheduleRepository.createBlock(
            title: "Tomorrow's Plan",
            notes: "Decide what needs to happen tomorrow so I can shut down with a clear mind.",
            date: today,
            startTime: time(hour: 16, minute: 30, on: today, calendar: calendar),
            durationMinutes: 30,
            category: .routine,
            in: modelContext,
            calendar: calendar
        )
        try await scheduleRepository.setBlockStatus(planningBlock, to: .completed, in: modelContext)
        
        try modelContext.save()
    }

    private func time(hour: Int, minute: Int, on date: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }
}
