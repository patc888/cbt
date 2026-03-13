import Foundation
import SwiftData
import Testing
@testable import TimeBlocking

struct TimeBlockingTests {
    @Test
    func scheduleMonthSupportBuildsSixWeekGridFromSelectedMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        calendar.firstWeekday = Weekday.monday.rawValue
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 18)))

        let dates = ScheduleMonthSupport.gridDates(for: date, calendar: calendar)

        #expect(dates.count == 42)
        #expect(dates.first == calendar.date(from: DateComponents(year: 2026, month: 2, day: 23)))
        #expect(dates.last == calendar.date(from: DateComponents(year: 2026, month: 4, day: 5)))
        #expect(calendar.isDate(dates[10], equalTo: date, toGranularity: .month))
    }

    @Test
    func scheduleMonthSummaryAggregatesOnlyDaysInDisplayedMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))

        let monthDayOne = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9)))
        let monthDayTwo = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 10)))
        let paddedDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 8)))

        let plannedBlock = TimeBlock(
            title: "Focus",
            startDate: monthDayOne,
            endDate: monthDayOne.addingTimeInterval(3_600),
            category: .focus,
            status: .planned
        )
        let mixedPlannedBlock = TimeBlock(
            title: "Wrap",
            startDate: monthDayTwo,
            endDate: monthDayTwo.addingTimeInterval(1_800),
            category: .routine,
            status: .planned
        )
        let mixedCompletedBlock = TimeBlock(
            title: "Done",
            startDate: monthDayTwo.addingTimeInterval(2_400),
            endDate: monthDayTwo.addingTimeInterval(6_000),
            category: .admin,
            status: .completed
        )
        let paddedBlock = TimeBlock(
            title: "Padding",
            startDate: paddedDay,
            endDate: paddedDay.addingTimeInterval(7_200),
            category: .custom,
            status: .planned
        )

        let days = [
            MonthlyPlanningDay(
                date: monthDayOne,
                snapshot: ScheduleDaySnapshot(
                    blocks: [plannedBlock],
                    completedCount: 0,
                    plannedCount: 1,
                    scheduledMinutes: 60
                ),
                isInDisplayedMonth: true
            ),
            MonthlyPlanningDay(
                date: monthDayTwo,
                snapshot: ScheduleDaySnapshot(
                    blocks: [mixedPlannedBlock, mixedCompletedBlock],
                    completedCount: 1,
                    plannedCount: 1,
                    scheduledMinutes: 90
                ),
                isInDisplayedMonth: true
            ),
            MonthlyPlanningDay(
                date: paddedDay,
                snapshot: ScheduleDaySnapshot(
                    blocks: [paddedBlock],
                    completedCount: 0,
                    plannedCount: 1,
                    scheduledMinutes: 120
                ),
                isInDisplayedMonth: false
            )
        ]

        let summary = ScheduleMonthSummary(days: days, calendar: calendar)

        #expect(summary.plannedCount == 2)
        #expect(summary.completedCount == 1)
        #expect(summary.scheduledMinutes == 150)
        #expect(summary.activeDayCount == 2)
        #expect(summary.hasBlocks)
        #expect(summary.busiestDayLabel != "Rest")
    }

    @Test
    func scheduleRepositoryBuildsDaySnapshotWithoutProfileState() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let plannedBlock = TimeBlock(
            title: "Block A",
            startDate: now.addingTimeInterval(1_800),
            endDate: now.addingTimeInterval(5_400),
            category: .focus,
            status: .planned
        )
        let completedBlock = TimeBlock(
            title: "Block B",
            startDate: now.addingTimeInterval(-7_200),
            endDate: now.addingTimeInterval(-3_600),
            category: .admin,
            status: .completed
        )

        let snapshot = ScheduleRepository().daySnapshot(
            for: now,
            from: [plannedBlock, completedBlock],
            includeCompleted: true,
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(snapshot.blocks.count == 2)
        #expect(snapshot.plannedCount == 1)
        #expect(snapshot.completedCount == 1)
        #expect(snapshot.scheduledMinutes == 150)
    }

    @Test
    @MainActor
    func prepareIfNeededCreatesOnePreferencesRecord() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let appEnvironment = AppEnvironment(persistenceController: persistenceController)
        let modelContext = ModelContext(persistenceController.container)

        appEnvironment.prepareIfNeeded(using: modelContext)
        appEnvironment.prepareIfNeeded(using: modelContext)

        let preferences = try modelContext.fetch(FetchDescriptor<AppPreferences>())
        #expect(preferences.count == 1)
        #expect(preferences.first?.id == "app-preferences")
    }

    @Test
    @MainActor
    func prepareIfNeededSeedsFirstRunSampleDataWhenStoreIsEmpty() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let appEnvironment = AppEnvironment(persistenceController: persistenceController)
        let modelContext = ModelContext(persistenceController.container)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        appEnvironment.prepareIfNeeded(using: modelContext)

        let preferences = try #require(modelContext.fetch(FetchDescriptor<AppPreferences>()).first)
        let templates = try modelContext.fetch(
            FetchDescriptor<ScheduleTemplate>(
                sortBy: [SortDescriptor(\.sortOrder)]
            )
        )
        let blocks = try modelContext.fetch(
            FetchDescriptor<TimeBlock>(
                sortBy: [
                    SortDescriptor(\.startDate),
                    SortDescriptor(\.sortOrder)
                ]
            )
        )
        let checklistItems = try modelContext.fetch(
            FetchDescriptor<BlockChecklistItem>(
                sortBy: [SortDescriptor(\.sortOrder)]
            )
        )

        #expect(preferences.defaultBlockDurationMinutes == 45)
        #expect(preferences.dayStartHour == 7)
        #expect(preferences.firstWeekday == .monday)
        #expect(preferences.showsCompletedBlocks == false)

        #expect(templates.map(\.name) == [
            "Morning Planning",
            "Focus Work",
            "Lunch Break",
            "Evening Wrap-Up"
        ])

        let expectedWeekdayMask = 0
            | (1 << (Weekday.monday.rawValue - 1))
            | (1 << (Weekday.tuesday.rawValue - 1))
            | (1 << (Weekday.wednesday.rawValue - 1))
            | (1 << (Weekday.thursday.rawValue - 1))
            | (1 << (Weekday.friday.rawValue - 1))
        #expect(templates.allSatisfy { $0.weekdayMask == expectedWeekdayMask })

        let generatedTodayBlocks = blocks.filter {
            $0.template != nil && calendar.isDate($0.startDate, inSameDayAs: today)
        }
        let manualErrandsBlock = try #require(blocks.first { $0.title == "Errands" })
        let weekday = calendar.component(.weekday, from: today)
        let expectedGeneratedCount = (expectedWeekdayMask & (1 << (weekday - 1))) != 0 ? 4 : 0

        #expect(blocks.count == expectedGeneratedCount + 1)
        #expect(generatedTodayBlocks.count == expectedGeneratedCount)
        #expect(calendar.isDate(manualErrandsBlock.startDate, inSameDayAs: today))
        #expect(manualErrandsBlock.template == nil)
        #expect(manualErrandsBlock.notes == "Example manual block: add one-off tasks that should not come from a template.")
        #expect(checklistItems.map(\.title) == [
            "Pick up essentials",
            "Drop off return",
            "Review tomorrow's first task"
        ])
        #expect(checklistItems.allSatisfy { $0.timeBlock?.id == manualErrandsBlock.id })

        if (expectedWeekdayMask & (1 << (weekday - 1))) != 0 {
            #expect(generatedTodayBlocks.map(\.title) == [
                "Morning Planning",
                "Focus Work",
                "Lunch Break",
                "Evening Wrap-Up"
            ])
        } else {
            #expect(generatedTodayBlocks.isEmpty)
        }
    }

    @Test
    @MainActor
    func prepareIfNeededDoesNotSeedWhenUserDataAlreadyExists() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let appEnvironment = AppEnvironment(persistenceController: persistenceController)
        let modelContext = ModelContext(persistenceController.container)
        let calendar = Calendar(identifier: .gregorian)
        let existingPreferences = AppPreferences(
            defaultBlockDurationMinutes: 90,
            dayStartHour: 5,
            firstWeekday: .sunday,
            showsCompletedBlocks: true
        )

        modelContext.insert(existingPreferences)
        modelContext.insert(
            TimeBlock(
                title: "Existing Block",
                startDate: Date(timeIntervalSince1970: 1_700_000_000),
                endDate: Date(timeIntervalSince1970: 1_700_003_600),
                category: .custom,
                status: .planned,
                sortOrder: 0
            )
        )
        try modelContext.save()

        appEnvironment.prepareIfNeeded(using: modelContext)

        let preferences = try modelContext.fetch(FetchDescriptor<AppPreferences>())
        let templates = try modelContext.fetch(FetchDescriptor<ScheduleTemplate>())
        let blocks = try modelContext.fetch(FetchDescriptor<TimeBlock>())
        let checklistItems = try modelContext.fetch(FetchDescriptor<BlockChecklistItem>())

        #expect(preferences.count == 1)
        #expect(preferences.first?.defaultBlockDurationMinutes == 90)
        #expect(preferences.first?.dayStartHour == 5)
        #expect(preferences.first?.firstWeekday == .sunday)
        #expect(preferences.first?.showsCompletedBlocks == true)
        #expect(templates.isEmpty)
        #expect(blocks.count == 1)
        #expect(blocks.first?.title == "Existing Block")
        #expect(checklistItems.isEmpty)
        #expect(calendar.isDate(blocks.first?.startDate ?? .distantPast, equalTo: Date(timeIntervalSince1970: 1_700_000_000), toGranularity: .second))
    }

    @Test
    func scheduleRepositoryCanHideCompletedBlocks() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let plannedBlock = TimeBlock(
            title: "Planned",
            startDate: now,
            endDate: now.addingTimeInterval(3_600),
            status: .planned
        )
        let completedBlock = TimeBlock(
            title: "Done",
            startDate: now.addingTimeInterval(3_600),
            endDate: now.addingTimeInterval(5_400),
            status: .completed
        )

        let snapshot = ScheduleRepository().daySnapshot(
            for: now,
            from: [plannedBlock, completedBlock],
            includeCompleted: false
        )

        #expect(snapshot.blocks.count == 1)
        #expect(snapshot.blocks.first?.title == "Planned")
        #expect(snapshot.completedCount == 0)
    }

    @Test
    func scheduleRepositoryBuildsDashboardSummaryForToday() {
        let now = Date(timeIntervalSince1970: 2_500_000)
        let completedBlock = TimeBlock(
            title: "Early Done",
            startDate: now.addingTimeInterval(-7_200),
            endDate: now.addingTimeInterval(-5_400),
            category: .admin,
            status: .completed
        )
        let nextBlock = TimeBlock(
            title: "Current Focus",
            startDate: now.addingTimeInterval(1_800),
            endDate: now.addingTimeInterval(5_400),
            category: .focus,
            status: .planned
        )
        let laterBlock = TimeBlock(
            title: "Wrap Up",
            startDate: now.addingTimeInterval(10_800),
            endDate: now.addingTimeInterval(12_600),
            category: .routine,
            status: .planned
        )
        let tomorrowBlock = TimeBlock(
            title: "Tomorrow",
            startDate: now.addingTimeInterval(90_000),
            endDate: now.addingTimeInterval(93_600),
            category: .custom,
            status: .planned
        )

        let summary = ScheduleRepository().dashboardSummary(
            for: now,
            from: [completedBlock, tomorrowBlock, laterBlock, nextBlock],
            calendar: Calendar(identifier: .gregorian)
        )

        #expect(summary.daySnapshot.completedCount == 1)
        #expect(summary.daySnapshot.plannedCount == 2)
        #expect(summary.daySnapshot.scheduledMinutes == 150)
        #expect(summary.nextBlock?.title == "Current Focus")
        #expect(summary.upcomingBlocks.count == 3)
        #expect(summary.totalBlocks == 3)
        #expect(summary.remainingPlannedCount == 2)
        #expect(summary.currentBlock(at: now) == nil)
        #expect(summary.remainingTodayBlocks(after: now).map(\.title) == ["Current Focus", "Wrap Up"])
        #expect(summary.remainingScheduledMinutes(after: now) == 150)
    }

    @Test
    func scheduleRepositoryFetchesDaySnapshotFromModelContext() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let calendar = Calendar(identifier: .gregorian)
        let repository = ScheduleRepository()
        let date = Date(timeIntervalSince1970: 2_500_000)

        modelContext.insert(
            TimeBlock(
                title: "Earlier Day",
                startDate: date.addingTimeInterval(-7_200),
                endDate: date.addingTimeInterval(-5_400),
                category: .admin,
                status: .completed,
                sortOrder: 0
            )
        )
        modelContext.insert(
            TimeBlock(
                title: "Keep Me",
                startDate: date.addingTimeInterval(1_800),
                endDate: date.addingTimeInterval(5_400),
                category: .focus,
                status: .planned,
                sortOrder: 1
            )
        )
        modelContext.insert(
            TimeBlock(
                title: "Tomorrow",
                startDate: date.addingTimeInterval(90_000),
                endDate: date.addingTimeInterval(93_600),
                category: .custom,
                status: .planned,
                sortOrder: 0
            )
        )
        try modelContext.save()

        let snapshot = try repository.daySnapshot(
            for: date,
            includeCompleted: false,
            in: modelContext,
            calendar: calendar
        )

        #expect(snapshot.blocks.count == 1)
        #expect(snapshot.blocks.first?.title == "Keep Me")
        #expect(snapshot.plannedCount == 1)
        #expect(snapshot.completedCount == 0)
        #expect(snapshot.scheduledMinutes == 60)
    }

    @Test
    func scheduleRepositoryFetchesDashboardSummaryFromModelContext() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let calendar = Calendar(identifier: .gregorian)
        let repository = ScheduleRepository()
        let now = Date(timeIntervalSince1970: 2_500_000)

        modelContext.insert(
            TimeBlock(
                title: "Early Done",
                startDate: now.addingTimeInterval(-7_200),
                endDate: now.addingTimeInterval(-5_400),
                category: .admin,
                status: .completed,
                sortOrder: 0
            )
        )
        modelContext.insert(
            TimeBlock(
                title: "Current Focus",
                startDate: now.addingTimeInterval(1_800),
                endDate: now.addingTimeInterval(5_400),
                category: .focus,
                status: .planned,
                sortOrder: 1
            )
        )
        modelContext.insert(
            TimeBlock(
                title: "Wrap Up",
                startDate: now.addingTimeInterval(10_800),
                endDate: now.addingTimeInterval(12_600),
                category: .routine,
                status: .planned,
                sortOrder: 2
            )
        )
        modelContext.insert(
            TimeBlock(
                title: "Tomorrow",
                startDate: now.addingTimeInterval(90_000),
                endDate: now.addingTimeInterval(93_600),
                category: .custom,
                status: .planned,
                sortOrder: 0
            )
        )
        try modelContext.save()

        let summary = try repository.dashboardSummary(
            for: now,
            in: modelContext,
            calendar: calendar
        )

        #expect(summary.daySnapshot.completedCount == 1)
        #expect(summary.daySnapshot.plannedCount == 2)
        #expect(summary.daySnapshot.scheduledMinutes == 150)
        #expect(summary.nextBlock?.title == "Current Focus")
        #expect(summary.upcomingBlocks.count == 3)
        #expect(summary.totalBlocks == 3)
        #expect(summary.remainingPlannedCount == 2)
        #expect(summary.currentBlock(at: now) == nil)
        #expect(summary.remainingTodayBlocks(after: now).map(\.title) == ["Current Focus", "Wrap Up"])
        #expect(summary.remainingScheduledMinutes(after: now) == 150)
    }

    @Test
    func scheduleRepositoryGeneratesTemplateBlocksOncePerDay() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let calendar = Calendar(identifier: .gregorian)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let weekdayMask = 1 << (calendar.component(.weekday, from: date) - 1)
        let template = ScheduleTemplate(
            name: "Morning Focus",
            notes: "Deep work",
            defaultStartHour: 9,
            defaultDurationMinutes: 90,
            weekdayMask: weekdayMask,
            category: .focus,
            sortOrder: 3
        )

        modelContext.insert(template)
        try modelContext.save()

        let repository = ScheduleRepository()
        let firstPass = try repository.generateBlocksIfNeeded(
            for: date,
            in: modelContext,
            calendar: calendar
        )
        let secondPass = try repository.generateBlocksIfNeeded(
            for: date,
            in: modelContext,
            calendar: calendar
        )
        let blocks = try modelContext.fetch(FetchDescriptor<TimeBlock>())

        #expect(firstPass.count == 1)
        #expect(secondPass.isEmpty)
        #expect(blocks.count == 1)
        #expect(blocks.first?.template?.id == template.id)
        #expect(blocks.first?.title == "Morning Focus")
        #expect(calendar.isDate(blocks.first?.startDate ?? .distantPast, inSameDayAs: date))
    }

    @Test
    func scheduleRepositoryRegeneratesTemplateBlocksForTheSelectedDay() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let calendar = Calendar(identifier: .gregorian)
        let repository = ScheduleRepository()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let weekdayMask = 1 << (calendar.component(.weekday, from: date) - 1)
        let template = ScheduleTemplate(
            name: "Morning Focus",
            notes: "Deep work",
            defaultStartHour: 9,
            defaultDurationMinutes: 90,
            weekdayMask: weekdayMask,
            category: .focus,
            sortOrder: 0
        )

        modelContext.insert(template)
        try modelContext.save()

        let originalGeneratedBlock = try #require(
            repository.generateBlocksIfNeeded(for: date, in: modelContext, calendar: calendar).first
        )
        _ = try repository.createBlock(
            title: "Manual Planning",
            notes: nil,
            date: date,
            startTime: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: date) ?? date,
            durationMinutes: 30,
            category: .admin,
            in: modelContext,
            calendar: calendar
        )

        try repository.updateTemplate(
            template,
            name: "Updated Focus",
            notes: "Fresh template",
            defaultStartTime: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: date) ?? date,
            durationMinutes: 60,
            weekdayMask: weekdayMask,
            category: .focus,
            in: modelContext,
            calendar: calendar
        )

        let regeneratedBlocks = try repository.regenerateTemplateBlocks(
            for: date,
            in: modelContext,
            calendar: calendar
        )
        let blocks = try modelContext.fetch(
            FetchDescriptor<TimeBlock>(
                sortBy: [
                    SortDescriptor(\.startDate),
                    SortDescriptor(\.sortOrder)
                ]
            )
        )

        #expect(regeneratedBlocks.count == 1)
        #expect(blocks.count == 2)
        #expect(blocks.filter { $0.template != nil }.count == 1)
        #expect(blocks.contains { $0.title == "Manual Planning" && $0.template == nil })
        #expect(blocks.contains { $0.title == "Updated Focus" && $0.template?.id == template.id })
        #expect(blocks.allSatisfy { $0.id != originalGeneratedBlock.id || $0.template == nil })
    }

    @Test
    func scheduleRepositoryRegeneratePreservesCompletedGeneratedBlocksAndManualBlocks() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let calendar = Calendar(identifier: .gregorian)
        let repository = ScheduleRepository()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let weekdayMask = 1 << (calendar.component(.weekday, from: date) - 1)
        let morningTemplate = ScheduleTemplate(
            name: "Morning Focus",
            notes: "Deep work",
            defaultStartHour: 9,
            defaultDurationMinutes: 90,
            weekdayMask: weekdayMask,
            category: .focus,
            sortOrder: 0
        )
        let lunchTemplate = ScheduleTemplate(
            name: "Lunch",
            notes: "Break",
            defaultStartHour: 12,
            defaultDurationMinutes: 60,
            weekdayMask: weekdayMask,
            category: .personal,
            sortOrder: 1
        )

        modelContext.insert(morningTemplate)
        modelContext.insert(lunchTemplate)
        try modelContext.save()

        let generatedBlocks = try repository.generateBlocksIfNeeded(
            for: date,
            in: modelContext,
            calendar: calendar
        )
        let completedGeneratedBlock = try #require(
            generatedBlocks.first { $0.template?.id == lunchTemplate.id }
        )

        try repository.setBlockStatus(
            completedGeneratedBlock,
            to: .completed,
            in: modelContext
        )
        _ = try repository.createBlock(
            title: "Manual Planning",
            notes: nil,
            date: date,
            startTime: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: date) ?? date,
            durationMinutes: 30,
            category: .admin,
            in: modelContext,
            calendar: calendar
        )

        try repository.updateTemplate(
            morningTemplate,
            name: "Updated Focus",
            notes: "Fresh template",
            defaultStartTime: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: date) ?? date,
            durationMinutes: 60,
            weekdayMask: weekdayMask,
            category: .focus,
            in: modelContext,
            calendar: calendar
        )

        let regeneratedBlocks = try repository.regenerateTemplateBlocks(
            for: date,
            in: modelContext,
            calendar: calendar
        )
        let blocks = try modelContext.fetch(
            FetchDescriptor<TimeBlock>(
                sortBy: [
                    SortDescriptor(\.startDate),
                    SortDescriptor(\.sortOrder)
                ]
            )
        )

        #expect(regeneratedBlocks.count == 1)
        #expect(blocks.count == 3)
        #expect(blocks.contains { $0.title == "Updated Focus" && $0.template?.id == morningTemplate.id })
        #expect(blocks.contains { $0.id == completedGeneratedBlock.id && $0.status == .completed })
        #expect(blocks.contains { $0.title == "Manual Planning" && $0.template == nil })
    }

    @Test
    func scheduleRepositoryDetachesGeneratedBlocksAfterManualEdit() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let calendar = Calendar(identifier: .gregorian)
        let repository = ScheduleRepository()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let weekdayMask = 1 << (calendar.component(.weekday, from: date) - 1)
        let template = ScheduleTemplate(
            name: "Morning Focus",
            notes: "Deep work",
            defaultStartHour: 9,
            defaultDurationMinutes: 90,
            weekdayMask: weekdayMask,
            category: .focus,
            sortOrder: 0
        )

        modelContext.insert(template)
        try modelContext.save()

        let generatedBlock = try #require(
            repository.generateBlocksIfNeeded(for: date, in: modelContext, calendar: calendar).first
        )
        let updatedStartTime = calendar.date(bySettingHour: 11, minute: 30, second: 0, of: date) ?? date

        try repository.updateBlock(
            generatedBlock,
            title: "Focused Work",
            notes: "Adjusted by hand",
            date: date,
            startTime: updatedStartTime,
            durationMinutes: 60,
            category: .admin,
            in: modelContext,
            calendar: calendar
        )

        #expect(generatedBlock.template == nil)
        #expect(generatedBlock.title == "Focused Work")

        let regeneratedBlocks = try repository.regenerateTemplateBlocks(
            for: date,
            in: modelContext,
            calendar: calendar
        )
        let blocks = try modelContext.fetch(
            FetchDescriptor<TimeBlock>(
                sortBy: [
                    SortDescriptor(\.startDate),
                    SortDescriptor(\.sortOrder)
                ]
            )
        )

        #expect(regeneratedBlocks.count == 1)
        #expect(blocks.count == 2)
        #expect(blocks.contains { $0.title == "Focused Work" && $0.template == nil })
        #expect(blocks.contains { $0.title == "Morning Focus" && $0.template?.id == template.id })
    }

    @Test
    func scheduleRepositoryMovesBlocksToAnotherDayWhilePreservingTimeAndDuration() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let calendar = Calendar(identifier: .gregorian)
        let repository = ScheduleRepository()
        let sourceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let destinationDate = calendar.date(byAdding: .day, value: 2, to: sourceDate) ?? sourceDate
        let movingBlockStart = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: sourceDate) ?? sourceDate
        let movingBlockEnd = calendar.date(byAdding: .minute, value: 75, to: movingBlockStart) ?? movingBlockStart
        let existingDestinationStart = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: destinationDate) ?? destinationDate
        let existingDestinationEnd = calendar.date(byAdding: .minute, value: 45, to: existingDestinationStart) ?? existingDestinationStart
        let movingBlock = TimeBlock(
            title: "Deep Work",
            startDate: movingBlockStart,
            endDate: movingBlockEnd,
            category: .focus,
            status: .planned,
            sortOrder: 1
        )

        modelContext.insert(movingBlock)
        modelContext.insert(
            TimeBlock(
                title: "Existing Destination Block",
                startDate: existingDestinationStart,
                endDate: existingDestinationEnd,
                category: .admin,
                status: .planned,
                sortOrder: 3
            )
        )
        try modelContext.save()

        try repository.moveBlock(
            movingBlock,
            toDay: destinationDate,
            in: modelContext,
            calendar: calendar
        )

        let movedComponents = calendar.dateComponents([.hour, .minute], from: movingBlock.startDate)
        #expect(calendar.isDate(movingBlock.startDate, inSameDayAs: destinationDate))
        #expect(movedComponents.hour == 9)
        #expect(movedComponents.minute == 30)
        #expect(Int(movingBlock.endDate.timeIntervalSince(movingBlock.startDate) / 60) == 75)
        #expect(movingBlock.sortOrder == 4)
    }

    @Test
    func scheduleRepositoryDetachesGeneratedBlocksWhenMovedToAnotherDay() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let calendar = Calendar(identifier: .gregorian)
        let repository = ScheduleRepository()
        let sourceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let destinationDate = calendar.date(byAdding: .day, value: 1, to: sourceDate) ?? sourceDate
        let weekdayMask = 1 << (calendar.component(.weekday, from: sourceDate) - 1)
        let template = ScheduleTemplate(
            name: "Morning Focus",
            notes: "Deep work",
            defaultStartHour: 9,
            defaultDurationMinutes: 90,
            weekdayMask: weekdayMask,
            category: .focus,
            sortOrder: 0
        )

        modelContext.insert(template)
        try modelContext.save()

        let generatedBlock = try #require(
            repository.generateBlocksIfNeeded(for: sourceDate, in: modelContext, calendar: calendar).first
        )

        try repository.moveBlock(
            generatedBlock,
            toDay: destinationDate,
            in: modelContext,
            calendar: calendar
        )

        #expect(calendar.isDate(generatedBlock.startDate, inSameDayAs: destinationDate))
        #expect(generatedBlock.template == nil)
    }

    @Test
    func scheduleRepositoryReschedulesBlocksWithinTheDayWhilePreservingDuration() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let calendar = Calendar(identifier: .gregorian)
        let repository = ScheduleRepository()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let originalStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        let originalEnd = calendar.date(byAdding: .minute, value: 90, to: originalStart) ?? originalStart
        let updatedStart = calendar.date(bySettingHour: 13, minute: 15, second: 0, of: date) ?? date
        let block = TimeBlock(
            title: "Deep Work",
            startDate: originalStart,
            endDate: originalEnd,
            category: .focus,
            status: .planned,
            sortOrder: 0
        )

        modelContext.insert(block)
        try modelContext.save()

        try repository.rescheduleBlock(
            block,
            toStartDate: updatedStart,
            in: modelContext,
            calendar: calendar
        )

        let movedComponents = calendar.dateComponents([.hour, .minute], from: block.startDate)
        #expect(calendar.isDate(block.startDate, inSameDayAs: date))
        #expect(movedComponents.hour == 13)
        #expect(movedComponents.minute == 15)
        #expect(Int(block.endDate.timeIntervalSince(block.startDate) / 60) == 90)
    }

    @Test
    func scheduleRepositoryDetachesGeneratedBlocksWhenRescheduledWithinTheDay() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let calendar = Calendar(identifier: .gregorian)
        let repository = ScheduleRepository()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedStart = calendar.date(bySettingHour: 11, minute: 45, second: 0, of: date) ?? date
        let weekdayMask = 1 << (calendar.component(.weekday, from: date) - 1)
        let template = ScheduleTemplate(
            name: "Morning Focus",
            notes: "Deep work",
            defaultStartHour: 9,
            defaultDurationMinutes: 90,
            weekdayMask: weekdayMask,
            category: .focus,
            sortOrder: 0
        )

        modelContext.insert(template)
        try modelContext.save()

        let generatedBlock = try #require(
            repository.generateBlocksIfNeeded(for: date, in: modelContext, calendar: calendar).first
        )

        try repository.rescheduleBlock(
            generatedBlock,
            toStartDate: updatedStart,
            in: modelContext,
            calendar: calendar
        )

        #expect(calendar.isDate(generatedBlock.startDate, inSameDayAs: date))
        #expect(generatedBlock.template == nil)
    }

    @Test
    func scheduleRepositoryPreservesCompletedGeneratedBlocksDuringRegenerate() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let calendar = Calendar(identifier: .gregorian)
        let repository = ScheduleRepository()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let weekdayMask = 1 << (calendar.component(.weekday, from: date) - 1)
        let template = ScheduleTemplate(
            name: "Morning Focus",
            notes: "Deep work",
            defaultStartHour: 9,
            defaultDurationMinutes: 90,
            weekdayMask: weekdayMask,
            category: .focus,
            sortOrder: 0
        )

        modelContext.insert(template)
        try modelContext.save()

        let generatedBlock = try #require(
            repository.generateBlocksIfNeeded(for: date, in: modelContext, calendar: calendar).first
        )
        generatedBlock.status = .completed
        generatedBlock.updatedAt = .now
        try modelContext.save()

        let regeneratedBlocks = try repository.regenerateTemplateBlocks(
            for: date,
            in: modelContext,
            calendar: calendar
        )
        let blocks = try modelContext.fetch(FetchDescriptor<TimeBlock>())

        #expect(regeneratedBlocks.isEmpty)
        #expect(blocks.count == 1)
        #expect(blocks.first?.status == .completed)
        #expect(blocks.first?.template?.id == template.id)
    }

    @Test
    func scheduleRepositorySkipsTemplatesOutsideTheirWeekdayMask() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let calendar = Calendar(identifier: .gregorian)
        let date = Date(timeIntervalSince1970: 1_700_086_400)
        let weekday = calendar.component(.weekday, from: date)
        let differentWeekday = weekday == 1 ? 2 : 1
        let weekdayMask = 1 << (differentWeekday - 1)
        let template = ScheduleTemplate(
            name: "Off Day Template",
            defaultStartHour: 7,
            defaultDurationMinutes: 45,
            weekdayMask: weekdayMask
        )

        modelContext.insert(template)
        try modelContext.save()

        let generatedBlocks = try ScheduleRepository().generateBlocksIfNeeded(
            for: date,
            in: modelContext,
            calendar: calendar
        )

        #expect(generatedBlocks.isEmpty)
        #expect(try modelContext.fetch(FetchDescriptor<TimeBlock>()).isEmpty)
    }

    @Test
    func scheduleRepositoryCanCreateAndUpdateTemplate() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let repository = ScheduleRepository()
        let calendar = Calendar(identifier: .gregorian)
        let startTime = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: .now) ?? .now
        let updatedStartTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now

        let createdTemplate = try repository.createTemplate(
            name: " Morning Routine ",
            notes: " Prep for the day ",
            defaultStartTime: startTime,
            durationMinutes: 75,
            weekdayMask: 0b0001110,
            category: .routine,
            in: modelContext,
            calendar: calendar
        )

        #expect(createdTemplate.name == "Morning Routine")
        #expect(createdTemplate.notes == "Prep for the day")
        #expect(createdTemplate.defaultStartHour == 6)
        #expect(createdTemplate.defaultDurationMinutes == 75)
        #expect(createdTemplate.sortOrder == 0)

        try repository.updateTemplate(
            createdTemplate,
            name: "Deep Work",
            notes: " ",
            defaultStartTime: updatedStartTime,
            durationMinutes: 120,
            weekdayMask: 0b0010000,
            category: .focus,
            in: modelContext,
            calendar: calendar
        )

        let templates = try modelContext.fetch(FetchDescriptor<ScheduleTemplate>())
        #expect(templates.count == 1)
        #expect(templates.first?.name == "Deep Work")
        #expect(templates.first?.notes == nil)
        #expect(templates.first?.defaultStartHour == 10)
        #expect(templates.first?.defaultDurationMinutes == 120)
        #expect(templates.first?.weekdayMask == 0b0010000)
        #expect(templates.first?.category == .focus)
    }

    @Test
    func scheduleRepositoryCanDeleteTemplate() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let repository = ScheduleRepository()
        let startTime = Calendar(identifier: .gregorian).date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now

        let template = try repository.createTemplate(
            name: "Delete Me",
            notes: nil,
            defaultStartTime: startTime,
            durationMinutes: 30,
            weekdayMask: 0b0000010,
            category: .custom,
            in: modelContext
        )

        try repository.deleteTemplate(template, in: modelContext)

        #expect(try modelContext.fetch(FetchDescriptor<ScheduleTemplate>()).isEmpty)
    }

    @Test
    func scheduleRepositoryCreatesChecklistItemsWithNewBlock() throws {
        let persistenceController = PersistenceController(inMemory: true)
        let modelContext = ModelContext(persistenceController.container)
        let repository = ScheduleRepository()
        let calendar = Calendar(identifier: .gregorian)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let startTime = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: date) ?? date

        let block = try repository.createBlock(
            title: " Errands ",
            notes: " Quick run ",
            date: date,
            startTime: startTime,
            durationMinutes: 45,
            category: .personal,
            checklistItemTitles: [
                " Pick up groceries ",
                " ",
                "Mail package"
            ],
            in: modelContext,
            calendar: calendar
        )

        let checklistItems = try modelContext.fetch(
            FetchDescriptor<BlockChecklistItem>(
                sortBy: [SortDescriptor(\.sortOrder)]
            )
        )

        #expect(block.title == "Errands")
        #expect(block.notes == "Quick run")
        #expect(checklistItems.map(\.title) == [
            "Pick up groceries",
            "Mail package"
        ])
        #expect(checklistItems.map(\.sortOrder) == [0, 1])
        #expect(checklistItems.allSatisfy { $0.timeBlock?.id == block.id })
        #expect((block.checklistItems ?? []).count == 2)
    }
}
