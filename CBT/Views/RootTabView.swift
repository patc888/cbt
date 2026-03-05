import SwiftUI

struct RootTabView: View {
    @Environment(ThemeManager.self) private var themeManager

    @State private var selectedTab: FloatingTab = .home
    @StateObject private var breathing = BreathingPresenter.shared

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

            FloatingBottomToolbar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            updateTabBarAppearance()
        }
        .sheet(isPresented: $breathing.isPresented) {
            NavigationStack {
                BreathingResetView(
                    durationSeconds: breathing.durationSeconds,
                    autoStart: breathing.autoStart,
                    showsDismissControl: true
                )
            }
        }
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
