import SwiftData
import SwiftUI

struct StreakToolbarButton: View {
    @Environment(ThemeManager.self) private var themeManager
    @AppStorage(AppConfiguration.showStreakInToolbarKey) private var showStreakInToolbar = true
    @Query(sort: \MoodEntry.createdAt, order: .reverse) private var moodEntries: [MoodEntry]
    @Query(sort: \ThoughtRecord.createdAt, order: .reverse) private var thoughtRecords: [ThoughtRecord]
    @Query(sort: \ExerciseCompletion.createdAt, order: .reverse) private var exerciseCompletions: [ExerciseCompletion]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var journalEntries: [JournalEntry]
    @Query(sort: \MoodCheckIn.createdAt, order: .reverse) private var moodCheckIns: [MoodCheckIn]
    @Query(sort: \FlexibleJournalEntry.date, order: .reverse) private var flexibleJournalEntries: [FlexibleJournalEntry]
    @Query(sort: \BreathingSession.createdAt, order: .reverse) private var breathingSessions: [BreathingSession]
    @Query(sort: \PlannedActivity.createdAt, order: .reverse) private var plannedActivities: [PlannedActivity]
    @Query(sort: \AssessmentLog.date, order: .reverse) private var assessmentLogs: [AssessmentLog]
    @Query(sort: \PersonalityAssessmentLog.date, order: .reverse) private var personalityAssessmentLogs: [PersonalityAssessmentLog]
    @Query(sort: \Course.title) private var courses: [Course]

    @State private var showingStreak = false

    private var activeDays: Set<Date> {
        let calendar = Calendar.current
        return [
            moodEntries.compactMap { $0.isDeleted ? nil : calendar.startOfDay(for: $0.createdAt) },
            thoughtRecords.compactMap { $0.isDeleted ? nil : calendar.startOfDay(for: $0.createdAt) },
            exerciseCompletions.compactMap { $0.isDeleted ? nil : calendar.startOfDay(for: $0.createdAt) },
            journalEntries.compactMap { $0.isDeleted ? nil : calendar.startOfDay(for: $0.createdAt) },
            moodCheckIns.compactMap { $0.isDeleted ? nil : calendar.startOfDay(for: $0.createdAt) },
            flexibleJournalEntries.map { calendar.startOfDay(for: $0.date) },
            breathingSessions.compactMap { $0.isDeleted ? nil : calendar.startOfDay(for: $0.createdAt) },
            plannedActivities.compactMap { activity in
                guard !activity.isDeleted, activity.isCompleted else { return nil }
                return calendar.startOfDay(for: activity.completedAt ?? activity.createdAt)
            },
            assessmentLogs.map { calendar.startOfDay(for: $0.date) },
            personalityAssessmentLogs.map { calendar.startOfDay(for: $0.date) },
            courses.compactMap { course in
                guard course.isCompleted, let completedAt = course.completedAt else { return nil }
                return calendar.startOfDay(for: completedAt)
            }
        ]
        .reduce(into: Set<Date>()) { $0.formUnion($1) }
    }

    private var snapshot: StreakSnapshot {
        StreakSnapshot(activeDays: activeDays)
    }

    var body: some View {
        Group {
            if showStreakInToolbar {
                Button {
                    HapticManager.shared.mediumImpact()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                        showingStreak = true
                    }
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
            StreakSheet(activeDays: activeDays)
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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Achievement.createdAt) private var achievements: [Achievement]

    let activeDays: Set<Date>
    @State private var hasAppeared = false
    @State private var achievementProgress: [String: AchievementProgress] = [:]

    private var snapshot: StreakSnapshot {
        StreakSnapshot(activeDays: activeDays)
    }

    var body: some View {
        NavigationStack {
            DSSheetContainer(maxContentWidth: 760) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        StreakHeroCard(snapshot: snapshot, animate: hasAppeared && !reduceMotion)
                            .streakEntrance(index: 0, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        StreakStatsRow(snapshot: snapshot)
                            .streakEntrance(index: 1, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        AchievementsProfileSection(
                            achievements: achievements,
                            progress: achievementProgress
                        )
                        .streakEntrance(index: 2, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        StreakCalendarMonth(activeDays: snapshot.activeDays, animate: hasAppeared && !reduceMotion)
                            .streakEntrance(index: 3, isVisible: hasAppeared, reduceMotion: reduceMotion)
                    }
                    .padding(.vertical, DSSpacing.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Streak")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .foregroundStyle(themeManager.selectedColor)
                }
            }
            .onAppear {
                guard !hasAppeared else { return }
                if reduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                        hasAppeared = true
                    }
                }
            }
            .task {
                refreshAchievements()
            }
        }
        .dsSheetPresentation(detents: [.large])
    }

    private func refreshAchievements() {
        AchievementService.shared.evaluateAchievements(in: modelContext)
        achievementProgress = AchievementService.shared.progressSnapshots(in: modelContext)
    }
}

private struct StreakHeroCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let snapshot: StreakSnapshot
    let animate: Bool

