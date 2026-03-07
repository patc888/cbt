import SwiftUI

struct RootTabView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTab: FloatingTab = .home
    @StateObject private var breathing = BreathingPresenter.shared
    @State private var isInExerciseFlow = false
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView(selectedTab: $selectedTab)
                }
                .tag(FloatingTab.home)
                .toolbar(.hidden, for: .tabBar)

                NavigationStack {
                    InsightsView()
                }
                .tag(FloatingTab.insights)
                .toolbar(.hidden, for: .tabBar)

                NavigationStack {
                    ExercisesView()
                }
                .tag(FloatingTab.exercises)
                .toolbar(.hidden, for: .tabBar)

                NavigationStack {
                    JournalView()
                        .navigationDestination(for: TimelineRoute.self) { route in
                            switch route {
                            case .journal(let entry):
                                JournalEntryDetailView(entry: entry)
                            case .mood(let entry):
                                MoodDetailView(entry: entry)
                            case .thought(let record):
                                ThoughtRecordDetailView(record: record)
                            case .exercise(let exerciseID):
                                if let exercise = ExerciseLibrary.shared.exercises.first(where: { $0.id == exerciseID }) {
                                    ExerciseDetailView(exercise: exercise)
                                } else {
                                    ContentUnavailableView(
                                        "Exercise Not Found",
                                        systemImage: "exclamationmark.triangle",
                                        description: Text("This exercise is no longer available.")
                                    )
                                }
                            }
                        }
                }
                .tag(FloatingTab.journal)
                .toolbar(.hidden, for: .tabBar)

                NavigationStack {
                    SettingsView(showsDismissControl: false)
                }
                .tag(FloatingTab.settings)
                .toolbar(.hidden, for: .tabBar)
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
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            updateTabBarAppearance()
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
}
