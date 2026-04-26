import SwiftUI
import Charts
import SwiftData

struct DashboardInsightsView: View {
    @Query private var allBlocks: [TimeBlock]

    
    @State private var viewModel = DashboardInsightsViewModel()
    @State private var timeRange: TimeRange = .sevenDays
    @State private var selectedDate: Date?

    init() {
        let earliestStartDate = Date.now.addingTimeInterval(-60 * 24 * 60 * 60)
        _allBlocks = Query(
            filter: #Predicate<TimeBlock> { block in
                block.startDate > earliestStartDate
            },
            sort: \TimeBlock.startDate,
            order: .forward
        )
    }
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case sevenDays = "7D"
        case thirtyDays = "30D"
        var id: String { rawValue }
        var days: Int {
            switch self {
            case .sevenDays: return 7
            case .thirtyDays: return 30
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isCalculating {
                VStack {
                    ProgressView()
                    Text("Analyzing your schedule...")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 40)
            } else {
                timeRangePicker
                
                streaksCard
                
                consistencyRingCard
                
                dailyTrendCard
                
                weeklyOverviewCard
                
                goalProgressSection
                
                topCategoriesSection
            }
        }
        .task {
            await viewModel.recalculate(timeRangeDays: timeRange.days, blocks: allBlocks)
        }
        .onChange(of: timeRange) { _, _ in
            Task { await viewModel.recalculate(timeRangeDays: timeRange.days, blocks: allBlocks) }
        }
        .onChange(of: allBlocks.count) { _, _ in
            Task { await viewModel.recalculate(timeRangeDays: timeRange.days, blocks: allBlocks) }
        }
    }
    
    private var timeRangePicker: some View {
        Picker("Time Range", selection: $timeRange) {
            ForEach(TimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
    
    // MARK: - Streaks
    private var streaksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Activity Streaks")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
            
            HStack(spacing: 12) {
                TimeMetricTile(
                    title: "Current Streak",
                    value: "\(viewModel.currentStreak)",
                    systemImage: "flame.fill",
                    unit: "days",
                    iconColor: .orange
                )
                
                TimeMetricTile(
                    title: "Longest Streak",
                    value: "\(viewModel.longestStreak)",
                    systemImage: "star.fill",
                    unit: "days",
                    iconColor: .yellow
                )
            }
        }
        .padding(Theme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.cardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - Consistency Ring
    private var consistencyRingCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Consistency")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("\(viewModel.milestonesCompleted)/4")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            ZStack {
                // Background Track
                Circle()
                    .stroke(Theme.primaryAccent.opacity(0.1), lineWidth: 18)
                    .frame(width: 160, height: 160)

                // Outer Ring (Active Days)
                Circle()
                    .trim(from: 0, to: max(0.001, viewModel.consistencyProgress))
                    .stroke(
                        LinearGradient(
                            colors: [Theme.primaryAccent, Theme.secondaryAccent],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 160, height: 160)
                    .shadow(color: Theme.primaryAccent.opacity(0.3), radius: 6, x: 0, y: 3)

                // Inner Ring (Milestones)
                Circle()
                    .stroke(Theme.secondaryAccent.opacity(0.1), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: max(0.001, Double(viewModel.milestonesCompleted) / 4.0))
                    .stroke(
                        LinearGradient(
                            colors: [Theme.secondaryAccent, Theme.primaryAccent.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)

                VStack(spacing: 2) {
                    Text("\(Int((viewModel.consistencyProgress * 100).rounded()))%")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                    Text("ACTIVE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .tracking(2)
                }
            }

            
            Text("\(viewModel.activeDaysCount) active days in last \(timeRange.days) days")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(Theme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.cardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
        )
    }

    // MARK: - Daily Trend
    private var dailyTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daily Completion")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("RATE")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            if viewModel.dailyCompletionRates.isEmpty {
                Text("Not enough data for trends.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(height: 150)
            } else {
                Chart {
                    ForEach(viewModel.dailyCompletionRates) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Rate", point.rate)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .foregroundStyle(Theme.primaryAccent)

                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Rate", point.rate)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.primaryAccent.opacity(0.2), Theme.primaryAccent.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    
                    RuleMark(y: .value("Goal", 0.8))
                        .foregroundStyle(Color.green.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                    if let selectedDate {
                        RuleMark(x: .value("Selected", selectedDate, unit: .day))
                            .foregroundStyle(Theme.primaryAccent.opacity(0.3))
                            .offset(y: -10)
                            .annotation(position: .top, spacing: 0) {
                                if let point = viewModel.dailyCompletionRates.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                                    VStack(spacing: 4) {
                                        Text(point.date.formatted(.dateTime.month().day()))
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundStyle(Theme.secondaryText)
                                        Text("\(Int((point.rate * 100).rounded()))%")
                                            .font(.system(size: 14, weight: .black, design: .rounded))
                                            .foregroundStyle(Theme.primaryAccent)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Theme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(color: .black.opacity(0.1), radius: 4)
                                }
                            }
                    }
                }
                .chartYScale(domain: 0...1)
                .chartXSelection(value: $selectedDate)
                .frame(height: 180)
            }
            
            HStack(spacing: 12) {
                TimeMetricTile(
                    title: "Avg Rate",
                    value: viewModel.averageCompletionRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "-",
                    systemImage: "chart.bar.fill",
                    unit: nil,
                    iconColor: Theme.primaryAccent
                )
                
                TimeMetricTile(
                    title: "Total Done",
                    value: "\(viewModel.totalCompletedBlocks)",
                    systemImage: "checkmark.seal.fill",
                    unit: "blocks",
                    iconColor: Theme.successGreen
                )
            }
        }
        .padding(Theme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.cardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
        )
    }

    // MARK: - Weekly Overview
    private var weeklyOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Weekly Performance")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("8 WEEKS")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            if viewModel.weeklyCompletionRates.isEmpty {
                Text("Analyzing weeks...")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(height: 150)
            } else {
                Chart {
                    ForEach(viewModel.weeklyCompletionRates) { point in
                        BarMark(
                            x: .value("Week", point.weekStart, unit: .weekOfYear),
                            y: .value("Rate", point.rate)
                        )
                        .foregroundStyle(Theme.secondaryAccent.opacity(0.7))
                        .cornerRadius(6)
                    }
                }
                .chartYScale(domain: 0...1.1)
                .frame(height: 150)
            }
        }
        .padding(Theme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.cardBackground)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
        )
    }

    // MARK: - Goals
    private var goalProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Productivity Goals")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
                .padding(.horizontal, 4)

            goalBar(title: "Overall Completion", progress: viewModel.completionGoalProgress, color: Theme.primaryAccent)
            goalBar(title: "Routine Discipline", progress: viewModel.routineGoalProgress, color: Theme.successGreen)
            goalBar(title: "Focus Time", progress: viewModel.focusGoalProgress, color: .blue)
        }
    }

    private func goalBar(title: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.1))
                        .frame(height: 12)

                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * min(1, max(0, progress)), height: 12)
                }
            }
            .frame(height: 12)
        }
        .padding(Theme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.cardBackground)
                .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
        )
    }

    // MARK: - Top Categories
    private var topCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Focus Areas")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            VStack(spacing: 8) {
                if viewModel.topCategories.isEmpty {
                    Text("No categories completed yet.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .padding()
                } else {
                    ForEach(viewModel.topCategories) { category in
                        HStack {
                            Text(category.name)
                                .font(.system(.body, design: .rounded).weight(.medium))
                            Spacer()
                            Text("\(category.count)")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.primaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.primaryAccent.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.cardBackground)
                        )
                    }
                }
            }
        }
    }
}