    private var accent: Color {
        themeManager.selectedColor
    }

    private var secondaryAccent: Color {
        Color(hex: themeManager.selectedTheme.secondaryHex)
    }

    private var headline: String {
        if snapshot.currentStreak == 0 {
            return "Ready to begin"
        }
        return snapshot.currentStreak == 1 ? "1 day strong" : "\(snapshot.currentStreak) days strong"
    }

    private var subheadline: String {
        snapshot.currentStreak == 0
            ? "One check-in today starts the chain."
            : "\(snapshot.nextMilestone - snapshot.currentStreak) days to your \(snapshot.nextMilestone)-day milestone."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 18) {
                StreakFlameMedallion(accent: accent, secondaryAccent: secondaryAccent, animate: animate)

                VStack(alignment: .leading, spacing: 8) {
                    Label("\(snapshot.currentStreak)/\(snapshot.nextMilestone)", systemImage: "sparkle")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.15), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.18), lineWidth: 1)
                        )

                    Text(headline)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subheadline)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            StreakProgressTrack(progress: snapshot.milestoneProgress, accent: .white, animate: animate)

            HStack(spacing: 10) {
                StreakHeroPill(icon: "flag.checkered", title: "Next", value: "\(snapshot.nextMilestone)d")
                StreakHeroPill(icon: "trophy.fill", title: "Best", value: "\(snapshot.longestStreak)d")
            }
        }
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent,
                            secondaryAccent.opacity(colorScheme == .dark ? 0.95 : 0.9),
                            accent.opacity(colorScheme == .dark ? 0.72 : 0.82)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    ZStack {
                        StreakHeroGlowPattern(animate: animate)

                        LinearGradient(
                            colors: [.white.opacity(0.28), .white.opacity(0.04), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )

                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                    }
                }
        }
        .shadow(
            color: accent.opacity(colorScheme == .dark ? 0.32 : 0.18),
            radius: colorScheme == .dark ? 26 : 18,
            x: 0,
            y: colorScheme == .dark ? 18 : 10
        )
        .accessibilityElement(children: .combine)
    }
}

private struct StreakFlameMedallion: View {
    let accent: Color
    let secondaryAccent: Color
    let animate: Bool

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 88, height: 88)
                .scaleEffect(pulse && animate ? 1.1 : 0.94)
                .opacity(pulse && animate ? 0.25 : 0.55)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 72, height: 72)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                }

            Image(systemName: "flame.fill")
                .font(.system(size: 36, weight: .black))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, secondaryAccent.opacity(0.85))
                .shadow(color: .white.opacity(0.35), radius: 10, x: 0, y: 0)
                .scaleEffect(pulse && animate ? 1.05 : 0.98)
        }
        .frame(width: 88, height: 88)
        .onAppear {
            guard animate else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChange(of: animate) { _, newValue in
            guard newValue else {
                pulse = false
                return
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct StreakHeroGlowPattern: View {
    let animate: Bool
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: proxy.size.width * 0.72)
                    .blur(radius: 24)
                    .offset(
                        x: drift && animate ? proxy.size.width * 0.22 : proxy.size.width * 0.06,
                        y: drift && animate ? -proxy.size.height * 0.28 : -proxy.size.height * 0.18
                    )

                Circle()
                    .fill(.black.opacity(0.12))
                    .frame(width: proxy.size.width * 0.9)
                    .blur(radius: 34)
                    .offset(x: proxy.size.width * 0.42, y: proxy.size.height * 0.58)

                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(index.isMultiple(of: 2) ? 0.24 : 0.14))
                        .frame(width: CGFloat(4 + (index % 3) * 3))
                        .offset(
                            x: proxy.size.width * CGFloat([0.16, 0.35, 0.68, 0.82, 0.24, 0.53, 0.74, 0.9][index]),
                            y: proxy.size.height * CGFloat([0.18, 0.1, 0.22, 0.42, 0.68, 0.78, 0.62, 0.16][index])
                        )
                        .opacity(animate && drift ? 1 : 0.55)
                        .scaleEffect(animate && drift ? 1.2 : 0.85)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear {
            guard animate else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
        .onChange(of: animate) { _, newValue in
            guard newValue else {
                drift = false
                return
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

private struct StreakProgressTrack: View {
    let progress: Double
    let accent: Color
    let animate: Bool

    @State private var visibleProgress = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.2))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.58)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, proxy.size.width * visibleProgress))
                        .overlay(alignment: .trailing) {
                            Circle()
                                .fill(.white)
                                .frame(width: 14, height: 14)
                                .shadow(color: .white.opacity(0.45), radius: 8, x: 0, y: 0)
                                .padding(.trailing, 2)
                        }
                }
            }
            .frame(height: 12)

            HStack {
                Text("Milestone progress")
                Spacer()
                Text("\(Int((visibleProgress * 100).rounded()))%")
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.76))
        }
        .onAppear {
            if animate {
                withAnimation(.spring(response: 0.9, dampingFraction: 0.84).delay(0.15)) {
                    visibleProgress = progress
                }
            } else {
                visibleProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.75, dampingFraction: 0.85)) {
                visibleProgress = newValue
            }
        }
    }
}

