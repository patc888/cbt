import SwiftUI
import WidgetKit

private struct WidgetRetentionSnapshot: Codable, Equatable {
    static let appGroupIdentifier = "group.com.melichan.CBT"
    static let defaultsKey = "cbt.widget.retentionSnapshot.v1"

    var generatedAt: Date
    var hasActivity: Bool
    var hasActivityToday: Bool
    var currentStreak: Int
    var weeklyActivityCount: Int
    var weeklyCheckInCount: Int
    var weeklyPracticeCount: Int
    var lastActivityKind: String?

    static let empty = WidgetRetentionSnapshot(
        generatedAt: Date.distantPast,
        hasActivity: false,
        hasActivityToday: false,
        currentStreak: 0,
        weeklyActivityCount: 0,
        weeklyCheckInCount: 0,
        weeklyPracticeCount: 0,
        lastActivityKind: nil
    )

    static func load() -> WidgetRetentionSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: defaultsKey),
              let snapshot = try? JSONDecoder().decode(WidgetRetentionSnapshot.self, from: data)
        else {
            return .empty
        }
        return snapshot
    }
}

private enum CBTWidgetLink {
    static let home = URL(string: "cbt://morningIntentions")!
    static let checkIn = URL(string: "cbt://moodCheckIn")!
    static let journal = URL(string: "cbt://journal")!
    static let practice = URL(string: "cbt://courseContinuation")!
    static let weekly = URL(string: "cbt://weeklyReport")!

    static func continueURL(for kind: String?) -> URL {
        switch kind {
        case "journal":
            return journal
        case "breathing", "practice", "thought record", "activity":
            return practice
        case "check-in", "mood":
            return checkIn
        default:
            return home
        }
    }
}

private enum CBTWidgetKind: String, CaseIterable {
    case tinyWin = "TinyWinWidget"
    case dailyCheckIn = "DailyCheckInWidget"
    case momentum = "MomentumWidget"
    case continueFlow = "ContinueWidget"
    case weeklyProgress = "WeeklyProgressWidget"

    var title: String {
        switch self {
        case .tinyWin: return "Today's Tiny Win"
        case .dailyCheckIn: return "Daily Check-In"
        case .momentum: return "Momentum"
        case .continueFlow: return "Continue"
        case .weeklyProgress: return "Weekly Progress"
        }
    }

    var description: String {
        switch self {
        case .tinyWin: return "A privacy-safe supportive nudge."
        case .dailyCheckIn: return "A gentle shortcut into your mood check-in."
        case .momentum: return "See your current streak without private details."
        case .continueFlow: return "Return to a safe next step."
        case .weeklyProgress: return "A small weekly activity summary."
        }
    }

    func url(for snapshot: WidgetRetentionSnapshot) -> URL {
        switch self {
        case .tinyWin, .dailyCheckIn, .momentum:
            return CBTWidgetLink.checkIn
        case .continueFlow:
            return CBTWidgetLink.continueURL(for: snapshot.lastActivityKind)
        case .weeklyProgress:
            return CBTWidgetLink.weekly
        }
    }
}

private struct RetentionEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetRetentionSnapshot
}

private struct RetentionProvider: TimelineProvider {
    func placeholder(in context: Context) -> RetentionEntry {
        RetentionEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (RetentionEntry) -> Void) {
        completion(RetentionEntry(date: Date(), snapshot: WidgetRetentionSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RetentionEntry>) -> Void) {
        let entry = RetentionEntry(date: Date(), snapshot: WidgetRetentionSnapshot.load())
        completion(Timeline(entries: [entry], policy: .after(nextRefreshDate(after: entry.date))))
    }

    private func nextRefreshDate(after date: Date) -> Date {
        Calendar.current.date(byAdding: .hour, value: 4, to: date)
            ?? Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date))
            ?? date
    }
}

