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
                .dsSheetPresentation()
        }
        .sheet(isPresented: $showingNewThoughtRecord) {
            NewThoughtRecordFlowView()
                .dsSheetPresentation()
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(DailyRecommendationService.lastHomeVisitKey) private var lastHomeVisitInterval: Double = 0
    @AppStorage("cbt_home_tomorrowAnchor") private var tomorrowAnchorID = ""
    @AppStorage("cbt_home_tomorrowAnchorUpdatedAt") private var tomorrowAnchorUpdatedAt: Double = 0
    @State private var viewModel = HomeDashboardViewModel()
    @State private var refreshNonce = 0
    @State private var hasAppeared = false
    @State private var sessionLastHomeVisit: Date?
    @State private var hasRecordedHomeVisit = false
    @State private var selectedExercise: Exercise?
    @State private var showingActivityPlanner = false
    @State private var showingIntroToCBT = false
    @State private var showingSafetySupport = false
    private var calendar: Calendar { .current }

    private var heroItems: [DailyPlanItem] {
        [.moodCheckIn, .breathingReset, .exercises, .thoughtRecord, .activityPlanner]
    }

    private var completedHeroItems: Int {
        heroItems.filter { viewModel.completionSnapshot.state(for: $0).isCompleted }.count
    }

    private var heroProgress: Double {
        guard !heroItems.isEmpty else { return 0 }
        return Double(completedHeroItems) / Double(heroItems.count)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppScreenHeadline(title: String(localized: "Daily Plan"))
                .padding(.horizontal, 16)

                HomeHeroCard(
                    selectedDate: selectedDate,
                    completedCount: completedHeroItems,
                    totalCount: heroItems.count,
                    activeDayCount: viewModel.activeDates.count,
                    progress: heroProgress,
                    animate: hasAppeared && !reduceMotion
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .homeEntrance(index: 0, isVisible: hasAppeared, reduceMotion: reduceMotion)

                HomeDateRailCard(
                    selectedDate: $selectedDate,
                    weekDates: Self.dashboardWeekDates,
                    dayHasActivity: { date in
                        viewModel.activeDates.contains(calendar.startOfDay(for: date))
                    }
                )
                .padding(.horizontal, 16)
                .opacity(viewModel.isInitialized ? 1 : 0.6)
                .homeEntrance(index: 1, isVisible: hasAppeared, reduceMotion: reduceMotion)

                Group {
                    if viewModel.isInitialized {
                        DailyPlanView(
                            recommendations: viewModel.recommendations,
                            completionSnapshot: viewModel.completionSnapshot,
                            onRecommendationSelected: performRecommendation,
                            onLogMood: { attemptingNewMoodEntry = true },
                            onThoughtRecord: { attemptingNewThoughtRecord = true },
                            onBreathingReset: { presentBreathingReset(durationSeconds: 60) },
                            onActivityPlanner: { showingActivityPlanner = true }
                        )
                    } else {
                        HomeDashboardSkeleton()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .homeEntrance(index: 2, isVisible: hasAppeared, reduceMotion: reduceMotion)

                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.isInitialized {
                        HomeDashboardSkeleton()
                    } else {
                        HomeSectionHeader(
                            title: String(localized: "More for today"),
                            subtitle: String(localized: "A few small tools to keep the day steady.")
                        )

                        TipOfTheDayPlanCard(
                            completionState: viewModel.completionSnapshot.state(for: .tipOfTheDay),
                            action: { showingTipModal = true }
                        )

                        TomorrowAnchorCard(
                            selectedAnchor: tomorrowAnchor,
                            updatedAt: tomorrowAnchorDate,
                            onSelect: saveTomorrowAnchor
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .homeEntrance(index: 3, isVisible: hasAppeared, reduceMotion: reduceMotion)
            }
            .responsiveMaxWidth()
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                    hasAppeared = true
                }
            }
        }
        .sheet(isPresented: $showingTipModal, onDismiss: {
            withAnimation {
                viewModel.markItemAsDone(.tipOfTheDay, for: selectedDate)
            }
        }) {
            TipOfTheDayModal(isPresented: $showingTipModal)
                .dsSheetPresentation(detents: [.medium])
        }
        .sheet(item: $selectedExercise, onDismiss: {
            refreshNonce &+= 1
        }) { exercise in
            NavigationStack {
                ExerciseDetailView(exercise: exercise)
            }
            .dsSheetPresentation()
        }
        .sheet(isPresented: $showingActivityPlanner, onDismiss: {
            refreshNonce &+= 1
        }) {
            NavigationStack {
                ActivityPlannerView()
            }
            .dsSheetPresentation()
        }
        .sheet(isPresented: $showingIntroToCBT) {
            NavigationStack {
                WhatIsCBTPagerView()
            }
            .dsSheetPresentation()
        }
        .sheet(isPresented: $showingSafetySupport) {
            NavigationStack {
                SafetyPlanView()
            }
            .dsSheetPresentation()
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
        let lastOpenedAt = currentSessionLastHomeVisit()
        let snapshot = LaunchSafeFetch.homeDashboardSnapshot(
            selectedDate: selectedDate,
            visibleDates: Self.dashboardWeekDates,
            from: modelContext
        )
        let recommendations = DailyRecommendationService.shared.primaryRecommendations(
            from: modelContext,
            lastOpenedAt: lastOpenedAt
        )

        await viewModel.apply(
            snapshot: snapshot,
            selectedDate: selectedDate,
            recommendations: recommendations
        )

        recordHomeVisitIfNeeded()
    }

    private func currentSessionLastHomeVisit() -> Date? {
        if let sessionLastHomeVisit {
            return sessionLastHomeVisit
        }

        guard lastHomeVisitInterval > 0 else {
            return nil
        }

        let storedDate = Date(timeIntervalSince1970: lastHomeVisitInterval)
        sessionLastHomeVisit = storedDate
        return storedDate
    }

    private func recordHomeVisitIfNeeded() {
        guard !hasRecordedHomeVisit else { return }
        hasRecordedHomeVisit = true
        lastHomeVisitInterval = Date().timeIntervalSince1970
    }

    private func performRecommendation(_ recommendation: DailyRecommendation) {
        perform(destination: recommendation.destination)
    }

    private func perform(destination: DailyRecommendationDestination) {
        switch destination {
        case .moodCheckIn:
            attemptingNewMoodEntry = true
        case .thoughtRecord:
            attemptingNewThoughtRecord = true
        case .breathingReset(let durationSeconds):
            presentBreathingReset(durationSeconds: durationSeconds)
        case .behavioralActivation:
            showingActivityPlanner = true
        case .libraryExercise(let exerciseID):
            if let exercise = LibraryService.shared.exercise(withID: exerciseID) {
                selectedExercise = exercise
            } else {
                selectedTab = .exercises
            }
        case .guidedJournal(_):
            selectedTab = .journal
        case .introToCBT:
            showingIntroToCBT = true
        case .course(_), .program(_):
            selectedTab = .exercises
        case .assessments:
            selectedTab = .assessments
        case .safetySupport:
            showingSafetySupport = true
        }
    }

    private func presentBreathingReset(durationSeconds: Int) {
        BreathingPresenter.shared.present(
            durationSeconds: durationSeconds,
            autoStart: true,
            onComplete: {
                withAnimation {
                    viewModel.markItemAsDone(.breathingReset, for: selectedDate)
                }
                refreshNonce &+= 1
            }
        )
    }

    private var tomorrowAnchor: TomorrowAnchor? {
        TomorrowAnchor(rawValue: tomorrowAnchorID)
    }

    private var tomorrowAnchorDate: Date? {
        guard tomorrowAnchorUpdatedAt > 0 else { return nil }
        return Date(timeIntervalSince1970: tomorrowAnchorUpdatedAt)
    }

    private func saveTomorrowAnchor(_ anchor: TomorrowAnchor) {
        HapticManager.shared.selection()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            tomorrowAnchorID = anchor.rawValue
            tomorrowAnchorUpdatedAt = Date().timeIntervalSince1970
        }
    }
}

private enum TomorrowAnchor: String, CaseIterable, Identifiable {
    case mood
    case breathing
    case thought
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mood:
            return String(localized: "Mood")
        case .breathing:
            return String(localized: "Reset")
        case .thought:
            return String(localized: "Thought")
        case .activity:
            return String(localized: "Activity")
        }
    }

    var subtitle: String {
        switch self {
        case .mood:
            return String(localized: "Check in before the day gets loud.")
        case .breathing:
            return String(localized: "Start with one minute of breathing.")
        case .thought:
            return String(localized: "Catch one thought and reframe it.")
        case .activity:
            return String(localized: "Plan one nourishing action.")
        }
    }

    var systemImage: String {
        switch self {
        case .mood:
            return "face.smiling"
        case .breathing:
            return "wind"
        case .thought:
            return "brain.head.profile"
        case .activity:
            return "calendar.badge.clock"
        }
    }
}

