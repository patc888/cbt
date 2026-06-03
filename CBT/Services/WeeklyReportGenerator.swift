import Foundation
import PDFKit
import SwiftData
import UIKit

@MainActor
struct WeeklyReportGenerator {
    struct Report {
        let generatedAt: Date
        let dateRange: DateInterval
        let moodSummary: MoodSummary
        let emotionSummary: [Frequency]
        let triggerSummary: [Frequency]
        let activityPatternSummary: ActivityPatternSummary
        let thoughtRecordSummary: ThoughtRecordSummary
        let completedExercises: [Frequency]
        let breathingJournalSummary: BreathingJournalSummary
        let therapyPrep: TherapySessionPrep
        let suggestedFocus: [String]
        let thoughtExcerpts: [Excerpt]
        let journalExcerpts: [Excerpt]
        let includesExcerpts: Bool

        var displayEndDate: Date {
            dateRange.end.addingTimeInterval(-1)
        }
    }

    struct MoodSummary {
        let recordCount: Int
        let activeDays: Int
        let averageScore: Double?
        let lowestScore: Int?
        let highestScore: Int?
        let averageIntensity: Double?
        let firstHalfAverage: Double?
        let secondHalfAverage: Double?
        let moodChange: Double?
    }

    struct ActivityPatternSummary {
        let activeDays: Int
        let totalTrackedEvents: Int
        let busiestDay: Date?
        let busiestDayCount: Int
        let completedPlannedActivities: Int
        let plannedActivityCategories: [Frequency]
        let activityTagSummary: [Frequency]
        let averageActualEnjoyment: Double?
    }

    struct ThoughtRecordSummary {
        let recordCount: Int
        let averageIntensityBefore: Double?
        let averageIntensityAfter: Double?
        let averageIntensityChange: Double?
        let distortionSummary: [Frequency]
        let emotionSummary: [Frequency]
    }

    struct BreathingJournalSummary {
        let breathingSessionCount: Int
        let totalBreathingSeconds: Int
        let journalEntryCount: Int
        let flexibleJournalEntryCount: Int
        let timedJournalEntryCount: Int
    }

    struct TherapySessionPrep {
        let topPatterns: [String]
        let usefulReframes: [SessionPrepItem]
        let unresolvedThoughts: [SessionPrepItem]
        let assessmentChanges: [AssessmentChange]
        let discussionPrompts: [String]
    }

    struct SessionPrepItem: Identifiable {
        let id = UUID()
        let title: String
        let date: Date?
        let detail: String
    }

    struct AssessmentChange: Identifiable {
        let id = UUID()
        let title: String
        let latestScoreText: String
        let previousScoreText: String?
        let changeText: String
        let interpretation: String?
        let date: Date
    }

