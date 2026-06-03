import SwiftUI

struct InsightsLoadingStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text(String(localized: "Crunching your data..."))
                .foregroundStyle(Theme.secondaryText)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.paddingMedium)
        .cardStyle()
        .padding(.horizontal, 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Loading insights"))
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
                message: String(localized: "Start with a 1-minute mood check-in. A few saved moments will turn into patterns here."),
                actionTitle: String(localized: "Add a Mood Check-In"),
                actionSystemImage: "face.smiling"
            ) {
                HapticManager.shared.lightImpact()
                attemptingAddMood = true
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 12)
    }
}
