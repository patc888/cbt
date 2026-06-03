import Foundation

struct RetentionMoodEvent: Sendable {
    let createdAt: Date
    let moodScore: Int
    let triggers: [String]
    let energyScore: Int?

    init(createdAt: Date, moodScore: Int, triggers: [String], energyScore: Int? = nil) {
        self.createdAt = createdAt
        self.moodScore = moodScore
        self.triggers = triggers
        self.energyScore = energyScore
    }
}

struct RetentionThoughtEvent: Sendable {
    let createdAt: Date
    let intensityBefore: Int
    let intensityAfter: Int
}

struct RetentionDatedEvent: Sendable {
    let createdAt: Date
}

struct RetentionInsightCard: Identifiable, Sendable {
    let id: String
    let title: String
    let message: String
    let detail: String
    let iconName: String
    let valueText: String?
}

struct PersonalPatternUnlock: Identifiable, Sendable {
    let id: String
    let title: String
    let message: String
    let detail: String
    let iconName: String
    let requiredCheckInDays: Int
    let isUnlocked: Bool
}

struct RetentionInsightsSnapshot: Sendable {
    let cards: [RetentionInsightCard]
    let patternUnlocks: [PersonalPatternUnlock]
    let emptyStateMessage: String?

    nonisolated static let empty = RetentionInsightsSnapshot(
        cards: [],
        patternUnlocks: [],
        emptyStateMessage: "Add a few check-ins, breathing sessions, journals, or exercise completions to see progress cards here."
    )
}

