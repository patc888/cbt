import Foundation

struct CalendarMoodPatternMoodEvent: Sendable {
    let createdAt: Date
    let moodScore: Int
    let stressScore: Int?
    let sleepQualityScore: Int?
    let triggers: [String]

    init(
        createdAt: Date,
        moodScore: Int,
        stressScore: Int? = nil,
        sleepQualityScore: Int? = nil,
        triggers: [String] = []
    ) {
        self.createdAt = createdAt
        self.moodScore = min(10, max(1, moodScore))
        self.stressScore = stressScore.map { min(10, max(1, $0)) }
        self.sleepQualityScore = sleepQualityScore.map { min(10, max(1, $0)) }
        self.triggers = triggers
    }
}

struct CalendarMoodPatternExerciseEvent: Sendable {
    let createdAt: Date
}

enum CalendarMoodPatternCalculator {
    static func summary(
        moods: [CalendarMoodPatternMoodEvent],
        exerciseCompletions: [CalendarMoodPatternExerciseEvent],
        calendar: Calendar
    ) -> CalendarMoodPatternSummary {
        CalendarMoodPatternSummary(
            moodByWeekday: moodByWeekday(moods: moods, calendar: calendar),
            stressByWeekday: stressByWeekday(moods: moods, calendar: calendar),
            moodByTimeOfDay: moodByTimeOfDay(moods: moods, calendar: calendar),
            triggerFrequencyByDayType: triggerFrequencyByDayType(moods: moods, calendar: calendar),
            sleepQualityVsMood: sleepQualityVsMood(moods: moods),
            exerciseMoodAfterCompletion: exerciseMoodAfterCompletion(
                moods: moods,
                exerciseCompletions: exerciseCompletions,
                calendar: calendar
            )
        )
    }

    static func moodByWeekday(
        moods: [CalendarMoodPatternMoodEvent],
        calendar: Calendar
    ) -> [WeekdayMoodPattern] {
        weekdayAverages(
            values: moods.map { ($0.createdAt, Double($0.moodScore)) },
            calendar: calendar
        )
    }

    static func stressByWeekday(
        moods: [CalendarMoodPatternMoodEvent],
        calendar: Calendar
    ) -> [WeekdayMoodPattern] {
        weekdayAverages(
            values: moods.compactMap { event in
                guard let stressScore = event.stressScore else { return nil }
                return (event.createdAt, Double(stressScore))
            },
            calendar: calendar
        )
    }

    static func moodByTimeOfDay(
        moods: [CalendarMoodPatternMoodEvent],
        calendar: Calendar
    ) -> [TimeOfDayMoodPattern] {
        let timedMoods = moods.filter { hasTimeComponent($0.createdAt, calendar: calendar) }
        let grouped = Dictionary(grouping: timedMoods) { event in
            timeBucket(for: event.createdAt, calendar: calendar)
        }

        return CalendarMoodTimeBucket.allCases.compactMap { bucket in
            guard let events = grouped[bucket], !events.isEmpty else { return nil }
            return TimeOfDayMoodPattern(
                id: bucket,
                bucket: bucket,
                averageMood: average(events.map { Double($0.moodScore) }),
                entryCount: events.count
            )
        }
    }

    static func triggerFrequencyByDayType(
        moods: [CalendarMoodPatternMoodEvent],
        calendar: Calendar
    ) -> [TriggerDayTypePattern] {
        var buckets: [String: (displayName: String, weekday: Int, weekend: Int)] = [:]

        for mood in moods {
            let isWeekend = calendar.isDateInWeekend(mood.createdAt)
            for trigger in uniqueNormalizedLabels(mood.triggers) {
                var bucket = buckets[trigger.key] ?? (displayName: trigger.displayName, weekday: 0, weekend: 0)
                if isWeekend {
                    bucket.weekend += 1
                } else {
                    bucket.weekday += 1
                }
                buckets[trigger.key] = bucket
            }
        }

        return buckets.map { key, bucket in
            TriggerDayTypePattern(
                id: key,
                trigger: bucket.displayName,
                weekdayCount: bucket.weekday,
                weekendCount: bucket.weekend
            )
        }
        .sorted { first, second in
            if first.totalCount == second.totalCount {
                return first.trigger < second.trigger
            }
            return first.totalCount > second.totalCount
        }
        .prefix(5)
        .map { $0 }
    }

