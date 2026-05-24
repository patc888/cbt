import Foundation
import SwiftData

struct WeeklyReportFrequency: Equatable, Sendable, Identifiable {
    var id: String { label }
    let label: String
    let count: Int
}

enum WeeklyReportTrendDirection: String, Equatable, Sendable {
    case higher
    case lower
    case steady
    case unavailable
}

struct WeeklyReportMoodTrend: Equatable, Sendable {
    let direction: WeeklyReportTrendDirection
    let currentAverage: Double?
    let previousAverage: Double?
    let change: Double?
    let summary: String
}

struct WeeklyReportAssessmentChange: Equatable, Sendable, Identifiable {
    var id: String { "\(assessmentType)-\(currentDate.timeIntervalSinceReferenceDate)" }
    let assessmentType: String
    let previousDate: Date
    let previousScore: Double
    let currentDate: Date
    let currentScore: Double
    let change: Double
    let summary: String
}

struct WeeklyReportAchievementUnlock: Equatable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let unlockedAt: Date
}

struct WeeklyReport: Equatable, Sendable {
    let generatedAt: Date
    let weekStart: Date
    let weekEnd: Date
    let moodCheckInCount: Int
    let averageMood: Double?
    let moodTrend: WeeklyReportMoodTrend
    let mostCommonEmotions: [WeeklyReportFrequency]
    let mostCommonTriggers: [WeeklyReportFrequency]
    let mostCommonActivityTags: [WeeklyReportFrequency]
    let thoughtRecordCount: Int
    let mostCommonCognitiveDistortions: [WeeklyReportFrequency]
    let exercisesCompleted: Int
    let breathingSessionsCompleted: Int
    let guidedJournalsCompleted: Int
    let plannedActivitiesCompleted: Int
    let assessmentChanges: [WeeklyReportAssessmentChange]
    let achievementsUnlocked: [WeeklyReportAchievementUnlock]
    let suggestedFocusForNextWeek: String
    let insufficientDataMessages: [String]

    var weekDateRange: DateInterval {
        DateInterval(start: weekStart, end: weekEnd)
    }

    var hasAnyData: Bool {
        moodCheckInCount > 0 ||
        thoughtRecordCount > 0 ||
        exercisesCompleted > 0 ||
        breathingSessionsCompleted > 0 ||
        guidedJournalsCompleted > 0 ||
        plannedActivitiesCompleted > 0 ||
        !assessmentChanges.isEmpty ||
        !achievementsUnlocked.isEmpty
    }
}

@MainActor
struct WeeklyReportService {
    private struct MoodSample {
        let createdAt: Date
        let moodScore: Int
    }

    private let calendar: Calendar
    private let now: () -> Date

    init(calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.now = now
    }

