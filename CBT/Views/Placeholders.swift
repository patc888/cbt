import SwiftUI
import SwiftData


struct JournalView: View {
    enum JournalTab: String, CaseIterable, Identifiable {
        case mood = "Mood"
        case thoughts = "Thoughts"
        case sessions = "Sessions"

        var id: String { rawValue }

        var subtitle: String {
            switch self {
            case .mood:
                return "Quick check-ins to track your emotional patterns."
            case .thoughts:
                return "Capture situations and reframe automatic thoughts."
            case .sessions:
                return "Timed practice sessions from exercises and tools."
            }
        }

        var icon: String {
            switch self {
            case .mood:
                return "face.smiling"
            case .thoughts:
                return "brain.head.profile"
            case .sessions:
                return "book.pages"
            }
        }
    }
    @State private var selectedTab: JournalTab = .mood
    
    var body: some View {
        ZStack {
            Theme.secondaryBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    TopHeadlineView(
                        title: "Journal",
                        subtitle: "Track mood and thoughts in one place"
                    )

                    SegmentedToggle(
                        selection: $selectedTab,
                        options: JournalTab.allCases,
                        titleKey: \.rawValue
                    )

                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: selectedTab.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.primaryColor)
                        Text(selectedTab.subtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.secondaryText.opacity(0.12), lineWidth: 0.8)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)

                switch selectedTab {
                case .mood:
                    MoodListView()
                case .thoughts:
                    ThoughtRecordListView()
                case .sessions:
                    JournalSessionsListView()
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Sessions List
struct JournalSessionsListView: View {
    @Query(
        filter: #Predicate<JournalEntry> { !$0.isDeleted },
        sort: \JournalEntry.createdAt,
        order: .reverse
    ) private var entries: [JournalEntry]

    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    var body: some View {
        if entries.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "book.pages")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.secondaryText)
                Text("No Sessions Yet")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Text("Complete a timed exercise, affirmation, or distortion practice and save it to see entries here.")
                    .font(.system(size: 14, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 32)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(entries) { entry in
                        NavigationLink(value: TimelineRoute.journal(entry)) {
                            JournalSessionRow(entry: entry, accent: accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 16)
                .responsiveMaxWidth()
            }
        }
    }
}

struct JournalSessionRow: View {
    let entry: JournalEntry
    let accent: Color

    private var sourceKind: SessionSourceKind? {
        guard let kind = entry.sourceKind else { return nil }
        return SessionSourceKind(rawValue: kind)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: sourceKind?.iconName ?? "book.pages")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(entry.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.secondaryText)
                }

                HStack(spacing: 8) {
                    if let kind = sourceKind {
                        Text(kind.displayName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(accent)
                    }
                    if let secs = entry.durationSeconds, secs > 0 {
                        Text(formattedDuration(secs))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func formattedDuration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let r = seconds % 60
        return r > 0 ? "\(m)m \(r)s" : "\(m)m"
    }
}
