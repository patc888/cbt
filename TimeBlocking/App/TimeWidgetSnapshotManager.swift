import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
struct TimeWidgetSnapshotManager {
    private let repository: ScheduleRepository
    private let store: TimeBlockingWidgetSnapshotStore

    init(
        repository: ScheduleRepository,
        store: TimeBlockingWidgetSnapshotStore? = nil
    ) {
        self.repository = repository
        self.store = store ?? TimeBlockingWidgetSnapshotStore()
    }

    func refresh(
        using modelContext: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws {
        let summary = try repository.dashboardSummary(
            for: now,
            in: modelContext,
            calendar: calendar
        )

        let snapshot = TimeBlockingWidgetSnapshot(
            generatedAt: now,
            referenceDay: calendar.startOfDay(for: now),
            upcomingBlocks: summary.upcomingBlocks.map { block in
                TimeBlockingWidgetBlockSnapshot(
                    title: block.title,
                    categoryTitle: block.category.title,
                    startDate: block.startDate,
                    endDate: block.endDate
                )
            },
            todaySummary: TimeBlockingWidgetTodaySummarySnapshot(
                plannedCount: summary.daySnapshot.plannedCount,
                completedCount: summary.daySnapshot.completedCount,
                scheduledMinutes: summary.daySnapshot.scheduledMinutes
            )
        )

        try store.save(snapshot)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
