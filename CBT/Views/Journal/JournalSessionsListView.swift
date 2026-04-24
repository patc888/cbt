import SwiftUI
import SwiftData

// MARK: - Sessions List
struct JournalSessionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @State private var entries: [JournalEntry] = []

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }



    var body: some View {
        Group {
            if entries.isEmpty {
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
                        ForEach(entries) { entry in
                            NavigationLink(value: TimelineRoute.journal(entry.persistentModelID)) {
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
        .task {
            await refreshEntries()
        }
    }

    @MainActor
    private func refreshEntries() async {
        entries = LaunchSafeFetch.journalEntries(from: modelContext)
    }
}
