import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var showingAddMood = false
    @State private var showingAddThought = false
    @State private var attemptingAddMood = false
    @State private var attemptingAddThought = false
    @State private var isDashboardReady = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ThemedBackground().ignoresSafeArea()
            
            
            if isDashboardReady {
                TimelineDashboardContent(
                    showingAddMood: $showingAddMood,
                    showingAddThought: $showingAddThought,
                    attemptingAddMood: $attemptingAddMood,
                    attemptingAddThought: $attemptingAddThought
                )
            } else {
                VStack {
                    TopHeadlineView(title: "Timeline")
                        .padding(.horizontal)
                    Spacer()
                }
            }
        }

// moved to TimelineDashboardContent
        .navigationTitle("")
        #if os(iOS) && !targetEnvironment(macCatalyst)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()
                ListActionPillButton(
                    title: "+ Mood",
                    color: themeManager.selectedColor,
                    font: .system(.caption, design: .rounded).weight(.bold)
                ) {
                    attemptingAddMood = true
                }
                ListActionPillButton(
                    title: "+ Thought",
                    color: themeManager.secondaryColor,
                    font: .system(.caption, design: .rounded).weight(.bold)
                ) {
                    attemptingAddThought = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showingAddMood) {
            MoodCheckinView()
        }
        .sheet(isPresented: $showingAddThought) {
            NewThoughtRecordFlowView()
        }
        .withUsageGate(isAttemptingAction: $attemptingAddMood) {
            showingAddMood = true
        }
        .withUsageGate(isAttemptingAction: $attemptingAddThought) {
            showingAddThought = true
        }
        .navigationDestination(for: TimelineRoute.self) { route in
            switch route {
            case .mood(let entry):
                MoodDetailView(entry: entry)
            case .thought(let record):
                ThoughtRecordDetailView(record: record)
            case .exercise(let exerciseID):
                if let exercise = ExerciseLibrary.shared.exercise(withID: exerciseID) {
                    ExerciseDetailView(exercise: exercise)
                } else {
                    ContentUnavailableView(
                        "Exercise Not Found",
                        systemImage: "exclamationmark.triangle",
                        description: Text("This exercise is no longer available.")
                    )
                }
            case .journal(let entry):
                JournalEntryDetailView(entry: entry)
            }
        }
        .task {
            guard !isDashboardReady else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            isDashboardReady = true
        }
    }
}

// MARK: - Subviews

struct TimelineDashboardContent: View {
    @Binding var showingAddMood: Bool
    @Binding var showingAddThought: Bool
    @Binding var attemptingAddMood: Bool
    @Binding var attemptingAddThought: Bool

    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \MoodEntry.createdAt, order: .reverse) private var moodEntries: [MoodEntry]
    @Query(sort: \ThoughtRecord.createdAt, order: .reverse) private var thoughtRecords: [ThoughtRecord]
    @Query(sort: \ExerciseCompletion.createdAt, order: .reverse) private var exerciseCompletions: [ExerciseCompletion]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var journalEntries: [JournalEntry]
    @State private var viewModel = TimelineViewModel()

    init(
        showingAddMood: Binding<Bool>,
        showingAddThought: Binding<Bool>,
        attemptingAddMood: Binding<Bool>,
        attemptingAddThought: Binding<Bool>
    ) {
        self._showingAddMood = showingAddMood
        self._showingAddThought = showingAddThought
        self._attemptingAddMood = attemptingAddMood
        self._attemptingAddThought = attemptingAddThought
    }

    var body: some View {
        Group {
            if viewModel.isInitialized && viewModel.groupedItems.isEmpty {
                VStack(spacing: 20) {
                    TopHeadlineView(title: "Timeline")
                        .padding(.horizontal)

                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.secondaryText)

                    Text("No Activity Yet")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)

                    Text("Your timeline will show your mood check-ins, thought records, and completed exercises.")
                        .font(.system(.subheadline, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        Button {
                            HapticManager.shared.lightImpact()
                            attemptingAddMood = true
                        } label: {
                            Label("Log Mood", systemImage: "face.smiling")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .frame(maxWidth: 220)
                                .padding(.vertical, 10)
                                .foregroundStyle(.white)
                                .background(themeManager.selectedColor)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            HapticManager.shared.lightImpact()
                            attemptingAddThought = true
                        } label: {
                            Label("New Thought Record", systemImage: "brain")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .frame(maxWidth: 220)
                                .padding(.vertical, 10)
                                .foregroundStyle(.white)
                                .background(themeManager.secondaryColor)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 16)

                    Spacer()
                }
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                        TopHeadlineView(title: "Timeline")

                        ForEach(viewModel.groupedItems, id: \.key) { date, items in
                            Section {
                                ForEach(items) { item in
                                    if let route = item.route {
                                        NavigationLink(value: route) {
                                            TimelineRow(item: item)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        TimelineRow(item: item)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(formatHeaderDate(date))
                                        .font(.system(.caption, design: .rounded).weight(.bold))
                                        .foregroundColor(Theme.secondaryText)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                                .background(ThemedBackground())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .responsiveMaxWidth()
                    .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
                }
            }
        }
        .task(id: refreshSignature) {
            await viewModel.update(
                moodEntries: moodEntries,
                thoughtRecords: thoughtRecords,
                exerciseCompletions: exerciseCompletions,
                journalEntries: journalEntries
            )
        }
    }

    private func formatHeaderDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private var refreshSignature: String {
        [
            signature(for: moodEntries),
            signature(for: thoughtRecords),
            signature(for: exerciseCompletions),
            signature(for: journalEntries)
        ].joined(separator: "|")
    }

    private func signature(for entries: [MoodEntry]) -> String {
        let activeEntries = entries.filter { !$0.isDeleted }
        let latest = activeEntries.first?.createdAt.timeIntervalSinceReferenceDate ?? 0
        let earliest = activeEntries.last?.createdAt.timeIntervalSinceReferenceDate ?? 0
        return "\(activeEntries.count):\(latest):\(earliest)"
    }

    private func signature(for entries: [ThoughtRecord]) -> String {
        let activeEntries = entries.filter { !$0.isDeleted }
        let latest = activeEntries.first?.createdAt.timeIntervalSinceReferenceDate ?? 0
        let earliest = activeEntries.last?.createdAt.timeIntervalSinceReferenceDate ?? 0
        return "\(activeEntries.count):\(latest):\(earliest)"
    }

    private func signature(for entries: [ExerciseCompletion]) -> String {
        let activeEntries = entries.filter { !$0.isDeleted }
        let latest = activeEntries.first?.createdAt.timeIntervalSinceReferenceDate ?? 0
        let earliest = activeEntries.last?.createdAt.timeIntervalSinceReferenceDate ?? 0
        return "\(activeEntries.count):\(latest):\(earliest)"
    }

    private func signature(for entries: [JournalEntry]) -> String {
        let activeEntries = entries.filter { !$0.isDeleted }
        let latest = activeEntries.first?.createdAt.timeIntervalSinceReferenceDate ?? 0
        let earliest = activeEntries.last?.createdAt.timeIntervalSinceReferenceDate ?? 0
        return "\(activeEntries.count):\(latest):\(earliest)"
    }
}
