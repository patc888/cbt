import Foundation

enum MonthlyBadgeKind: String, CaseIterable, Identifiable {
    case weeklyCheckIns
    case wellnessActivities
    case courseCompletion
    case toolVariety

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weeklyCheckIns:
            return "Weekly Check-ins"
        case .wellnessActivities:
            return "Wellness Activities"
        case .courseCompletion:
            return "Course Finish"
        case .toolVariety:
            return "Tool Mix"
        }
    }

    var description: String {
        switch self {
        case .weeklyCheckIns:
            return "One check-in in each week of the month."
        case .wellnessActivities:
            return "Ten saved wellness activities this month."
        case .courseCompletion:
            return "Complete any course this month."
        case .toolVariety:
            return "Use three different tool types this month."
        }
    }

    var imageName: String {
        switch self {
        case .weeklyCheckIns:
            return "calendar.badge.checkmark"
        case .wellnessActivities:
            return "sparkles"
        case .courseCompletion:
            return "graduationcap.fill"
        case .toolVariety:
            return "square.grid.2x2.fill"
        }
    }
}

struct MonthlyBadgeProgressItem: Identifiable, Equatable {
    let kind: MonthlyBadgeKind
    let currentValue: Int
    let targetValue: Int
    let unitSingular: String
    let unitPlural: String
    let statusLabel: String

    var id: String { kind.rawValue }

    var isComplete: Bool {
        currentValue >= targetValue
    }

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(Double(currentValue) / Double(targetValue), 1)
    }

    var progressLabel: String {
        let visibleValue = min(currentValue, targetValue)
        let unit = targetValue == 1 ? unitSingular : unitPlural
        return "\(visibleValue) of \(targetValue) \(unit)"
    }
}

struct MonthlyBadgeProgress: Equatable {
    let monthStart: Date
    let monthEnd: Date
    let monthTitle: String
    let badges: [MonthlyBadgeProgressItem]

    var completedCount: Int {
        badges.filter(\.isComplete).count
    }
}

struct MonthlyBadgeJournalActivity: Equatable {
    let createdAt: Date
    let sourceKind: String?
}

struct MonthlyBadgeActivitySnapshot: Equatable {
    var moodEntryDates: [Date] = []
    var moodCheckInDates: [Date] = []
    var thoughtRecordDates: [Date] = []
    var exerciseCompletionDates: [Date] = []
    var journalEntries: [MonthlyBadgeJournalActivity] = []
    var flexibleJournalDates: [Date] = []
    var breathingSessionDates: [Date] = []
    var plannedActivityCompletionDates: [Date] = []
    var courseCompletionDates: [Date] = []
}

