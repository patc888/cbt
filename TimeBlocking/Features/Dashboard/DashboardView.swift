import Charts
import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.melichan.TimeBlocking", category: "DashboardView")

struct DashboardView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext

    private var now: Date {
        .now
    }

    @Query private var blocks: [TimeBlock]

    init() {
        let earliestEndDate = Date.now.addingTimeInterval(-86400)
        _blocks = Query(
            filter: #Predicate<TimeBlock> { block in
                block.endDate > earliestEndDate
            },
            sort: \TimeBlock.startDate
        )
    }

    private var summary: ScheduleDashboardSummary {
        appEnvironment.scheduleRepository.dashboardSummary(
            for: now,
            from: blocks
        )
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
        ZStack(alignment: .top) {
            AuroraBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Spacer()
                        Text("Stats")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                    TimeCard {
                        VStack(alignment: .leading, spacing: 16) {
                            TimeSectionHeader("Today", subtitle: todayLabel)
                                .padding(.top, 4)

                            if summary.isEmpty {
                                Divider()

                                PremiumEmptyStateView(
                                    title: "No Plan Yet",
                                    message: "Add a block in Schedule, or create routines for plans you want to regenerate later.",
                                    systemImage: "calendar.badge.plus",
                                    eyebrow: "Get Started",
                                    actionTitle: "Add Block"
                                ) {
                                    appEnvironment.appState.showAddBlock()
                                }
                    .padding(.vertical, 20)
                                } else {

                                Divider()

                                // MARK: - Overview Main Stat
                                VStack(spacing: 4) {
                                    let rate = summary.totalBlocks > 0
                                        ? Int((Double(summary.daySnapshot.completedCount) / Double(summary.totalBlocks)) * 100)
                                        : 0

                                    Text("\(rate)%")
                                        .font(.system(size: 52, weight: .black, design: .rounded))
                                        .foregroundStyle(Theme.primaryText)
                                        .contentTransition(.numericText())

                                    Text("\(summary.daySnapshot.completedCount) of \(summary.totalBlocks) Blocks Completed")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                        .padding(.top, 4)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)

                                DashboardInsightsView()

                                // MARK: - Quick Stats Grid
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    TimeMetricTile(
                                        title: "Planned Today",
                                        value: "\(summary.daySnapshot.plannedCount)",
                                        systemImage: "calendar.badge.clock"
                                    )
                                    TimeMetricTile(
                                        title: "Completed",
                                        value: "\(summary.daySnapshot.completedCount)",
                                        systemImage: "checkmark.circle",
                                        iconColor: Theme.successGreen
                                    )
                                    TimeMetricTile(
                                        title: "Scheduled",
                                        value: "\(summary.daySnapshot.scheduledMinutes)",
                                        systemImage: "timer",
                                        unit: "min",
                                        iconColor: Theme.secondaryAccent
                                    )
                                    TimeMetricTile(
                                        title: "Remaining",
                                        value: "\(summary.remainingScheduledMinutes(after: now))",
                                        systemImage: currentBlock == nil ? "forward.fill" : "play.circle.fill",
                                        unit: "min",
                                        iconColor: Theme.warningOrange
                                    )
                                }

                                Text(completionText)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                    .padding(.top, 10)
                            }
                        }
                    }

                    if let currentBlock {
                        TimeCard {
                            VStack(alignment: .leading, spacing: 16) {
                                TimeSectionHeader("In Progress", subtitle: "Ends at \(currentBlock.endDate.formatted(date: .omitted, time: .shortened))")

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

                                Divider()

                                TimeBlockRowView(block: nextBlock)
                            }
                        }
                    }
                }
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 60)
            .padding(.bottom, 40)

            topBar
        }
        .ignoresSafeArea()
#if os(iOS)
        .statusBarHidden(true)
#endif
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .bottomBar)
        .toolbar(.hidden, for: .tabBar)
        #endif
    }

    private var topBar: some View {
        HStack {
            Button(action: {
                HapticManager.shared.lightImpact()
                appEnvironment.appState.showScheduleHome()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.primaryAccent)
                    .frame(width: 36, height: 36)
                    .background(Theme.primaryAccent.opacity(0.1))
                    .clipShape(Circle())
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
    }
}

#Preview {
    DashboardView()
        .environment(AppEnvironment(persistenceController: .preview))
        .modelContainer(PersistenceController.preview.container)
}

