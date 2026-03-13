import Foundation
import SwiftUI

struct ScheduleBlockConflictSummary: Hashable {
    let blockID: UUID
    let eventCount: Int
    let overlapMinutes: Int

    var badgeText: String {
        eventCount == 1 ? "1 conflict" : "\(eventCount) conflicts"
    }

    var detailText: String {
        if overlapMinutes > 0 {
            return "\(badgeText) • \(overlapMinutes) min overlap"
        }

        return badgeText
    }
}

struct ScheduleFreeTimeWindow: Hashable, Identifiable {
    let startDate: Date
    let endDate: Date

    var id: String {
        "\(startDate.timeIntervalSinceReferenceDate)-\(endDate.timeIntervalSinceReferenceDate)"
    }

    var durationMinutes: Int {
        max(Int(endDate.timeIntervalSince(startDate) / 60), 0)
    }
}

struct SchedulePlanningGuidanceSnapshot {
    let blockConflictsByID: [UUID: ScheduleBlockConflictSummary]
    let overlappingBlockIDs: Set<UUID>
    let allDayEventCount: Int
    let openWindows: [ScheduleFreeTimeWindow]

    var conflictingBlockCount: Int {
        blockConflictsByID.count
    }

    var overlappingBlockCount: Int {
        overlappingBlockIDs.count
    }

    var bestWindow: ScheduleFreeTimeWindow? {
        openWindows.max { lhs, rhs in
            lhs.durationMinutes < rhs.durationMinutes
        }
    }

    var hasConflicts: Bool {
        !blockConflictsByID.isEmpty
    }

    var hasOverlappingBlocks: Bool {
        !overlappingBlockIDs.isEmpty
    }

    var hasOpenWindows: Bool {
        !openWindows.isEmpty
    }

    static func build(
        for date: Date,
        blocks: [TimeBlock],
        overlappingBlockIDs: Set<UUID>,
        calendarEvents: [TimeCalendarEvent],
        dayStartHour: Int,
        calendar: Calendar
    ) -> SchedulePlanningGuidanceSnapshot {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let planningStart = calendar.date(
            bySettingHour: min(max(dayStartHour, 0), 23),
            minute: 0,
            second: 0,
            of: startOfDay
        ) ?? startOfDay
        let planningInterval = DateInterval(start: planningStart, end: endOfDay)
        let timedEvents = calendarEvents.filter { !$0.isAllDay }
        let allDayEventCount = calendarEvents.filter(\.isAllDay).count

        let conflictEntries: [(UUID, ScheduleBlockConflictSummary)] = blocks.compactMap { block in
                let overlapSegments = timedEvents.compactMap { event in
                    overlapInterval(
                        between: DateInterval(start: block.startDate, end: block.endDate),
                        and: DateInterval(start: event.startDate, end: event.endDate)
                    )
                }

                guard !overlapSegments.isEmpty else {
                    return nil
                }

                let mergedSegments = mergeIntervals(overlapSegments)
                let overlapMinutes = mergedSegments.reduce(into: 0) { partialResult, interval in
                    partialResult += max(Int(interval.duration / 60), 0)
                }

                return (
                    block.id,
                    ScheduleBlockConflictSummary(
                        blockID: block.id,
                        eventCount: overlapSegments.count,
                        overlapMinutes: overlapMinutes
                    )
                )
            }
        let blockConflictsByID = Dictionary(uniqueKeysWithValues: conflictEntries)

        let occupiedIntervals = mergeIntervals(
            blocks.map { DateInterval(start: $0.startDate, end: $0.endDate) } +
            timedEvents.map { DateInterval(start: $0.startDate, end: $0.endDate) }
        )
        let clippedOccupiedIntervals = occupiedIntervals.compactMap {
            clip($0, to: planningInterval)
        }
        let openWindows = freeWindows(
            within: planningInterval,
            occupiedIntervals: clippedOccupiedIntervals,
            minimumDurationMinutes: 15
        )

        return SchedulePlanningGuidanceSnapshot(
            blockConflictsByID: blockConflictsByID,
            overlappingBlockIDs: overlappingBlockIDs,
            allDayEventCount: allDayEventCount,
            openWindows: openWindows
        )
    }
}

struct SchedulePlanningGuidanceView: View {
    let snapshot: SchedulePlanningGuidanceSnapshot
    let onResolveConflicts: (() -> Void)?

