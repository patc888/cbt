import SwiftUI
import SwiftData
import OSLog

struct HomeView: View {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CBT", category: "HomeView")
    @Binding var selectedTab: FloatingTab
    @Environment(ThemeManager.self) private var themeManager

    @State private var selectedDate = Date()
    @State private var showingNewMoodEntry = false
    @State private var showingNewThoughtRecord = false
    @State private var attemptingNewMoodEntry = false
    @State private var attemptingNewThoughtRecord = false
    @State private var showingTipModal = false
    @State private var selectedMoodForFlow: MoodColor? = nil
    @State private var isDashboardReady = false
    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TopHeadlineView(
                        title: String(localized: "Daily Plan"),
                        subtitle: String(localized: "Step by step toward balance"),
                        alignment: .leading
                    )
                    .padding(.horizontal, 16)

                    if isDashboardReady {
                        HomeDashboardContent(
                            selectedTab: $selectedTab,
                            selectedDate: $selectedDate,
                            showingNewMoodEntry: $showingNewMoodEntry,
                            showingNewThoughtRecord: $showingNewThoughtRecord,
                            attemptingNewMoodEntry: $attemptingNewMoodEntry,
                            attemptingNewThoughtRecord: $attemptingNewThoughtRecord,
                            showingTipModal: $showingTipModal,
                            selectedMoodForFlow: $selectedMoodForFlow
                        )
                    } else {
                        HomeDashboardPlaceholder()
                    }
                }
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("home-scroll-view")
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-screen")
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear {
            Self.logger.info("HomeView mounted")
        }
        .task {
            guard !isDashboardReady else { return }
            // Keep the first HomeView render SwiftData-free, then
            // construct the query-backed dashboard only after the
            // root model container, NavigationStack, and TabView have
            // all settled on iPad's regular-width launch path.
            await Task.yield()
            guard !Task.isCancelled else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            isDashboardReady = true
        }
        .onKeyPress(".") {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                toggleManualItems()
            }
            return .handled
        }
        .sheet(isPresented: $showingNewMoodEntry, onDismiss: { selectedMoodForFlow = nil }) {
            MoodCheckinView(initialMood: selectedMoodForFlow)
        }
        .sheet(isPresented: $showingNewThoughtRecord) {
            NewThoughtRecordFlowView()
        }
    }

    private func toggleManualItems() {
        // Delegated to HomeDashboardContent via ViewModel if needed
    }
}

private struct HomeDashboardPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HomeDashboardSkeleton()
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
        }
    }
}

// MARK: - Subviews

struct HomeDashboardContent: View {
    private struct RefreshKey: Equatable {
        let selectedDay: Date
        let moodCount: Int
        let thoughtCount: Int
        let completionCount: Int
        let journalCount: Int
    }

    @Binding var selectedTab: FloatingTab
    @Binding var selectedDate: Date
    @Binding var showingNewMoodEntry: Bool
    @Binding var showingNewThoughtRecord: Bool
    @Binding var attemptingNewMoodEntry: Bool
    @Binding var attemptingNewThoughtRecord: Bool
    @Binding var showingTipModal: Bool
    @Binding var selectedMoodForFlow: MoodColor?

