import Foundation
import SwiftData

struct ScheduleDaySnapshot {
    let blocks: [TimeBlock]
    let completedCount: Int
    let plannedCount: Int
    let scheduledMinutes: Int
}

struct ScheduleDashboardSummary {
    let daySnapshot: ScheduleDaySnapshot
    let upcomingBlocks: [TimeBlock]

    var nextBlock: TimeBlock? {
        upcomingBlocks.first
    }

    var totalBlocks: Int {
        daySnapshot.blocks.count
    }

    var remainingPlannedCount: Int {
        daySnapshot.blocks.filter { $0.status == .planned }.count
    }

    var completionRate: Double {
        guard totalBlocks > 0 else {
            return 0
        }

        return Double(daySnapshot.completedCount) / Double(totalBlocks)
    }

    func currentBlock(at date: Date = .now) -> TimeBlock? {
        daySnapshot.blocks.first { block in
            block.status == .planned && block.startDate <= date && block.endDate >= date
        }
    }

    func remainingTodayBlocks(after date: Date = .now) -> [TimeBlock] {
        daySnapshot.blocks.filter { block in
            block.status == .planned && block.endDate >= date
        }
    }

    func remainingScheduledMinutes(after date: Date = .now) -> Int {
        remainingTodayBlocks(after: date).reduce(0) { partialResult, block in
            let effectiveStart = max(block.startDate, date)
            let remainingDuration = block.endDate.timeIntervalSince(effectiveStart)
            return partialResult + max(Int(remainingDuration / 60), 0)
        }
    }

    var isEmpty: Bool {
        daySnapshot.blocks.isEmpty && upcomingBlocks.isEmpty
    }
}

