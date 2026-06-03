import SwiftUI
import Charts

struct InsightsCalendarPatternsCard: View {
    let summary: CalendarMoodPatternSummary

    @Environment(ThemeManager.self) private var themeManager

    private var hasAnyData: Bool {
        !summary.moodByWeekday.isEmpty ||
            !summary.stressByWeekday.isEmpty ||
            !summary.moodByTimeOfDay.isEmpty ||
            !summary.triggerFrequencyByDayType.isEmpty ||
            !summary.sleepQualityVsMood.isEmpty ||
            summary.exerciseMoodAfterCompletion.averageMoodAfterCompletion != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "Calendar Patterns"))
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(Theme.primaryText)

                Spacer()

                Text(String(localized: "CHECK-INS"))
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            if !hasAnyData {
                Text(String(localized: "Calendar patterns appear after check-ins include mood, stress, sleep, triggers, or completed exercises."))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            } else {
                if summary.moodByWeekday.count >= 2 {
                    weekdayChart(
                        title: String(localized: "Mood By Day"),
                        values: summary.moodByWeekday,
                        color: themeManager.selectedColor,
                        accessibilityLabel: String(localized: "Mood by day of week chart")
                    )
                } else {
                    lowDataRow(
                        icon: "calendar",
                        title: String(localized: "Mood By Day"),
                        message: String(localized: "Add mood check-ins on at least two weekdays to compare days.")
                    )
                }

                if summary.stressByWeekday.count >= 2 {
                    weekdayChart(
                        title: String(localized: "Stress By Day"),
                        values: summary.stressByWeekday,
                        color: themeManager.secondaryColor,
                        accessibilityLabel: String(localized: "Stress by day of week chart")
                    )
                } else {
                    lowDataRow(
                        icon: "calendar.badge.exclamationmark",
                        title: String(localized: "Stress By Day"),
                        message: String(localized: "Stress patterns appear after check-ins include stress ratings on at least two weekdays.")
                    )
                }

                patternRows
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var patternRows: some View {
        VStack(spacing: 10) {
            if summary.moodByTimeOfDay.count >= 2 {
                if let bestTime = summary.moodByTimeOfDay.max(by: { $0.averageMood < $1.averageMood }) {
                    metricRow(
                        icon: "clock",
                        title: String(localized: "Mood By Time"),
                        value: "\(bestTime.bucket.displayName): \(bestTime.averageMood.formatted(.number.precision(.fractionLength(1))))/10",
                        detail: String(localized: "\(bestTime.entryCount) timed check-ins")
                    )
                }
            } else {
                lowDataRow(
                    icon: "clock",
                    title: String(localized: "Mood By Time"),
                    message: String(localized: "Timed mood patterns appear after check-ins with times in at least two parts of the day.")
                )
            }

            if let trigger = summary.triggerFrequencyByDayType.first {
                metricRow(
                    icon: "tag",
                    title: String(localized: "Triggers"),
                    value: trigger.trigger,
                    detail: String(localized: "\(trigger.weekdayCount) weekday, \(trigger.weekendCount) weekend")
                )
            } else {
                lowDataRow(
                    icon: "tag",
                    title: String(localized: "Triggers"),
                    message: String(localized: "Weekday and weekend trigger patterns appear after check-ins include triggers.")
                )
            }

            if summary.sleepQualityVsMood.count >= 2 {
                if let sleep = summary.sleepQualityVsMood.max(by: { $0.averageMood < $1.averageMood }) {
                    metricRow(
                        icon: "bed.double",
                        title: String(localized: "Sleep And Mood"),
                        value: "\(sleep.label): \(sleep.averageMood.formatted(.number.precision(.fractionLength(1))))/10",
                        detail: String(localized: "\(sleep.entryCount) entries")
                    )
                }
            } else {
                lowDataRow(
                    icon: "bed.double",
                    title: String(localized: "Sleep And Mood"),
                    message: String(localized: "Sleep patterns appear after check-ins include sleep quality in at least two ranges.")
                )
            }

            let exercise = summary.exerciseMoodAfterCompletion
            if let average = exercise.averageMoodAfterCompletion, exercise.matchedMoodCount >= 1 {
                metricRow(
                    icon: "figure.walk",
                    title: String(localized: "After Exercises"),
                    value: "\(average.formatted(.number.precision(.fractionLength(1))))/10",
                    detail: exerciseDetail(for: exercise)
                )
            } else {
                lowDataRow(
                    icon: "figure.walk",
                    title: String(localized: "After Exercises"),
                    message: String(localized: "This appears after completed exercises have a mood check-in within 24 hours.")
                )
            }
        }
    }

    private func weekdayChart(
        title: String,
        values: [WeekdayMoodPattern],
        color: Color,
        accessibilityLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            Chart(values) { value in
                BarMark(
                    x: .value(String(localized: "Day"), value.label),
                    y: .value(String(localized: "Average"), value.averageScore)
                )
                .foregroundStyle(color.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .chartYScale(domain: 0...10)
            .chartPlotStyle { plotArea in
                plotArea
                    .background(color.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .frame(height: 140)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private func metricRow(
        icon: String,
        title: String,
        value: String,
        detail: String
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 32, height: 32)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
                Text(value)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            Text(detail)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func exerciseDetail(for exercise: ExerciseMoodAfterCompletionPattern) -> String {
        guard let delta = exercise.deltaFromOtherMoodEntries else {
            return String(localized: "\(exercise.matchedMoodCount) mood entries after \(exercise.completionCount) completions")
        }

        let formattedDelta = abs(delta).formatted(.number.precision(.fractionLength(1)))
        return delta >= 0
            ? String(localized: "+\(formattedDelta) vs other mood entries")
            : String(localized: "-\(formattedDelta) vs other mood entries")
    }

    private func lowDataRow(
        icon: String,
        title: String,
        message: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 32, height: 32)
                .background(Theme.secondaryText.opacity(0.08), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Text(message)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
    }
}