    struct Frequency: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
        let percentage: Double
    }

    struct Excerpt: Identifiable {
        let id = UUID()
        let title: String
        let date: Date
        let body: String
    }

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func generateReport(
        from modelContext: ModelContext,
        weekStart selectedWeekStart: Date,
        includeExcerpts: Bool = false
    ) throws -> Report {
        let dateRange = weekInterval(containing: selectedWeekStart)

        let moodEntries = try modelContext.fetch(
            FetchDescriptor<MoodEntry>(
                predicate: #Predicate<MoodEntry> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\MoodEntry.createdAt)]
            )
        )
        .filter { isInRange($0.createdAt, dateRange) }

        let moodCheckIns = try modelContext.fetch(
            FetchDescriptor<MoodCheckIn>(
                predicate: #Predicate<MoodCheckIn> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\MoodCheckIn.createdAt)]
            )
        )
        .filter { isInRange($0.createdAt, dateRange) }

        let thoughtRecords = try modelContext.fetch(
            FetchDescriptor<ThoughtRecord>(
                predicate: #Predicate<ThoughtRecord> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\ThoughtRecord.createdAt)]
            )
        )
        .filter { isInRange($0.createdAt, dateRange) }

        let exerciseCompletions = try modelContext.fetch(
            FetchDescriptor<ExerciseCompletion>(
                predicate: #Predicate<ExerciseCompletion> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\ExerciseCompletion.createdAt)]
            )
        )
        .filter { isInRange($0.createdAt, dateRange) }

        let journalEntries = try modelContext.fetch(
            FetchDescriptor<JournalEntry>(
                predicate: #Predicate<JournalEntry> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\JournalEntry.createdAt)]
            )
        )
        .filter { isInRange($0.createdAt, dateRange) }

        let flexibleJournalEntries = try modelContext.fetch(
            FetchDescriptor<FlexibleJournalEntry>(
                sortBy: [SortDescriptor(\FlexibleJournalEntry.date)]
            )
        )
        .filter { isInRange($0.date, dateRange) }

        let breathingSessions = try modelContext.fetch(
            FetchDescriptor<BreathingSession>(
                predicate: #Predicate<BreathingSession> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\BreathingSession.createdAt)]
            )
        )
        .filter { isInRange($0.createdAt, dateRange) }

        let plannedActivities = try modelContext.fetch(
            FetchDescriptor<PlannedActivity>(
                predicate: #Predicate<PlannedActivity> { $0.isDeleted == false },
                sortBy: [SortDescriptor(\PlannedActivity.scheduledDate)]
            )
        )
        .filter { activity in
            guard activity.isCompleted else { return false }
            let activityDate = activity.completedAt ?? activity.scheduledDate
            return isInRange(activityDate, dateRange)
        }

        let assessmentLogs = try modelContext.fetch(
            FetchDescriptor<AssessmentLog>(
                sortBy: [SortDescriptor(\AssessmentLog.date)]
            )
        )

        let moodSummary = makeMoodSummary(
            moodEntries: moodEntries,
            moodCheckIns: moodCheckIns,
            dateRange: dateRange
        )
        let activityPatternSummary = makeActivityPatternSummary(
            moodEntries: moodEntries,
            moodCheckIns: moodCheckIns,
            thoughtRecords: thoughtRecords,
            exerciseCompletions: exerciseCompletions,
            journalEntries: journalEntries,
            flexibleJournalEntries: flexibleJournalEntries,
            breathingSessions: breathingSessions,
            plannedActivities: plannedActivities
        )
        let thoughtRecordSummary = makeThoughtRecordSummary(from: thoughtRecords)
        let completedExercises = makeCompletedExerciseSummary(from: exerciseCompletions)
        let breathingJournalSummary = makeBreathingJournalSummary(
            breathingSessions: breathingSessions,
            journalEntries: journalEntries,
            flexibleJournalEntries: flexibleJournalEntries
        )
        let emotionSummary = makeFrequencies(
            from: moodEntries.flatMap(\.emotions) + thoughtRecords.flatMap(\.emotions)
        )
        let triggerSummary = makeFrequencies(from: moodEntries.flatMap(\.triggers))
        let suggestedFocus = makeSuggestedFocus(
            moodSummary: moodSummary,
            triggerSummary: triggerSummary,
            activityPatternSummary: activityPatternSummary,
            thoughtRecordSummary: thoughtRecordSummary,
            completedExercises: completedExercises,
            breathingJournalSummary: breathingJournalSummary
        )
        let therapyPrep = makeTherapySessionPrep(
            dateRange: dateRange,
            moodSummary: moodSummary,
            emotionSummary: emotionSummary,
            triggerSummary: triggerSummary,
            activityPatternSummary: activityPatternSummary,
            thoughtRecordSummary: thoughtRecordSummary,
            thoughtRecords: thoughtRecords,
            assessmentLogs: assessmentLogs,
            includePrivateText: includeExcerpts
        )

        return Report(
            generatedAt: Date(),
            dateRange: dateRange,
            moodSummary: moodSummary,
            emotionSummary: emotionSummary,
            triggerSummary: triggerSummary,
            activityPatternSummary: activityPatternSummary,
            thoughtRecordSummary: thoughtRecordSummary,
            completedExercises: completedExercises,
            breathingJournalSummary: breathingJournalSummary,
            therapyPrep: therapyPrep,
            suggestedFocus: suggestedFocus,
            thoughtExcerpts: includeExcerpts ? makeThoughtExcerpts(from: thoughtRecords) : [],
            journalExcerpts: includeExcerpts ? makeJournalExcerpts(from: journalEntries, flexibleJournalEntries: flexibleJournalEntries) : [],
            includesExcerpts: includeExcerpts
        )
    }

    func generatePDFURL(
        from modelContext: ModelContext,
        weekStart: Date,
        includeExcerpts: Bool = false
    ) throws -> URL {
        let report = try generateReport(
            from: modelContext,
            weekStart: weekStart,
            includeExcerpts: includeExcerpts
        )
        let data = makePDFData(from: report)
        guard let document = PDFDocument(data: data) else {
            throw WeeklyReportError.pdfCreationFailed
        }

        let filenameDate = Self.filenameFormatter.string(from: report.dateRange.start)
        let filename = "CBT-Weekly-Report-\(filenameDate).pdf"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        guard document.write(to: fileURL) else {
            throw WeeklyReportError.pdfWriteFailed
        }

        return fileURL
    }

    private func makeMoodSummary(
        moodEntries: [MoodEntry],
        moodCheckIns: [MoodCheckIn],
        dateRange: DateInterval
    ) -> MoodSummary {
        let moodPoints = moodEntries.map { (date: $0.createdAt, score: $0.moodScore) }
            + moodCheckIns.map { (date: $0.createdAt, score: $0.moodScore) }
        let scores = moodPoints.map { Double($0.score) }
        let days = Set(moodPoints.map { calendar.startOfDay(for: $0.date) })
        let splitDate = dateRange.start.addingTimeInterval(dateRange.duration / 2)
        let firstHalf = moodPoints.filter { $0.date < splitDate }.map { Double($0.score) }
        let secondHalf = moodPoints.filter { $0.date >= splitDate }.map { Double($0.score) }
        let firstAverage = average(firstHalf)
        let secondAverage = average(secondHalf)

        return MoodSummary(
            recordCount: moodPoints.count,
            activeDays: days.count,
            averageScore: average(scores),
            lowestScore: moodPoints.map { $0.score }.min(),
            highestScore: moodPoints.map { $0.score }.max(),
            averageIntensity: average(moodEntries.compactMap { $0.intensity.map(Double.init) }),
            firstHalfAverage: firstAverage,
            secondHalfAverage: secondAverage,
            moodChange: delta(from: firstAverage, to: secondAverage)
        )
    }

    private func makeActivityPatternSummary(
        moodEntries: [MoodEntry],
        moodCheckIns: [MoodCheckIn],
        thoughtRecords: [ThoughtRecord],
        exerciseCompletions: [ExerciseCompletion],
        journalEntries: [JournalEntry],
        flexibleJournalEntries: [FlexibleJournalEntry],
        breathingSessions: [BreathingSession],
        plannedActivities: [PlannedActivity]
    ) -> ActivityPatternSummary {
        let eventDates = moodEntries.map(\.createdAt)
            + moodCheckIns.map(\.createdAt)
            + thoughtRecords.map(\.createdAt)
            + exerciseCompletions.map(\.createdAt)
            + journalEntries.map(\.createdAt)
            + flexibleJournalEntries.map(\.date)
            + breathingSessions.map(\.createdAt)
            + plannedActivities.map { $0.completedAt ?? $0.scheduledDate }
        let dayCounts = Dictionary(grouping: eventDates.map { calendar.startOfDay(for: $0) }, by: { $0 })
            .mapValues(\.count)
        let busiest = dayCounts.sorted {
            if $0.value == $1.value {
                return $0.key < $1.key
            }
            return $0.value > $1.value
        }
        .first

        return ActivityPatternSummary(
            activeDays: dayCounts.count,
            totalTrackedEvents: eventDates.count,
            busiestDay: busiest?.key,
            busiestDayCount: busiest?.value ?? 0,
            completedPlannedActivities: plannedActivities.count,
            plannedActivityCategories: makeFrequencies(from: plannedActivities.map(\.category)),
            activityTagSummary: makeFrequencies(
                from: moodEntries.flatMap { entry in
                    entry.activityTags.isEmpty ? entry.contextTags : entry.activityTags
                }
            ),
            averageActualEnjoyment: average(plannedActivities.compactMap { $0.actualEnjoyment.map(Double.init) })
        )
    }

    private func makeThoughtRecordSummary(from records: [ThoughtRecord]) -> ThoughtRecordSummary {
        let beforeAverage = average(records.map { Double($0.intensityBefore) })
        let afterAverage = average(records.map { Double($0.intensityAfter) })

        return ThoughtRecordSummary(
            recordCount: records.count,
            averageIntensityBefore: beforeAverage,
            averageIntensityAfter: afterAverage,
            averageIntensityChange: delta(from: beforeAverage, to: afterAverage),
            distortionSummary: makeFrequencies(from: records.flatMap(\.distortions)),
            emotionSummary: makeFrequencies(from: records.flatMap(\.emotions))
        )
    }

    private func makeCompletedExerciseSummary(from completions: [ExerciseCompletion]) -> [Frequency] {
        makeFrequencies(
            from: completions.map { completion in
                ExerciseService.shared.exercise(withID: completion.exerciseID)?.title
                    ?? completion.exerciseID
            }
        )
    }

    private func makeBreathingJournalSummary(
        breathingSessions: [BreathingSession],
        journalEntries: [JournalEntry],
        flexibleJournalEntries: [FlexibleJournalEntry]
    ) -> BreathingJournalSummary {
        BreathingJournalSummary(
            breathingSessionCount: breathingSessions.count,
            totalBreathingSeconds: breathingSessions.map(\.durationSeconds).reduce(0, +),
            journalEntryCount: journalEntries.count,
            flexibleJournalEntryCount: flexibleJournalEntries.count,
            timedJournalEntryCount: journalEntries.filter { ($0.durationSeconds ?? 0) > 0 }.count
        )
    }

    private func makeSuggestedFocus(
        moodSummary: MoodSummary,
        triggerSummary: [Frequency],
        activityPatternSummary: ActivityPatternSummary,
        thoughtRecordSummary: ThoughtRecordSummary,
        completedExercises: [Frequency],
        breathingJournalSummary: BreathingJournalSummary
    ) -> [String] {
        var suggestions: [String] = []

        if moodSummary.recordCount == 0 {
            suggestions.append("Add a few mood check-ins next week so patterns have a clearer baseline.")
        } else if let averageScore = moodSummary.averageScore, averageScore <= 4 {
            suggestions.append("Look back at lower-mood days gently and note what support felt accessible.")
        }

        if let topTrigger = triggerSummary.first, topTrigger.count >= 2 {
            suggestions.append("Plan one coping response for recurring \(topTrigger.label) triggers.")
        }

        if thoughtRecordSummary.recordCount == 0 {
            suggestions.append("Try one short thought record when an intense thought shows up.")
        } else if let change = thoughtRecordSummary.averageIntensityChange, change > -10 {
            suggestions.append("Try returning to one balanced thought later in the day and note whether it still feels useful.")
        } else {
            suggestions.append("Keep using any thought-record rhythm that felt workable this week.")
        }

        if completedExercises.isEmpty && activityPatternSummary.completedPlannedActivities == 0 {
            suggestions.append("Schedule one small nourishing or mastery activity before the week gets busy.")
        }

        if breathingJournalSummary.breathingSessionCount == 0 && breathingJournalSummary.journalEntryCount == 0 && breathingJournalSummary.flexibleJournalEntryCount == 0 {
            suggestions.append("Add one brief breathing or journal check-in to capture what helps in the moment.")
        }

        return Array(suggestions.prefix(4))
    }

    private func makeTherapySessionPrep(
        dateRange: DateInterval,
        moodSummary: MoodSummary,
        emotionSummary: [Frequency],
        triggerSummary: [Frequency],
        activityPatternSummary: ActivityPatternSummary,
        thoughtRecordSummary: ThoughtRecordSummary,
        thoughtRecords: [ThoughtRecord],
        assessmentLogs: [AssessmentLog],
        includePrivateText: Bool
    ) -> TherapySessionPrep {
        let topPatterns = makeTherapyTopPatterns(
            moodSummary: moodSummary,
            emotionSummary: emotionSummary,
            triggerSummary: triggerSummary,
            activityPatternSummary: activityPatternSummary,
            thoughtRecordSummary: thoughtRecordSummary
        )
        let usefulReframes = makeUsefulReframes(from: thoughtRecords, includePrivateText: includePrivateText)
        let unresolvedThoughts = makeUnresolvedThoughts(from: thoughtRecords, includePrivateText: includePrivateText)
        let assessmentChanges = makeAssessmentChanges(from: assessmentLogs, dateRange: dateRange)
        let discussionPrompts = makeDiscussionPrompts(
            topPatterns: topPatterns,
            usefulReframes: usefulReframes,
            unresolvedThoughts: unresolvedThoughts,
            assessmentChanges: assessmentChanges,
            moodSummary: moodSummary,
            triggerSummary: triggerSummary
        )

        return TherapySessionPrep(
            topPatterns: topPatterns,
            usefulReframes: usefulReframes,
            unresolvedThoughts: unresolvedThoughts,
            assessmentChanges: assessmentChanges,
            discussionPrompts: discussionPrompts
        )
    }

    private func makeTherapyTopPatterns(
        moodSummary: MoodSummary,
        emotionSummary: [Frequency],
        triggerSummary: [Frequency],
        activityPatternSummary: ActivityPatternSummary,
        thoughtRecordSummary: ThoughtRecordSummary
    ) -> [String] {
        var patterns: [String] = []

        if let topEmotion = emotionSummary.first {
            patterns.append("\(topEmotion.label) showed up most often across mood and thought records.")
        }

        if let topTrigger = triggerSummary.first {
            patterns.append("\(topTrigger.label) was the most repeated trigger.")
        }

        if let topDistortion = thoughtRecordSummary.distortionSummary.first {
            patterns.append("\(topDistortion.label) was the most common thought pattern.")
        }

        if let moodChange = moodSummary.moodChange, abs(moodChange) >= 1 {
            let direction = moodChange > 0 ? "rose" : "dipped"
            patterns.append("Average mood \(direction) by \(formatAbsolute(moodChange)) points between the first and second half of the week.")
        }

        if let busiestDay = activityPatternSummary.busiestDay {
            patterns.append("\(Self.weekdayFormatter.string(from: busiestDay)) had the highest self-tracking activity.")
        }

        return Array(patterns.prefix(5))
    }

    private func makeUsefulReframes(from records: [ThoughtRecord], includePrivateText: Bool) -> [SessionPrepItem] {
        records
            .filter { !$0.displayReframe.isEmpty && $0.intensityAfter < $0.intensityBefore }
            .sorted {
                let firstChange = $0.intensityBefore - $0.intensityAfter
                let secondChange = $1.intensityBefore - $1.intensityAfter
                if firstChange == secondChange {
                    return $0.createdAt > $1.createdAt
                }
                return firstChange > secondChange
            }
            .prefix(3)
            .map { record in
                let drop = record.intensityBefore - record.intensityAfter
                let detail = includePrivateText
                    ? "\"\(snippet(record.displayReframe, maxLength: 180))\""
                    : "Private reframe hidden in summary mode."
                return SessionPrepItem(
                    title: "Intensity dropped \(drop) points",
                    date: record.completedAt ?? record.createdAt,
                    detail: detail
                )
            }
    }

    private func makeUnresolvedThoughts(from records: [ThoughtRecord], includePrivateText: Bool) -> [SessionPrepItem] {
        records
            .filter { record in
                record.isDraft ||
                    record.displayReframe.isEmpty ||
                    record.intensityAfter >= 60 ||
                    record.intensityAfter >= record.intensityBefore
            }
            .sorted {
                if $0.intensityAfter == $1.intensityAfter {
                    return $0.createdAt > $1.createdAt
                }
                return $0.intensityAfter > $1.intensityAfter
            }
            .prefix(3)
            .map { record in
                let reason: String
                if record.isDraft {
                    reason = "Draft thought record"
                } else if record.displayReframe.isEmpty {
                    reason = "No balanced thought saved"
                } else if record.intensityAfter >= record.intensityBefore {
                    reason = "Intensity did not decrease"
                } else {
                    reason = "Intensity stayed high"
                }

                let privateText = record.automaticThought.trimmingCharacters(in: .whitespacesAndNewlines)
                let detail = includePrivateText && !privateText.isEmpty
                    ? "\(reason): \(snippet(privateText, maxLength: 180))"
                    : "\(reason). Private thought text hidden in summary mode."
                return SessionPrepItem(
                    title: "After intensity \(record.intensityAfter)%",
                    date: record.completedAt ?? record.createdAt,
                    detail: detail
                )
            }
    }

    private func makeAssessmentChanges(from logs: [AssessmentLog], dateRange: DateInterval) -> [AssessmentChange] {
        let groupedLogs = Dictionary(grouping: logs, by: \.assessmentType)
        let weeklyLatest = groupedLogs.compactMap { assessmentType, logs -> AssessmentChange? in
            let sorted = logs.sorted { $0.date > $1.date }
            guard let latest = sorted.first(where: { isInRange($0.date, dateRange) }) else { return nil }
            let previous = sorted.first { $0.date < latest.date }
            let latestValue = assessmentDisplayValue(latest)
            let previousValue = previous.map(assessmentDisplayValue)
            let kind = AssessmentKind(rawValue: assessmentType)
            let latestText = kind?.scoreText(for: latestValue) ?? format(latestValue)
            let previousText = previousValue.map { kind?.scoreText(for: $0) ?? format($0) }
            let changeText: String

            if let previousValue {
                let change = latestValue - previousValue
                changeText = assessmentChangeText(change, isSupportiveScore: kind?.isSupportiveScore ?? false)
            } else {
                changeText = "First result this week"
            }

            return AssessmentChange(
                title: kind?.title ?? assessmentType,
                latestScoreText: latestText,
                previousScoreText: previousText,
                changeText: changeText,
                interpretation: kind?.interpretation(for: latestValue),
                date: latest.date
            )
        }

        return weeklyLatest.sorted { $0.date > $1.date }.prefix(4).map { $0 }
    }

    private func makeDiscussionPrompts(
        topPatterns: [String],
        usefulReframes: [SessionPrepItem],
        unresolvedThoughts: [SessionPrepItem],
        assessmentChanges: [AssessmentChange],
        moodSummary: MoodSummary,
        triggerSummary: [Frequency]
    ) -> [String] {
        var prompts: [String] = []

        if let unresolved = unresolvedThoughts.first {
            prompts.append("What support or skill would help with the unresolved thought from \(dateLabel(unresolved.date))?")
        }

        if let topTrigger = triggerSummary.first {
            prompts.append("What plan would make \(topTrigger.label) triggers more workable next week?")
        } else if let pattern = topPatterns.first {
            prompts.append("What does this pattern suggest we should understand better: \(pattern)")
        }

        if let assessment = assessmentChanges.first {
            prompts.append("What might explain the latest \(assessment.title) result and \(assessment.changeText.lowercased())?")
        }

        if let reframe = usefulReframes.first {
            prompts.append("How can the reframe that helped on \(dateLabel(reframe.date)) be practiced or generalized?")
        }

        if prompts.count < 3, let averageMood = moodSummary.averageScore {
            prompts.append("What was happening around the week’s average mood of \(format(averageMood, suffix: "/10"))?")
        }

        if prompts.count < 3 {
            prompts.append("What are the three most important moments from this week to bring into the session?")
        }

        if prompts.count < 3 {
            prompts.append("What would make the next week feel 5% more supported?")
        }

        return Array(prompts.prefix(3))
    }

    private func makeThoughtExcerpts(from records: [ThoughtRecord]) -> [Excerpt] {
        records.prefix(4).compactMap { record in
            let parts = [
                labeledSnippet("Situation", record.situation),
                labeledSnippet("Automatic thought", record.automaticThought),
                labeledSnippet("Balanced thought", record.balancedThought)
            ].compactMap { $0 }

            guard !parts.isEmpty else { return nil }
            return Excerpt(
                title: "Thought Record",
                date: record.createdAt,
                body: parts.joined(separator: "\n")
            )
        }
    }

    private func makeJournalExcerpts(
        from journalEntries: [JournalEntry],
        flexibleJournalEntries: [FlexibleJournalEntry]
    ) -> [Excerpt] {
        let journalExcerpts = journalEntries.compactMap { entry -> Excerpt? in
            let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Journal Entry" : entry.title
            let body = snippet(entry.body, maxLength: 260)
            guard !body.isEmpty else { return nil }

            return Excerpt(
                title: title,
                date: entry.createdAt,
                body: body
            )
        }

        let flexibleExcerpts = flexibleJournalEntries.compactMap { entry -> Excerpt? in
            let responses = entry.responses
                .map { snippet($0, maxLength: 180) }
                .filter { !$0.isEmpty }
                .prefix(2)
            guard !responses.isEmpty else { return nil }

            return Excerpt(
                title: entry.templateType.isEmpty ? "Guided Journal" : entry.templateType.capitalized,
                date: entry.date,
                body: responses.joined(separator: "\n")
            )
        }

        return Array((journalExcerpts + flexibleExcerpts).sorted { $0.date < $1.date }.prefix(4))
    }

    private func labeledSnippet(_ label: String, _ value: String) -> String? {
        let text = snippet(value, maxLength: 220)
        guard !text.isEmpty else { return nil }
        return "\(label): \(text)"
    }

    private func makeFrequencies(from labels: [String]) -> [Frequency] {
        var counts: [String: (label: String, count: Int)] = [:]

        for label in labels {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let key = trimmed.lowercased()
            if let current = counts[key] {
                counts[key] = (current.label, current.count + 1)
            } else {
                counts[key] = (trimmed, 1)
            }
        }

        let total = max(counts.values.map { $0.count }.reduce(0, +), 1)
        return counts.values
            .map { Frequency(label: $0.label, count: $0.count, percentage: Double($0.count) / Double(total)) }
            .sorted {
                if $0.count == $1.count {
                    return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
                }
                return $0.count > $1.count
            }
    }

    private func weekInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 24 * 60 * 60)
    }

    private func isInRange(_ date: Date, _ range: DateInterval) -> Bool {
        date >= range.start && date < range.end
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func delta(from start: Double?, to end: Double?) -> Double? {
        guard let start, let end else { return nil }
        return end - start
    }

    private func assessmentDisplayValue(_ log: AssessmentLog) -> Double {
        log.scoreValue ?? Double(log.score)
    }

    private func assessmentChangeText(_ change: Double, isSupportiveScore: Bool) -> String {
        guard abs(change) >= 0.05 else { return "About the same" }
        let direction: String

        if isSupportiveScore {
            direction = change > 0 ? "more support" : "less support"
        } else {
            direction = change > 0 ? "higher load" : "lower load"
        }

        return "\(direction), \(formatSigned(change, suffix: ""))"
    }

    private func dateLabel(_ date: Date?) -> String {
        guard let date else { return "this week" }
        return Self.shortDateFormatter.string(from: date)
    }

    private func formatAbsolute(_ value: Double) -> String {
        Self.numberFormatter.string(from: NSNumber(value: abs(value))) ?? String(format: "%.1f", abs(value))
    }

    private func snippet(_ value: String, maxLength: Int) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard collapsed.count > maxLength else { return collapsed }

        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: maxLength)
        return collapsed[..<endIndex].trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func makePDFData(from report: Report) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: WeeklyPDFLayout.pageRect)
        return renderer.pdfData { context in
            var page = WeeklyReportPDFPage(context: context, report: report)
            page.draw()
        }
    }

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum WeeklyReportError: LocalizedError {
    case pdfCreationFailed
    case pdfWriteFailed

    var errorDescription: String? {
        switch self {
        case .pdfCreationFailed:
            return "The weekly report PDF could not be created."
        case .pdfWriteFailed:
            return "The weekly report PDF could not be written to disk."
        }
    }
}

