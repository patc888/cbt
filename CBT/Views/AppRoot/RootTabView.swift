import SwiftUI

struct RootTabView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTab: FloatingTab = .home
    @State private var activatedTabs: Set<FloatingTab> = [.home]
    @StateObject private var breathing = BreathingPresenter.shared
    @State private var isInExerciseFlow = false
    @State private var isInQuizFlow = false
    @State private var presentedContextualDeepLink: ContextualNotificationDeepLink?

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
        .animation(
            reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.52),
            value: breathing.isPresented
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
                onComplete: breathing.onComplete,
                onDismiss: {
                    breathing.onDismiss?()
                    breathing.isPresented = false
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

    private func updateTabBarAppearance() {
#if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
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
        case .morningIntentions:
            GuidedPromptView(flow: .flow(for: .morningIntentions))
        case .eveningReflection:
            GuidedPromptView(flow: .flow(for: .eveningReflection))
        case .breathing:
            BreathingResetView(
                durationSeconds: 60,
                autoStart: true,
                showsDismissControl: true
            )
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
        case .morningIntentions, .eveningReflection:
            activatedTabs.insert(.journal)
            selectedTab = .journal
            presentedContextualDeepLink = deepLink
        case .affirmation:
            activatedTabs.insert(.exercises)
            selectedTab = .exercises
            presentedContextualDeepLink = .affirmation
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
