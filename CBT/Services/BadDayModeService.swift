import Foundation

nonisolated enum BadDayModeTrigger: Equatable, Sendable {
    case missedDays(Int)
    case veryLowMood(Int)
    case manual
}

nonisolated struct BadDayModeContext: Equatable, Sendable {
    let shouldShow: Bool
    let trigger: BadDayModeTrigger?
    let missedDays: Int
    let latestMoodScore: Int?
    let latestMoodDate: Date?

    static let inactive = BadDayModeContext(
        shouldShow: false,
        trigger: nil,
        missedDays: 0,
        latestMoodScore: nil,
        latestMoodDate: nil
    )
}

nonisolated enum BadDayModeService {
    static let veryLowMoodThreshold = 2
    static let missedDaysThreshold = 2
    static let restartTodayMoodScore = 5
    static let restartTodayNote = "Restarted today with Bad Day Mode."

    /// Momentum recovery rule: tapping Restart Today records a normal activity for today only.
    /// It never inserts backdated entries and never changes older streak days.
    static func allowsRestartToday(hasActivityToday: Bool) -> Bool {
        !hasActivityToday
    }

    static func context(
        activeDays: Set<Date>,
        latestMoodScore: Int?,
        latestMoodDate: Date? = nil,
        today: Date = Date(),
        calendar: Calendar = .current,
        manual: Bool = false
    ) -> BadDayModeContext {
        let todayStart = calendar.startOfDay(for: today)
        let normalizedDays = Set(activeDays.map { calendar.startOfDay(for: $0) })
        let missedDays = missedDaysSinceLastActivity(
            activeDays: normalizedDays,
            today: todayStart,
            calendar: calendar
        )

        if manual {
            return BadDayModeContext(
                shouldShow: true,
                trigger: .manual,
                missedDays: missedDays,
                latestMoodScore: latestMoodScore,
                latestMoodDate: latestMoodDate
            )
        }

        if missedDays >= missedDaysThreshold {
            return BadDayModeContext(
                shouldShow: true,
                trigger: .missedDays(missedDays),
                missedDays: missedDays,
                latestMoodScore: latestMoodScore,
                latestMoodDate: latestMoodDate
            )
        }

        if let latestMoodScore,
           latestMoodScore <= veryLowMoodThreshold,
           latestMoodDate.map({ calendar.isDate($0, inSameDayAs: todayStart) }) ?? true {
            return BadDayModeContext(
                shouldShow: true,
                trigger: .veryLowMood(latestMoodScore),
                missedDays: missedDays,
                latestMoodScore: latestMoodScore,
                latestMoodDate: latestMoodDate
            )
        }

        return BadDayModeContext(
            shouldShow: false,
            trigger: nil,
            missedDays: missedDays,
            latestMoodScore: latestMoodScore,
            latestMoodDate: latestMoodDate
        )
    }

    static func missedDaysSinceLastActivity(
        activeDays: Set<Date>,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        let pastDays = activeDays
            .map { calendar.startOfDay(for: $0) }
            .filter { $0 < todayStart }

        guard let lastPastDay = pastDays.max() else {
            return activeDays.contains(todayStart) ? 0 : missedDaysThreshold
        }

        let dayGap = calendar.dateComponents([.day], from: lastPastDay, to: todayStart).day ?? 0
        return max(0, dayGap - 1)
    }
}
