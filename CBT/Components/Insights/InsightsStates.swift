import SwiftUI

struct InsightsLoadingStateView: View {
    var body: some View {
        VStack {
            ProgressView()
                .padding()
            Text(String(localized: "Crunching your data..."))
                .foregroundStyle(Theme.secondaryText)
                .font(.subheadline)
        }
        .padding(.vertical, 40)
    }
}

struct InsightsEmptyStateView: View {
    @Binding var attemptingAddMood: Bool
    @Binding var attemptingAddThought: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            SupportiveEmptyStateView(
                systemImage: "chart.line.uptrend.xyaxis",
                title: String(localized: "Insights"),
                message: String(localized: "Insights turn check-ins and thought records into gentle patterns you can reflect on over time."),
                actionTitle: String(localized: "Add a Mood Check-In"),
                actionSystemImage: "face.smiling"
            ) {
                HapticManager.shared.lightImpact()
                attemptingAddMood = true
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}