struct ScheduleRepository {
    @discardableResult
    func createTemplate(
        name: String,
        notes: String?,
        defaultStartTime: Date,
        durationMinutes: Int,
        weekdayMask: Int,
        category: TimeBlockCategory,
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> ScheduleTemplate {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedHour = calendar.component(.hour, from: defaultStartTime)
        let nextSortOrder = try nextTemplateSortOrder(in: modelContext)

        let template = ScheduleTemplate(
            name: trimmedName,
            notes: trimmedNotes?.isEmpty == true ? nil : trimmedNotes,
            defaultStartHour: min(max(resolvedHour, 0), 23),
            defaultDurationMinutes: max(durationMinutes, 15),
            weekdayMask: weekdayMask,
            category: category,
            sortOrder: nextSortOrder,
            createdAt: .now,
            updatedAt: .now
        )

        modelContext.insert(template)
        try modelContext.save()
        return template
    }

    func updateTemplate(
        _ template: ScheduleTemplate,
        name: String,
        notes: String?,
        defaultStartTime: Date,
        durationMinutes: Int,
        weekdayMask: Int,
        category: TimeBlockCategory,
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedHour = calendar.component(.hour, from: defaultStartTime)

        template.name = trimmedName
        template.notes = trimmedNotes?.isEmpty == true ? nil : trimmedNotes
        template.defaultStartHour = min(max(resolvedHour, 0), 23)
        template.defaultDurationMinutes = max(durationMinutes, 15)
        template.weekdayMask = weekdayMask
        template.category = category
        template.updatedAt = .now

        try modelContext.save()
    }

    func deleteTemplate(
        _ template: ScheduleTemplate,
        in modelContext: ModelContext
    ) throws {
        modelContext.delete(template)
        try modelContext.save()
    }

    @discardableResult
    func createBlock(
        title: String,
        notes: String?,
        date: Date,
        startTime: Date,
        durationMinutes: Int,
        category: TimeBlockCategory,
        checklistItemTitles: [String] = [],
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> TimeBlock {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedChecklistItemTitles = checklistItemTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let resolvedDurationMinutes = max(durationMinutes, 1)
        let startDate = merge(date: date, time: startTime, calendar: calendar)
        let endDate = calendar.date(byAdding: .minute, value: resolvedDurationMinutes, to: startDate) ?? startDate

        let block = TimeBlock(
            title: trimmedTitle,
            notes: trimmedNotes?.isEmpty == true ? nil : trimmedNotes,
            startDate: startDate,
            endDate: endDate,
            category: category,
            status: .planned,
            isPinned: false,
            sortOrder: try highestSortOrder(
                on: date,
                in: modelContext,
                calendar: calendar
            ) + 1,
            updatedAt: .now
        )

        modelContext.insert(block)

        for (index, checklistTitle) in trimmedChecklistItemTitles.enumerated() {
            let item = BlockChecklistItem(
                title: checklistTitle,
                sortOrder: index,
                updatedAt: .now,
                timeBlock: block
            )
            block.checklistItems?.append(item)
            modelContext.insert(item)
        }

        try modelContext.save()
        return block
    }

    func updateBlock(
        _ block: TimeBlock,
        title: String,
        notes: String?,
        date: Date,
        startTime: Date,
        durationMinutes: Int,
        category: TimeBlockCategory,
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = normalizedNotes(notes)
        let resolvedDurationMinutes = max(durationMinutes, 1)
        let startDate = merge(date: date, time: startTime, calendar: calendar)
        let endDate = calendar.date(byAdding: .minute, value: resolvedDurationMinutes, to: startDate) ?? startDate
        let movedToDifferentDay = !calendar.isDate(block.startDate, inSameDayAs: startDate)
        let hasManualScheduleChanges =
            block.title != trimmedTitle ||
            normalizedNotes(block.notes) != trimmedNotes ||
            block.startDate != startDate ||
            block.endDate != endDate ||
            block.category != category

        if hasManualScheduleChanges {
            detachGeneratedBlockIfNeeded(block)
        }

        block.title = trimmedTitle
        block.notes = trimmedNotes
        block.startDate = startDate
        block.endDate = endDate
        block.category = category
        block.updatedAt = .now

        if movedToDifferentDay {
            block.sortOrder = try nextSortOrder(
                on: startDate,
                excluding: block,
                in: modelContext,
                calendar: calendar
            )
        }

        try modelContext.save()
    }

    func moveBlock(
        _ block: TimeBlock,
        toDay destinationDate: Date,
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        let originalStartDate = block.startDate
        let originalEndDate = block.endDate
        let dayStart = calendar.startOfDay(for: destinationDate)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: originalStartDate)
        let duration = max(originalEndDate.timeIntervalSince(originalStartDate), 60)
        let movedStartDate = calendar.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: timeComponents.second ?? 0,
            of: dayStart
        ) ?? dayStart
        let movedEndDate = movedStartDate.addingTimeInterval(duration)
        let movedToDifferentDay = !calendar.isDate(originalStartDate, inSameDayAs: movedStartDate)

        guard originalStartDate != movedStartDate || originalEndDate != movedEndDate else {
            return
        }

        detachGeneratedBlockIfNeeded(block)

        block.startDate = movedStartDate
        block.endDate = movedEndDate
        block.updatedAt = .now

        if movedToDifferentDay {
            block.sortOrder = try nextSortOrder(
                on: movedStartDate,
                excluding: block,
                in: modelContext,
                calendar: calendar
            )
        }

        try modelContext.save()
    }

    func rescheduleBlock(
        _ block: TimeBlock,
        toStartDate startDate: Date,
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        let originalStartDate = block.startDate
        let originalEndDate = block.endDate
        let duration = max(originalEndDate.timeIntervalSince(originalStartDate), 60)
        let movedEndDate = startDate.addingTimeInterval(duration)
        let movedToDifferentDay = !calendar.isDate(originalStartDate, inSameDayAs: startDate)

        guard originalStartDate != startDate || originalEndDate != movedEndDate else {
            return
        }

        detachGeneratedBlockIfNeeded(block)

        block.startDate = startDate
        block.endDate = movedEndDate
        block.updatedAt = .now

        if movedToDifferentDay {
            block.sortOrder = try nextSortOrder(
                on: startDate,
                excluding: block,
                in: modelContext,
                calendar: calendar
            )
        }

        try modelContext.save()
    }

