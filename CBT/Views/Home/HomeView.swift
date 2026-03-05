import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selectedTab: FloatingTab

    @Query(filter: #Predicate<MoodEntry> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var moodEntries: [MoodEntry]
    @Query(filter: #Predicate<ThoughtRecord> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var thoughtRecords: [ThoughtRecord]
    @Query(filter: #Predicate<ExerciseCompletion> { $0.isDeleted == false }, sort: \.createdAt, order: .reverse) private var exerciseCompletions: [ExerciseCompletion]

    @State private var selectedDate = Date()
    @State private var selectedSection: HomeSection = .plan
    @State private var showingNewMoodEntry = false
    @State private var showingNewThoughtRecord = false
    @State private var showingTipModal = false
    @State private var showingQuickAdd = false
    @State private var isMoodPickerExpanded = false
    @State private var selectedMoodForFlow: MoodColor? = nil

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekDates = (-180...180).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }

        ZStack {
            Theme.secondaryBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 16)


                SegmentedToggle(
                    selection: $selectedSection,
                    options: HomeSection.allCases,
                    titleKey: \.rawValue
                )
                .padding(.horizontal, 16)

                if selectedSection == .plan {
                    WeekStripView(selectedDate: $selectedDate, weekDates: weekDates) { date in
                        hasActivity(on: date)
                    }
                    .frame(height: 90)
                    .padding(.top, 8)
                    planContent
                } else {
                    TimelineView()
                }
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
                    title: "CBT Tip",
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
        .overlay(alignment: .bottomTrailing) {
            MoodFABPicker(isExpanded: $isMoodPickerExpanded) { mood in
                selectedMoodForFlow = mood
                showingNewMoodEntry = true
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack {
            Spacer()

            Text("CBT")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)

            Spacer()
        }
    }

    private var planContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Today's Plan")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .padding(.bottom, 4)

                PlanCard(
                    title: "Mood Check-In",
                    subtitle: "Capture how you feel right now.",
                    trailingSymbol: "face.smiling"
                ) {
                    VStack(spacing: 0) {
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start quick check-in")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.primaryText)
                                Text("Takes about 1 minute")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                            }

                            Spacer()

                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.primaryColor)
                        }
                        .padding(.top, 12)
                    }
                } action: {
                    showingNewMoodEntry = true
                }

                PlanCard(
                    title: "Thought Record",
                    subtitle: "Challenge one difficult thought.",
                    trailingSymbol: "brain"
                ) {
                    showingNewThoughtRecord = true
                }

                PlanCard(
                    title: "Exercises",
                    subtitle: "Practice one CBT tool.",
                    trailingSymbol: "figure.mind.and.body"
                ) {
                    selectedTab = .exercises
                }

                PlanCard(
                    title: "Breathing Reset",
                    subtitle: "Calm your body in 60 seconds",
                    trailingSymbol: "wind"
                ) {
                    BreathingPresenter.shared.present(durationSeconds: 60, autoStart: true)
                }

                PlanCard(
                    title: "Insights",
                    subtitle: "Review trends and patterns.",
                    trailingSymbol: "chart.line.uptrend.xyaxis"
                ) {
                    selectedTab = .insights
                }

                PlanCard(
                    title: "Journal",
                    subtitle: "Browse mood and thought entries.",
                    trailingSymbol: "book.pages"
                ) {
                    selectedTab = .journal
                }

                PlanCard(
                    title: "Tip of the Day",
                    subtitle: "Open a quick CBT reminder.",
                    trailingSymbol: "lightbulb"
                ) {
                    showingTipModal = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 12)
            .responsiveMaxWidth()
            .frame(maxWidth: .infinity)
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
}

private enum HomeSection: String, CaseIterable, Identifiable {
    case plan = "Plan"
    case activity = "Activity"

    var id: String { rawValue }
}
