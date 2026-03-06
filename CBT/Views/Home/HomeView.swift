import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selectedTab: FloatingTab

    @Query(filter: #Predicate<MoodEntry> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var moodEntries: [MoodEntry]
    @Query(filter: #Predicate<ThoughtRecord> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var thoughtRecords: [ThoughtRecord]
    @Query(filter: #Predicate<ExerciseCompletion> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var exerciseCompletions: [ExerciseCompletion]
    @Query(filter: #Predicate<JournalEntry> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var journalEntries: [JournalEntry]
    @Environment(ThemeManager.self) private var themeManager

    @State private var selectedDate = Date()
    @State private var showingNewMoodEntry = false
    @State private var showingNewThoughtRecord = false
    @State private var showingTipModal = false
    @State private var showingQuickAdd = false
    @State private var selectedMoodForFlow: MoodColor? = nil

    private enum DailyPlanItem {
        case moodCheckIn
        case thoughtRecord
        case exercises
        case breathingReset
        case insights
        case journal
        case tipOfTheDay
    }

    private struct DailyPlanCompletionSnapshot {
        let moodCheckIn: PlanCardCompletionState
        let thoughtRecord: PlanCardCompletionState
        let exercises: PlanCardCompletionState
        let breathingReset: PlanCardCompletionState
        let insights: PlanCardCompletionState
        let journal: PlanCardCompletionState
        let tipOfTheDay: PlanCardCompletionState

        func state(for item: DailyPlanItem) -> PlanCardCompletionState {
            switch item {
            case .moodCheckIn:
                return moodCheckIn
            case .thoughtRecord:
                return thoughtRecord
            case .exercises:
                return exercises
            case .breathingReset:
                return breathingReset
            case .insights:
                return insights
            case .journal:
                return journal
            case .tipOfTheDay:
                return tipOfTheDay
            }
        }
    }

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekDates = (-180...180).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let completionSnapshot = dailyPlanCompletionSnapshot(calendar: calendar)

        ZStack {
            ThemedBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TopHeadlineView(
                        title: "Daily Plan",
                        subtitle: "Step by step toward balance",
                        alignment: .leading
                    )
                    .padding(.horizontal, 16)

                    WeekStripView(selectedDate: $selectedDate, weekDates: weekDates) { date in
                        hasActivity(on: date)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 16) {
                        PlanCard(
                            title: "Mood Check-In",
                            subtitle: "Capture how you feel right now.",
                            trailingSymbol: "face.smiling",
                            completionState: completionSnapshot.state(for: .moodCheckIn)
                        ) {
                            VStack(spacing: 0) {
                                Divider()
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Start quick check-in")
                                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                                            .foregroundStyle(Theme.primaryText)
                                        Text("Takes about 1 minute")
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

                        PlanCard(
                            title: "Thought Record",
                            subtitle: "Challenge one difficult thought.",
                            trailingSymbol: "brain",
                            completionState: completionSnapshot.state(for: .thoughtRecord)
                        ) {
                            showingNewThoughtRecord = true
                        }

                        PlanCard(
                            title: "Exercises",
                            subtitle: "Practice one CBT tool.",
                            trailingSymbol: "figure.mind.and.body",
                            completionState: completionSnapshot.state(for: .exercises)
                        ) {
                            selectedTab = .exercises
                        }

                        PlanCard(
                            title: "Breathing Reset",
                            subtitle: "Calm your body in 60 seconds",
                            trailingSymbol: "wind",
                            completionState: completionSnapshot.state(for: .breathingReset)
                        ) {
                            BreathingPresenter.shared.present(durationSeconds: 60, autoStart: true)
                        }

                        PlanCard(
                            title: "Insights",
                            subtitle: "Review trends and patterns.",
                            trailingSymbol: "chart.line.uptrend.xyaxis",
                            completionState: completionSnapshot.state(for: .insights)
                        ) {
                            selectedTab = .insights
                        }

                        PlanCard(
                            title: "Journal",
                            subtitle: "Browse mood and thought entries.",
                            trailingSymbol: "book.pages",
                            completionState: completionSnapshot.state(for: .journal)
                        ) {
                            selectedTab = .journal
                        }

                        PlanCard(
                            title: "Tip of the Day",
                            subtitle: "Open a quick CBT reminder.",
                            trailingSymbol: "lightbulb",
                            completionState: completionSnapshot.state(for: .tipOfTheDay)
                        ) {
                            showingTipModal = true
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingNewMoodEntry, onDismiss: { selectedMoodForFlow = nil }) {
            MoodCheckinView(initialMood: selectedMoodForFlow)
        }
        .sheet(isPresented: $showingNewThoughtRecord) {
            NewThoughtRecordFlowView()
        }
        .sheet(isPresented: $showingTipModal) {
            FeatureModalPresenter {
                DSFeatureModal(
                    title: "Tip for Today",
                    subtitle: "Try naming one thought before reacting. Even a short pause can make the next step clearer.",
                    bullets: [
                        DSBullet(icon: "brain", text: "Notice the thought"),
                        DSBullet(icon: "arrow.triangle.2.circlepath", text: "Check for alternatives"),
                        DSBullet(icon: "checkmark.circle", text: "Choose a small next action")
                    ],
                    primaryTitle: "Got it",
                    primaryAction: {
                        HapticManager.shared.lightImpact()
                        showingTipModal = false
                    },
                    secondaryTitle: "Close",
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
        .confirmationDialog("Quick Add", isPresented: $showingQuickAdd, titleVisibility: .visible) {
            Button("Mood Check-In") {
                showingNewMoodEntry = true
            }
            Button("Thought Record") {
                showingNewThoughtRecord = true
            }
            Button("Breathing Reset") {
                BreathingPresenter.shared.present(durationSeconds: 60, autoStart: true)
            }
            Button("Exercise") {
                selectedTab = .exercises
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func hasActivity(on date: Date) -> Bool {
        let calendar = Calendar.current

        if moodEntries.contains(where: { calendar.isDate($0.createdAt, inSameDayAs: date) }) {
            return true
        }
        if thoughtRecords.contains(where: { calendar.isDate($0.createdAt, inSameDayAs: date) }) {
            return true
        }
        if exerciseCompletions.contains(where: { calendar.isDate($0.createdAt, inSameDayAs: date) }) {
            return true
        }
        return false
    }

    private func dailyPlanCompletionSnapshot(calendar: Calendar) -> DailyPlanCompletionSnapshot {
        let selectedDay = calendar.startOfDay(for: selectedDate)

        let moodDays = Set(moodEntries.map { calendar.startOfDay(for: $0.createdAt) })
        let thoughtRecordDays = Set(thoughtRecords.map { calendar.startOfDay(for: $0.createdAt) })
        let exerciseDays = Set(exerciseCompletions.map { calendar.startOfDay(for: $0.createdAt) })
        let breathingDays = Set(
            journalEntries
                .filter { $0.sourceKind == SessionSourceKind.breathing.rawValue }
                .map { calendar.startOfDay(for: $0.createdAt) }
        )

        return DailyPlanCompletionSnapshot(
            moodCheckIn: moodDays.contains(selectedDay) ? .completed : .incomplete,
            thoughtRecord: thoughtRecordDays.contains(selectedDay) ? .completed : .incomplete,
            exercises: exerciseDays.contains(selectedDay) ? .completed : .incomplete,
            breathingReset: breathingDays.contains(selectedDay) ? .completed : .incomplete,
            insights: .notTracked,
            journal: .notTracked,
            tipOfTheDay: .notTracked
        )
    }
}