enum MonthlyBadgeCalculator {
    static func progress(
        for referenceDate: Date = Date(),
        snapshot: MonthlyBadgeActivitySnapshot,
        calendar: Calendar = .current
    ) -> MonthlyBadgeProgress {
        let monthInterval = calendar.dateInterval(of: .month, for: referenceDate) ?? DateInterval(
            start: calendar.startOfDay(for: referenceDate),
            duration: 24 * 60 * 60
        )

        let monthTitle = Self.monthTitle(for: monthInterval.start, calendar: calendar)
        let moodDates = snapshot.moodEntryDates + snapshot.moodCheckInDates
        let monthlyMoodMoments = Self.uniqueMinuteCount(
            moodDates.filter { Self.contains($0, in: monthInterval) },
            calendar: calendar
        )

        let requiredWeeks = Self.weekBuckets(in: monthInterval, calendar: calendar)
        let completedCheckInWeeks = Set(
            moodDates
                .filter { Self.contains($0, in: monthInterval) }
                .map { Self.weekBucket(for: $0, calendar: calendar) }
        )
        .intersection(requiredWeeks)
        .count
        let elapsedWeekTarget = Self.elapsedWeekTarget(
            in: monthInterval,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let monthlyThoughts = snapshot.thoughtRecordDates.filter { Self.contains($0, in: monthInterval) }.count
        let monthlyExercises = snapshot.exerciseCompletionDates.filter { Self.contains($0, in: monthInterval) }.count
        let monthlyJournals = snapshot.journalEntries.filter { Self.contains($0.createdAt, in: monthInterval) }
        let monthlyFlexibleJournals = snapshot.flexibleJournalDates.filter { Self.contains($0, in: monthInterval) }.count
        let monthlyBreathing = snapshot.breathingSessionDates.filter { Self.contains($0, in: monthInterval) }.count
        let monthlyPlannedActivities = snapshot.plannedActivityCompletionDates.filter { Self.contains($0, in: monthInterval) }.count
        let monthlyCourses = snapshot.courseCompletionDates.filter { Self.contains($0, in: monthInterval) }.count

        let wellnessActivityCount = monthlyMoodMoments
            + monthlyThoughts
            + monthlyExercises
            + monthlyJournals.count
            + monthlyFlexibleJournals
            + monthlyBreathing
            + monthlyPlannedActivities

        let toolTypes = Self.toolTypes(
            moodMomentCount: monthlyMoodMoments,
            thoughtCount: monthlyThoughts,
            exerciseCount: monthlyExercises,
            journalEntries: monthlyJournals,
            flexibleJournalCount: monthlyFlexibleJournals,
            breathingCount: monthlyBreathing
        )

        let weeklyTarget = max(requiredWeeks.count, 1)
        let weeklyComplete = completedCheckInWeeks >= weeklyTarget
        let weeklyStatus: String
        if weeklyComplete {
            weeklyStatus = "Complete"
        } else if elapsedWeekTarget > 0 && completedCheckInWeeks >= elapsedWeekTarget {
            weeklyStatus = "On track"
        } else if completedCheckInWeeks > 0 {
            weeklyStatus = "In progress"
        } else {
            weeklyStatus = "Available"
        }

        let badges = [
            MonthlyBadgeProgressItem(
                kind: .weeklyCheckIns,
                currentValue: completedCheckInWeeks,
                targetValue: weeklyTarget,
                unitSingular: "week",
                unitPlural: "weeks",
                statusLabel: weeklyStatus
            ),
            MonthlyBadgeProgressItem(
                kind: .wellnessActivities,
                currentValue: wellnessActivityCount,
                targetValue: 10,
                unitSingular: "activity",
                unitPlural: "activities",
                statusLabel: Self.statusLabel(currentValue: wellnessActivityCount, targetValue: 10)
            ),
            MonthlyBadgeProgressItem(
                kind: .courseCompletion,
                currentValue: monthlyCourses,
                targetValue: 1,
                unitSingular: "course",
                unitPlural: "courses",
                statusLabel: Self.statusLabel(currentValue: monthlyCourses, targetValue: 1)
            ),
            MonthlyBadgeProgressItem(
                kind: .toolVariety,
                currentValue: toolTypes.count,
                targetValue: 3,
                unitSingular: "type",
                unitPlural: "types",
                statusLabel: Self.statusLabel(currentValue: toolTypes.count, targetValue: 3)
            )
        ]

        return MonthlyBadgeProgress(
            monthStart: monthInterval.start,
            monthEnd: monthInterval.end,
            monthTitle: monthTitle,
            badges: badges
        )
    }

    private static func statusLabel(currentValue: Int, targetValue: Int) -> String {
        if currentValue >= targetValue {
            return "Complete"
        }
        return currentValue > 0 ? "In progress" : "Available"
    }

    private static func contains(_ date: Date, in interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
    }

    private static func toolTypes(
        moodMomentCount: Int,
        thoughtCount: Int,
        exerciseCount: Int,
        journalEntries: [MonthlyBadgeJournalActivity],
        flexibleJournalCount: Int,
        breathingCount: Int
    ) -> Set<String> {
        var types = Set<String>()

        if moodMomentCount > 0 {
            types.insert("mood")
        }
        if thoughtCount > 0 {
            types.insert("thought")
        }
        if flexibleJournalCount > 0 || journalEntries.contains(where: { $0.sourceKind == nil }) {
            types.insert("journal")
        }
        if breathingCount > 0 || journalEntries.contains(where: { $0.sourceKind == "breathing" }) {
            types.insert("breathing")
        }
        if exerciseCount > 0 || journalEntries.contains(where: { entry in
            guard let sourceKind = entry.sourceKind else { return false }
            return [
                "exercise",
                "affirmation",
                "distortionExample"
            ].contains(sourceKind)
        }) {
            types.insert("exercise")
        }

        return types
    }

    private static func uniqueMinuteCount(_ dates: [Date], calendar: Calendar) -> Int {
        Set(
            dates.map {
                calendar.dateComponents([.year, .month, .day, .hour, .minute], from: $0)
            }
        )
        .count
    }

    private static func monthTitle(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    private static func elapsedWeekTarget(
        in monthInterval: DateInterval,
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        guard referenceDate >= monthInterval.start else { return 0 }
        guard referenceDate < monthInterval.end else {
            return weekBuckets(in: monthInterval, calendar: calendar).count
        }

        let referenceDayEnd = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: referenceDate)
        ) ?? referenceDate
        let elapsedInterval = DateInterval(
            start: monthInterval.start,
            end: min(referenceDayEnd, monthInterval.end)
        )
        return weekBuckets(in: elapsedInterval, calendar: calendar).count
    }

    private static func weekBuckets(in interval: DateInterval, calendar: Calendar) -> Set<WeekBucket> {
        var buckets = Set<WeekBucket>()
        var day = calendar.startOfDay(for: interval.start)

        while day < interval.end {
            buckets.insert(weekBucket(for: day, calendar: calendar))
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }

        return buckets
    }

    private static func weekBucket(for date: Date, calendar: Calendar) -> WeekBucket {
        let components = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)
        return WeekBucket(
            weekOfYear: components.weekOfYear ?? 0,
            yearForWeekOfYear: components.yearForWeekOfYear ?? 0
        )
    }
}

private struct WeekBucket: Hashable {
    let weekOfYear: Int
    let yearForWeekOfYear: Int
}