private struct StreakHeroPill: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct StreakStatsRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let snapshot: StreakSnapshot
    @State private var reveal = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                metricCards
            }

            VStack(spacing: 12) {
                metricCards
            }
        }
        .onAppear {
            if reduceMotion {
                reveal = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.12)) {
                    reveal = true
                }
            }
        }
    }

    @ViewBuilder
    private var metricCards: some View {
        DSMetricCard(
            title: "Current",
            value: "\(snapshot.currentStreak)",
            icon: "flame.fill",
            subtitle: snapshot.currentStreak == 1 ? "day" : "days"
        )
        .scaleEffect(reveal ? 1 : 0.94)
        .opacity(reveal ? 1 : 0)

        DSMetricCard(
            title: "Longest",
            value: "\(snapshot.longestStreak)",
            icon: "trophy.fill",
            subtitle: snapshot.longestStreak == 1 ? "day" : "days"
        )
        .scaleEffect(reveal ? 1 : 0.94)
        .opacity(reveal ? 1 : 0)
    }
}

private struct StreakCalendarMonth: View {
    @Environment(ThemeManager.self) private var themeManager

    let activeDays: Set<Date>
    let animate: Bool

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
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    monthHeaderTitle

                    Spacer()

                    activeLegend
                }

                VStack(alignment: .leading, spacing: 8) {
                    monthHeaderTitle
                    activeLegend
                }
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
                        isCurrentMonth: calendar.isDate(day, equalTo: monthStart, toGranularity: .month),
                        animate: animate,
                        delay: Double(daySlots.firstIndex(of: day) ?? 0) * 0.012
                    )
                }
            }
        }
        .padding(18)
        .background(DSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(themeManager.selectedColor.opacity(0.14), lineWidth: 1)
        }
    }

    private var monthHeaderTitle: some View {
        Text(monthTitle)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(DSTheme.primaryText)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var activeLegend: some View {
        Label("Active", systemImage: "checkmark.circle.fill")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(themeManager.selectedColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct StreakCalendarDay: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let date: Date
    let isActive: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let animate: Bool
    let delay: Double
    @State private var visible = false

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var body: some View {
        VStack(spacing: 5) {
            Text("\(dayNumber)")
                .font(.system(size: 13, weight: isToday || isActive ? .heavy : .medium, design: .rounded))
                .foregroundStyle(textColor)
                .padding(.horizontal, 7)
                .frame(minWidth: 26, minHeight: 26)
                .background(
                    ZStack {
                        if isActive {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            themeManager.selectedColor,
                                            Color(hex: themeManager.selectedTheme.secondaryHex)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: themeManager.selectedColor.opacity(0.28), radius: 7, x: 0, y: 4)
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
                .fill(isActive ? themeManager.selectedColor.opacity(0.09) : Color.clear)
        )
        .opacity(isCurrentMonth ? 1.0 : 0.3)
        .scaleEffect(visible ? 1 : 0.84)
        .opacity(visible ? (isCurrentMonth ? 1.0 : 0.3) : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            if reduceMotion || !animate {
                visible = true
            } else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78).delay(delay)) {
                    visible = true
                }
            }
        }
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

private struct StreakEntranceModifier: ViewModifier {
    let index: Int
    let isVisible: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 18)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.98)
            .animation(
                reduceMotion ? nil : .spring(response: 0.62, dampingFraction: 0.86).delay(Double(index) * 0.08),
                value: isVisible
            )
    }
}

private extension View {
    func streakEntrance(index: Int, isVisible: Bool, reduceMotion: Bool) -> some View {
        modifier(StreakEntranceModifier(index: index, isVisible: isVisible, reduceMotion: reduceMotion))
    }
}