private struct WeeklyReportPDFPage {
    let context: UIGraphicsPDFRendererContext
    let report: WeeklyReportGenerator.Report

    private var y: CGFloat = 0

    init(context: UIGraphicsPDFRendererContext, report: WeeklyReportGenerator.Report) {
        self.context = context
        self.report = report
    }

    mutating func draw() {
        beginPage()
        drawHeader()
        drawMoodSummary()
        drawTherapySessionPrep()
        drawEmotionTriggerSummary()
        drawActivityPatternSummary()
        drawThoughtRecordSummary()
        drawExercisesBreathingSummary()
        drawJournalActivitySummary()
        drawSuggestedFocus()
        drawExcerptsIfNeeded()
        drawFooter()
    }

    private mutating func beginPage() {
        context.beginPage()
        y = WeeklyPDFLayout.margin
    }

    private mutating func ensureSpace(_ height: CGFloat) {
        if y + height > WeeklyPDFLayout.pageRect.height - WeeklyPDFLayout.margin - 30 {
            drawFooter()
            beginPage()
        }
    }

    private mutating func drawHeader() {
        drawTextBlock(
            "Weekly Report",
            font: .systemFont(ofSize: 24, weight: .semibold),
            color: .label,
            spacingAfter: 4
        )
        drawTextBlock(
            "\(Self.dateFormatter.string(from: report.dateRange.start)) - \(Self.dateFormatter.string(from: report.displayEndDate))",
            font: .systemFont(ofSize: 12, weight: .medium),
            color: .secondaryLabel,
            spacingAfter: 2
        )
        drawTextBlock(
            "Generated \(Self.dateTimeFormatter.string(from: report.generatedAt)) | Detail level: \(report.includesExcerpts ? "Includes journal/thought excerpts" : "Summary only")",
            font: .systemFont(ofSize: 9, weight: .regular),
            color: .secondaryLabel,
            spacingAfter: 12
        )
        drawDisclaimerBox()
        y += 8
    }