    func deleteBlock(
        _ block: TimeBlock,
        in modelContext: ModelContext
    ) throws {
        modelContext.delete(block)
        try modelContext.save()
    }

    func daySnapshot(
        for date: Date,
        from blocks: [TimeBlock],
        includeCompleted: Bool,
        calendar: Calendar = .current
    ) -> ScheduleDaySnapshot {
        let bounds = dayBounds(for: date, calendar: calendar)
        let filteredBlocks = blocks
            .filter { $0.startDate >= bounds.start && $0.startDate < bounds.end }
            .filter { includeCompleted || $0.status != .completed }
            .sorted(by: compareBlocks)

        return ScheduleDaySnapshot(
            blocks: filteredBlocks,
            completedCount: filteredBlocks.filter { $0.status == .completed }.count,
            plannedCount: filteredBlocks.filter { $0.status == .planned }.count,
            scheduledMinutes: scheduledMinutes(for: filteredBlocks)
        )
    }

    func daySnapshot(
        for date: Date,
        includeCompleted: Bool,
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> ScheduleDaySnapshot {
        let blocks = try dayBlocks(
            on: date,
            includeCompleted: includeCompleted,
            in: modelContext,
            calendar: calendar
        )

        return ScheduleDaySnapshot(
            blocks: blocks,
            completedCount: blocks.filter { $0.status == .completed }.count,
            plannedCount: blocks.filter { $0.status == .planned }.count,
            scheduledMinutes: scheduledMinutes(for: blocks)
        )
    }

    func upcomingBlocks(
        from blocks: [TimeBlock],
        startingAt date: Date = .now,
        limit: Int = 6
    ) -> [TimeBlock] {
        Array(
            blocks
                .filter { $0.endDate >= date && $0.status == .planned }
                .sorted(by: compareBlocks)
                .prefix(limit)
        )
    }

    func upcomingBlocks(
        in modelContext: ModelContext,
        startingAt date: Date = .now,
        limit: Int = 6
    ) throws -> [TimeBlock] {
        guard limit > 0 else {
            return []
        }

        let descriptor = FetchDescriptor<TimeBlock>(
            predicate: #Predicate<TimeBlock> { block in
                block.endDate >= date
            },
            sortBy: defaultBlockSortDescriptors
        )
        return Array(
            try modelContext.fetch(descriptor)
                .filter { $0.status == .planned }
                .prefix(limit)
        )
    }

    func dashboardSummary(
        for date: Date = .now,
        from blocks: [TimeBlock],
        calendar: Calendar = .current
    ) -> ScheduleDashboardSummary {
        let daySnapshot = daySnapshot(
            for: date,
            from: blocks,
            includeCompleted: true,
            calendar: calendar
        )

        return ScheduleDashboardSummary(
            daySnapshot: daySnapshot,
            upcomingBlocks: upcomingBlocks(
                from: blocks,
                startingAt: date,
                limit: 3
            )
        )
    }

