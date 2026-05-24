import SwiftUI
import SwiftData

// MARK: - Sessions List
struct JournalSessionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?
    @State private var entries: [JournalEntry] = []

    private var accent: Color {
        themeManager?.selectedColor ?? .accentColor
    }



    var body: some View {
        Group {
            if entries.isEmpty {
                SupportiveEmptyStateView(
                    systemImage: "book.pages",
                    title: String(localized: "Saved Sessions"),
                    message: String(localized: "Saved sessions keep notes from timed practices, exercises, and calming tools in one private place."),
                    actionTitle: String(localized: "Start Breathing Reset"),
                    actionSystemImage: "wind"
                ) {
                    HapticManager.shared.lightImpact()
                    BreathingPresenter.shared.present(durationSeconds: 60, autoStart: true)
                }
                .padding(.horizontal, 24)
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
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshEntries() }
        }
    }

    @MainActor
    private func refreshEntries() async {
        entries = LaunchSafeFetch.journalEntries(from: modelContext)
    }
}