private struct TomorrowAnchorCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let selectedAnchor: TomorrowAnchor?
    let updatedAt: Date?
    let onSelect: (TomorrowAnchor) -> Void

    private var statusText: String {
        guard let selectedAnchor else {
            return String(localized: "Pick one tiny thing to come back for tomorrow.")
        }

        if let updatedAt, Calendar.current.isDateInToday(updatedAt) {
            return String(localized: "\(selectedAnchor.title) is saved for tomorrow.")
        }

        return String(localized: "Your next anchor is \(selectedAnchor.title.lowercased()).")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    headerIcon
                    titleBlock
                    Spacer(minLength: 8)
                    savedBadge
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        headerIcon
                        titleBlock
                    }
                    savedBadge
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 118), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(TomorrowAnchor.allCases) { anchor in
                    TomorrowAnchorButton(
                        anchor: anchor,
                        isSelected: anchor == selectedAnchor
                    ) {
                        onSelect(anchor)
                    }
                }
            }

            if let selectedAnchor {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.uturn.forward.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(themeManager.selectedColor)
                        .padding(.top, 1)

                    Text(selectedAnchor.subtitle)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DSTheme.cardBackground)
                .overlay {
                    LinearGradient(
                        colors: [
                            themeManager.selectedColor.opacity(colorScheme == .dark ? 0.16 : 0.08),
                            themeManager.secondaryColor.opacity(colorScheme == .dark ? 0.1 : 0.04),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(themeManager.selectedColor.opacity(0.14), lineWidth: 1)
                }
        }
        .shadow(
            color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.14 : 0.05),
            radius: colorScheme == .dark ? 16 : 8,
            x: 0,
            y: colorScheme == .dark ? 10 : 5
        )
        .accessibilityElement(children: .contain)
    }

    private var headerIcon: some View {
        Image(systemName: selectedAnchor?.systemImage ?? "arrow.forward.circle.fill")
            .font(.system(size: 18, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(
                LinearGradient(
                    colors: [themeManager.selectedColor, themeManager.secondaryColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .accessibilityHidden(true)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Tomorrow's Anchor"))
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(statusText)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var savedBadge: some View {
        if selectedAnchor != nil {
            Label(String(localized: "Saved"), systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.successGreen)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Theme.successGreen.opacity(0.1), in: Capsule())
        }
    }
}

private struct TomorrowAnchorButton: View {
    @Environment(ThemeManager.self) private var themeManager

    let anchor: TomorrowAnchor
    let isSelected: Bool
    let action: () -> Void

    private var accent: Color {
        isSelected ? Theme.successGreen : themeManager.selectedColor
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : anchor.systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 18)
                    .accessibilityHidden(true)

                Text(anchor.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, tint: accent, hapticType: nil))
        .frame(minHeight: 44)
        .accessibilityLabel(isSelected ? "\(anchor.title), saved for tomorrow" : anchor.title)
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

private struct HomeHeroCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let selectedDate: Date
    let completedCount: Int
    let totalCount: Int
    let activeDayCount: Int
    let progress: Double
    let animate: Bool

    private var accent: Color {
        themeManager.selectedColor
    }

    private var secondaryAccent: Color {
        themeManager.secondaryColor
    }

    private var dateLabel: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return String(localized: "Today")
        }
        return selectedDate.formatted(.dateTime.weekday(.wide))
    }

    private var headline: String {
        if completedCount >= totalCount, totalCount > 0 {
            return String(localized: "Plan complete")
        }
        if completedCount == 0 {
            return String(localized: "Start with one small win")
        }
        return String(localized: "\(completedCount) of \(totalCount) wins banked")
    }

    private var subheadline: String {
        if completedCount >= totalCount, totalCount > 0 {
            return String(localized: "You showed up for your mind today. Let that count.")
        }
        let remaining = max(totalCount - completedCount, 0)
        return String(localized: "\(remaining) gentle steps left in your CBT rhythm.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    HomeHeroMedallion(accent: accent, secondaryAccent: secondaryAccent, animate: animate)
                    heroCopy
                }

                VStack(alignment: .leading, spacing: 16) {
                    HomeHeroMedallion(accent: accent, secondaryAccent: secondaryAccent, animate: animate)
                    heroCopy
                }
            }

            HomeProgressTrack(progress: progress, accent: .white, animate: animate)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    HomeHeroPill(icon: "checkmark.seal.fill", title: String(localized: "Done"), value: "\(completedCount)/\(totalCount)")
                    HomeHeroPill(icon: "sparkles", title: String(localized: "Active"), value: "\(activeDayCount)d")
                }

                VStack(spacing: 10) {
                    HomeHeroPill(icon: "checkmark.seal.fill", title: String(localized: "Done"), value: "\(completedCount)/\(totalCount)")
                    HomeHeroPill(icon: "sparkles", title: String(localized: "Active"), value: "\(activeDayCount)d")
                }
            }
        }
        .padding(22)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    #if canImport(UIKit)
                    .fill(Color(UIColor.systemBackground))
                    #elseif canImport(AppKit)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    #else
                    .fill(Color.black)
                    #endif
                    .shadow(
                        color: accent.opacity(colorScheme == .dark ? 0.32 : 0.18),
                        radius: colorScheme == .dark ? 26 : 18,
                        x: 0,
                        y: colorScheme == .dark ? 18 : 10
                    )

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent,
                                secondaryAccent.opacity(colorScheme == .dark ? 0.95 : 0.9),
                                accent.opacity(colorScheme == .dark ? 0.72 : 0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
                .overlay {
                    ZStack {
                        HomeHeroGlowPattern(animate: animate)

                        LinearGradient(
                            colors: [.white.opacity(0.28), .white.opacity(0.04), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )

                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                    }
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dateLabel), \(headline). \(subheadline)")
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(selectedDate.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.15), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )

            Text(headline)
                .font(.system(size: 33, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)

            Text(subheadline)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeHeroMedallion: View {
    let accent: Color
    let secondaryAccent: Color
    let animate: Bool

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 88, height: 88)
                .scaleEffect(pulse && animate ? 1.1 : 0.94)
                .opacity(pulse && animate ? 0.25 : 0.55)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 72, height: 72)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                }

            Image(systemName: "checklist.checked")
                .font(.system(size: 34, weight: .black))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, secondaryAccent.opacity(0.85))
                .shadow(color: .white.opacity(0.35), radius: 10, x: 0, y: 0)
                .scaleEffect(pulse && animate ? 1.05 : 0.98)
        }
        .frame(width: 88, height: 88)
        .onAppear {
            updatePulse()
        }
        .onChange(of: animate) { _, _ in
            updatePulse()
        }
    }

    private func updatePulse() {
        guard animate else {
            pulse = false
            return
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

private struct HomeHeroGlowPattern: View {
    let animate: Bool
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: proxy.size.width * 0.72)
                    .blur(radius: 24)
                    .offset(
                        x: drift && animate ? proxy.size.width * 0.22 : proxy.size.width * 0.06,
                        y: drift && animate ? -proxy.size.height * 0.28 : -proxy.size.height * 0.18
                    )

                Circle()
                    .fill(.black.opacity(0.12))
                    .frame(width: proxy.size.width * 0.9)
                    .blur(radius: 34)
                    .offset(x: proxy.size.width * 0.42, y: proxy.size.height * 0.58)

                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(index.isMultiple(of: 2) ? 0.24 : 0.14))
                        .frame(width: CGFloat(4 + (index % 3) * 3))
                        .offset(
                            x: proxy.size.width * CGFloat([0.16, 0.35, 0.68, 0.82, 0.24, 0.53, 0.74, 0.9][index]),
                            y: proxy.size.height * CGFloat([0.18, 0.1, 0.22, 0.42, 0.68, 0.78, 0.62, 0.16][index])
                        )
                        .opacity(animate && drift ? 1 : 0.55)
                        .scaleEffect(animate && drift ? 1.2 : 0.85)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear {
            updateDrift()
        }
        .onChange(of: animate) { _, _ in
            updateDrift()
        }
    }

    private func updateDrift() {
        guard animate else {
            drift = false
            return
        }
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            drift = true
        }
    }
}