    private mutating func drawMoodSummary() {
        let mood = report.moodSummary
        drawSectionTitle("Mood Summary")
        drawKeyValueRows([
            ("Mood records", "\(mood.recordCount) across \(mood.activeDays) day\(mood.activeDays == 1 ? "" : "s")"),
            ("Average mood", format(mood.averageScore, suffix: "/10")),
            ("Mood range", moodRangeText(mood)),
            ("Average intensity", format(mood.averageIntensity, suffix: "%")),
            ("Week shift", formatSigned(mood.moodChange, suffix: " points"))
        ])
    }

    private mutating func drawTherapySessionPrep() {
        let prep = report.therapyPrep
        drawSectionTitle("Therapy Session Prep")
        drawSubsection(title: "Top patterns", emptyText: "No clear patterns available yet.") {
            drawBullets(prep.topPatterns)
        } isEmpty: {
            prep.topPatterns.isEmpty
        }
        drawSessionPrepItems("Most useful reframes", prep.usefulReframes, emptyText: "No intensity-reducing reframes recorded this week.")
        drawSessionPrepItems("Unresolved thoughts", prep.unresolvedThoughts, emptyText: "No unresolved thought records surfaced this week.")
        drawAssessmentChanges(prep.assessmentChanges)
        drawSubsection(title: "3 things to discuss", emptyText: "Discussion prompts appear once more weekly data is available.") {
            drawBullets(prep.discussionPrompts)
        } isEmpty: {
            prep.discussionPrompts.isEmpty
        }
    }

