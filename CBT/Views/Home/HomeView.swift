import SwiftUI
import SwiftData
import OSLog

struct HomeView: View {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "CBT", category: "HomeView")
    @Binding var selectedTab: FloatingTab
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.scenePhase) private var scenePhase

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
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            guard !isDashboardReady else { return }
            // Keep the first HomeView render SwiftData-free, then
            // construct the query-backed dashboard only after the
            // root model container, NavigationStack, and TabView have
            // all settled on the first active launch pass.
            await Task.yield()
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(250))
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
    private static let dashboardWeekDates: [Date] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-180...180).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }()

    @Binding var selectedTab: FloatingTab
    @Binding var selectedDate: Date
    @Binding var showingNewMoodEntry: Bool
    @Binding var showingNewThoughtRecord: Bool
    @Binding var attemptingNewMoodEntry: Bool
    @Binding var attemptingNewThoughtRecord: Bool
    @Binding var showingTipModal: Bool
    @Binding var selectedMoodForFlow: MoodColor?

    @Environment(ThemeManager.self) private var themeManager
    @Query(
        sort: \MoodEntry.createdAt,
        order: .reverse
    )
    private var moodEntries: [MoodEntry]
    @Query(
        sort: \ThoughtRecord.createdAt,
        order: .reverse
    )
    private var thoughtRecords: [ThoughtRecord]
    @Query(
        sort: \ExerciseCompletion.createdAt,
        order: .reverse
    )
    private var exerciseCompletions: [ExerciseCompletion]
    @Query(
        sort: \JournalEntry.createdAt,
        order: .reverse
    )
    private var journalEntries: [JournalEntry]

    @State private var viewModel = HomeDashboardViewModel()

    private var activeMoodEntries: [MoodEntry] {
        moodEntries.filter { !$0.isDeleted }
    }

    private var activeThoughtRecords: [ThoughtRecord] {
        thoughtRecords.filter { !$0.isDeleted }
    }

    private var activeExerciseCompletions: [ExerciseCompletion] {
        exerciseCompletions.filter { !$0.isDeleted }
    }

    private var activeJournalEntries: [JournalEntry] {
        journalEntries.filter { !$0.isDeleted }
    }

    init(
        selectedTab: Binding<FloatingTab>,
        selectedDate: Binding<Date>,
        showingNewMoodEntry: Binding<Bool>,
        showingNewThoughtRecord: Binding<Bool>,
        attemptingNewMoodEntry: Binding<Bool>,
        attemptingNewThoughtRecord: Binding<Bool>,
        showingTipModal: Binding<Bool>,
        selectedMoodForFlow: Binding<MoodColor?>
    ) {
        self._selectedTab = selectedTab
        self._selectedDate = selectedDate
        self._showingNewMoodEntry = showingNewMoodEntry
        self._showingNewThoughtRecord = showingNewThoughtRecord
        self._attemptingNewMoodEntry = attemptingNewMoodEntry
        self._attemptingNewThoughtRecord = attemptingNewThoughtRecord
        self._showingTipModal = showingTipModal
        self._selectedMoodForFlow = selectedMoodForFlow
    }

    var body: some View {
        let calendar = Calendar.current

        VStack(alignment: .leading, spacing: 16) {
            WeekStripView(selectedDate: $selectedDate, weekDates: Self.dashboardWeekDates) { date in
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
        .task(id: refreshSignature) {
            await refreshDashboardSnapshot()
        }
        .onAppear {
            if !viewModel.isInitialized {
                viewModel.isInitialized = true
            }
        }
    }

    private var refreshSignature: String {
        let selectedDay = Calendar.current.startOfDay(for: selectedDate).timeIntervalSinceReferenceDate
        return [
            String(selectedDay),
            signature(for: activeMoodEntries.map(\.createdAt)),
            signature(for: activeThoughtRecords.map(\.createdAt)),
            signature(for: activeExerciseCompletions.map(\.createdAt)),
            signature(for: activeJournalEntries.map(\.createdAt))
        ].joined(separator: "|")
    }

    @MainActor
    private func refreshDashboardSnapshot() async {
        await viewModel.update(
            selectedDate: selectedDate,
            moodEntries: activeMoodEntries,
            thoughtRecords: activeThoughtRecords,
            exerciseCompletions: activeExerciseCompletions,
            journalEntries: activeJournalEntries
        )
    }

    private func signature(for dates: [Date]) -> String {
        let latest = dates.first?.timeIntervalSinceReferenceDate ?? 0
        let earliest = dates.last?.timeIntervalSinceReferenceDate ?? 0
        return "\(dates.count):\(latest):\(earliest)"
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
