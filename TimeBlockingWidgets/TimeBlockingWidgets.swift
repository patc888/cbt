import SwiftUI
import WidgetKit

struct TimeBlockingWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: TimeBlockingWidgetSnapshot
}

struct TimeBlockingWidgetProvider: TimelineProvider {
    private let store = TimeBlockingWidgetSnapshotStore()

    func placeholder(in context: Context) -> TimeBlockingWidgetEntry {
        TimeBlockingWidgetEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (TimeBlockingWidgetEntry) -> Void) {
        completion(makeEntry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimeBlockingWidgetEntry>) -> Void) {
        let entryDate = Date.now
        let entry = makeEntry(for: entryDate)
        let refreshDate = entry.snapshot.recommendedRefreshDate(from: entryDate)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func makeEntry(for date: Date) -> TimeBlockingWidgetEntry {
        let snapshot = store.load() ?? .empty(now: date)
        return TimeBlockingWidgetEntry(date: date, snapshot: snapshot)
    }
}

struct NextBlockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextBlockWidget", provider: TimeBlockingWidgetProvider()) { entry in
            NextBlockWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Block")
        .description("Shows the next upcoming planned block.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodaySummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodaySummaryWidget", provider: TimeBlockingWidgetProvider()) { entry in
            TodaySummaryWidgetView(entry: entry)
        }
        .configurationDisplayName("Today Summary")
        .description("Shows today's planned, completed, and scheduled totals.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct NextBlockWidgetView: View {
    let entry: TimeBlockingWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let block = entry.snapshot.nextBlock(at: entry.date) {
                VStack(alignment: .leading, spacing: 10) {
                    widgetHeader(title: "Next Block", systemImage: "calendar.badge.clock")

                    Text(block.title)
                        .font(.system(size: family == .systemSmall ? 16 : 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(family == .systemSmall ? 3 : 2)

                    Text(block.categoryTitle.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(block.startDate, style: .time)
                            .font(.system(size: family == .systemSmall ? 20 : 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text(timeRangeText(for: block))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                EmptyWidgetStateView(
                    title: "No Upcoming Block",
                    message: "Your next planned block will appear here."
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            WidgetBackground()
        }
    }

    private func timeRangeText(for block: TimeBlockingWidgetBlockSnapshot) -> String {
        "\(block.startDate.formatted(date: .omitted, time: .shortened)) - \(block.endDate.formatted(date: .omitted, time: .shortened))"
    }
}

private struct TodaySummaryWidgetView: View {
    let entry: TimeBlockingWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let summary = entry.snapshot.summaryForCurrentDay(at: entry.date), !summary.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    widgetHeader(title: "Today Summary", systemImage: "chart.bar.fill")

                    if family == .systemSmall {
                        VStack(alignment: .leading, spacing: 10) {
                            metricValue(label: "Planned", value: "\(summary.plannedCount)")
                            metricValue(label: "Completed", value: "\(summary.completedCount)")
                            metricValue(label: "Minutes", value: "\(summary.scheduledMinutes)")
                        }
                    } else {
                        HStack(spacing: 12) {
                            summaryMetric(label: "Planned", value: "\(summary.plannedCount)")
                            summaryMetric(label: "Completed", value: "\(summary.completedCount)")
                            summaryMetric(label: "Minutes", value: "\(summary.scheduledMinutes)")
                        }
                    }

                    Spacer(minLength: 0)
                }
            } else {
                EmptyWidgetStateView(
                    title: "Nothing Scheduled",
                    message: "Today's totals will appear after you add blocks."
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            WidgetBackground()
        }
    }

    private func summaryMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func metricValue(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

private struct EmptyWidgetStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetHeader(title: title, systemImage: "sparkles.rectangle.stack")

            Spacer(minLength: 0)

            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.98, blue: 1.0),
                Color(red: 0.90, green: 0.94, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 90, height: 90)
                .offset(x: 24, y: -24)
        }
    }
}

private func widgetHeader(title: String, systemImage: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.blue)

        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

private extension TimeBlockingWidgetSnapshot {
    static var preview: TimeBlockingWidgetSnapshot {
        let now = Date.now
        return TimeBlockingWidgetSnapshot(
            generatedAt: now,
            referenceDay: Calendar.current.startOfDay(for: now),
            upcomingBlocks: [
                TimeBlockingWidgetBlockSnapshot(
                    title: "Focus Work",
                    categoryTitle: "Focus",
                    startDate: now.addingTimeInterval(1800),
                    endDate: now.addingTimeInterval(5400)
                ),
                TimeBlockingWidgetBlockSnapshot(
                    title: "Lunch Break",
                    categoryTitle: "Personal",
                    startDate: now.addingTimeInterval(7200),
                    endDate: now.addingTimeInterval(10800)
                )
            ],
            todaySummary: TimeBlockingWidgetTodaySummarySnapshot(
                plannedCount: 4,
                completedCount: 1,
                scheduledMinutes: 225
            )
        )
    }
}

#Preview(as: .systemSmall) {
    NextBlockWidget()
} timeline: {
    TimeBlockingWidgetEntry(date: .now, snapshot: .preview)
}

#Preview(as: .systemMedium) {
    TodaySummaryWidget()
} timeline: {
    TimeBlockingWidgetEntry(date: .now, snapshot: .preview)
}
