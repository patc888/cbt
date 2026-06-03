import Foundation
import SwiftData

@MainActor
struct DailyPlanCompletionService {
    static let shared = DailyPlanCompletionService()

    @discardableResult
    func complete(
        itemType: DailyPlanCompletionItemType,
        itemID: String? = nil,
        title: String,
        on date: Date = Date(),
        completedAt: Date = Date(),
        sourceScreen: String? = nil,
        durationSeconds: Int? = nil,
        wasRecommended: Bool = false,
        recommendationReason: String? = nil,
        allowsDuplicates: Bool = false,
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> DailyPlanCompletion {
        let day = calendar.startOfDay(for: date)
        if !allowsDuplicates, let existing = try existingCompletion(
            itemType: itemType,
            itemID: itemID,
            on: day,
            in: context,
            calendar: calendar
        ) {
            return existing
        }

        let completion = DailyPlanCompletion(
            date: day,
            itemType: itemType,
            itemID: normalizedItemID(itemID),
            title: title,
            completedAt: completedAt,
            sourceScreen: sourceScreen,
            durationSeconds: durationSeconds,
            wasRecommended: wasRecommended,
            recommendationReason: recommendationReason
        )
        context.insert(completion)
        try context.save()
        return completion
    }

    func completionsForToday(
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> [DailyPlanCompletion] {
        try completions(on: now, in: context, calendar: calendar)
    }

    func completionsForThisWeek(
        in context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> [DailyPlanCompletion] {
        let interval = calendar.dateInterval(of: .weekOfYear, for: now)
        let start = interval?.start ?? calendar.startOfDay(for: now)
        let end = interval?.end ?? calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(604_800)
        return try completions(from: start, to: end, in: context)
    }

    func completions(
        byType itemType: DailyPlanCompletionItemType,
        in context: ModelContext
    ) throws -> [DailyPlanCompletion] {
        let rawType = itemType.rawValue
        return try context.fetch(FetchDescriptor<DailyPlanCompletion>(
            predicate: #Predicate<DailyPlanCompletion> {
                $0.isDeleted == false && $0.itemType == rawType
            },
            sortBy: [SortDescriptor(\DailyPlanCompletion.completedAt, order: .reverse)]
        ))
    }

    func latestCompletion(in context: ModelContext) throws -> DailyPlanCompletion? {
        var descriptor = FetchDescriptor<DailyPlanCompletion>(
            predicate: #Predicate<DailyPlanCompletion> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\DailyPlanCompletion.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func hasCompletion(
        _ itemType: DailyPlanCompletionItemType,
        itemID: String? = nil,
        on date: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> Bool {
        try existingCompletion(
            itemType: itemType,
            itemID: itemID,
            on: calendar.startOfDay(for: date),
            in: context,
            calendar: calendar
        ) != nil
    }

    private func existingCompletion(
        itemType: DailyPlanCompletionItemType,
        itemID: String?,
        on day: Date,
        in context: ModelContext,
        calendar: Calendar
    ) throws -> DailyPlanCompletion? {
        let rawType = itemType.rawValue
        let normalizedID = normalizedItemID(itemID)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        var descriptor = FetchDescriptor<DailyPlanCompletion>(
            predicate: #Predicate<DailyPlanCompletion> {
                $0.isDeleted == false &&
                $0.itemType == rawType &&
                $0.itemID == normalizedID &&
                $0.date >= day &&
                $0.date < dayEnd
            },
            sortBy: [SortDescriptor(\DailyPlanCompletion.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func completions(
        on date: Date,
        in context: ModelContext,
        calendar: Calendar
    ) throws -> [DailyPlanCompletion] {
        let day = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        return try completions(from: day, to: dayEnd, in: context)
    }

    private func completions(
        from start: Date,
        to end: Date,
        in context: ModelContext
    ) throws -> [DailyPlanCompletion] {
        try context.fetch(FetchDescriptor<DailyPlanCompletion>(
            predicate: #Predicate<DailyPlanCompletion> {
                $0.isDeleted == false &&
                $0.date >= start &&
                $0.date < end
            },
            sortBy: [SortDescriptor(\DailyPlanCompletion.completedAt, order: .reverse)]
        ))
    }

    private func normalizedItemID(_ itemID: String?) -> String? {
        guard let itemID else { return nil }
        let trimmed = itemID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
