import SwiftUI
import SwiftData

// MARK: - Sessions List
struct JournalSessionsListView: View {
    @Query(
        sort: \JournalEntry.createdAt,
        order: .reverse
    ) private var entries: [JournalEntry]

    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    private var activeEntries: [JournalEntry] {
        entries.filter { !$0.isDeleted }
    }

    var body: some View {
        if activeEntries.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "book.pages")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.secondaryText)
                Text(String(localized: "No Sessions Yet"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Text(String(localized: "Complete a timed exercise, affirmation, or distortion practice and save it to see entries here."))
                    .font(.system(size: 14, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 32)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(activeEntries) { entry in
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
                .frame(maxWidth: .infinity)
            }
        }
    }
}
