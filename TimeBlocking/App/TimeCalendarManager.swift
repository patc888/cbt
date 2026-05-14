import EventKit
import Foundation
import Observation

enum TimeCalendarAccessState: String {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unsupported
    case insufficientAccess
}

struct TimeCalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let sourceTitle: String
}

struct TimeCalendarDaySummary: Equatable {
    let totalCount: Int
    let timedCount: Int
    let busyMinutes: Int
    let hasAllDayEvent: Bool

    static let empty = TimeCalendarDaySummary(
        totalCount: 0,
        timedCount: 0,
        busyMinutes: 0,
        hasAllDayEvent: false
    )

    var hasEvents: Bool {
        totalCount > 0
    }
}

@MainActor
@Observable
final class TimeCalendarManager {
    private let eventStore: EKEventStore

    private(set) var accessState: TimeCalendarAccessState
    private(set) var events: [TimeCalendarEvent] = []
    private(set) var loadedInterval: DateInterval?
    private(set) var isLoading = false
    private(set) var isRequestingAccess = false
    private(set) var lastErrorMessage: String?

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
        self.accessState = Self.currentAccessState()
    }

    func refreshAuthorizationStatus() {
        let refreshedState = Self.currentAccessState()
        accessState = refreshedState

        if refreshedState != .authorized {
            clearEvents(resetError: false)
        }
    }

    func requestAccess() async {
        guard accessState == .notDetermined else {
            refreshAuthorizationStatus()
            return
        }

        isRequestingAccess = true
        lastErrorMessage = nil
        defer { isRequestingAccess = false }

        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            accessState = granted ? .authorized : .denied

            if !granted {
                clearEvents(resetError: false)
            }
        } catch {
            accessState = Self.currentAccessState()
            clearEvents(resetError: false)
            lastErrorMessage = "Calendar access could not be completed."
        }
    }

    func loadEvents(in interval: DateInterval) async {
        refreshAuthorizationStatus()

        guard accessState == .authorized else {
            return
        }

        if loadedInterval == interval {
            return
        }

        isLoading = true
        defer { isLoading = false }

        let predicate = eventStore.predicateForEvents(
            withStart: interval.start,
            end: interval.end,
            calendars: nil
        )

        let loadedEvents = eventStore.events(matching: predicate)
            .sorted {
                if $0.startDate == $1.startDate {
                    return $0.endDate < $1.endDate
                }

                return $0.startDate < $1.startDate
            }
            .map(Self.map)

        events = loadedEvents
        loadedInterval = interval
        lastErrorMessage = nil
    }

    func clearLoadedRange() {
        clearEvents(resetError: true)
    }

    func events(on date: Date, calendar: Calendar) -> [TimeCalendarEvent] {
        let dayInterval = dayInterval(for: date, calendar: calendar)
        return events
            .filter { event in
                event.endDate > dayInterval.start && event.startDate < dayInterval.end
            }
            .sorted(by: eventSort(lhs:rhs:))
    }

    func summary(for date: Date, calendar: Calendar) -> TimeCalendarDaySummary {
        let dayInterval = dayInterval(for: date, calendar: calendar)
        let overlappingEvents = events(on: date, calendar: calendar)

        guard !overlappingEvents.isEmpty else {
            return .empty
        }

        let busyMinutes = overlappingEvents.reduce(into: 0) { partialResult, event in
            guard !event.isAllDay else {
                return
            }

            let clippedStart = max(event.startDate, dayInterval.start)
            let clippedEnd = min(event.endDate, dayInterval.end)

            guard clippedEnd > clippedStart else {
                return
            }

            partialResult += Int(clippedEnd.timeIntervalSince(clippedStart) / 60)
        }

        return TimeCalendarDaySummary(
            totalCount: overlappingEvents.count,
            timedCount: overlappingEvents.filter { !$0.isAllDay }.count,
            busyMinutes: busyMinutes,
            hasAllDayEvent: overlappingEvents.contains(where: \.isAllDay)
        )
    }

    private func clearEvents(resetError: Bool) {
        events = []
        loadedInterval = nil

        if resetError {
            lastErrorMessage = nil
        }
    }

    private func dayInterval(for date: Date, calendar: Calendar) -> DateInterval {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        return DateInterval(start: startOfDay, end: endOfDay)
    }

    private static func currentAccessState() -> TimeCalendarAccessState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            return .authorized
        case .writeOnly:
            return .insufficientAccess
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .unsupported
        }
    }

    private static func map(_ event: EKEvent) -> TimeCalendarEvent {
        let identifierPrefix = event.eventIdentifier ?? event.calendarItemIdentifier
        let stableOccurrenceKey = Int(event.startDate.timeIntervalSinceReferenceDate)

        return TimeCalendarEvent(
            id: "\(identifierPrefix)-\(stableOccurrenceKey)",
            title: event.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Untitled Event",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            location: event.location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            notes: event.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            sourceTitle: event.calendar.title
        )
    }

    private func eventSort(lhs: TimeCalendarEvent, rhs: TimeCalendarEvent) -> Bool {
        if lhs.isAllDay != rhs.isAllDay {
            return lhs.isAllDay && !rhs.isAllDay
        }

        if lhs.startDate == rhs.startDate {
            return lhs.endDate < rhs.endDate
        }

        return lhs.startDate < rhs.startDate
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