    func generateReport(forWeekContaining selectedDate: Date, from modelContext: ModelContext) throws -> WeeklyReport {
        let week = weekInterval(containing: selectedDate)
        let previousWeek = previousWeekInterval(before: week)

        let moodEntries = try fetchMoodEntries(from: modelContext)
        let moodCheckIns = try fetchMoodCheckIns(from: modelContext)
        let thoughtRecords = try fetchThoughtRecords(from: modelContext)
        let exerciseCompletions = try fetchExerciseCompletions(from: modelContext)
        let breathingSessions = try fetchBreathingSessions(from: modelContext)
        let flexibleJournalEntries = try fetchFlexibleJournalEntries(from: modelContext)
        let plannedActivities = try fetchPlannedActivities(from: modelContext)
        let assessmentLogs = try fetchAssessmentLogs(from: modelContext)
        let achievements = try fetchAchievements(from: modelContext)

        let weekMoodEntries = moodEntries.filter { contains($0.createdAt, in: week) }
        let weekThoughtRecords = thoughtRecords.filter { contains($0.createdAt, in: week) }
        let currentMoodSamples = moodSamples(from: moodEntries, checkIns: moodCheckIns, in: week)
        let previousMoodSamples = moodSamples(from: moodEntries, checkIns: moodCheckIns, in: previousWeek)
        let averageMood = average(currentMoodSamples.map { Double($0.moodScore) })
        let previousAverageMood = average(previousMoodSamples.map { Double($0.moodScore) })
        let moodTrend = makeMoodTrend(currentAverage: averageMood, previousAverage: previousAverageMood)

        let emotionValues = weekMoodEntries.flatMap(\.emotions) + weekThoughtRecords.flatMap(\.emotions)
        let mostCommonEmotions = makeFrequencies(from: emotionValues)
        let mostCommonTriggers = makeFrequencies(from: weekMoodEntries.flatMap(\.triggers))
        let activityTagValues = weekMoodEntries.flatMap { entry in
            entry.activityTags.isEmpty ? entry.contextTags : entry.activityTags
        }
        let mostCommonActivityTags = makeFrequencies(from: activityTagValues)
        let mostCommonCognitiveDistortions = makeFrequencies(from: weekThoughtRecords.flatMap(\.distortions))

        let weekExerciseCompletions = exerciseCompletions.filter { contains($0.createdAt, in: week) }
        let weekBreathingSessions = breathingSessions.filter { contains($0.createdAt, in: week) }
        let weekGuidedJournals = flexibleJournalEntries.filter { contains($0.date, in: week) }
        let weekPlannedActivitiesCompleted = plannedActivities.filter {
            guard $0.isCompleted else { return false }
            return contains($0.completedAt ?? $0.scheduledDate, in: week)
        }
        let assessmentChanges = makeAssessmentChanges(from: assessmentLogs, in: week)
        let achievementsUnlocked = achievements
            .compactMap { achievement -> WeeklyReportAchievementUnlock? in
                guard achievement.isUnlocked, let unlockedAt = achievement.unlockedAt, contains(unlockedAt, in: week) else {
                    return nil
                }
                return WeeklyReportAchievementUnlock(id: achievement.id, title: achievement.title, unlockedAt: unlockedAt)
            }
            .sorted { $0.unlockedAt > $1.unlockedAt }
        let insufficientDataMessages = makeInsufficientDataMessages(
            moodCount: currentMoodSamples.count,
            previousMoodCount: previousMoodSamples.count,
            emotionCount: mostCommonEmotions.count,
            triggerCount: mostCommonTriggers.count,
            activityTagCount: mostCommonActivityTags.count,
            thoughtRecordCount: weekThoughtRecords.count
        )

        return WeeklyReport(
            generatedAt: now(),
            weekStart: week.start,
            weekEnd: week.end,
            moodCheckInCount: currentMoodSamples.count,
            averageMood: averageMood,
            moodTrend: moodTrend,
            mostCommonEmotions: mostCommonEmotions,
            mostCommonTriggers: mostCommonTriggers,
            mostCommonActivityTags: mostCommonActivityTags,
            thoughtRecordCount: weekThoughtRecords.count,
            mostCommonCognitiveDistortions: mostCommonCognitiveDistortions,
            exercisesCompleted: weekExerciseCompletions.count,
            breathingSessionsCompleted: weekBreathingSessions.count,
            guidedJournalsCompleted: weekGuidedJournals.count,
            plannedActivitiesCompleted: weekPlannedActivitiesCompleted.count,
            assessmentChanges: assessmentChanges,
            achievementsUnlocked: achievementsUnlocked,
            suggestedFocusForNextWeek: makeSuggestedFocus(
                moodCount: currentMoodSamples.count,
                mostCommonTrigger: mostCommonTriggers.first,
                mostCommonDistortion: mostCommonCognitiveDistortions.first,
                plannedActivitiesCompleted: weekPlannedActivitiesCompleted.count,
                guidedJournalsCompleted: weekGuidedJournals.count,
                breathingSessionsCompleted: weekBreathingSessions.count
            ),
            insufficientDataMessages: insufficientDataMessages
        )
    }

