import SwiftUI
import SwiftData
import OSLog

struct HomeView: View {
    private static let logger = AppLogger.make(category: "HomeView")
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
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                DeferredRenderView(
                    isEnabled: scenePhase == .active,
                    delay: .milliseconds(250)
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        AppScreenHeadline(title: String(localized: "Daily Plan"))
                        .padding(.horizontal, 16)

                        HomeDashboardPlaceholder()
                    }
                } content: {
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
        }
        .onAppear {
            Self.logger.info("HomeView mounted")
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

private struct HomeDashboardContent: View {
    private struct DashboardRefreshToken: Equatable {
        let day: Date
        let nonce: Int
    }

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

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var themeManager
    @State private var viewModel = HomeDashboardViewModel()
    @State private var refreshNonce = 0
    private var calendar: Calendar { .current }

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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppScreenHeadline(title: String(localized: "Daily Plan"))
                .padding(.horizontal, 16)

                WeekStripView(selectedDate: $selectedDate, weekDates: Self.dashboardWeekDates) { date in
                    viewModel.activeDates.contains(calendar.startOfDay(for: date))
                }
                .padding(.top, 8)
                .opacity(viewModel.isInitialized ? 1 : 0.6)

                DailyPlanView(
                    onLogMood: { attemptingNewMoodEntry = true },
                    onDailyBreathing: {
                        BreathingPresenter.shared.present(
                            durationSeconds: 60,
                            autoStart: true,
                            onComplete: {
                                withAnimation {
                                    viewModel.markItemAsDone(.breathingReset, for: selectedDate)
                                }
                            }
                        )
                    },
                    onDailyLesson: {
                        selectedTab = .exercises
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.isInitialized {
                        HomeDashboardSkeleton()
                    } else {
                        Text(String(localized: "More for today"))
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                            .padding(.top, 2)

                        ThoughtRecordPlanCard(
                            completionState: viewModel.completionSnapshot.state(for: .thoughtRecord),
                            action: { attemptingNewThoughtRecord = true }
                        )

                        TipOfTheDayPlanCard(
                            completionState: viewModel.completionSnapshot.state(for: .tipOfTheDay),
                            action: { showingTipModal = true }
                        )

                        ActivityPlannerPlanCard(
                            completionState: viewModel.completionSnapshot.state(for: .activityPlanner),
                            action: { selectedTab = .exercises }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .responsiveMaxWidth()
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showingTipModal, onDismiss: {
            withAnimation {
                viewModel.markItemAsDone(.tipOfTheDay, for: selectedDate)
            }
        }) {
            TipOfTheDayModal(isPresented: $showingTipModal)
        }
        .onChange(of: showingNewMoodEntry) { _, isPresented in
            guard !isPresented else { return }
            refreshNonce &+= 1
        }
        .onChange(of: showingNewThoughtRecord) { _, isPresented in
            guard !isPresented else { return }
            refreshNonce &+= 1
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshNonce &+= 1
        }
        .task(id: DashboardRefreshToken(
            day: calendar.startOfDay(for: selectedDate),
            nonce: refreshNonce
        )) {
            await refreshDashboard()
        }
        .withUsageGate(isAttemptingAction: $attemptingNewMoodEntry) {
            showingNewMoodEntry = true
        }
        .withUsageGate(isAttemptingAction: $attemptingNewThoughtRecord) {
            showingNewThoughtRecord = true
        }
    }

    @MainActor
    private func refreshDashboard() async {
        let snapshot = LaunchSafeFetch.homeDashboardSnapshot(
            selectedDate: selectedDate,
            visibleDates: Self.dashboardWeekDates,
            from: modelContext
        )

        await viewModel.apply(
            snapshot: snapshot,
            selectedDate: selectedDate
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