    private mutating func drawEmotionTriggerSummary() {
        drawSectionTitle("Emotions / Triggers")
        drawFrequencyList("Top emotions", report.emotionSummary, emptyText: "No emotions recorded this week.")
        drawFrequencyList("Top triggers", report.triggerSummary, emptyText: "No triggers recorded this week.")
    }

    private mutating func drawActivityPatternSummary() {
        let activity = report.activityPatternSummary
        drawSectionTitle("Activity Patterns")
        var rows = [
            ("Active days", "\(activity.activeDays) of 7"),
            ("Tracked events", "\(activity.totalTrackedEvents)"),
            ("Busiest day", busiestDayText(activity)),
            ("Completed planned activities", "\(activity.completedPlannedActivities)")
        ]

        if let averageEnjoyment = activity.averageActualEnjoyment {
            rows.append(("Average actual enjoyment", format(averageEnjoyment, suffix: "/10")))
        }

        drawKeyValueRows(rows)
        drawFrequencyList("Activity tags", activity.activityTagSummary, emptyText: "No activity or context tags recorded this week.")
        drawFrequencyList("Completed activity categories", activity.plannedActivityCategories, emptyText: "No completed planned activities recorded this week.")
    }

    private mutating func drawThoughtRecordSummary() {
        let thought = report.thoughtRecordSummary
        drawSectionTitle("Thought Patterns")
        drawKeyValueRows([
            ("Thought records", "\(thought.recordCount)"),
            ("Average intensity before", format(thought.averageIntensityBefore, suffix: "%")),
            ("Average intensity after", format(thought.averageIntensityAfter, suffix: "%")),
            ("Average change", formatSigned(thought.averageIntensityChange, suffix: " points"))
        ])
        drawFrequencyList("Common distortions", thought.distortionSummary, emptyText: "No distortions recorded this week.")
        drawFrequencyList("Thought record emotions", thought.emotionSummary, emptyText: "No thought record emotions recorded this week.")
    }

