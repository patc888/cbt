import Charts
import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.melichan.TimeBlocking", category: "DashboardTrendChart")

struct DashboardTrendChart: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEnvironment.self) private var appEnvironment
    
    // Config
    let daysToLookBack = 14
    
    // State
    @State private var chartData: [DailyStat] = []
    @State private var selectedDate: Date?
    @State private var selectedStat: DailyStat?
    
    // UI Theme
    @Environment(\.colorScheme) private var colorScheme
    
    struct DailyStat: Identifiable, Equatable {
        let date: Date
        let plannedCount: Int
        let completedCount: Int
        let completedMinutes: Int
        let plannedMinutes: Int
        
        var id: Date { date }
    }
    
    var body: some View {
        TimeCard {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: - Header
                HStack(alignment: .bottom) {
                    TimeSectionHeader("Recent Progress", subtitle: "Last \(daysToLookBack) Days")
                    
                    Spacer()
                    
                    if let selectedStat = selectedStat {
                        // Tooltip in header pattern (since we don't have enough space for floating tooltips on standard iOS cards sometimes)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(selectedStat.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.secondaryText)
                                .textCase(.uppercase)
                            
                            HStack(spacing: 4) {
                                Text("\(selectedStat.completedCount)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.primaryText)
                                Text("/")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                Text("\(selectedStat.plannedCount)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                Text("Blocks")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                        }
                    } else if let latest = chartData.last {
                        // Default to latest
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Completion Rate")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.secondaryText)
                                .textCase(.uppercase)
                            
                            let rate = latest.plannedCount > 0 ? Int((Double(latest.completedCount) / Double(latest.plannedCount)) * 100) : 0
                            
                            Text("\(rate)%")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.primaryAccent)
                        }
                    }
                }
                
                Divider()
                
                // MARK: - Chart Area
                if chartData.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                } else {
                    Chart {
                        // 1. Gradient Area (Donor Style) for Completed
                        ForEach(chartData) { stat in
                            AreaMark(
                                x: .value("Date", stat.date),
                                y: .value("Completed", stat.completedCount)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Theme.successGreen.opacity(0.15),
                                        Theme.successGreen.opacity(0.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                        
                        // 2. Solid Line (Planned Blocks - Baseline/Goal)
                        ForEach(chartData) { stat in
                            LineMark(
                                x: .value("Date", stat.date),
                                y: .value("Planned", stat.plannedCount)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .foregroundStyle(Theme.secondaryText.opacity(0.5))
                        }
                        
                        // 3. Main Solid Line (Completed Blocks)
                        ForEach(chartData) { stat in
                            LineMark(
                                x: .value("Date", stat.date),
                                y: .value("Completed", stat.completedCount)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.successGreen)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            
                            PointMark(
                                x: .value("Date", stat.date),
                                y: .value("Completed", stat.completedCount)
                            )
                            .foregroundStyle(Theme.successGreen)
                        }
                        
                        // 4. Selection Highlight
                        if let selectedDate, let selectedStat {
                            RuleMark(x: .value("Selected", selectedDate))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                .foregroundStyle(Theme.secondaryText.opacity(0.5))
                            
                            PointMark(
                                x: .value("Selected Date", selectedDate),
                                y: .value("Selected Completed", selectedStat.completedCount)
                            )
                            .symbol {
                                Circle()
                                    .fill(Theme.successGreen)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(Theme.backgroundColor, lineWidth: 3))
                                    .shadow(color: Color.black.opacity(0.2), radius: 3)
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                                .foregroundStyle(Theme.secondaryText.opacity(0.15))
                            AxisValueLabel() {
                                if let intVal = value.as(Int.self) {
                                    Text("\(intVal)")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 3)) { value in
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            if let frameAnchor = proxy.plotFrame {
                                                let origin = geo[frameAnchor].origin
                                                let x = value.location.x - origin.x
                                                if let date: Date = proxy.value(atX: x) {
                                                    // Snap to nearest date
                                                    if let nearest = chartData.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                        if selectedDate != nearest.date {
                                                            #if os(iOS)
                                                            let generator = UISelectionFeedbackGenerator()
                                                            generator.prepare()
                                                            generator.selectionChanged()
                                                            #endif
                                                            selectedDate = nearest.date
                                                            selectedStat = nearest
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .onEnded { _ in
                                            #if os(iOS)
                                            let generator = UIImpactFeedbackGenerator(style: .light)
                                            generator.impactOccurred()
                                            #endif
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                withAnimation(.easeOut) {
                                                    selectedDate = nil
                                                    selectedStat = nil
                                                }
                                            }
                                        }
                                )
                        }
                    }
                    .frame(height: 180)
                    .padding(.top, 8)
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Data Loading
    @MainActor
    private func loadData() async {
        // Find blocks from the last N days
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let startDate = calendar.date(byAdding: .day, value: -(daysToLookBack - 1), to: today) ?? today.addingTimeInterval(Double(-(daysToLookBack - 1)) * 86400)
        let endDate = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86400)
        
        let descriptor = FetchDescriptor<TimeBlock>(
            predicate: #Predicate<TimeBlock> { block in
                block.startDate >= startDate && block.startDate < endDate
            }
        )
        
        do {
            let fetchedBlocks = try modelContext.fetch(descriptor)
            
            // Group by day locally
            var grouped: [Date: [TimeBlock]] = [:]
            for block in fetchedBlocks {
                let day = calendar.startOfDay(for: block.startDate)
                grouped[day, default: []].append(block)
            }
            
            var generatedStats: [DailyStat] = []
            
            // Ensure all days are represented, even if empty
            for i in 0..<daysToLookBack {
                let currentDay = calendar.date(byAdding: .day, value: i, to: startDate) ?? startDate.addingTimeInterval(Double(i) * 86400)
                let blocksForDay = grouped[currentDay] ?? []
                
                let planned = blocksForDay.count
                let completed = blocksForDay.filter { $0.status == .completed }.count
                
                let plannedMins = blocksForDay.reduce(0) { total, block in
                    total + Int(block.endDate.timeIntervalSince(block.startDate) / 60)
                }
                
                let completedMins = blocksForDay.filter({ $0.status == .completed }).reduce(0) { total, block in
                    total + Int(block.endDate.timeIntervalSince(block.startDate) / 60)
                }
                
                generatedStats.append(
                    DailyStat(
                        date: currentDay,
                        plannedCount: planned,
                        completedCount: completed,
                        completedMinutes: completedMins,
                        plannedMinutes: plannedMins
                    )
                )
            }
            
            await MainActor.run {
                withAnimation {
                    self.chartData = generatedStats.sorted(by: { $0.date < $1.date })
                }
            }
            
        } catch {
            logger.error("Failed to load chart data: \(error.localizedDescription, privacy: .public)")
        }
    }
}
