import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Query(filter: #Predicate<MoodEntry> { $0.isDeleted == false }, sort: \.createdAt, order: .forward)
    private var moodEntries: [MoodEntry]

    @Query(filter: #Predicate<ThoughtRecord> { $0.isDeleted == false }, sort: \.createdAt, order: .forward)
    private var thoughtRecords: [ThoughtRecord]

    @Query(filter: #Predicate<ExerciseCompletion> { $0.isDeleted == false }, sort: \.createdAt, order: .forward)
    private var exerciseCompletions: [ExerciseCompletion]

    @State private var timeRange: TimeRange = .sevenDays
    @AppStorage("cbt_moodGoalValue") private var moodGoalValue = 7

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

    private var cutoffDate: Date {
        Calendar.current.date(byAdding: .day, value: -timeRange.days, to: Date()) ?? Date()
    }

    private var filteredMoodEntries: [MoodEntry] {
        moodEntries.filter { $0.createdAt >= cutoffDate }
    }

    private var filteredThoughtRecords: [ThoughtRecord] {
        thoughtRecords.filter { $0.createdAt >= cutoffDate }
    }

    private var filteredExerciseCompletions: [ExerciseCompletion] {
        exerciseCompletions.filter { $0.createdAt >= cutoffDate }
    }

    private var activeDaysCount: Int {
        let moodDays = filteredMoodEntries.map { Calendar.current.startOfDay(for: $0.createdAt) }
        let thoughtDays = filteredThoughtRecords.map { Calendar.current.startOfDay(for: $0.createdAt) }
        let exerciseDays = filteredExerciseCompletions.map { Calendar.current.startOfDay(for: $0.createdAt) }
        return Set(moodDays + thoughtDays + exerciseDays).count
    }

    private var dailyMoodAverages: [DailyMoodAverage] {
        let grouped = Dictionary(grouping: filteredMoodEntries) { Calendar.current.startOfDay(for: $0.createdAt) }
        return grouped.map { day, entries in
            let avg = Double(entries.map(\.moodScore).reduce(0, +)) / Double(entries.count)
            return DailyMoodAverage(date: day, averageScore: avg)
        }
        .sorted { $0.date < $1.date }
    }

    private var averageMood: Double? {
        guard !filteredMoodEntries.isEmpty else { return nil }
        return Double(filteredMoodEntries.map(\.moodScore).reduce(0, +)) / Double(filteredMoodEntries.count)
    }

    private var averageIntensityImprovement: Int? {
        let valid = filteredThoughtRecords.filter { (0...100).contains($0.intensityBefore) && (0...100).contains($0.intensityAfter) }
        guard !valid.isEmpty else { return nil }
        let total = valid.map { $0.intensityBefore - $0.intensityAfter }.reduce(0, +)
        return total / valid.count
    }

    private var consistencyGoalTarget: Int {
        max(3, Int((Double(timeRange.days) * 0.7).rounded()))
    }

    private var consistencyProgress: Double {
        guard consistencyGoalTarget > 0 else { return 0 }
        return min(1, Double(activeDaysCount) / Double(consistencyGoalTarget))
    }

    private var moodGoalProgress: Double {
        guard !filteredMoodEntries.isEmpty else { return 0 }
        let hits = filteredMoodEntries.filter { $0.moodScore >= moodGoalValue }.count
        return Double(hits) / Double(filteredMoodEntries.count)
    }

    private var thoughtGoalProgress: Double {
        guard let improvement = averageIntensityImprovement else { return 0 }
        return min(1, Double(max(0, improvement)) / 15.0)
    }

    private var exerciseGoalTarget: Int {
        max(2, timeRange.days / 4)
    }

    private var exerciseProgress: Double {
        guard exerciseGoalTarget > 0 else { return 0 }
        return min(1, Double(filteredExerciseCompletions.count) / Double(exerciseGoalTarget))
    }

    private var milestonesCompleted: Int {
        [consistencyProgress, moodGoalProgress, thoughtGoalProgress, exerciseProgress].filter { $0 >= 1.0 }.count
    }

    private var topEmotions: [EmotionCount] {
        let all = filteredMoodEntries.flatMap(\.emotions) + filteredThoughtRecords.flatMap(\.emotions)
        var counts: [String: Int] = [:]

        for emotion in all {
            let normalized = emotion.trimmingCharacters(in: .whitespaces).lowercased()
            if !normalized.isEmpty {
                counts[normalized, default: 0] += 1
            }
        }

        return counts.map { EmotionCount(name: $0.key.capitalized, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(4)
            .map { $0 }
    }

    private var topDistortions: [DistortionCount] {
        var counts: [String: Int] = [:]

        for distortion in filteredThoughtRecords.flatMap(\.distortions) {
            let normalized = distortion.trimmingCharacters(in: .whitespaces).lowercased()
            if !normalized.isEmpty {
                counts[normalized, default: 0] += 1
            }
        }

        return counts.map { DistortionCount(name: $0.key.capitalized, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        ZStack {
            Theme.secondaryBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    TopHeadlineView(title: "Insights")

                    SegmentedToggle(selection: $timeRange, options: TimeRange.allCases, titleKey: \.rawValue)

                    milestonesRingCard
                    trendsCard
                    goalProgressSection
                    rankingCard(title: "Top Emotions", rows: topEmotions.map { ($0.name, $0.count) }, emptyText: "No emotions recorded.")
                    rankingCard(title: "Top Distortions", rows: topDistortions.map { ($0.name, $0.count) }, emptyText: "No distortions recorded.")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 12)
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var milestonesRingCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Milestones")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("\(milestonesCompleted)/4")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            ZStack {
                Circle()
                    .stroke(Theme.secondaryColor.opacity(0.15), lineWidth: 24)
                    .frame(width: 190, height: 190)

                Circle()
                    .trim(from: 0, to: max(0.001, consistencyProgress))
                    .stroke(Theme.secondaryColor, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 190, height: 190)

                Circle()
                    .stroke(Theme.primaryColor.opacity(0.12), lineWidth: 18)
                    .frame(width: 136, height: 136)

                Circle()
                    .trim(from: 0, to: max(0.001, Double(milestonesCompleted) / 4.0))
                    .stroke(Theme.primaryColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 136, height: 136)

                VStack(spacing: 4) {
                    Text("\(Int((consistencyProgress * 100).rounded()))%")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                    Text("CONSISTENCY")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Text("\(activeDaysCount) active days in last \(timeRange.days) days")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var trendsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Wellbeing Trends")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("\(filteredMoodEntries.count) ENTRIES")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            if dailyMoodAverages.isEmpty {
                Text("No mood data for this range.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 18)
            } else {
                Chart {
                    ForEach(dailyMoodAverages) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Mood", point.averageScore)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2.2))
                        .foregroundStyle(Theme.primaryColor)

                        PointMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Mood", point.averageScore)
                        )
                        .foregroundStyle(Theme.primaryColor)
                    }

                    RuleMark(y: .value("Mood Goal", Double(moodGoalValue)))
                        .foregroundStyle(Theme.secondaryColor.opacity(0.85))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
                .chartYScale(domain: 1...10)
                .frame(height: 220)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MiniStatCard(
                    title: "Avg Mood",
                    value: averageMood.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "-",
                    unit: "/10",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: Theme.primaryColor,
                    valueColor: Theme.primaryText,
                    state: .neutral
                )

                MiniStatCard(
                    title: "Thought Relief",
                    value: averageIntensityImprovement.map { "\($0)" } ?? "-",
                    unit: "pts",
                    icon: "brain",
                    iconColor: Theme.secondaryColor,
                    valueColor: Theme.primaryText,
                    state: .neutral
                )
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var goalProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Goal Progress")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)

            goalProgressCard(
                title: "Consistency Goal",
                subtitle: "\(activeDaysCount) of \(consistencyGoalTarget) active days",
                progress: consistencyProgress,
                tint: Theme.primaryColor
            )

            goalProgressCard(
                title: "Mood Goal (\(moodGoalValue)+)",
                subtitle: "\(Int((moodGoalProgress * 100).rounded()))% entries hit target",
                progress: moodGoalProgress,
                tint: Theme.secondaryColor
            )

            goalProgressCard(
                title: "Thought Relief Goal",
                subtitle: averageIntensityImprovement.map { "\($0) of 15 pts average relief" } ?? "No thought records yet",
                progress: thoughtGoalProgress,
                tint: .orange
            )

            goalProgressCard(
                title: "Exercise Goal",
                subtitle: "\(filteredExerciseCompletions.count) of \(exerciseGoalTarget) exercises",
                progress: exerciseProgress,
                tint: .green
            )
        }
    }

    private func goalProgressCard(title: String, subtitle: String, progress: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("\(Int((min(1, max(0, progress)) * 100).rounded()))%")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.8))
            }

            Text(subtitle)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.toggleBackgroundColor(for: .light))
                        .frame(height: 10)

                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * min(1, max(0, progress)), height: 10)
                }
            }
            .frame(height: 10)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func rankingCard(title: String, rows: [(String, Int)], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)

            if rows.isEmpty {
                Text(emptyText)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack {
                            Text(row.0)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                            Spacer()
                            Text("\(row.1)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.primaryColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}