    static func sleepQualityVsMood(
        moods: [CalendarMoodPatternMoodEvent]
    ) -> [SleepMoodPattern] {
        let pairs = moods.compactMap { event -> (key: String, label: String, moodScore: Int)? in
            guard let score = event.sleepQualityScore else { return nil }
            switch score {
            case 1...4:
                return ("low", "Low sleep", event.moodScore)
            case 5...7:
                return ("okay", "Okay sleep", event.moodScore)
            default:
                return ("restful", "Restful sleep", event.moodScore)
            }
        }

        let grouped = Dictionary(grouping: pairs) { $0.key }
        let order = ["low", "okay", "restful"]

        return order.compactMap { key in
            guard let values = grouped[key], !values.isEmpty else { return nil }
            return SleepMoodPattern(
                id: key,
                label: values[0].label,
                averageMood: average(values.map { Double($0.moodScore) }),
                entryCount: values.count
            )
        }
    }

    static func exerciseMoodAfterCompletion(
        moods: [CalendarMoodPatternMoodEvent],
        exerciseCompletions: [CalendarMoodPatternExerciseEvent],
        calendar: Calendar
    ) -> ExerciseMoodAfterCompletionPattern {
        guard !exerciseCompletions.isEmpty else { return .empty }

        let sortedMoods = moods.sorted { $0.createdAt < $1.createdAt }
        var matchedMoodDates = Set<Date>()
        var matchedMoodScores: [Double] = []

        for completion in exerciseCompletions.sorted(by: { $0.createdAt < $1.createdAt }) {
            guard let windowEnd = calendar.date(byAdding: .hour, value: 24, to: completion.createdAt),
                  let mood = sortedMoods.first(where: {
                      $0.createdAt >= completion.createdAt && $0.createdAt <= windowEnd
                  })
            else {
                continue
            }

            matchedMoodDates.insert(mood.createdAt)
            matchedMoodScores.append(Double(mood.moodScore))
        }

        let otherMoodScores = sortedMoods
            .filter { !matchedMoodDates.contains($0.createdAt) }
            .map { Double($0.moodScore) }
        let afterAverage = matchedMoodScores.isEmpty ? nil : average(matchedMoodScores)
        let otherAverage = otherMoodScores.isEmpty ? nil : average(otherMoodScores)
        let delta = afterAverage.flatMap { after in
            otherAverage.map { after - $0 }
        }

        return ExerciseMoodAfterCompletionPattern(
            completionCount: exerciseCompletions.count,
            matchedMoodCount: matchedMoodScores.count,
            averageMoodAfterCompletion: afterAverage,
            averageMoodWithoutRecentExercise: otherAverage,
            deltaFromOtherMoodEntries: delta
        )
    }

    private static func weekdayAverages(
        values: [(date: Date, value: Double)],
        calendar: Calendar
    ) -> [WeekdayMoodPattern] {
        let grouped = Dictionary(grouping: values) { calendar.component(.weekday, from: $0.date) }

        return weekdayOrder(calendar: calendar).compactMap { weekday in
            guard let values = grouped[weekday], !values.isEmpty else { return nil }
            return WeekdayMoodPattern(
                id: weekday,
                weekday: weekday,
                label: weekdayLabel(weekday, calendar: calendar),
                averageScore: average(values.map(\.value)),
                entryCount: values.count
            )
        }
    }

    private static func weekdayOrder(calendar: Calendar) -> [Int] {
        let first = calendar.firstWeekday
        return (0..<7).map { offset in
            ((first + offset - 1) % 7) + 1
        }
    }

    private static func weekdayLabel(_ weekday: Int, calendar: Calendar) -> String {
        var symbols = calendar.shortStandaloneWeekdaySymbols
        if symbols.count != 7 {
            symbols = Calendar(identifier: .gregorian).shortStandaloneWeekdaySymbols
        }
        return symbols[max(0, min(weekday - 1, symbols.count - 1))]
    }

    private static func hasTimeComponent(_ date: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        return (components.hour ?? 0) != 0 ||
            (components.minute ?? 0) != 0 ||
            (components.second ?? 0) != 0 ||
            (components.nanosecond ?? 0) != 0
    }

    private static func timeBucket(
        for date: Date,
        calendar: Calendar
    ) -> CalendarMoodTimeBucket {
        switch calendar.component(.hour, from: date) {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }

    private static func uniqueNormalizedLabels(_ values: [String]) -> [(key: String, displayName: String)] {
        var seen = Set<String>()
        var labels: [(key: String, displayName: String)] = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
            guard seen.insert(key).inserted else { continue }
            labels.append((key: key, displayName: trimmed.capitalized))
        }

        return labels
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