enum RetentionInsightsService {
    nonisolated static func snapshot(
        moods: [RetentionMoodEvent],
        checkIns: [RetentionDatedEvent],
        thoughts: [RetentionThoughtEvent],
        exerciseCompletions: [RetentionDatedEvent],
        journalEntries: [RetentionDatedEvent],
        flexibleJournalEntries: [RetentionDatedEvent],
        breathingSessions: [RetentionDatedEvent],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> RetentionInsightsSnapshot {
        let today = calendar.startOfDay(for: referenceDate)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
        let allActivityDays = Set(
            moods.map { calendar.startOfDay(for: $0.createdAt) }
            + checkIns.map { calendar.startOfDay(for: $0.createdAt) }
            + thoughts.map { calendar.startOfDay(for: $0.createdAt) }
            + exerciseCompletions.map { calendar.startOfDay(for: $0.createdAt) }
            + journalEntries.map { calendar.startOfDay(for: $0.createdAt) }
            + flexibleJournalEntries.map { calendar.startOfDay(for: $0.createdAt) }
            + breathingSessions.map { calendar.startOfDay(for: $0.createdAt) }
        )

        var cards: [RetentionInsightCard] = []

        let checkInDaysThisWeek = Set(
            (moods.map(\.createdAt) + checkIns.map(\.createdAt))
                .map { calendar.startOfDay(for: $0) }
                .filter { $0 >= weekStart && $0 <= today }
        ).count
        if checkInDaysThisWeek > 0 {
            cards.append(RetentionInsightCard(
                id: "weekly-check-ins",
                title: "Weekly Check-Ins",
                message: "You checked in \(dayCountText(checkInDaysThisWeek)) this week.",
                detail: "That gives your future self more local data to reflect on.",
                iconName: "calendar.badge.checkmark",
                valueText: "\(checkInDaysThisWeek)"
            ))
        }

        if let trigger = mostCommonTrigger(from: moods) {
            cards.append(RetentionInsightCard(
                id: "common-trigger",
                title: "Common Trigger",
                message: "Your most common trigger was \(trigger.name).",
                detail: "\(trigger.count) check-ins included this tag.",
                iconName: "tag",
                valueText: "\(trigger.count)"
            ))
        }

        let breathingDays = Set(
            breathingSessions
                .map { calendar.startOfDay(for: $0.createdAt) }
                .filter { $0 >= weekStart && $0 <= today }
        ).count
        if breathingDays > 0 {
            cards.append(RetentionInsightCard(
                id: "breathing-days",
                title: "Breathing Practice",
                message: "Breathing was part of \(dayCountText(breathingDays)) this week.",
                detail: "Short practices still count.",
                iconName: "wind",
                valueText: "\(breathingDays)"
            ))
        }

        if let intensity = averageIntensityChange(from: thoughts) {
            cards.append(RetentionInsightCard(
                id: "thought-record-intensity",
                title: "After Reflection",
                message: "Your average intensity after thought records was lower.",
                detail: "Average before \(intensity.before), average after \(intensity.after).",
                iconName: "square.and.pencil",
                valueText: "-\(intensity.delta)"
            ))
        }

        let exercisesThisMonth = exerciseCompletions.filter {
            let day = calendar.startOfDay(for: $0.createdAt)
            return day >= monthStart && day <= today
        }.count
        if exercisesThisMonth > 0 {
            cards.append(RetentionInsightCard(
                id: "monthly-exercises",
                title: "Exercises This Month",
                message: "You completed \(exerciseCountText(exercisesThisMonth)) this month.",
                detail: "Every completed exercise is practice logged locally.",
                iconName: "checkmark.seal",
                valueText: "\(exercisesThisMonth)"
            ))
        }

        if returnedAfterMissedDay(from: allActivityDays, calendar: calendar) {
            cards.append(RetentionInsightCard(
                id: "returned-after-missed-day",
                title: "Returned After A Missed Day",
                message: "You returned after a missed day.",
                detail: "Coming back is part of consistency.",
                iconName: "arrow.uturn.backward.circle",
                valueText: nil
            ))
        }

        let patternUnlocks = makePersonalPatternUnlocks(
            moods: moods,
            checkIns: checkIns,
            thoughts: thoughts,
            exerciseCompletions: exerciseCompletions,
            journalEntries: journalEntries,
            flexibleJournalEntries: flexibleJournalEntries,
            breathingSessions: breathingSessions,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let emptyState = cards.isEmpty ? lowDataMessage(
            activityDayCount: allActivityDays.count,
            hasAnyData: !allActivityDays.isEmpty
        ) : nil

        return RetentionInsightsSnapshot(
            cards: cards,
            patternUnlocks: patternUnlocks,
            emptyStateMessage: emptyState
        )
    }

    private nonisolated static func makePersonalPatternUnlocks(
        moods: [RetentionMoodEvent],
        checkIns: [RetentionDatedEvent],
        thoughts: [RetentionThoughtEvent],
        exerciseCompletions: [RetentionDatedEvent],
        journalEntries: [RetentionDatedEvent],
        flexibleJournalEntries: [RetentionDatedEvent],
        breathingSessions: [RetentionDatedEvent],
        referenceDate: Date,
        calendar: Calendar
    ) -> [PersonalPatternUnlock] {
        let checkInDays = Set(
            (moods.map(\.createdAt) + checkIns.map(\.createdAt))
                .map { calendar.startOfDay(for: $0) }
        ).count
        guard checkInDays >= 3 else {
            return [lockedUnlock(id: "first-pattern", requiredCheckInDays: 3, checkInDays: checkInDays)]
        }

        var unlocks: [PersonalPatternUnlock] = []

        if let trigger = mostCommonTrigger(from: moods), trigger.count >= 2 {
            unlocks.append(PersonalPatternUnlock(
                id: "trigger-repetition",
                title: "First Pattern Unlocked",
                message: "\(trigger.name) has shown up in \(trigger.count) check-ins.",
                detail: "Repeating tags help you see what asks for extra care.",
                iconName: "sparkles",
                requiredCheckInDays: 3,
                isUnlocked: true
            ))
        }

        if checkInDays >= 5, let lowEnergyTrigger = repeatedLowEnergyTrigger(from: moods) {
            unlocks.append(PersonalPatternUnlock(
                id: "low-energy-trigger",
                title: "Energy Pattern",
                message: "\(lowEnergyTrigger.name) shows up often on low-energy days.",
                detail: "\(lowEnergyTrigger.count) low-energy check-ins included this tag.",
                iconName: "battery.25",
                requiredCheckInDays: 5,
                isUnlocked: true
            ))
        }

        let returnCount = breathingReturnCount(
            checkIns: checkIns,
            moods: moods,
            thoughts: thoughts,
            exerciseCompletions: exerciseCompletions,
            journalEntries: journalEntries,
            flexibleJournalEntries: flexibleJournalEntries,
            breathingSessions: breathingSessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        if checkInDays >= 7, returnCount >= 2 {
            unlocks.append(PersonalPatternUnlock(
                id: "breathing-return",
                title: "Return Pattern",
                message: "Breathing helped you return \(countText(returnCount)) this week.",
                detail: "You paired breathing with another check-in or reflection on those days.",
                iconName: "wind",
                requiredCheckInDays: 7,
                isUnlocked: true
            ))
        }

        if checkInDays >= 8, let liftCount = journalMoodLiftCount(
            moods: moods,
            journalEntries: journalEntries,
            flexibleJournalEntries: flexibleJournalEntries
        ), liftCount >= 2 {
            unlocks.append(PersonalPatternUnlock(
                id: "journal-mood-lift",
                title: "Journaling Pattern",
                message: "Your mood tends to lift after journaling.",
                detail: "Mood was higher after \(countText(liftCount)) with journal entries.",
                iconName: "book.pages",
                requiredCheckInDays: 8,
                isUnlocked: true
            ))
        }

        if let next = nextLockedUnlock(after: unlocks, checkInDays: checkInDays) {
            unlocks.append(next)
        }

        return Array(unlocks.prefix(4))
    }

    private nonisolated static func repeatedLowEnergyTrigger(from moods: [RetentionMoodEvent]) -> (name: String, count: Int)? {
        var counts: [String: (name: String, count: Int)] = [:]
        for mood in moods where (mood.energyScore ?? 10) <= 4 {
            var seen = Set<String>()
            for trigger in mood.triggers {
                let trimmed = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
                guard !key.isEmpty, key != "nothing specific", seen.insert(key).inserted else { continue }
                var bucket = counts[key] ?? (name: trimmed.capitalized, count: 0)
                bucket.count += 1
                counts[key] = bucket
            }
        }

        return counts.values
            .filter { $0.count >= 2 }
            .sorted {
                if $0.count == $1.count { return $0.name < $1.name }
                return $0.count > $1.count
            }
            .first
    }

    private nonisolated static func breathingReturnCount(
        checkIns: [RetentionDatedEvent],
        moods: [RetentionMoodEvent],
        thoughts: [RetentionThoughtEvent],
        exerciseCompletions: [RetentionDatedEvent],
        journalEntries: [RetentionDatedEvent],
        flexibleJournalEntries: [RetentionDatedEvent],
        breathingSessions: [RetentionDatedEvent],
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        let today = calendar.startOfDay(for: referenceDate)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let breathingDays = Set(
            breathingSessions
                .map { calendar.startOfDay(for: $0.createdAt) }
                .filter { $0 >= weekStart && $0 <= today }
        )
        let otherActivityDays = Set(
            checkIns.map { calendar.startOfDay(for: $0.createdAt) }
            + moods.map { calendar.startOfDay(for: $0.createdAt) }
            + thoughts.map { calendar.startOfDay(for: $0.createdAt) }
            + exerciseCompletions.map { calendar.startOfDay(for: $0.createdAt) }
            + journalEntries.map { calendar.startOfDay(for: $0.createdAt) }
            + flexibleJournalEntries.map { calendar.startOfDay(for: $0.createdAt) }
        )

        return breathingDays.filter { otherActivityDays.contains($0) }.count
    }

    private nonisolated static func journalMoodLiftCount(
        moods: [RetentionMoodEvent],
        journalEntries: [RetentionDatedEvent],
        flexibleJournalEntries: [RetentionDatedEvent]
    ) -> Int? {
        let journals = (journalEntries + flexibleJournalEntries).map(\.createdAt).sorted()
        guard journals.count >= 2, moods.count >= 4 else { return nil }

        let sortedMoods = moods.sorted { $0.createdAt < $1.createdAt }
        var liftCount = 0

        for journalDate in journals {
            let before = sortedMoods
                .filter { $0.createdAt <= journalDate && journalDate.timeIntervalSince($0.createdAt) <= 24 * 60 * 60 }
                .last
            let after = sortedMoods
                .filter { $0.createdAt > journalDate && $0.createdAt.timeIntervalSince(journalDate) <= 36 * 60 * 60 }
                .first
            if let before, let after, after.moodScore > before.moodScore {
                liftCount += 1
            }
        }

        return liftCount
    }

    private nonisolated static func lockedUnlock(
        id: String,
        requiredCheckInDays: Int,
        checkInDays: Int
    ) -> PersonalPatternUnlock {
        PersonalPatternUnlock(
            id: id,
            title: "Next Pattern",
            message: "\(max(0, requiredCheckInDays - checkInDays)) more check-in \(requiredCheckInDays - checkInDays == 1 ? "day" : "days") to unlock another discovery.",
            detail: "Patterns get more useful as your local history grows.",
            iconName: "lock",
            requiredCheckInDays: requiredCheckInDays,
            isUnlocked: false
        )
    }

    private nonisolated static func nextLockedUnlock(
        after unlocks: [PersonalPatternUnlock],
        checkInDays: Int
    ) -> PersonalPatternUnlock? {
        let thresholds = [3, 5, 7, 8]
        guard let nextThreshold = thresholds.first(where: { $0 > checkInDays }) else {
            return nil
        }
        return lockedUnlock(id: "next-pattern-\(nextThreshold)", requiredCheckInDays: nextThreshold, checkInDays: checkInDays)
    }

    private nonisolated static func mostCommonTrigger(from moods: [RetentionMoodEvent]) -> (name: String, count: Int)? {
        var counts: [String: (name: String, count: Int)] = [:]
        for mood in moods {
            var seen = Set<String>()
            for trigger in mood.triggers {
                let trimmed = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
                guard !key.isEmpty, key != "nothing specific", seen.insert(key).inserted else { continue }
                var bucket = counts[key] ?? (name: trimmed.capitalized, count: 0)
                bucket.count += 1
                counts[key] = bucket
            }
        }

        return counts.values.sorted { first, second in
            if first.count == second.count {
                return first.name < second.name
            }
            return first.count > second.count
        }.first
    }

    private nonisolated static func averageIntensityChange(from thoughts: [RetentionThoughtEvent]) -> (before: Int, after: Int, delta: Int)? {
        let validThoughts = thoughts.filter {
            (0...100).contains($0.intensityBefore) &&
            (0...100).contains($0.intensityAfter) &&
            $0.intensityAfter < $0.intensityBefore
        }
        guard validThoughts.count >= 2 else { return nil }

        let averageBefore = validThoughts.map(\.intensityBefore).reduce(0, +) / validThoughts.count
        let averageAfter = validThoughts.map(\.intensityAfter).reduce(0, +) / validThoughts.count
        guard averageAfter < averageBefore else { return nil }

        return (averageBefore, averageAfter, averageBefore - averageAfter)
    }

    private nonisolated static func returnedAfterMissedDay(from days: Set<Date>, calendar: Calendar) -> Bool {
        let sortedDays = days.sorted()
        guard sortedDays.count >= 2 else { return false }

        for index in 1..<sortedDays.count {
            let previous = sortedDays[index - 1]
            let current = sortedDays[index]
            let gap = calendar.dateComponents([.day], from: previous, to: current).day ?? 0
            if gap > 1 {
                return true
            }
        }

        return false
    }

    private nonisolated static func lowDataMessage(activityDayCount: Int, hasAnyData: Bool) -> String {
        if hasAnyData {
            return "A little more data will unlock progress cards. Try one check-in, breathing session, journal, or exercise this week."
        }
        return RetentionInsightsSnapshot.empty.emptyStateMessage ?? ""
    }

    private nonisolated static func dayCountText(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    private nonisolated static func exerciseCountText(_ count: Int) -> String {
        count == 1 ? "1 exercise" : "\(count) exercises"
    }

    private nonisolated static func countText(_ count: Int) -> String {
        switch count {
        case 1:
            return "once"
        case 2:
            return "twice"
        default:
            return "\(count) times"
        }
    }
}
