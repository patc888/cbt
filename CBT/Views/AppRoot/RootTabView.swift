import SwiftUI

struct RootTabView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTab: FloatingTab = .home
    @State private var activatedTabs: Set<FloatingTab> = []
    @StateObject private var breathing = BreathingPresenter.shared
    @State private var isInExerciseFlow = false
    @State private var isInQuizFlow = false
    @State private var presentedContextualDeepLink: ContextualNotificationDeepLink?
    @State private var activeAchievementToast: AchievementToastItem?
    @State private var achievementToastQueue: [AchievementToastItem] = []

    private var selectedTabBinding: Binding<FloatingTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                activatedTabs.insert(newTab)
                selectedTab = newTab
            }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: selectedTabBinding) {
                tabContent(for: .home) {
                    HomeView(selectedTab: selectedTabBinding)
                }
                .tag(FloatingTab.home)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar(.hidden, for: .tabBar)
                #elseif os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif

                tabContent(for: .insights) {
                    InsightsView()
                }
                .tag(FloatingTab.insights)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar(.hidden, for: .tabBar)
                #elseif os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif

                tabContent(for: .assessments) {
                    AssessmentsView()
                }
                .tag(FloatingTab.assessments)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar(.hidden, for: .tabBar)
                #elseif os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif

                tabContent(for: .toolkit) {
                    CopingToolkitView()
                }
                .tag(FloatingTab.toolkit)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar(.hidden, for: .tabBar)
                #elseif os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif

                tabContent(for: .exercises) {
                    LibraryView()
                }
                .tag(FloatingTab.exercises)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar(.hidden, for: .tabBar)
                #elseif os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif

                tabContent(for: .journal) {
                    JournalView()
                }
                .tag(FloatingTab.journal)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar(.hidden, for: .tabBar)
                #elseif os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif

                tabContent(for: .profile) {
                    ProfileView()
                }
                .tag(FloatingTab.profile)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar(.hidden, for: .tabBar)
                #elseif os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif

                tabContent(for: .profile) {
                    ProfileView()
                }
                .tag(FloatingTab.profile)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar(.hidden, for: .tabBar)
                #elseif os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif

                tabContent(for: .settings) {
                    SettingsView(showsDismissControl: false)
                }
                .tag(FloatingTab.settings)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar(.hidden, for: .tabBar)
                #elseif os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif
            }
            .tint(themeManager.selectedColor)

            if !isInExerciseFlow && !isInQuizFlow {
                FloatingBottomToolbar(selectedTab: selectedTabBinding)
            }
        }
        .fullScreenCover(item: $presentedContextualDeepLink) { deepLink in
            contextualDestination(for: deepLink)
        }
        .onOpenURL { url in
            guard let deepLink = ContextualNotificationDeepLink(url: url) else { return }
            handleContextualDeepLink(deepLink)
        }
        .onReceive(NotificationCenter.default.publisher(for: .contextualNotificationDeepLinkReceived)) { notification in
            guard let deepLink = notification.object as? ContextualNotificationDeepLink else { return }
            handleContextualDeepLink(deepLink)
        }
        .onReceive(NotificationCenter.default.publisher(for: .appTabSelectionRequested)) { notification in
            guard let tab = notification.object as? FloatingTab else { return }
            activatedTabs.insert(tab)
            selectedTab = tab
        }
        .onReceive(NotificationCenter.default.publisher(for: .exerciseFlowDidEnter)) { _ in
            isInExerciseFlow = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .exerciseFlowDidExit)) { _ in
            isInExerciseFlow = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .quizFlowDidEnter)) { _ in
            isInQuizFlow = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .quizFlowDidExit)) { _ in
            isInQuizFlow = false
        }
        .onChange(of: selectedTab) { _, newTab in
            activatedTabs.insert(newTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            updateTabBarAppearance()
        }
        .task {
            guard activatedTabs.isEmpty else { return }
            // Let the tab and navigation containers settle for one more
            // async turn before constructing the initial home subtree.
            // On iPad, we add a tiny explicit sleep to ensure split-view 
            // and sidebar transitions are fully committed.
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            guard !Task.isCancelled else { return }
            
            await Task.yield()
            guard !Task.isCancelled else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            activatedTabs.insert(.home)
        }
        .overlay {
            if breathing.isPresented {
                breathingStepCardOverlay
            }
        }
        .overlay(alignment: .top) {
            if let activeAchievementToast {
                AchievementToastView(item: activeAchievementToast)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .move(edge: .top))
                    )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .achievementsUnlocked)) { notification in
            guard let achievements = notification.userInfo?["achievements"] as? [Achievement],
                  !achievements.isEmpty else { return }
            enqueueAchievementToasts(for: achievements)
        }
        .onChange(of: activeAchievementToast) { _, toast in
            guard toast != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
                dismissActiveAchievementToast()
            }
        }
        .animation(
            reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.52),
            value: breathing.isPresented
        )
        .animation(
            reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.42, dampingFraction: 0.86),
            value: activeAchievementToast
        )
    }

    @ViewBuilder
    private var breathingStepCardOverlay: some View {
        NavigationStack {
            BreathingResetView(
                durationSeconds: breathing.durationSeconds,
                pattern: breathing.pattern,
                autoStart: breathing.autoStart,
                showsDismissControl: true,
                showControls: breathing.showControls,
                hideBackground: false,
                onComplete: {
                    breathing.onComplete?()
                    clearBreathingPresentation()
                },
                onDismiss: {
                    breathing.onDismiss?()
                    clearBreathingPresentation()
                }
            )
        }
        .ignoresSafeArea()
        .transition(.asymmetric(
            insertion: reduceMotion
                ? .opacity
                : .opacity.combined(with: .move(edge: .bottom)),
            removal: reduceMotion
                ? .opacity
                : .opacity.combined(with: .move(edge: .bottom))
        ))
    }

    private func clearBreathingPresentation() {
        breathing.isPresented = false
        breathing.onComplete = nil
        breathing.onDismiss = nil
    }

    private func updateTabBarAppearance() {
#if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        UIScrollView.appearance().isDirectionalLockEnabled = true
        UIScrollView.appearance().alwaysBounceHorizontal = false
#endif
    }

    @ViewBuilder
    private func contextualDestination(for deepLink: ContextualNotificationDeepLink) -> some View {
        switch deepLink {
        case .affirmation:
            NavigationStack {
                AffirmationPlayerView()
            }
        case .journal:
            JournalView()
        case .moodCheckIn:
            MoodCheckinView()
        case .morningIntentions:
            GuidedPromptView(flow: .flow(for: .morningIntentions))
        case .eveningReflection:
            GuidedPromptView(flow: .flow(for: .eveningReflection))
        case .sleepWindDown:
            GuidedPromptView(flow: .flow(for: .eveningReflection))
        case .breathing:
            BreathingResetView(
                durationSeconds: 60,
                autoStart: true,
                showsDismissControl: true
            )
        case .weeklyReport:
            NavigationStack {
                WeeklyReviewView()
            }
        case .plannedActivity:
            ActivityPlannerView()
        case .courseContinuation:
            LibraryView()
        }
    }

    private func handleContextualDeepLink(_ deepLink: ContextualNotificationDeepLink) {
        switch deepLink {
        case .breathing:
            activatedTabs.insert(.home)
            selectedTab = .home
            BreathingPresenter.shared.present(durationSeconds: 60, autoStart: true)
        case .journal:
            activatedTabs.insert(.journal)
            selectedTab = .journal
        case .moodCheckIn:
            activatedTabs.insert(.home)
            selectedTab = .home
            presentedContextualDeepLink = .moodCheckIn
        case .morningIntentions, .eveningReflection:
            activatedTabs.insert(.journal)
            selectedTab = .journal
            presentedContextualDeepLink = deepLink
        case .sleepWindDown:
            activatedTabs.insert(.journal)
            selectedTab = .journal
            presentedContextualDeepLink = .sleepWindDown
        case .affirmation:
            activatedTabs.insert(.exercises)
            selectedTab = .exercises
            presentedContextualDeepLink = .affirmation
        case .weeklyReport:
            activatedTabs.insert(.insights)
            selectedTab = .insights
            presentedContextualDeepLink = .weeklyReport
        case .plannedActivity:
            activatedTabs.insert(.exercises)
            selectedTab = .exercises
            presentedContextualDeepLink = .plannedActivity
        case .courseContinuation:
            activatedTabs.insert(.exercises)
            selectedTab = .exercises
        }
    }

    @ViewBuilder
    private func tabContent<Content: View>(
        for tab: FloatingTab,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if activatedTabs.contains(tab) {
            DeferredTabRoot(isSelected: selectedTab == tab) {
                content()
            }
        } else {
            ThemedBackground()
                .accessibilityHidden(true)
        }
    }

    private func enqueueAchievementToasts(for achievements: [Achievement]) {
        let toasts = achievements
            .sorted { ($0.unlockedAt ?? $0.createdAt) < ($1.unlockedAt ?? $1.createdAt) }
            .map(AchievementToastItem.init)

        if activeAchievementToast == nil {
            activeAchievementToast = toasts.first
            achievementToastQueue.append(contentsOf: toasts.dropFirst())
        } else {
            achievementToastQueue.append(contentsOf: toasts)
        }
    }

    private func dismissActiveAchievementToast() {
        guard activeAchievementToast != nil else { return }

        if achievementToastQueue.isEmpty {
            activeAchievementToast = nil
        } else {
            activeAchievementToast = achievementToastQueue.removeFirst()
        }
    }
}

private struct AchievementToastItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let imageName: String

    nonisolated init(achievement: Achievement) {
        id = achievement.id
        title = achievement.title
        description = achievement.achievementDescription
        imageName = achievement.imageName
    }
}

private struct AchievementToastView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let item: AchievementToastItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: item.imageName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 38, height: 38)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "Milestone unlocked"))
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .textCase(.uppercase)

                Text(item.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 420)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DSTheme.cardBackground)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12),
                    radius: 16,
                    x: 0,
                    y: 8
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(themeManager.selectedColor.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DeferredTabRoot<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isSelected {
            content()
        } else {
            DeferredRenderView {
                ThemedBackground()
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .controlSize(.regular)
                    }
            } content: {
                content()
            }
        }
    }
}
