import SwiftData
import SwiftUI

struct TopHeadlineView<Leading: View, Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    let leading: Leading
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .center) {
                // Leading Content (e.g., Streak Button)
                HStack {
                    leading
                    Spacer()
                }

                // Centered Title
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DSTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(DSTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)

                // Trailing Content
                HStack {
                    Spacer()
                    trailing
                }
            }
            .frame(height: 44)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }
}

extension TopHeadlineView where Leading == EmptyView, Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

extension TopHeadlineView where Leading == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.init(title: title, subtitle: subtitle, leading: { EmptyView() }, trailing: trailing)
    }
}

extension TopHeadlineView where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder leading: () -> Leading) {
        self.init(title: title, subtitle: subtitle, leading: leading, trailing: { EmptyView() })
    }
}

struct StreakToolbarButton: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("cbt_showStreakInToolbar") private var showStreakInToolbar = true
    @Query(sort: \MoodEntry.createdAt, order: .reverse) private var moodEntries: [MoodEntry]
    @Query(sort: \ThoughtRecord.createdAt, order: .reverse) private var thoughtRecords: [ThoughtRecord]
    @Query(sort: \ExerciseCompletion.createdAt, order: .reverse) private var exerciseCompletions: [ExerciseCompletion]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var journalEntries: [JournalEntry]

    @State private var showingStreak = false

    private var activeDays: Set<Date> {
        let calendar = Calendar.current
        let moodDays = moodEntries
            .filter { !$0.isDeleted }
            .map { calendar.startOfDay(for: $0.createdAt) }
        let thoughtDays = thoughtRecords
            .filter { !$0.isDeleted }
            .map { calendar.startOfDay(for: $0.createdAt) }
        let exerciseDays = exerciseCompletions
            .filter { !$0.isDeleted }
            .map { calendar.startOfDay(for: $0.createdAt) }
        let journalDays = journalEntries
            .filter { !$0.isDeleted }
            .map { calendar.startOfDay(for: $0.createdAt) }

        return Set(moodDays + thoughtDays + exerciseDays + journalDays)
    }

    private var snapshot: StreakSnapshot {
        StreakSnapshot(activeDays: activeDays)
    }

    var body: some View {
        Group {
            if showStreakInToolbar {
                Button {
                    HapticManager.shared.selection()
                    showingStreak = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14, weight: .bold))

                        Text("\(snapshot.currentStreak)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(themeManager.selectedColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(themeManager.selectedColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Streak, \(snapshot.currentStreak) days")
                .accessibilityHint("Shows your activity streak calendar")
            }
        }
        .sheet(isPresented: $showingStreak) {
            StreakSheet(activeDays: activeDays, showStreakInToolbar: $showStreakInToolbar)
        }
    }
}

private struct StreakSnapshot {
    let activeDays: Set<Date>
    let calendar: Calendar
    let today: Date

    init(activeDays: Set<Date>, calendar: Calendar = .current, now: Date = Date()) {
        self.calendar = calendar
        self.today = calendar.startOfDay(for: now)
        self.activeDays = Set(activeDays.map { calendar.startOfDay(for: $0) })
    }

    var currentStreak: Int {
        guard activeDays.contains(today) else { return 0 }

        var day = today
        var count = 0
        while activeDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    var longestStreak: Int {
        let sortedDays = activeDays.sorted()
        guard !sortedDays.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for index in sortedDays.indices.dropFirst() {
            let previous = sortedDays[sortedDays.index(before: index)]
            let day = sortedDays[index]
            let difference = calendar.dateComponents([.day], from: previous, to: day).day ?? 0

            if difference == 1 {
                current += 1
            } else if difference > 1 {
                current = 1
            }
            longest = max(longest, current)
        }

        return longest
    }

    var nextMilestone: Int {
        [3, 7, 14, 30, 60, 100, 365].first { currentStreak < $0 } ?? (((currentStreak / 100) + 1) * 100)
    }

    var milestoneProgress: Double {
        guard nextMilestone > 0 else { return 0 }
        return min(1, Double(currentStreak) / Double(nextMilestone))
    }
}

private struct StreakSheet: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    let activeDays: Set<Date>
    @Binding var showStreakInToolbar: Bool

