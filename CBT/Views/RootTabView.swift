import SwiftUI

struct RootTabView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTab: FloatingTab = .home
    @State private var activatedTabs: Set<FloatingTab> = []
    @StateObject private var breathing = BreathingPresenter.shared
    @State private var isInExerciseFlow = false
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                tabContent(for: .home) {
                    NavigationStack {
                        HomeView(selectedTab: $selectedTab)
                    }
                }
                .tag(FloatingTab.home)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar(.hidden, for: .tabBar)
                #elseif os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif

                tabContent(for: .insights) {
                    NavigationStack {
                        InsightsView()
                    }
                }
                .tag(FloatingTab.insights)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar(.hidden, for: .tabBar)
                #elseif os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif

                tabContent(for: .exercises) {
                    NavigationStack {
                        ExercisesView()
                    }
                }
                .tag(FloatingTab.exercises)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar(.hidden, for: .tabBar)
                #elseif os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif

                tabContent(for: .journal) {
                    NavigationStack {
                        JournalView()
                            .navigationDestination(for: TimelineRoute.self) { route in
                                TimelineRouteDestinationView(route: route)
                            }
                    }
                }
                .tag(FloatingTab.journal)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar(.hidden, for: .tabBar)
                #elseif os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif

                tabContent(for: .settings) {
                    NavigationStack {
                        SettingsView(showsDismissControl: false)
                    }
                }
                .tag(FloatingTab.settings)
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbar(.hidden, for: .tabBar)
                #elseif os(iOS)
                .toolbar(.hidden, for: .tabBar)
                #endif
            }
            .tint(themeManager.selectedColor)

            if !isInExerciseFlow {
                FloatingBottomToolbar(selectedTab: $selectedTab)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .exerciseFlowDidEnter)) { _ in
            isInExerciseFlow = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .exerciseFlowDidExit)) { _ in
            isInExerciseFlow = false
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
    private func tabContent<Content: View>(
        for tab: FloatingTab,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if activatedTabs.contains(tab) {
            DeferredTabRoot {
                content()
            }
        } else {
            Color.clear
                .accessibilityHidden(true)
        }
    }
}

private struct DeferredTabRoot<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
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
