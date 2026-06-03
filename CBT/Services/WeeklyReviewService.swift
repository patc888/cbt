import Foundation
import SwiftData

struct WeeklyReviewFrequency: Equatable, Sendable, Identifiable {
    var id: String { label }
    let label: String
    let count: Int
}

struct WeeklyReviewCompletion: Equatable, Sendable, Identifiable {
    var id: String { label }
    let label: String
    let count: Int
}

struct WeeklyReviewBestPatternRecap: Equatable, Sendable {
    let patternText: String
    let recommendedNextAction: String
}

struct WeeklyReview: Equatable, Sendable {
    let generatedAt: Date
    let weekStart: Date
    let weekEnd: Date
    let progressLetter: String
    let activityDayCount: Int
    let checkInCount: Int
    let averageMood: Double?
    let averageAnxietyStress: Double?
    let mostCommonTriggers: [WeeklyReviewFrequency]
    let completedExercises: [WeeklyReviewCompletion]
    let completedTinyWins: [WeeklyReviewCompletion]
    let practicedValues: [WeeklyReviewCompletion]
    let ritualIntention: String
    let ritualLearning: String
    let ritualValueReflection: String
    let bestPatternRecap: WeeklyReviewBestPatternRecap
    let whatHelpedMost: String
    let suggestedFocusForNextWeek: String
    let lowDataMessages: [String]

    var hasAnyData: Bool {
        activityDayCount > 0 ||
        checkInCount > 0 ||
        !completedExercises.isEmpty ||
        !completedTinyWins.isEmpty ||
        !practicedValues.isEmpty
    }
}

@MainActor
struct WeeklyReviewService {
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

    func generateReview(forWeekContaining selectedDate: Date, from modelContext: ModelContext) throws -> WeeklyReview {
        let week = weekInterval(containing: selectedDate)
        let moodEntries = try fetchMoodEntries(from: modelContext)
        let moodCheckIns = try fetchMoodCheckIns(from: modelContext)
        let exerciseCompletions = try fetchExerciseCompletions(from: modelContext)
        let breathingSessions = try fetchBreathingSessions(from: modelContext)
        let plannedActivities = try fetchPlannedActivities(from: modelContext)
        let tinyWinCompletions = try fetchTinyWinCompletions(from: modelContext)
        let valueActionCompletions = LaunchSafeFetch.valueActionCompletions(from: modelContext)
        let ritualEntry = try fetchRitualEntry(weekStart: week.start, from: modelContext)

        let weekMoodEntries = moodEntries.filter { contains($0.createdAt, in: week) }
        let weekMoodSamples = moodSamples(from: moodEntries, checkIns: moodCheckIns, in: week)
        let anxietyStressScores = anxietyStressIntensityScores(from: weekMoodEntries)
        let weekExerciseCompletions = exerciseCompletions.filter { contains($0.createdAt, in: week) }
        let weekBreathingSessions = breathingSessions.filter { contains($0.createdAt, in: week) }
        let completedActivities = plannedActivities.filter { activity in
            guard activity.isCompleted else { return false }
            return contains(activity.completedAt ?? activity.scheduledDate, in: week)
        }
        let weekTinyWins = tinyWinCompletions.filter { contains($0.createdAt, in: week) }
        let weekValueActions = valueActionCompletions.filter { contains($0.createdAt, in: week) }
        let activityDays = weeklyActivityDays(
            moodSamples: weekMoodSamples,
            exerciseCompletions: weekExerciseCompletions,
            breathingSessions: weekBreathingSessions,
            completedActivities: completedActivities,
            tinyWinCompletions: weekTinyWins,
            valueActionCompletions: weekValueActions
        )

        let triggers = makeFrequencies(from: weekMoodEntries.flatMap(\.triggers), limit: 5)
        let exercises = makeCompletions(from: weekExerciseCompletions.map(exerciseTitle(for:)), limit: 5)
        let tinyWins = makeCompletions(from: weekTinyWins.map(tinyWinTitle(for:)), limit: 5)
        let practicedValues = makeCompletions(from: weekValueActions.map(\.valueName), limit: 5)
        let supportActions = completedSupportActions(
            exerciseCompletions: weekExerciseCompletions,
            breathingSessions: weekBreathingSessions,
            completedActivities: completedActivities,
            tinyWinCompletions: weekTinyWins
        )

        return WeeklyReview(
            generatedAt: now(),
            weekStart: week.start,
            weekEnd: week.end,
            progressLetter: makeProgressLetter(
                activityDays: activityDays,
                checkInCount: weekMoodSamples.count,
                breathingSessionCount: weekBreathingSessions.count,
                exerciseCount: weekExerciseCompletions.count,
                tinyWinCount: completedActivities.count + weekTinyWins.count,
                valueActionCount: weekValueActions.count
            ),
            activityDayCount: activityDays.count,
            checkInCount: weekMoodSamples.count,
            averageMood: average(weekMoodSamples.map { Double($0.moodScore) }),
            averageAnxietyStress: average(anxietyStressScores),
            mostCommonTriggers: triggers,
            completedExercises: exercises,
            completedTinyWins: tinyWins,
            practicedValues: practicedValues,
            ritualIntention: ritualEntry?.intention ?? "",
            ritualLearning: ritualEntry?.learning ?? "",
            ritualValueReflection: ritualEntry?.valueReflection ?? "",
            bestPatternRecap: makeBestPatternRecap(
                checkInCount: weekMoodSamples.count,
                averageMood: average(weekMoodSamples.map { Double($0.moodScore) }),
                averageAnxietyStress: average(anxietyStressScores),
                mostCommonTrigger: triggers.first,
                supportActions: supportActions
            ),
            whatHelpedMost: makeWhatHelpedMost(from: supportActions),
            suggestedFocusForNextWeek: makeSuggestedFocus(
                checkInCount: weekMoodSamples.count,
                averageMood: average(weekMoodSamples.map { Double($0.moodScore) }),
                averageAnxietyStress: average(anxietyStressScores),
                mostCommonTrigger: triggers.first,
                completedExercises: exercises,
                completedTinyWins: tinyWins
            ),
            lowDataMessages: makeLowDataMessages(
                checkInCount: weekMoodSamples.count,
                anxietyStressCount: anxietyStressScores.count,
                triggerCount: triggers.reduce(0) { $0 + $1.count },
                completedPracticeCount: weekExerciseCompletions.count + weekBreathingSessions.count + completedActivities.count + weekTinyWins.count + weekValueActions.count
            )
        )
    }

