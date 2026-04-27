import SwiftUI

struct WeeklyConsistencyCard: View {
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?

    let moodEntries: [MoodEntry]
    let thoughtRecords: [ThoughtRecord]
    let exerciseCompletions: [ExerciseCompletion]

    private var tintColor: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    private var weekInterval: DateInterval {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())
        ?? DateInterval(start: Calendar.current.startOfDay(for: Date()), duration: 7 * 24 * 60 * 60)
    }

    private func isInCurrentWeek(_ date: Date) -> Bool {
        weekInterval.contains(date)
    }

    private var activeDaysSet: Set<Date> {
        let moodDays = moodEntries
            .filter { isInCurrentWeek($0.createdAt) }
            .map { Calendar.current.startOfDay(for: $0.createdAt) }

        let thoughtDays = thoughtRecords
            .filter { isInCurrentWeek($0.createdAt) }
            .map { Calendar.current.startOfDay(for: $0.createdAt) }

        let exerciseDays = exerciseCompletions
            .filter { isInCurrentWeek($0.createdAt) }
            .map { Calendar.current.startOfDay(for: $0.createdAt) }

        return Set(moodDays + thoughtDays + exerciseDays)
    }

    private var activeDays: Int {
        activeDaysSet.count
    }

    private var progress: Double {
        Double(activeDays) / 7.0
    }

    private var statusText: String {
        switch activeDays {
        case 0:
            return "Start today"
        case 1...3:
            return "Building"
        case 4...6:
            return "Strong"
        default:
            return "Perfect week"
        }
    }

    private var overallActivityDays: Set<Date> {
        let moodDays = moodEntries.map { Calendar.current.startOfDay(for: $0.createdAt) }
        let thoughtDays = thoughtRecords.map { Calendar.current.startOfDay(for: $0.createdAt) }
        let exerciseDays = exerciseCompletions.map { Calendar.current.startOfDay(for: $0.createdAt) }
        return Set(moodDays + thoughtDays + exerciseDays)
    }

    private var streakDays: Int {
        guard !overallActivityDays.isEmpty else { return 0 }
        var current = Calendar.current.startOfDay(for: Date())
        var streak = 0

        while overallActivityDays.contains(current) {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: current) else { break }
            current = previous
        }

        return streak
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Weekly Consistency")
                .font(.headline)

            VStack(spacing: 10) {
                ProgressRing(progress: progress, lineWidth: 14, accentColor: tintColor) {
                    VStack(spacing: 4) {
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("THIS WEEK")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 170, height: 170)

                Text("\(activeDays) of 7 days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemFill))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)

            MetricCardGrid {
                MetricCard(
                    icon: "calendar",
                    title: "Active Days",
                    value: "\(activeDays) / 7"
                )

                MetricCard(
                    icon: "flame",
                    title: "Streak",
                    value: "\(streakDays)",
                    subtitle: streakDays == 1 ? "day" : "days"
                )
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
        .tint(tintColor)
    }
}