private struct HomeProgressTrack: View {
    let progress: Double
    let accent: Color
    let animate: Bool

    @State private var visibleProgress = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.2))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.58)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, proxy.size.width * visibleProgress))
                        .overlay(alignment: .trailing) {
                            Circle()
                                .fill(.white)
                                .frame(width: 14, height: 14)
                                .shadow(color: .white.opacity(0.45), radius: 8, x: 0, y: 0)
                                .padding(.trailing, 2)
                        }
                }
            }
            .frame(height: 12)

            HStack {
                Text(String(localized: "Daily rhythm"))
                Spacer()
                Text("\(Int((visibleProgress * 100).rounded()))%")
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.76))
        }
        .onAppear {
            updateProgress(progress)
        }
        .onChange(of: progress) { _, newValue in
            updateProgress(newValue)
        }
    }

    private func updateProgress(_ newValue: Double) {
        if animate {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.85)) {
                visibleProgress = newValue
            }
        } else {
            visibleProgress = newValue
        }
    }
}

private struct HomeHeroPill: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct HomeDateRailCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedDate: Date
    let weekDates: [Date]
    let dayHasActivity: (Date) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    headerTitle
                    Spacer()
                    activeLegend
                }

                VStack(alignment: .leading, spacing: 8) {
                    headerTitle
                    activeLegend
                }
            }

            WeekStripView(
                selectedDate: $selectedDate,
                weekDates: weekDates,
                dayHasActivity: dayHasActivity
            )
            .padding(.horizontal, -12)
            .padding(.bottom, -4)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DSTheme.cardBackground)
                .overlay {
                    LinearGradient(
                        colors: [
                            themeManager.selectedColor.opacity(colorScheme == .dark ? 0.18 : 0.1),
                            themeManager.secondaryColor.opacity(colorScheme == .dark ? 0.12 : 0.06),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(themeManager.selectedColor.opacity(0.14), lineWidth: 1)
                }
        }
        .shadow(
            color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.16 : 0.06),
            radius: colorScheme == .dark ? 18 : 10,
            x: 0,
            y: colorScheme == .dark ? 12 : 6
        )
    }

    private var headerTitle: some View {
        Label(String(localized: "Choose your day"), systemImage: "calendar.badge.clock")
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
    }

    private var activeLegend: some View {
        Label(String(localized: "Active"), systemImage: "checkmark.circle.fill")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(themeManager.selectedColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct HomeSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            Text(subtitle)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }
}

private struct HomeEntranceModifier: ViewModifier {
    let index: Int
    let isVisible: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 18)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.98)
            .animation(
                reduceMotion ? nil : .spring(response: 0.62, dampingFraction: 0.86).delay(Double(index) * 0.08),
                value: isVisible
            )
    }
}

private extension View {
    func homeEntrance(index: Int, isVisible: Bool, reduceMotion: Bool) -> some View {
        modifier(HomeEntranceModifier(index: index, isVisible: isVisible, reduceMotion: reduceMotion))
    }
}