    private var primaryWindows: [ScheduleFreeTimeWindow] {
        Array(snapshot.openWindows.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("Planning Guidance", systemImage: "clock.badge.magnifyingglass")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)

                Spacer(minLength: 0)

                if snapshot.hasConflicts {
                    Text("\(snapshot.conflictingBlockCount) block\(snapshot.conflictingBlockCount == 1 ? "" : "s") in conflict")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }

            if snapshot.hasOverlappingBlocks {
                HStack(spacing: 12) {
                    Label(
                        "\(snapshot.overlappingBlockCount) overlapping block\(snapshot.overlappingBlockCount == 1 ? "" : "s")",
                        systemImage: "rectangle.on.rectangle.angled"
                    )
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)

                    Spacer(minLength: 0)

                    if let onResolveConflicts {
                        Button("Resolve Conflicts", action: onResolveConflicts)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.primaryPurple)
                            .controlSize(.small)
                    }
                }
            }

            if snapshot.hasConflicts || snapshot.allDayEventCount > 0 {
                HStack(spacing: 8) {
                    if snapshot.hasConflicts {
                        Label(
                            "\(snapshot.conflictingBlockCount) timed conflict\(snapshot.conflictingBlockCount == 1 ? "" : "s")",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                    }

                    if snapshot.allDayEventCount > 0 {
                        Label(
                            "\(snapshot.allDayEventCount) all-day event\(snapshot.allDayEventCount == 1 ? "" : "s")",
                            systemImage: "sun.max.fill"
                        )
                    }
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
            }

            if let bestWindow = snapshot.bestWindow {
                guidanceCallout(
                    title: "Best available slot",
                    value: bestWindowLabel(for: bestWindow)
                )
            } else {
                guidanceCallout(
                    title: "Best available slot",
                    value: "No open window left in this planning day"
                )
            }

            if !primaryWindows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Open windows")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)

                    ForEach(primaryWindows) { window in
                        HStack(spacing: 8) {
                            Text(windowRangeText(for: window))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.primaryText)

                            Spacer(minLength: 0)

                            Text(durationText(for: window.durationMinutes))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.primaryPurple)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private func guidanceCallout(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.primaryPurple.opacity(0.08))
        )
    }

    private func bestWindowLabel(for window: ScheduleFreeTimeWindow) -> String {
        "\(windowRangeText(for: window)) (\(durationText(for: window.durationMinutes)))"
    }

    private func windowRangeText(for window: ScheduleFreeTimeWindow) -> String {
        let start = window.startDate.formatted(date: .omitted, time: .shortened)
        let end = window.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }

    private func durationText(for minutes: Int) -> String {
        if minutes.isMultiple(of: 60) {
            return "\(minutes / 60)h"
        }

        if minutes > 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return "\(hours)h \(remainder)m"
        }

        return "\(minutes) min"
    }
}

private func overlapInterval(between lhs: DateInterval, and rhs: DateInterval) -> DateInterval? {
    let start = max(lhs.start, rhs.start)
    let end = min(lhs.end, rhs.end)
    return end > start ? DateInterval(start: start, end: end) : nil
}

private func clip(_ interval: DateInterval, to container: DateInterval) -> DateInterval? {
    overlapInterval(between: interval, and: container)
}

private func mergeIntervals(_ intervals: [DateInterval]) -> [DateInterval] {
    guard !intervals.isEmpty else {
        return []
    }

    let sortedIntervals = intervals.sorted { lhs, rhs in
        if lhs.start == rhs.start {
            return lhs.end < rhs.end
        }

        return lhs.start < rhs.start
    }

    var merged: [DateInterval] = [sortedIntervals[0]]

    for interval in sortedIntervals.dropFirst() {
        guard let last = merged.last else {
            merged.append(interval)
            continue
        }

        if interval.start <= last.end {
            merged[merged.count - 1] = DateInterval(
                start: last.start,
                end: max(last.end, interval.end)
            )
        } else {
            merged.append(interval)
        }
    }

    return merged
}

private func freeWindows(
    within planningInterval: DateInterval,
    occupiedIntervals: [DateInterval],
    minimumDurationMinutes: Int
) -> [ScheduleFreeTimeWindow] {
    let mergedOccupiedIntervals = mergeIntervals(occupiedIntervals)
    let minimumDuration = TimeInterval(minimumDurationMinutes * 60)
    var windows: [ScheduleFreeTimeWindow] = []
    var currentStart = planningInterval.start

    for interval in mergedOccupiedIntervals {
        if interval.start > currentStart {
            let window = ScheduleFreeTimeWindow(
                startDate: currentStart,
                endDate: interval.start
            )

            if window.endDate.timeIntervalSince(window.startDate) >= minimumDuration {
                windows.append(window)
            }
        }

        currentStart = max(currentStart, interval.end)
    }

    if planningInterval.end > currentStart {
        let window = ScheduleFreeTimeWindow(
            startDate: currentStart,
            endDate: planningInterval.end
        )

        if window.endDate.timeIntervalSince(window.startDate) >= minimumDuration {
            windows.append(window)
        }
    }

    return windows
}
