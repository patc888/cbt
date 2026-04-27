import Foundation

enum TrendsRange: String, CaseIterable, Identifiable {
    case sevenDays = "7D"
    case thirtyDays = "30D"
    case ninetyDays = "90D"
    case all = "All"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .sevenDays:
            return 7
        case .thirtyDays:
            return 30
        case .ninetyDays:
            return 90
        case .all:
            return nil
        }
    }
}

enum DateBucketing {
    static func startDate(for range: TrendsRange, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let days = range.days else { return nil }
        return calendar.date(byAdding: .day, value: -days, to: now)
    }

    static func filtered<T>(
        _ items: [T],
        by range: TrendsRange,
        date: (T) -> Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [T] {
        guard let start = startDate(for: range, now: now, calendar: calendar) else {
            return items
        }
        return items.filter { date($0) >= start }
    }
}