    @Query(filter: #Predicate<MoodEntry> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var moodEntries: [MoodEntry]
    @Query(filter: #Predicate<ThoughtRecord> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var thoughtRecords: [ThoughtRecord]
    @Query(filter: #Predicate<ExerciseCompletion> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var exerciseCompletions: [ExerciseCompletion]
    @Query(filter: #Predicate<JournalEntry> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var journalEntries: [JournalEntry]
    @Environment(ThemeManager.self) private var themeManager

    @State private var viewModel = HomeDashboardViewModel()

    private var refreshKey: RefreshKey {
        RefreshKey(
            selectedDay: Calendar.current.startOfDay(for: selectedDate),
            moodCount: moodEntries.count,
            thoughtCount: thoughtRecords.count,
            completionCount: exerciseCompletions.count,
            journalCount: journalEntries.count
        )
    }

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekDates = (-180...180).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }

        VStack(alignment: .leading, spacing: 16) {
            WeekStripView(selectedDate: $selectedDate, weekDates: weekDates) { date in
                viewModel.activeDates.contains(calendar.startOfDay(for: date))
            }
            .padding(.top, 8)
            .opacity(viewModel.isInitialized ? 1 : 0.6)

            VStack(alignment: .leading, spacing: 16) {
                if !viewModel.isInitialized {
                    HomeDashboardSkeleton()
                } else {
                    PlanCard(
                        title: String(localized: "Mood Check-In"),
                        subtitle: String(localized: "Capture how you feel right now."),
                        trailingSymbol: "face.smiling",
                        completionState: viewModel.completionSnapshot.state(for: .moodCheckIn)
                    ) {
                        VStack(spacing: 0) {
                            Divider()
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(localized: "Start quick check-in"))
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundStyle(Theme.primaryText)
                                    Text(String(localized: "Takes about 1 minute"))
                                        .font(.system(.caption, design: .rounded).weight(.medium))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(themeManager.selectedColor)
                            }
                            .padding(.top, 12)
                        }
                    } action: {
                        showingNewMoodEntry = true
                    }
                    .accessibilityIdentifier("home-plan-mood-check-in")

                    PlanCard(
                        title: String(localized: "Thought Record"),
                        subtitle: String(localized: "Challenge one difficult thought."),
                        trailingSymbol: "brain",
                        completionState: viewModel.completionSnapshot.state(for: .thoughtRecord)
                    ) {
                        showingNewThoughtRecord = true
                    }

                    PlanCard(
                        title: String(localized: "Exercises"),
                        subtitle: String(localized: "Practice one CBT tool."),
                        trailingSymbol: "figure.mind.and.body",
                        completionState: viewModel.completionSnapshot.state(for: .exercises)
                    ) {
                        selectedTab = .exercises
                    }

                    PlanCard(
                        title: String(localized: "Breathing Reset"),
                        subtitle: String(localized: "Calm your body in 60 seconds"),
                        trailingSymbol: "wind",
                        completionState: viewModel.completionSnapshot.state(for: .breathingReset)
                    ) {
                        BreathingPresenter.shared.present(
                            durationSeconds: 60,
                            autoStart: true,
                            onComplete: {
                                withAnimation {
                                    viewModel.markItemAsDone(.breathingReset, for: selectedDate)
                                }
                            }
                        )
                    }

                    PlanCard(
                        title: String(localized: "Tip of the Day"),
                        subtitle: String(localized: "Open a quick CBT reminder."),
                        trailingSymbol: "lightbulb",
                        completionState: viewModel.completionSnapshot.state(for: .tipOfTheDay)
                    ) {
                        showingTipModal = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showingTipModal, onDismiss: { 
            withAnimation {
                viewModel.markItemAsDone(.tipOfTheDay, for: selectedDate)
            }
        }) {
            FeatureModalPresenter {
                DSFeatureModal(
                    title: String(localized: "Tip for Today"),
                    subtitle: String(localized: "Try naming one thought before reacting. Even a short pause can make the next step clearer."),
                    bullets: [
                        DSBullet(icon: "brain", text: String(localized: "Notice the thought")),
                        DSBullet(icon: "arrow.triangle.2.circlepath", text: String(localized: "Check for alternatives")),
                        DSBullet(icon: "checkmark.circle", text: String(localized: "Choose a small next action"))
                    ],
                    primaryTitle: String(localized: "Got it"),
                    primaryAction: {
                        HapticManager.shared.lightImpact()
                        showingTipModal = false
                    },
                    secondaryTitle: String(localized: "Close"),
                    secondaryAction: {
                        HapticManager.shared.lightImpact()
                        showingTipModal = false
                    },
                    closeAction: {
                        HapticManager.shared.lightImpact()
                        showingTipModal = false
                    }
                )
            }
        }
        .task(id: refreshKey) { await updateData() }
    }

    private func updateData() async {
        await viewModel.update(
            selectedDate: selectedDate,
            moodEntries: moodEntries,
            thoughtRecords: thoughtRecords,
            exerciseCompletions: exerciseCompletions,
            journalEntries: journalEntries
        )
    }
}

private struct HomeDashboardSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 100)
            }
        }
    }
}