    private mutating func drawExercisesBreathingSummary() {
        let summary = report.breathingJournalSummary
        drawSectionTitle("Exercises and Breathing")
        drawFrequencyList("Completed exercises", report.completedExercises, emptyText: "No CBT exercises completed this week.")
        drawKeyValueRows([
            ("Breathing sessions", "\(summary.breathingSessionCount)"),
            ("Breathing time", durationText(seconds: summary.totalBreathingSeconds))
        ])
    }

    private mutating func drawJournalActivitySummary() {
        let summary = report.breathingJournalSummary
        drawSectionTitle("Journal Activity")
        drawKeyValueRows([
            ("Journal entries", "\(summary.journalEntryCount)"),
            ("Guided journal entries", "\(summary.flexibleJournalEntryCount)"),
            ("Timed journal entries", "\(summary.timedJournalEntryCount)")
        ])
    }

    private mutating func drawSuggestedFocus() {
        drawSectionTitle("Suggested Focus for Next Week")
        guard !report.suggestedFocus.isEmpty else {
            drawEmptyState("No focus suggestions available yet.")
            return
        }

        drawBullets(report.suggestedFocus)
    }

    private mutating func drawExcerptsIfNeeded() {
        drawSectionTitle("Journal / Thought Excerpts")
        guard report.includesExcerpts else {
            drawTextBlock(
                "Summary only was selected, so private journal and thought excerpts are not included.",
                font: .systemFont(ofSize: 10, weight: .regular),
                color: .secondaryLabel,
                spacingAfter: 12
            )
            return
        }

        let excerpts = report.thoughtExcerpts + report.journalExcerpts
        guard !excerpts.isEmpty else {
            drawEmptyState("No journal or thought excerpts were available for this week.")
            return
        }

        for excerpt in excerpts {
            ensureSpace(58)
            drawTextBlock(
                "\(excerpt.title) - \(Self.shortDateFormatter.string(from: excerpt.date))",
                font: .systemFont(ofSize: 10, weight: .semibold),
                color: .label,
                spacingAfter: 3
            )
            drawTextBlock(
                excerpt.body,
                font: .systemFont(ofSize: 9, weight: .regular),
                color: .secondaryLabel,
                spacingAfter: 10
            )
        }
    }