    func dashboardSummary(
        for date: Date = .now,
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> ScheduleDashboardSummary {
        let daySnapshot = try daySnapshot(
            for: date,
            includeCompleted: true,
            in: modelContext,
            calendar: calendar
        )

        return ScheduleDashboardSummary(
            daySnapshot: daySnapshot,
            upcomingBlocks: try upcomingBlocks(
                in: modelContext,
                startingAt: date,
                limit: 3
            )
        )
    }

    func hasBlocks(on date: Date, in blocks: [TimeBlock], calendar: Calendar = .current) -> Bool {
        let bounds = dayBounds(for: date, calendar: calendar)
        return blocks.contains { block in
            block.startDate >= bounds.start && block.startDate < bounds.end
        }
    }

    @discardableResult
    func generateBlocksIfNeeded(
        for date: Date,
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> [TimeBlock] {
        let matchingTemplates = try templates(for: date, in: modelContext, calendar: calendar)

        guard !matchingTemplates.isEmpty else {
            return []
        }

        let existingBlocks = try dayBlocks(
            on: date,
            includeCompleted: true,
            in: modelContext,
            calendar: calendar
        )

        let generatedTemplateIDs = Set(existingBlocks.compactMap { block in
            block.template?.id
        })

        var nextSortOrder = existingBlocks.map { $0.sortOrder }.max() ?? -1
        var generatedBlocks: [TimeBlock] = []

        for template in matchingTemplates where !generatedTemplateIDs.contains(template.id) {
            nextSortOrder += 1
            let block = makeBlock(
                from: template,
                for: date,
                sortOrder: nextSortOrder,
                calendar: calendar
            )
            modelContext.insert(block)
            generatedBlocks.append(block)
        }

        if !generatedBlocks.isEmpty {
            try modelContext.save()
        }

        return generatedBlocks
    }

    @discardableResult
    func regenerateTemplateBlocks(
        for date: Date,
        in modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> [TimeBlock] {
        let generatedBlocks = try generatedBlocksEligibleForRegeneration(
            on: date,
            in: modelContext,
            calendar: calendar
        )
        if !generatedBlocks.isEmpty {
            for block in generatedBlocks {
                modelContext.delete(block)
            }

            try modelContext.save()
        }

        return try generateBlocksIfNeeded(for: date, in: modelContext, calendar: calendar)
    }

    private func compareBlocks(_ lhs: TimeBlock, _ rhs: TimeBlock) -> Bool {
        if lhs.startDate == rhs.startDate {
            return lhs.sortOrder < rhs.sortOrder
        }

        return lhs.startDate < rhs.startDate
    }

    private func templateApplies(
        _ template: ScheduleTemplate,
        on date: Date,
        calendar: Calendar
    ) -> Bool {
        guard template.weekdayMask != 0 else {
            return false
        }

        let weekday = calendar.component(.weekday, from: date)
        let weekdayBit = 1 << (weekday - 1)
        return template.weekdayMask & weekdayBit != 0
    }

    private func makeBlock(
        from template: ScheduleTemplate,
        for date: Date,
        sortOrder: Int,
        calendar: Calendar
    ) -> TimeBlock {
        let clampedHour = min(max(template.defaultStartHour, 0), 23)
        let durationMinutes = max(template.defaultDurationMinutes, 0)
        let dayStart = calendar.startOfDay(for: date)
        let startDate = calendar.date(
            bySettingHour: clampedHour,
            minute: 0,
            second: 0,
            of: dayStart
        ) ?? dayStart
        let endDate = calendar.date(
            byAdding: .minute,
            value: durationMinutes,
            to: startDate
        ) ?? startDate

        return TimeBlock(
            title: template.name,
            notes: template.notes,
            startDate: startDate,
            endDate: endDate,
            category: template.category,
            status: .planned,
            isPinned: false,
            sortOrder: sortOrder,
            template: template
        )
    }

    private func nextSortOrder(
        on date: Date,
        excluding block: TimeBlock,
        in modelContext: ModelContext,
        calendar: Calendar
    ) throws -> Int {
        let maxSortOrder = try highestSortOrder(
            on: date,
            excludingBlockID: block.id,
            in: modelContext,
            calendar: calendar
        )
        return maxSortOrder + 1
    }

    private func nextTemplateSortOrder(in modelContext: ModelContext) throws -> Int {
        var descriptor = FetchDescriptor<ScheduleTemplate>(
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try modelContext.fetch(descriptor).first?.sortOrder ?? -1) + 1
    }

    private func detachGeneratedBlockIfNeeded(_ block: TimeBlock) {
        guard block.template != nil else {
            return
        }

        block.template = nil
    }

    private func normalizedNotes(_ notes: String?) -> String? {
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedNotes?.isEmpty == true ? nil : trimmedNotes
    }

    private func merge(date: Date, time: Date, calendar: Calendar) -> Date {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var mergedComponents = DateComponents()
        mergedComponents.year = dayComponents.year
        mergedComponents.month = dayComponents.month
        mergedComponents.day = dayComponents.day
        mergedComponents.hour = timeComponents.hour
        mergedComponents.minute = timeComponents.minute

        return calendar.date(from: mergedComponents) ?? date
    }

    private var defaultBlockSortDescriptors: [SortDescriptor<TimeBlock>] {
        [
            SortDescriptor(\.startDate),
            SortDescriptor(\.sortOrder)
        ]
    }

    private func dayBounds(for date: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    private func scheduledMinutes(for blocks: [TimeBlock]) -> Int {
        blocks.reduce(0) { partialResult, block in
            let duration = block.endDate.timeIntervalSince(block.startDate)
            return partialResult + max(Int(duration / 60), 0)
        }
    }

    private func dayBlocks(
        on date: Date,
        includeCompleted: Bool,
        in modelContext: ModelContext,
        calendar: Calendar
    ) throws -> [TimeBlock] {
        let bounds = dayBounds(for: date, calendar: calendar)
        let dayStart = bounds.start
        let dayEnd = bounds.end
        let blocks = try fetchBlocks(
            predicate: #Predicate<TimeBlock> { block in
                block.startDate >= dayStart && block.startDate < dayEnd
            },
            sortBy: defaultBlockSortDescriptors,
            in: modelContext
        )

        guard !includeCompleted else {
            return blocks
        }

        return blocks.filter { $0.status != .completed }
    }

    private func generatedBlocksEligibleForRegeneration(
        on date: Date,
        in modelContext: ModelContext,
        calendar: Calendar
    ) throws -> [TimeBlock] {
        let bounds = dayBounds(for: date, calendar: calendar)
        let dayStart = bounds.start
        let dayEnd = bounds.end
        return try fetchBlocks(
            predicate: #Predicate<TimeBlock> { block in
                block.startDate >= dayStart &&
                block.startDate < dayEnd &&
                block.template != nil
            },
            in: modelContext
        ).filter { $0.status != .completed }
    }

    private func templates(
        for date: Date,
        in modelContext: ModelContext,
        calendar: Calendar
    ) throws -> [ScheduleTemplate] {
        let descriptor = FetchDescriptor<ScheduleTemplate>(
            predicate: #Predicate<ScheduleTemplate> { template in
                template.weekdayMask != 0
            },
            sortBy: [
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.createdAt)
            ]
        )
        return try modelContext.fetch(descriptor).filter { template in
            templateApplies(template, on: date, calendar: calendar)
        }
    }

    private func highestSortOrder(
        on date: Date,
        excludingBlockID: UUID? = nil,
        in modelContext: ModelContext,
        calendar: Calendar
    ) throws -> Int {
        let bounds = dayBounds(for: date, calendar: calendar)
        let dayStart = bounds.start
        let dayEnd = bounds.end
        var descriptor = FetchDescriptor<TimeBlock>(
            predicate: #Predicate<TimeBlock> { block in
                block.startDate >= dayStart && block.startDate < dayEnd
            },
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )

        if excludingBlockID == nil {
            descriptor.fetchLimit = 1
        }

        let blocks = try modelContext.fetch(descriptor)
        return blocks.first(where: { $0.id != excludingBlockID })?.sortOrder ?? -1
    }

    private func fetchBlocks(
        predicate: Predicate<TimeBlock>,
        sortBy: [SortDescriptor<TimeBlock>] = [],
        in modelContext: ModelContext
    ) throws -> [TimeBlock] {
        try modelContext.fetch(
            FetchDescriptor<TimeBlock>(
                predicate: predicate,
                sortBy: sortBy
            )
        )
    }
}
