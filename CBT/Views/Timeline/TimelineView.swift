import SwiftUI
import SwiftData

struct TimelineView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var showingAddMood = false
    @State private var showingAddThought = false
    @State private var attemptingAddMood = false
    @State private var attemptingAddThought = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ThemedBackground().ignoresSafeArea()

            DeferredRenderView {
                VStack(spacing: 12) {
                    AppScreenHeadline(title: "Timeline")
                        .padding(.horizontal)
                    Spacer()
                }
            } content: {
                TimelineDashboardContent(
                    showingAddMood: $showingAddMood,
                    showingAddThought: $showingAddThought,
                    attemptingAddMood: $attemptingAddMood,
                    attemptingAddThought: $attemptingAddThought
                )
            }
        }
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
                    font: .system(.caption, design: .rounded).weight(.bold),
                    hapticType: .medium
                ) {
                    attemptingAddMood = true
                }
                ListActionPillButton(
                    title: "+ Thought",
                    color: themeManager.secondaryColor,
                    font: .system(.caption, design: .rounded).weight(.bold),
                    hapticType: .medium
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
            TimelineRouteDestinationView(route: route)
        }
    }
}

// MARK: - Subviews

private struct TimelineDashboardContent: View {
    @Binding var showingAddMood: Bool
    @Binding var showingAddThought: Bool
    @Binding var attemptingAddMood: Bool
    @Binding var attemptingAddThought: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var themeManager
    @State private var moodEntries: [MoodEntry] = []
    @State private var thoughtRecords: [ThoughtRecord] = []
    @State private var exerciseCompletions: [ExerciseCompletion] = []
    @State private var journalEntries: [JournalEntry] = []
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
                VStack(spacing: 12) {
                    AppScreenHeadline(title: "Timeline")
                        .padding(.horizontal)

                    Spacer()
                    
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(themeManager.selectedColor.opacity(0.12))
                                .frame(width: 100, height: 100)
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 44, weight: .light))
                                .foregroundStyle(themeManager.selectedColor)
                        }
                        .padding(.bottom, 8)

                        Text("Your Journey Starts Here")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.primaryText)

                        Text("Your timeline will beautifully document your growth, capturing every mood check-in and breakthrough.")
                            .font(.system(.subheadline, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.horizontal, 32)
                            .lineSpacing(4)
                    }

                    VStack(spacing: 16) {
                        Button {
                            HapticManager.shared.lightImpact()
                            attemptingAddMood = true
                        } label: {
                            HStack {
                                Image(systemName: "face.smiling")
                                Text("Log First Mood")
                            }
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(themeManager.selectedColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: themeManager.selectedColor.opacity(0.3), radius: 10, y: 5)
                        }
                        .buttonStyle(.plain)

                        Button {
                            HapticManager.shared.lightImpact()
                            attemptingAddThought = true
                        } label: {
                            HStack {
                                Image(systemName: "brain")
                                Text("New Thought Record")
                            }
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(themeManager.secondaryColor)
                            .background(themeManager.secondaryColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 48)
                    .padding(.top, 24)

                    Spacer()
                }
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                        AppScreenHeadline(title: "Timeline")

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
        // Use a lightweight refresh key so launch-time body evaluation does
        // not walk every queried SwiftData record.
        .task(id: "\(moodEntries.count)|\(thoughtRecords.count)|\(exerciseCompletions.count)|\(journalEntries.count)") {
            await viewModel.update(
                moodEntries: moodEntries,
                thoughtRecords: thoughtRecords,
                exerciseCompletions: exerciseCompletions,
                journalEntries: journalEntries
            )
        }
        .task {
            await refreshFetchedModels()
        }
        .onChange(of: showingAddMood) { _, isPresented in
            guard !isPresented else { return }
            Task { await refreshFetchedModels() }
        }
        .onChange(of: showingAddThought) { _, isPresented in
            guard !isPresented else { return }
            Task { await refreshFetchedModels() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshFetchedModels() }
        }
    }

    @MainActor
    private func refreshFetchedModels() async {
        moodEntries = LaunchSafeFetch.moodEntries(from: modelContext)
        thoughtRecords = LaunchSafeFetch.thoughtRecords(from: modelContext)
        exerciseCompletions = LaunchSafeFetch.exerciseCompletions(from: modelContext)
        journalEntries = LaunchSafeFetch.journalEntries(from: modelContext)
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
}