private struct RetentionWidgetView: View {
    let entry: RetentionEntry
    let kind: CBTWidgetKind

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularLockScreen
            case .accessoryInline:
                inlineLockScreen
            case .accessoryRectangular:
                rectangularLockScreen
            case .systemMedium:
                mediumHomeScreen
            default:
                smallHomeScreen
            }
        }
        .widgetURL(kind.url(for: entry.snapshot))
    }

    private var smallHomeScreen: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Spacer(minLength: 0)

            Text(primaryText)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .lineLimit(3)
                .minimumScaleFactor(0.7)

            Text(secondaryText)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)
            ctaLabel
        }
        .padding(16)
    }

    private var mediumHomeScreen: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 9) {
                header

                Text(primaryText)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(secondaryText)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.cbtAccent)
                    .accessibilityHidden(true)

                Spacer(minLength: 0)

                privacyPill
                ctaLabel
            }
        }
        .padding(18)
    }

    private var rectangularLockScreen: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(lockTitle)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .lineLimit(1)
                Text(lockSubtitle)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .lineLimit(1)
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    private var circularLockScreen: some View {
        Gauge(value: gaugeValue) {
            Image(systemName: systemImage)
        } currentValueLabel: {
            Text(circularValue)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.7)
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var inlineLockScreen: some View {
        Label(lockInlineText, systemImage: systemImage)
    }

    private var header: some View {
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

    private var ctaLabel: some View {
        HStack(spacing: 5) {
            Text(callToAction)
            Image(systemName: "arrow.right.circle.fill")
                .imageScale(.medium)
                .accessibilityHidden(true)
        }
        .font(.system(.caption, design: .rounded).weight(.bold))
        .foregroundStyle(Color.cbtAccent)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var privacyPill: some View {
        Label("Private", systemImage: "lock.fill")
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var primaryText: String {
        switch kind {
        case .tinyWin:
            return entry.snapshot.hasActivityToday ? "You showed up today." : "One tiny win is enough."
        case .dailyCheckIn:
            return "How are you feeling today?"
        case .momentum:
            return entry.snapshot.currentStreak > 0 ? "\(entry.snapshot.currentStreak) day momentum" : "Start today's momentum"
        case .continueFlow:
            return entry.snapshot.hasActivity ? "Continue where you left off" : "Begin with one gentle step"
        case .weeklyProgress:
            return entry.snapshot.weeklyActivityCount > 0 ? "\(entry.snapshot.weeklyActivityCount) moments this week" : "Build this week's progress"
        }
    }

    private var secondaryText: String {
        switch kind {
        case .tinyWin:
            return "Small counts. Start private."
        case .dailyCheckIn:
            return "A private check-in is one tap away."
        case .momentum:
            return entry.snapshot.currentStreak > 0 ? "Keep it light. Keep it going." : "A short check-in starts it."
        case .continueFlow:
            return "No details shown here."
        case .weeklyProgress:
            return "\(entry.snapshot.weeklyCheckInCount) check-ins, \(entry.snapshot.weeklyPracticeCount) practices."
        }
    }

    private var callToAction: String {
        switch kind {
        case .dailyCheckIn, .tinyWin, .momentum:
            return "Check in"
        case .continueFlow:
            return "Continue"
        case .weeklyProgress:
            return "Review"
        }
    }

    private var systemImage: String {
        switch kind {
        case .tinyWin:
            return "sparkle"
        case .dailyCheckIn:
            return "heart.text.square.fill"
        case .momentum:
            return "flame.fill"
        case .continueFlow:
            return "arrow.forward.circle.fill"
        case .weeklyProgress:
            return "chart.bar.fill"
        }
    }

    private var lockTitle: String {
        switch kind {
        case .tinyWin:
            return entry.snapshot.hasActivityToday ? "Tiny win done" : "Tiny win"
        case .dailyCheckIn:
            return "Daily check-in"
        case .momentum:
            return entry.snapshot.currentStreak > 0 ? "\(entry.snapshot.currentStreak) day streak" : "Start gently"
        case .continueFlow:
            return "Continue"
        case .weeklyProgress:
            return "\(entry.snapshot.weeklyActivityCount) this week"
        }
    }

    private var lockSubtitle: String {
        switch kind {
        case .tinyWin:
            return "One step helps"
        case .dailyCheckIn:
            return "Private shortcut"
        case .momentum:
            return "Momentum"
        case .continueFlow:
            return "No private text"
        case .weeklyProgress:
            return "Private summary"
        }
    }

    private var lockInlineText: String {
        switch kind {
        case .tinyWin:
            return entry.snapshot.hasActivityToday ? "Tiny win done" : "Tiny win"
        case .dailyCheckIn:
            return "Daily check-in"
        case .momentum:
            return entry.snapshot.currentStreak > 0 ? "\(entry.snapshot.currentStreak) day streak" : "Start gently"
        case .continueFlow:
            return "Continue privately"
        case .weeklyProgress:
            return "\(entry.snapshot.weeklyActivityCount) this week"
        }
    }

    private var circularValue: String {
        switch kind {
        case .momentum:
            return "\(entry.snapshot.currentStreak)"
        case .weeklyProgress:
            return "\(entry.snapshot.weeklyActivityCount)"
        default:
            return entry.snapshot.hasActivityToday ? "OK" : "Go"
        }
    }

    private var gaugeValue: Double {
        switch kind {
        case .momentum:
            return min(1, Double(entry.snapshot.currentStreak) / 7)
        case .weeklyProgress:
            return min(1, Double(entry.snapshot.weeklyActivityCount) / 7)
        default:
            return entry.snapshot.hasActivityToday ? 1 : 0.2
        }
    }
}

private struct RetentionWidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            colorScheme == .dark
                ? Color(red: 0.05, green: 0.06, blue: 0.07)
                : Color(red: 0.98, green: 0.98, blue: 0.97)

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
}

private func retentionConfiguration(for kind: CBTWidgetKind) -> some WidgetConfiguration {
    StaticConfiguration(kind: kind.rawValue, provider: RetentionProvider()) { entry in
        RetentionWidgetView(entry: entry, kind: kind)
            .containerBackground(for: .widget) {
                RetentionWidgetBackground()
            }
    }
    .configurationDisplayName(kind.title)
    .description(kind.description)
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryInline, .accessoryRectangular])
}