    private mutating func drawDisclaimerBox() {
        let text = "Disclaimer: This report summarizes self-tracking data entered in the app. It is not a diagnosis, medical advice, or a substitute for care from a qualified clinician."
        let inset: CGFloat = 8
        let height = textHeight(
            text,
            width: WeeklyPDFLayout.contentWidth - inset * 2,
            font: .systemFont(ofSize: 9, weight: .regular)
        ) + inset * 2
        ensureSpace(height + 8)

        UIColor.systemGray6.setFill()
        UIBezierPath(
            roundedRect: CGRect(x: WeeklyPDFLayout.margin, y: y, width: WeeklyPDFLayout.contentWidth, height: height),
            cornerRadius: 6
        )
        .fill()

        drawText(
            text,
            x: WeeklyPDFLayout.margin + inset,
            y: y + inset,
            width: WeeklyPDFLayout.contentWidth - inset * 2,
            height: height - inset * 2,
            font: .systemFont(ofSize: 9, weight: .regular),
            color: .secondaryLabel
        )
        y += height + 8
    }

    private mutating func drawSectionTitle(_ title: String) {
        ensureSpace(38)
        y += 8
        drawTextBlock(title, font: .systemFont(ofSize: 14, weight: .semibold), color: .label, spacingAfter: 4)
        drawRule(color: .systemGray4)
        y += 8
    }

    private mutating func drawKeyValueRows(_ rows: [(String, String)]) {
        for row in rows {
            ensureSpace(20)
            drawText(
                row.0.uppercased(),
                x: WeeklyPDFLayout.margin,
                y: y,
                width: 180,
                height: 16,
                font: .systemFont(ofSize: 8, weight: .semibold),
                color: .secondaryLabel
            )
            drawText(
                row.1,
                x: WeeklyPDFLayout.margin + 190,
                y: y,
                width: WeeklyPDFLayout.contentWidth - 190,
                height: 16,
                font: .systemFont(ofSize: 10, weight: .regular),
                color: .label
            )
            y += 18
        }
        y += 2
    }

    private mutating func drawFrequencyList(_ title: String?, _ frequencies: [WeeklyReportGenerator.Frequency], emptyText: String) {
        if let title {
            drawTextBlock(title, font: .systemFont(ofSize: 10, weight: .semibold), color: .label, spacingAfter: 4)
        }

        guard !frequencies.isEmpty else {
            drawEmptyState(emptyText)
            return
        }

        for frequency in frequencies.prefix(6) {
            ensureSpace(18)
            let percent = Int((frequency.percentage * 100).rounded())
            drawText(
                frequency.label,
                x: WeeklyPDFLayout.margin,
                y: y,
                width: 300,
                height: 15,
                font: .systemFont(ofSize: 10, weight: .regular),
                color: .label
            )
            drawText(
                "\(frequency.count) (\(percent)%)",
                x: WeeklyPDFLayout.margin + 365,
                y: y,
                width: 95,
                height: 15,
                font: .systemFont(ofSize: 10, weight: .regular),
                color: .secondaryLabel,
                alignment: .right
            )
            y += 16
        }
        y += 6
    }