    func weekInterval(containing date: Date) -> DateInterval {
        if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
            return interval
        }

        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 24 * 60 * 60)
        return DateInterval(start: start, end: end)
    }

    private func previousWeekInterval(before interval: DateInterval) -> DateInterval {
        let previousStart = calendar.date(byAdding: .weekOfYear, value: -1, to: interval.start)
            ?? interval.start.addingTimeInterval(-7 * 24 * 60 * 60)
        return DateInterval(start: previousStart, end: interval.start)
    }

    private func moodSamples(from moodEntries: [MoodEntry], checkIns: [MoodCheckIn], in interval: DateInterval) -> [MoodSample] {
        let entriesInInterval = moodEntries.filter { contains($0.createdAt, in: interval) }
        var samples = entriesInInterval.map { MoodSample(createdAt: $0.createdAt, moodScore: $0.moodScore) }

        for checkIn in checkIns where contains(checkIn.createdAt, in: interval) {
            let isDuplicate = entriesInInterval.contains { entry in
                entry.moodScore == checkIn.moodScore &&
                abs(entry.createdAt.timeIntervalSince(checkIn.createdAt)) <= 120
            }
            if !isDuplicate {
                samples.append(MoodSample(createdAt: checkIn.createdAt, moodScore: MoodEntry.clampMoodScore(checkIn.moodScore)))
            }
        }

        return samples.sorted { $0.createdAt < $1.createdAt }
    }

    private func makeMoodTrend(currentAverage: Double?, previousAverage: Double?) -> WeeklyReportMoodTrend {
        guard let currentAverage, let previousAverage else {
            return WeeklyReportMoodTrend(
                direction: .unavailable,
                currentAverage: currentAverage,
                previousAverage: previousAverage,
                change: nil,
                summary: "A week-to-week mood comparison will appear when both weeks have check-ins."
            )
        }

        let change = currentAverage - previousAverage
        if abs(change) < 0.1 {
            return WeeklyReportMoodTrend(
                direction: .steady,
                currentAverage: currentAverage,
                previousAverage: previousAverage,
                change: change,
                summary: "Average mood looked similar to the previous week."
            )
        }

        let formatted = abs(change).formatted(.number.precision(.fractionLength(1)))
        if change > 0 {
            return WeeklyReportMoodTrend(
                direction: .higher,
                currentAverage: currentAverage,
                previousAverage: previousAverage,
                change: change,
                summary: "Average mood was \(formatted) points higher than the previous week."
            )
        } else {
            return WeeklyReportMoodTrend(
                direction: .lower,
                currentAverage: currentAverage,
                previousAverage: previousAverage,
                change: change,
                summary: "Average mood was \(formatted) points lower than the previous week."
            )
        }
    }

    private func makeAssessmentChanges(from logs: [AssessmentLog], in interval: DateInterval) -> [WeeklyReportAssessmentChange] {
        let grouped = Dictionary(grouping: logs) { assessmentLabel($0.assessmentType) }

        return grouped.compactMap { assessmentType, entries in
            let sorted = entries.sorted { $0.date < $1.date }
            guard let latestInWeek = sorted.last(where: { contains($0.date, in: interval) }) else {
                return nil
            }
            guard let previous = sorted.last(where: { $0.date < latestInWeek.date }) else {
                return nil
            }

            let previousScore = scoreValue(for: previous)
            let currentScore = scoreValue(for: latestInWeek)
            let change = currentScore - previousScore
            let formattedChange = signed(change)
            let summary: String
            if abs(change) < 0.005 {
                summary = "\(assessmentType) score was unchanged from the prior entry."
            } else {
                summary = "\(assessmentType) score changed by \(formattedChange) from the prior entry."
            }

            return WeeklyReportAssessmentChange(
                assessmentType: assessmentType,
                previousDate: previous.date,
                previousScore: previousScore,
                currentDate: latestInWeek.date,
                currentScore: currentScore,
                change: change,
                summary: summary
            )
        }
        .sorted { $0.currentDate > $1.currentDate }
    }

    private func makeFrequencies(from values: [String], limit: Int = 5) -> [WeeklyReportFrequency] {
        var counts: [String: (label: String, count: Int)] = [:]

        for value in values {
            let label = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }

            let key = label
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()

            if let existing = counts[key] {
                counts[key] = (existing.label, existing.count + 1)
            } else {
                counts[key] = (label.localizedCapitalized, 1)
            }
        }

        return counts.values
            .map { WeeklyReportFrequency(label: $0.label, count: $0.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
                }
                return $0.count > $1.count
            }
            .prefix(limit)
            .map { $0 }
    }

    private func makeSuggestedFocus(
        moodCount: Int,
        mostCommonTrigger: WeeklyReportFrequency?,
        mostCommonDistortion: WeeklyReportFrequency?,
        plannedActivitiesCompleted: Int,
        guidedJournalsCompleted: Int,
        breathingSessionsCompleted: Int
    ) -> String {
        if moodCount == 0 {
            return "Consider starting with a few quick mood check-ins so next week's report has more to reflect back."
        }

        if let mostCommonTrigger, mostCommonTrigger.label != "Nothing Specific" {
            return "You might gently notice what surrounds \(mostCommonTrigger.label.lowercased()) next week, especially what helps before and after it shows up."
        }

        if let mostCommonDistortion {
            return "If \(mostCommonDistortion.label.lowercased()) appears again, a short thought record could help you look for a balanced next step."
        }

        if plannedActivitiesCompleted == 0 {
            return "A small planned activity could be a kind experiment for next week."
        }

        if guidedJournalsCompleted == 0 && breathingSessionsCompleted == 0 {
            return "A brief journal or breathing reset could give next week's report another helpful signal."
        }

        return "Keep tracking the practices that feel workable, and choose one small support to repeat next week."
    }

    private func makeInsufficientDataMessages(
        moodCount: Int,
        previousMoodCount: Int,
        emotionCount: Int,
        triggerCount: Int,
        activityTagCount: Int,
        thoughtRecordCount: Int
    ) -> [String] {
        var messages: [String] = []

        if moodCount == 0 {
            messages.append("No mood check-ins were recorded for this week.")
        }
        if moodCount > 0 && previousMoodCount == 0 {
            messages.append("Mood trend needs at least one check-in from the previous week.")
        }
        if emotionCount == 0 && triggerCount == 0 && activityTagCount == 0 {
            messages.append("Emotion, trigger, and context patterns will appear after those tags are recorded.")
        }
        if thoughtRecordCount == 0 {
            messages.append("Thought record patterns will appear after a thought record is saved this week.")
        }

        return messages
    }

    private func contains(_ date: Date, in interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func signed(_ value: Double) -> String {
        let formatted = abs(value).formatted(.number.precision(.fractionLength(1)))
        if value > 0 {
            return "+\(formatted)"
        } else if value < 0 {
            return "-\(formatted)"
        } else {
            return "0.0"
        }
    }

    private func scoreValue(for log: AssessmentLog) -> Double {
        log.scoreValue ?? Double(log.score)
    }

    private func assessmentLabel(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Assessment" : trimmed
    }

    private func fetchMoodEntries(from modelContext: ModelContext) throws -> [MoodEntry] {
        try modelContext.fetch(
            FetchDescriptor<MoodEntry>(
                predicate: #Predicate<MoodEntry> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\MoodEntry.createdAt)]
            )
        )
    }

    private func fetchMoodCheckIns(from modelContext: ModelContext) throws -> [MoodCheckIn] {
        try modelContext.fetch(
            FetchDescriptor<MoodCheckIn>(
                predicate: #Predicate<MoodCheckIn> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\MoodCheckIn.createdAt)]
            )
        )
    }

    private func fetchThoughtRecords(from modelContext: ModelContext) throws -> [ThoughtRecord] {
        try modelContext.fetch(
            FetchDescriptor<ThoughtRecord>(
                predicate: #Predicate<ThoughtRecord> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\ThoughtRecord.createdAt)]
            )
        )
    }

    private func fetchExerciseCompletions(from modelContext: ModelContext) throws -> [ExerciseCompletion] {
        try modelContext.fetch(
            FetchDescriptor<ExerciseCompletion>(
                predicate: #Predicate<ExerciseCompletion> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\ExerciseCompletion.createdAt)]
            )
        )
    }

    private func fetchBreathingSessions(from modelContext: ModelContext) throws -> [BreathingSession] {
        try modelContext.fetch(
            FetchDescriptor<BreathingSession>(
                predicate: #Predicate<BreathingSession> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\BreathingSession.createdAt)]
            )
        )
    }

    private func fetchFlexibleJournalEntries(from modelContext: ModelContext) throws -> [FlexibleJournalEntry] {
        try modelContext.fetch(
            FetchDescriptor<FlexibleJournalEntry>(
                sortBy: [SortDescriptor(\FlexibleJournalEntry.date)]
            )
        )
    }

    private func fetchPlannedActivities(from modelContext: ModelContext) throws -> [PlannedActivity] {
        try modelContext.fetch(
            FetchDescriptor<PlannedActivity>(
                predicate: #Predicate<PlannedActivity> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\PlannedActivity.scheduledDate)]
            )
        )
    }

    private func fetchAssessmentLogs(from modelContext: ModelContext) throws -> [AssessmentLog] {
        try modelContext.fetch(
            FetchDescriptor<AssessmentLog>(
                sortBy: [SortDescriptor(\AssessmentLog.date)]
            )
        )
    }

    private func fetchAchievements(from modelContext: ModelContext) throws -> [Achievement] {
        try modelContext.fetch(FetchDescriptor<Achievement>())
    }
}