    private var snapshot: StreakSnapshot {
        StreakSnapshot(activeDays: activeDays)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    StreakSummaryCard(snapshot: snapshot)
                    streakVisibilityCard
                    StreakCalendarMonth(activeDays: snapshot.activeDays)
                    StreakStatsRow(snapshot: snapshot)
                }
                .padding(16)
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
            }
            .background(ThemedBackground().ignoresSafeArea())
            .navigationTitle("Streak")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeManager.selectedColor)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    private var streakVisibilityCard: some View {
        DSCardContainer {
            ToggleRow(
                icon: "flame.fill",
                iconColor: themeManager.selectedColor,
                title: "Show Streak",
                subtitle: "Display the streak button in the top toolbar.",
                isOn: $showStreakInToolbar
            )
            .padding(.horizontal, -20)
            .padding(.vertical, -14)
        }
    }
}

private struct StreakSummaryCard: View {
    @Environment(ThemeManager.self) private var themeManager

    let snapshot: StreakSnapshot

    var body: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 52, height: 52)
                        .background(themeManager.selectedColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(snapshot.currentStreak)/\(snapshot.nextMilestone) day streak")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(DSTheme.primaryText)
                            .monospacedDigit()

                        Text(snapshot.currentStreak == 0 ? "Log one activity today to start." : "Next milestone is getting closer.")
                            .font(DSTypography.caption)
                            .foregroundStyle(DSTheme.secondaryText)
                    }
                }

                ProgressView(value: snapshot.milestoneProgress)
                    .tint(themeManager.selectedColor)
            }
        }
    }
}

private struct StreakStatsRow: View {
    let snapshot: StreakSnapshot

    var body: some View {
        HStack(spacing: 12) {
            DSMetricCard(
                title: "Current",
                value: "\(snapshot.currentStreak)",
                icon: "flame.fill",
                subtitle: snapshot.currentStreak == 1 ? "day" : "days"
            )

            DSMetricCard(
                title: "Longest",
                value: "\(snapshot.longestStreak)",
                icon: "trophy.fill",
                subtitle: snapshot.longestStreak == 1 ? "day" : "days"
            )
        }
    }
}

private struct StreakCalendarMonth: View {
    @Environment(ThemeManager.self) private var themeManager

    let activeDays: Set<Date>

    private var calendar: Calendar {
        Calendar.current
    }

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: Date())?.start ?? calendar.startOfDay(for: Date())
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: monthStart)
    }

    private var weekdaySymbols: [String] {
        calendar.shortStandaloneWeekdaySymbols.map { String($0.prefix(1)) }
    }

    private var daySlots: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else { return [] }
        let startWeekday = calendar.component(.weekday, from: monthInterval.start)
        let padding = (startWeekday - calendar.firstWeekday + 7) % 7
        let gridStart = calendar.date(byAdding: .day, value: -padding, to: monthInterval.start) ?? monthInterval.start

        return (0..<42).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart)
        }
    }

    var body: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(monthTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(DSTheme.primaryText)

                    Spacer()

                    Label("Active", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.selectedColor)
                }

                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(DSTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    ForEach(daySlots, id: \.self) { day in
                        StreakCalendarDay(
                            date: day,
                            isActive: activeDays.contains(calendar.startOfDay(for: day)),
                            isToday: calendar.isDateInToday(day),
                            isCurrentMonth: calendar.isDate(day, equalTo: monthStart, toGranularity: .month)
                        )
                    }
                }
            }
        }
    }
}

private struct StreakCalendarDay: View {
    @Environment(ThemeManager.self) private var themeManager

    let date: Date
    let isActive: Bool
    let isToday: Bool
    let isCurrentMonth: Bool

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(dayNumber)")
                .font(.system(size: 13, weight: isToday || isActive ? .bold : .medium, design: .rounded))
                .foregroundStyle(textColor)
                .padding(.horizontal, 7)
                .frame(minWidth: 26, minHeight: 26)
                .background(
                    ZStack {
                        if isActive {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(themeManager.selectedColor)
                        } else if isToday {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(themeManager.selectedColor.opacity(0.5), lineWidth: 2)
                        }
                    }
                )

            HStack(spacing: 3) {
                Circle()
                    .fill(isActive ? Theme.successGreen : Color.clear)
                    .frame(width: 5, height: 5)

                Circle()
                    .fill(isToday ? themeManager.selectedColor.opacity(isActive ? 0.8 : 0.55) : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isActive ? themeManager.selectedColor.opacity(0.08) : Color.clear)
        )
        .opacity(isCurrentMonth ? 1.0 : 0.3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var textColor: Color {
        if isActive {
            return .white
        }
        if isToday {
            return themeManager.selectedColor
        }
        return DSTheme.primaryText
    }

    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let status = isActive ? "active" : "not active"
        return "\(isToday ? "Today, " : "")\(formatter.string(from: date)). \(status)."
    }
}