    private mutating func drawSubsection(
        title: String,
        emptyText: String,
        drawContent: () -> Void,
        isEmpty: () -> Bool
    ) {
        drawTextBlock(title, font: .systemFont(ofSize: 10, weight: .semibold), color: .label, spacingAfter: 4)
        if isEmpty() {
            drawEmptyState(emptyText)
        } else {
            drawContent()
        }
    }

    private mutating func drawSessionPrepItems(
        _ title: String,
        _ items: [WeeklyReportGenerator.SessionPrepItem],
        emptyText: String
    ) {
        drawTextBlock(title, font: .systemFont(ofSize: 10, weight: .semibold), color: .label, spacingAfter: 4)
        guard !items.isEmpty else {
            drawEmptyState(emptyText)
            return
        }

        for item in items {
            let datePrefix = item.date.map { "\(Self.shortDateFormatter.string(from: $0)) - " } ?? ""
            drawTextBlock(
                "- \(datePrefix)\(item.title): \(item.detail)",
                font: .systemFont(ofSize: 10, weight: .regular),
                color: .label,
                spacingAfter: 5
            )
        }
        y += 4
    }

    private mutating func drawAssessmentChanges(_ changes: [WeeklyReportGenerator.AssessmentChange]) {
        drawTextBlock("Assessment changes", font: .systemFont(ofSize: 10, weight: .semibold), color: .label, spacingAfter: 4)
        guard !changes.isEmpty else {
            drawEmptyState("No assessments were logged this week.")
            return
        }

        for change in changes {
            let previous = change.previousScoreText.map { "previous \($0), " } ?? ""
            let interpretation = change.interpretation.map { ", \($0)" } ?? ""
            drawTextBlock(
                "- \(change.title): \(change.latestScoreText) (\(previous)\(change.changeText)\(interpretation))",
                font: .systemFont(ofSize: 10, weight: .regular),
                color: .label,
                spacingAfter: 5
            )
        }
        y += 4
    }

    private mutating func drawBullets(_ bullets: [String]) {
        for bullet in bullets {
            drawTextBlock(
                "- \(bullet)",
                font: .systemFont(ofSize: 10, weight: .regular),
                color: .label,
                spacingAfter: 5
            )
        }
        y += 4
    }

    private mutating func drawEmptyState(_ text: String) {
        drawTextBlock(text, font: .systemFont(ofSize: 10, weight: .regular), color: .secondaryLabel, spacingAfter: 10)
    }

    private mutating func drawFooter() {
        let footerY = WeeklyPDFLayout.pageRect.height - WeeklyPDFLayout.margin + 6
        drawRule(y: footerY - 10, color: .systemGray5)
        drawText(
            "Self-tracking summary only. Not diagnostic.",
            x: WeeklyPDFLayout.margin,
            y: footerY,
            width: WeeklyPDFLayout.contentWidth,
            height: 12,
            font: .systemFont(ofSize: 8, weight: .regular),
            color: .secondaryLabel
        )
    }

    private mutating func drawRule(y ruleY: CGFloat? = nil, color: UIColor = .systemGray3) {
        let lineY = ruleY ?? y
        color.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: WeeklyPDFLayout.margin, y: lineY))
        path.addLine(to: CGPoint(x: WeeklyPDFLayout.pageRect.width - WeeklyPDFLayout.margin, y: lineY))
        path.lineWidth = 0.5
        path.stroke()
    }

    private mutating func drawTextBlock(
        _ text: String,
        font: UIFont,
        color: UIColor,
        spacingAfter: CGFloat
    ) {
        let height = textHeight(text, width: WeeklyPDFLayout.contentWidth, font: font)
        ensureSpace(height + spacingAfter)
        drawText(
            text,
            x: WeeklyPDFLayout.margin,
            y: y,
            width: WeeklyPDFLayout.contentWidth,
            height: height,
            font: font,
            color: color
        )
        y += height + spacingAfter
    }

    private func drawText(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 1.5
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        (text as NSString).draw(
            with: CGRect(x: x, y: y, width: width, height: height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
    }

    private func textHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 1.5
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph
        ]
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return max(12, ceil(rect.height))
    }

    private func moodRangeText(_ mood: WeeklyReportGenerator.MoodSummary) -> String {
        guard let lowest = mood.lowestScore, let highest = mood.highestScore else { return "N/A" }
        return "\(lowest)-\(highest)/10"
    }

    private func busiestDayText(_ activity: WeeklyReportGenerator.ActivityPatternSummary) -> String {
        guard let busiestDay = activity.busiestDay else { return "N/A" }
        return "\(Self.weekdayFormatter.string(from: busiestDay)) (\(activity.busiestDayCount) events)"
    }

    private func durationText(seconds: Int) -> String {
        guard seconds > 0 else { return "0 minutes" }
        let minutes = Double(seconds) / 60.0
        let formatted = Self.numberFormatter.string(from: NSNumber(value: minutes)) ?? String(format: "%.1f", minutes)
        return "\(formatted) minutes"
    }

    private func format(_ value: Double?, suffix: String = "") -> String {
        guard let value else { return "N/A" }
        return "\(Self.numberFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value))\(suffix)"
    }

    private func formatSigned(_ value: Double?, suffix: String = "") -> String {
        guard let value else { return "N/A" }
        let formatted = Self.numberFormatter.string(from: NSNumber(value: abs(value))) ?? String(format: "%.1f", abs(value))
        if value > 0 {
            return "+\(formatted)\(suffix)"
        }
        if value < 0 {
            return "-\(formatted)\(suffix)"
        }
        return "0\(suffix)"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

private enum WeeklyPDFLayout {
    static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    static let margin: CGFloat = 54
    static let contentWidth: CGFloat = pageRect.width - (margin * 2)
}
