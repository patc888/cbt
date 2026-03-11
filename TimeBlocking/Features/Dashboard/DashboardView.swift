import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext

    private var now: Date {
        .now
    }

    private var summary: ScheduleDashboardSummary {
        do {
            return try appEnvironment.scheduleRepository.dashboardSummary(
                for: now,
                in: modelContext
            )
        } catch {
            assertionFailure("Failed to build dashboard summary: \(error)")
            return ScheduleDashboardSummary(
                daySnapshot: ScheduleDaySnapshot(
                    blocks: [],
                    completedCount: 0,
                    plannedCount: 0,
                    scheduledMinutes: 0
                ),
                upcomingBlocks: []
            )
        }
    }

    private var todayLabel: String {
        now.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 12)]
    }

    private var currentBlock: TimeBlock? {
        summary.currentBlock(at: now)
    }

    private var remainingTodayBlocks: [TimeBlock] {
        summary.remainingTodayBlocks(after: now)
    }

    private var upcomingLaterTodayBlocks: [TimeBlock] {
        let currentBlockID = currentBlock?.id
        return remainingTodayBlocks.filter { block in
            block.id != currentBlockID && block.startDate > now
        }
    }

    private var completionText: String {
        guard !summary.daySnapshot.blocks.isEmpty else {
            return "No blocks scheduled for today yet."
        }

        if summary.daySnapshot.completedCount == summary.totalBlocks {
            return "Everything scheduled for today is complete."
        }

        if let currentBlock {
            return "\(summary.daySnapshot.completedCount) of \(summary.totalBlocks) blocks completed. \(currentBlock.title) is in progress now."
        }

        if let nextBlock = remainingTodayBlocks.first {
            return "\(summary.daySnapshot.completedCount) of \(summary.totalBlocks) blocks completed. Next start: \(nextBlock.startDate.formatted(date: .omitted, time: .shortened))."
        }

        return "\(summary.daySnapshot.completedCount) of \(summary.totalBlocks) blocks completed. No more blocks remain today."
    }

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TimeCard {
                        VStack(alignment: .leading, spacing: 16) {
                            TimeSectionHeader("Today", subtitle: todayLabel)
                                .padding(.top, 4)

                            Text("A quick view of the current day and what is coming up next.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)

                            if summary.isEmpty {
                                Divider()
                                
                                EmptyStateView(
                                    title: "No Plan For Today",
                                    systemImage: "calendar.badge.plus",
                                    message: "Add a time block in Schedule or generate routines from Templates to build today’s overview."
                                )
                                .padding(.vertical, 20)
                            } else {
                                Divider()

                                LazyVGrid(columns: metricColumns, spacing: Theme.paddingMedium) {
                                    TimeMetricTile(
                                        title: "Planned Today",
                                        value: "\(summary.daySnapshot.plannedCount)",
                                        systemImage: "calendar.badge.clock"
                                    )
                                    TimeMetricTile(
                                        title: "Completed",
                                        value: "\(summary.daySnapshot.completedCount)",
                                        systemImage: "checkmark.circle"
                                    )
                                    TimeMetricTile(
                                        title: "Scheduled",
                                        value: "\(summary.daySnapshot.scheduledMinutes) min",
                                        systemImage: "timer"
                                    )
                                    TimeMetricTile(
                                        title: "Remaining",
                                        value: "\(summary.remainingScheduledMinutes(after: now)) min",
                                        systemImage: currentBlock == nil ? "forward.fill" : "play.circle.fill"
                                    )
                                }

                                Text(completionText)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                    .padding(.top, 4)
                            }
                        }
                    }

                    if let currentBlock {
                        TimeCard {
                            VStack(alignment: .leading, spacing: 16) {
                                TimeSectionHeader("In Progress", subtitle: "Ends at \(currentBlock.endDate.formatted(date: .omitted, time: .shortened))")

                                Text("This block is active right now.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)

                                Divider()

                                TimeBlockRowView(block: currentBlock)

                                if !upcomingLaterTodayBlocks.isEmpty {
                                    Divider().padding(.vertical, 8)

                                    TimeSectionHeader("Later Today", subtitle: "The next planned blocks after the current one")

                                    VStack(spacing: 0) {
                                        ForEach(upcomingLaterTodayBlocks) { block in
                                            TimeBlockRowView(block: block)

                                            if block.id != upcomingLaterTodayBlocks.last?.id {
                                                Divider().padding(.vertical, 12)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else if let nextBlock = remainingTodayBlocks.first {
                        TimeCard {
                            VStack(alignment: .leading, spacing: 16) {
                                TimeSectionHeader("Next Up", subtitle: nextBlock.startDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))

                                Text("The next planned block on today’s schedule.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)

                                Divider()

                                TimeBlockRowView(block: nextBlock)

                                let laterBlocks = Array(upcomingLaterTodayBlocks.dropFirst())
                                if !laterBlocks.isEmpty {
                                    Divider().padding(.vertical, 8)

                                    TimeSectionHeader("After That", subtitle: "The rest of today’s planned blocks")

                                    VStack(spacing: 0) {
                                        ForEach(laterBlocks) { block in
                                            TimeBlockRowView(block: block)

                                            if block.id != laterBlocks.last?.id {
                                                Divider().padding(.vertical, 12)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else if let nextBlock = summary.nextBlock {
                        TimeCard {
                            VStack(alignment: .leading, spacing: 16) {
                                TimeSectionHeader("Next Planned Block", subtitle: nextBlock.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))

                                Text("Today is clear. This is the next planned block in the schedule.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)

                                Divider()

                                TimeBlockRowView(block: nextBlock)
                            }
                        }
                    }
                }
                .padding()
                .padding(.top, 64) // Offset for custom header
                .padding(.bottom, 100)
            }
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppEnvironment(persistenceController: .preview))
        .modelContainer(PersistenceController.preview.container)
}