    @discardableResult
    func saveRitual(
        forWeekContaining selectedDate: Date,
        intention: String,
        learning: String,
        valueReflection: String,
        in modelContext: ModelContext
    ) throws -> WeeklyRitualEntry {
        let weekStart = weekInterval(containing: selectedDate).start
        let entry: WeeklyRitualEntry
        if let existingEntry = try fetchRitualEntry(weekStart: weekStart, from: modelContext) {
            entry = existingEntry
        } else {
            entry = WeeklyRitualEntry(weekStart: weekStart, createdAt: now(), updatedAt: now())
            modelContext.insert(entry)
        }

        entry.intention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.learning = learning.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.valueReflection = valueReflection.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.updatedAt = now()
        entry.isDeleted = false

        try modelContext.save()
        _ = try DailyPlanCompletionService.shared.complete(
            itemType: .weeklyReview,
            itemID: Self.weeklyReviewCompletionID(for: weekStart),
            title: "Weekly review",
            on: now(),
            sourceScreen: "Weekly Review",
            in: modelContext,
            calendar: calendar
        )
        return entry
    }

    func weekInterval(containing date: Date) -> DateInterval {
        if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
            return interval
        }

        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 24 * 60 * 60)
        return DateInterval(start: start, end: end)
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

    private func anxietyStressIntensityScores(from entries: [MoodEntry]) -> [Double] {
        entries.compactMap { entry in
            guard isAnxietyStressRelated(entry) else { return nil }
            return Double(entry.intensity ?? entry.moodScore)
        }
    }

    private func isAnxietyStressRelated(_ entry: MoodEntry) -> Bool {
        let values = entry.emotions + entry.triggers + entry.sensations + entry.contextTags
        return values.contains { value in
            let text = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
            return Self.anxietyStressKeywords.contains { text.contains($0) }
        }
    }

    private func completedSupportActions(
        exerciseCompletions: [ExerciseCompletion],
        breathingSessions: [BreathingSession],
        completedActivities: [PlannedActivity],
        tinyWinCompletions: [TinyWinCompletion]
    ) -> [String] {
        var actions = exerciseCompletions.map(exerciseTitle(for:))
        actions += breathingSessions.map { _ in "Breathing reset" }
        actions += completedActivities.map { activity in
            let category = activity.category.trimmingCharacters(in: .whitespacesAndNewlines)
            return category.isEmpty ? "Tiny win" : "\(category) tiny win"
        }
        actions += tinyWinCompletions.map { _ in "Tiny win" }
        return actions
    }

    private func weeklyActivityDays(
        moodSamples: [MoodSample],
        exerciseCompletions: [ExerciseCompletion],
        breathingSessions: [BreathingSession],
        completedActivities: [PlannedActivity],
        tinyWinCompletions: [TinyWinCompletion],
        valueActionCompletions: [ValueActionCompletion]
    ) -> [Date] {
        let dates = moodSamples.map(\.createdAt)
            + exerciseCompletions.map(\.createdAt)
            + breathingSessions.map(\.createdAt)
            + completedActivities.map { $0.completedAt ?? $0.scheduledDate }
            + tinyWinCompletions.map(\.createdAt)
            + valueActionCompletions.map(\.createdAt)

        return Set(dates.map { calendar.startOfDay(for: $0) }).sorted()
    }

    private func makeProgressLetter(
        activityDays: [Date],
        checkInCount: Int,
        breathingSessionCount: Int,
        exerciseCount: Int,
        tinyWinCount: Int,
        valueActionCount: Int
    ) -> String {
        guard !activityDays.isEmpty else {
            return "This week does not need a verdict. When you add one check-in, practice, or tiny win, your next letter will have a thread to hold onto."
        }

        var clauses = ["You showed up \(dayCountText(activityDays.count)) this week"]

        if let missedDays = missedDaysBeforeReturn(in: activityDays) {
            clauses.append("returned after \(missedDayCountText(missedDays))")
        }

        if breathingSessionCount > 0 {
            clauses.append("used breathing \(timeCountText(breathingSessionCount))")
        } else if checkInCount > 0 {
            clauses.append("checked in \(timeCountText(checkInCount))")
        } else if exerciseCount > 0 {
            clauses.append("completed \(exerciseCountText(exerciseCount))")
        } else if tinyWinCount > 0 {
            clauses.append("logged \(tinyWinCountText(tinyWinCount))")
        } else if valueActionCount > 0 {
            clauses.append("practiced a value \(timeCountText(valueActionCount))")
        }

        return "\(sentence(from: clauses)). That is real continuity: not perfection, just returning to what helps."
    }

    private func missedDaysBeforeReturn(in days: [Date]) -> Int? {
        guard days.count >= 2 else { return nil }

        for index in 1..<days.count {
            let gap = calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day ?? 0
            if gap > 1 {
                return gap - 1
            }
        }

        return nil
    }

    private func makeWhatHelpedMost(from actions: [String]) -> String {
        guard let top = makeFrequencies(from: actions, limit: 1).first else {
            return "No completed support tools were logged this week. One small check-in or practice can give next week's review more to work with."
        }

        if top.count == 1 {
            return "\(top.label) was logged this week. Notice whether it felt supportive, and keep what worked."
        }

        return "\(top.label) showed up most often this week. That may be worth keeping close next week."
    }

    private func makeBestPatternRecap(
        checkInCount: Int,
        averageMood: Double?,
        averageAnxietyStress: Double?,
        mostCommonTrigger: WeeklyReviewFrequency?,
        supportActions: [String]
    ) -> WeeklyReviewBestPatternRecap {
        if let topTrigger = mostCommonTrigger, topTrigger.count >= 2 {
            return WeeklyReviewBestPatternRecap(
                patternText: "\(topTrigger.label) appeared most often this week, showing up \(topTrigger.count) times.",
                recommendedNextAction: "Choose one small response for \(topTrigger.label.lowercased()) moments before the week begins."
            )
        }

        if let topSupport = makeFrequencies(from: supportActions, limit: 1).first, topSupport.count >= 2 {
            return WeeklyReviewBestPatternRecap(
                patternText: "\(topSupport.label) was the support you returned to most often this week.",
                recommendedNextAction: "Put \(topSupport.label.lowercased()) within easy reach once next week, especially on a demanding day."
            )
        }

        if let averageAnxietyStress, averageAnxietyStress >= 7 {
            return WeeklyReviewBestPatternRecap(
                patternText: "Stress-related intensity averaged \(averageText(averageAnxietyStress))/10 this week.",
                recommendedNextAction: "Pick one grounding or breathing reset now so it is easier to use during the next high-intensity moment."
            )
        }

        if let averageMood, averageMood <= 4 {
            return WeeklyReviewBestPatternRecap(
                patternText: "Mood averaged \(averageText(averageMood))/10 this week, which may signal a need for gentler pacing.",
                recommendedNextAction: "Schedule one very small nourishing activity near the start of next week."
            )
        }

        if checkInCount > 0 {
            return WeeklyReviewBestPatternRecap(
                patternText: "You created \(checkInCount) \(checkInCount == 1 ? "data point" : "data points") for noticing your week.",
                recommendedNextAction: "Add two check-ins next week at different times of day to make the next pattern clearer."
            )
        }

        return WeeklyReviewBestPatternRecap(
            patternText: "No clear weekly pattern has enough data yet.",
            recommendedNextAction: "Start with two gentle check-ins next week so the review has something steady to compare."
        )
    }

    private func makeSuggestedFocus(
        checkInCount: Int,
        averageMood: Double?,
        averageAnxietyStress: Double?,
        mostCommonTrigger: WeeklyReviewFrequency?,
        completedExercises: [WeeklyReviewCompletion],
        completedTinyWins: [WeeklyReviewCompletion]
    ) -> String {
        if checkInCount < 2 {
            return "Try two gentle check-ins next week so your review has a steadier baseline."
        }

        if let topTrigger = mostCommonTrigger, topTrigger.count >= 2 {
            return "Plan one small response for \(topTrigger.label.lowercased()) moments before they show up."
        }

        if let averageAnxietyStress, averageAnxietyStress >= 7 {
            return "Keep one grounding or breathing tool easy to reach during higher-stress moments."
        }

        if let averageMood, averageMood <= 4 {
            return "Choose one tiny nourishing activity early in the week and keep it very doable."
        }

        if completedExercises.isEmpty && completedTinyWins.isEmpty {
            return "Add one small practice or tiny win next week so you can see what supports you."
        }

        return "Keep noticing what helped, then repeat one workable support before the week gets crowded."
    }

    private func makeLowDataMessages(
        checkInCount: Int,
        anxietyStressCount: Int,
        triggerCount: Int,
        completedPracticeCount: Int
    ) -> [String] {
        var messages: [String] = []

        if checkInCount == 0 {
            messages.append("No check-ins were recorded for this week yet.")
        } else if checkInCount < 2 {
            messages.append("This week has one check-in, so averages may shift easily.")
        }

        if anxietyStressCount == 0 {
            messages.append("Anxiety or stress averages appear when check-ins include related tags and intensity.")
        }

        if triggerCount == 0 {
            messages.append("Trigger patterns appear after triggers are added to check-ins.")
        }

        if completedPracticeCount == 0 {
            messages.append("Completed exercises, breathing, or tiny wins will help show what supported you.")
        }

        return messages
    }

    private func makeFrequencies(from values: [String], limit: Int) -> [WeeklyReviewFrequency] {
        var counts: [String: (label: String, count: Int)] = [:]

        for value in values {
            let label = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }

            let key = label.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
            if let existing = counts[key] {
                counts[key] = (existing.label, existing.count + 1)
            } else {
                counts[key] = (label.localizedCapitalized, 1)
            }
        }

        return counts.values
            .map { WeeklyReviewFrequency(label: $0.label, count: $0.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
                }
                return $0.count > $1.count
            }
            .prefix(limit)
            .map { $0 }
    }

    private func makeCompletions(from values: [String], limit: Int) -> [WeeklyReviewCompletion] {
        makeFrequencies(from: values, limit: limit)
            .map { WeeklyReviewCompletion(label: $0.label, count: $0.count) }
    }

    private func exerciseTitle(for completion: ExerciseCompletion) -> String {
        ExerciseService.shared.exercise(withID: completion.exerciseID)?.title
            ?? LibraryService.shared.exercise(withID: completion.exerciseID)?.title
            ?? completion.exerciseID
    }

    private func tinyWinTitle(for completion: TinyWinCompletion) -> String {
        TinyWinService.wins.first { $0.id == completion.winID }?.title
            ?? "Tiny win"
    }

    private func fetchMoodEntries(from context: ModelContext) throws -> [MoodEntry] {
        try context.fetch(FetchDescriptor<MoodEntry>(
            predicate: #Predicate<MoodEntry> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\MoodEntry.createdAt)]
        ))
    }

    private func fetchMoodCheckIns(from context: ModelContext) throws -> [MoodCheckIn] {
        try context.fetch(FetchDescriptor<MoodCheckIn>(
            predicate: #Predicate<MoodCheckIn> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\MoodCheckIn.createdAt)]
        ))
    }

    private func fetchExerciseCompletions(from context: ModelContext) throws -> [ExerciseCompletion] {
        try context.fetch(FetchDescriptor<ExerciseCompletion>(
            predicate: #Predicate<ExerciseCompletion> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\ExerciseCompletion.createdAt)]
        ))
    }

    private func fetchBreathingSessions(from context: ModelContext) throws -> [BreathingSession] {
        try context.fetch(FetchDescriptor<BreathingSession>(
            predicate: #Predicate<BreathingSession> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\BreathingSession.createdAt)]
        ))
    }

    private func fetchPlannedActivities(from context: ModelContext) throws -> [PlannedActivity] {
        try context.fetch(FetchDescriptor<PlannedActivity>(
            predicate: #Predicate<PlannedActivity> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\PlannedActivity.scheduledDate)]
        ))
    }

    private func fetchTinyWinCompletions(from context: ModelContext) throws -> [TinyWinCompletion] {
        try context.fetch(FetchDescriptor<TinyWinCompletion>(
            predicate: #Predicate<TinyWinCompletion> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\TinyWinCompletion.createdAt)]
        ))
    }

    private func fetchValueActionCompletions(from context: ModelContext) throws -> [ValueActionCompletion] {
        try context.fetch(FetchDescriptor<ValueActionCompletion>(
            predicate: #Predicate<ValueActionCompletion> { $0.isDeleted == false },
            sortBy: [SortDescriptor(\ValueActionCompletion.createdAt)]
        ))
    }

    private func fetchRitualEntry(weekStart: Date, from context: ModelContext) throws -> WeeklyRitualEntry? {
        var descriptor = FetchDescriptor<WeeklyRitualEntry>(
            predicate: #Predicate<WeeklyRitualEntry> {
                $0.isDeleted == false && $0.weekStart == weekStart
            },
            sortBy: [SortDescriptor(\WeeklyRitualEntry.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func weeklyReviewCompletionID(for weekStart: Date) -> String {
        let components = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)
        return "weekly-review-\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)"
    }

    private func contains(_ date: Date, in interval: DateInterval) -> Bool {
        date >= interval.start && date < interval.end
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func averageText(_ value: Double) -> String {
        Self.numberFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    private func sentence(from clauses: [String]) -> String {
        switch clauses.count {
        case 0:
            return ""
        case 1:
            return clauses[0]
        case 2:
            return "\(clauses[0]) and \(clauses[1])"
        default:
            return "\(clauses.dropLast().joined(separator: ", ")), and \(clauses.last ?? "")"
        }
    }

    private func dayCountText(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    private func missedDayCountText(_ count: Int) -> String {
        count == 1 ? "1 missed day" : "\(count) missed days"
    }

    private func timeCountText(_ count: Int) -> String {
        count == 1 ? "once" : count == 2 ? "twice" : "\(count) times"
    }

    private func exerciseCountText(_ count: Int) -> String {
        count == 1 ? "1 exercise" : "\(count) exercises"
    }

    private func tinyWinCountText(_ count: Int) -> String {
        count == 1 ? "1 tiny win" : "\(count) tiny wins"
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let anxietyStressKeywords = [
        "anxious", "anxiety", "stress", "stressed", "overwhelmed", "worry", "worried",
        "panic", "fear", "nervous", "tense", "pressure", "burnout", "distress"
    ]
}