private struct TinyWinWidget: Widget {
    var body: some WidgetConfiguration {
        retentionConfiguration(for: .tinyWin)
    }
}

private struct DailyCheckInWidget: Widget {
    var body: some WidgetConfiguration {
        retentionConfiguration(for: .dailyCheckIn)
    }
}

private struct MomentumWidget: Widget {
    var body: some WidgetConfiguration {
        retentionConfiguration(for: .momentum)
    }
}

private struct ContinueWidget: Widget {
    var body: some WidgetConfiguration {
        retentionConfiguration(for: .continueFlow)
    }
}

private struct WeeklyProgressWidget: Widget {
    var body: some WidgetConfiguration {
        retentionConfiguration(for: .weeklyProgress)
    }
}

private extension Color {
    static let cbtAccent = Color(red: 50 / 255, green: 173 / 255, blue: 230 / 255)
    static let cbtAccentDeep = Color(red: 0 / 255, green: 113 / 255, blue: 164 / 255)
}

@main
struct CBTWidgets: WidgetBundle {
    var body: some Widget {
        TinyWinWidget()
        DailyCheckInWidget()
        MomentumWidget()
        ContinueWidget()
        WeeklyProgressWidget()
    }
}

#Preview(as: .systemSmall) {
    TinyWinWidget()
} timeline: {
    RetentionEntry(date: Date(), snapshot: .empty)
}

#Preview(as: .accessoryRectangular) {
    WeeklyProgressWidget()
} timeline: {
    RetentionEntry(date: Date(), snapshot: .empty)
}
