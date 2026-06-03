import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(DailyPlanPersonalizationKeys.onboardingCompleted) private var onboardingCompleted = false
    @AppStorage(FirstSessionWinService.completedKey) private var firstSessionWinCompleted = false

    @State private var shouldShowFirstSessionWin: Bool?

    var body: some View {
        if onboardingCompleted {
            if shouldShowFirstSessionWin == true {
                FirstSessionWinView {
                    shouldShowFirstSessionWin = false
                }
            } else if shouldShowFirstSessionWin == false || firstSessionWinCompleted {
                RootTabView()
            } else {
                ProgressView()
                    .task {
                        evaluateFirstSessionWinGate()
                    }
            }
        } else {
            OnboardingView()
        }
    }

    @MainActor
    private func evaluateFirstSessionWinGate() {
        guard onboardingCompleted else {
            shouldShowFirstSessionWin = nil
            return
        }

        shouldShowFirstSessionWin = FirstSessionWinService.shouldPresentAfterExistingUserCheck(
            modelContext: modelContext
        )
    }
}
