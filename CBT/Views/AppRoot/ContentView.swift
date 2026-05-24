import SwiftUI

struct ContentView: View {
    @AppStorage(DailyPlanPersonalizationKeys.onboardingCompleted) private var onboardingCompleted = false

    var body: some View {
        if onboardingCompleted {
            RootTabView()
        } else {
            OnboardingView()
        }
    }
}
