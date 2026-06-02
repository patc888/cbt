import SwiftUI
import WidgetKit

private enum DailyCheckInDeepLink {
    static let moodCheckIn = URL(string: "cbt://moodCheckIn")!
}

struct DailyCheckInEntry: TimelineEntry {
    let date: Date
}

struct DailyCheckInProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyCheckInEntry {
        DailyCheckInEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyCheckInEntry) -> Void) {
        completion(DailyCheckInEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyCheckInEntry>) -> Void) {
        let entry = DailyCheckInEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .after(nextRefreshDate(after: entry.date))))
    }

    private func nextRefreshDate(after date: Date) -> Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? calendar.date(byAdding: .hour, value: 6, to: date)
            ?? date
    }
}

struct DailyCheckInWidgetEntryView: View {
    let entry: DailyCheckInEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumLayout
            default:
                smallLayout
            }
        }
        .widgetURL(DailyCheckInDeepLink.moodCheckIn)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            brandHeader

            Spacer(minLength: 2)

            Text("How are you feeling today?")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .minimumScaleFactor(0.74)

            Spacer(minLength: 2)

            ctaLabel(title: "Check in")
        }
        .padding(16)
    }

    private var mediumLayout: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                brandHeader

                Text("How are you feeling today?")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)

                Text("A private daily check-in is one tap away.")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 10) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.cbtAccent)
                    .accessibilityHidden(true)

                Spacer(minLength: 0)

                Label("Private", systemImage: "lock.fill")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)

                ctaLabel(title: "Open")
            }
        }
        .padding(18)
    }

    private var brandHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.cbtAccent)
                .accessibilityHidden(true)

            Text("CBT")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }

    private func ctaLabel(title: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
            Image(systemName: "arrow.right.circle.fill")
                .imageScale(.medium)
                .accessibilityHidden(true)
        }
        .font(.system(.caption, design: .rounded).weight(.bold))
        .foregroundStyle(Color.cbtAccent)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

private struct DailyCheckInWidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            baseColor

            LinearGradient(
                colors: [
                    Color.cbtAccent.opacity(colorScheme == .dark ? 0.28 : 0.16),
                    Color.cbtAccentDeep.opacity(colorScheme == .dark ? 0.16 : 0.08),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var baseColor: Color {
        colorScheme == .dark
            ? Color(red: 0.05, green: 0.06, blue: 0.07)
            : Color(red: 0.98, green: 0.98, blue: 0.97)
    }
}

private extension Color {
    static let cbtAccent = Color(red: 50 / 255, green: 173 / 255, blue: 230 / 255)
    static let cbtAccentDeep = Color(red: 0 / 255, green: 113 / 255, blue: 164 / 255)
}

struct DailyCheckInWidget: Widget {
    let kind = "DailyCheckInWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyCheckInProvider()) { entry in
            DailyCheckInWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    DailyCheckInWidgetBackground()
                }
        }
        .configurationDisplayName("Daily Check-In")
        .description("A gentle shortcut into your mood check-in.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct CBTWidgets: WidgetBundle {
    var body: some Widget {
        DailyCheckInWidget()
    }
}

#Preview(as: .systemSmall) {
    DailyCheckInWidget()
} timeline: {
    DailyCheckInEntry(date: Date())
}

#Preview(as: .systemMedium) {
    DailyCheckInWidget()
} timeline: {
    DailyCheckInEntry(date: Date())
}
