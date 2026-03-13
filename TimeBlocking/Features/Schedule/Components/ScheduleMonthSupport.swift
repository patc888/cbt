import Foundation

struct MonthlyPlanningDay: Identifiable {
    let date: Date
    let snapshot: ScheduleDaySnapshot
    let isInDisplayedMonth: Bool

    var id: Date { date }

    var totalBlockCount: Int {
        snapshot.blocks.count
    }

    var completionFraction: Double {
        guard totalBlockCount > 0 else {
            return 0
        }

        return Double(snapshot.completedCount) / Double(totalBlockCount)
    }
}

struct ScheduleMonthSummary {
    let plannedCount: Int
    let completedCount: Int
    let scheduledMinutes: Int
    let activeDayCount: Int
    let busiestDayLabel: String
    let monthLabel: String

    var hasBlocks: Bool {
        activeDayCount > 0
    }

    var scheduledTimeText: String {
        if scheduledMinutes == 0 {
            return "0 min"
        }

        if scheduledMinutes.isMultiple(of: 60) {
            return "\(scheduledMinutes / 60)h"
        }

        return "\(scheduledMinutes) min"
    }

    init(days: [MonthlyPlanningDay], calendar: Calendar) {
        let inMonthDays = days.filter(\.isInDisplayedMonth)

        plannedCount = inMonthDays.reduce(0) { $0 + $1.snapshot.plannedCount }
        completedCount = inMonthDays.reduce(0) { $0 + $1.snapshot.completedCount }
        scheduledMinutes = inMonthDays.reduce(0) { $0 + $1.snapshot.scheduledMinutes }
        activeDayCount = inMonthDays.filter { !$0.snapshot.blocks.isEmpty }.count

        if let busiestDay = inMonthDays.max(by: { $0.snapshot.scheduledMinutes < $1.snapshot.scheduledMinutes }),
           busiestDay.snapshot.scheduledMinutes > 0 {
            busiestDayLabel = busiestDay.date.formatted(.dateTime.month(.abbreviated).day())
        } else {
            busiestDayLabel = "Rest"
        }

        if let firstDate = inMonthDays.first?.date {
            monthLabel = firstDate.formatted(.dateTime.month(.wide).year())
        } else {
            monthLabel = "This Month"
        }
    }
}

enum ScheduleMonthSupport {
    static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components).map(calendar.startOfDay(for:)) ?? calendar.startOfDay(for: date)
    }

    static func shiftedMonth(for date: Date, by offset: Int, calendar: Calendar) -> Date {
        let monthStart = startOfMonth(for: date, calendar: calendar)
        return calendar.date(byAdding: .month, value: offset, to: monthStart) ?? monthStart
    }

    static func gridDates(for monthContaining: Date, calendar: Calendar) -> [Date] {
        let monthStart = startOfMonth(for: monthContaining, calendar: calendar)
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: monthStart),
            let firstWeekInterval = calendar.dateInterval(of: .weekOfYear, for: monthStart),
            let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
            let lastWeekInterval = calendar.dateInterval(of: .weekOfYear, for: lastDayOfMonth)
        else {
            return [monthStart]
        }

        let gridStart = calendar.startOfDay(for: firstWeekInterval.start)
        let gridEnd = lastWeekInterval.end

        var dates: [Date] = []
        var currentDate = gridStart

        while currentDate < gridEnd {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? gridEnd
        }

        while dates.count < 42, let lastDate = dates.last {
            let nextDate = calendar.date(byAdding: .day, value: 1, to: lastDate) ?? lastDate
            dates.append(nextDate)
        }

        return dates
    }

    static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let startIndex = max(0, min(calendar.firstWeekday - 1, symbols.count - 1))

        return Array(symbols[startIndex...]) + symbols[..<startIndex]
    }
}
