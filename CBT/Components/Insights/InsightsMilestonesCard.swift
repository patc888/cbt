import SwiftUI

struct InsightsMilestonesCard: View {
    @Binding var timeRange: InsightsTimeRange
    let milestonesCompleted: Int
    let consistencyProgress: Double
    let activeDaysCount: Int

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visibleConsistencyProgress = 0.0
    @State private var visibleMilestoneProgress = 0.0

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(String(localized: "Milestones"))
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("\(milestonesCompleted)/4")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            SegmentedToggle(selection: $timeRange, options: InsightsTimeRange.allCases, titleKey: \.localizedName)

            ZStack {
                Circle()
                    .stroke(themeManager.secondaryColor.opacity(0.15), lineWidth: 24)
                    .frame(width: 190, height: 190)

                Circle()
                    .trim(from: 0, to: max(0.001, visibleConsistencyProgress))
                    .stroke(
                        LinearGradient(
                            colors: [themeManager.secondaryColor, themeManager.selectedColor.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 24, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 190, height: 190)

                Circle()
                    .stroke(themeManager.selectedColor.opacity(0.12), lineWidth: 18)
                    .frame(width: 136, height: 136)

                Circle()
                    .trim(from: 0, to: max(0.001, visibleMilestoneProgress))
                    .stroke(
                        LinearGradient(
                            colors: [themeManager.selectedColor, themeManager.secondaryColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 136, height: 136)

                VStack(spacing: 4) {
                    Text("\(Int((visibleConsistencyProgress * 100).rounded()))%")
                        .font(.system(.largeTitle, design: .rounded).weight(.black))
                        .foregroundStyle(Theme.primaryText)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("CONSISTENCY")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Consistency Progress")
            .accessibilityValue("\(Int((consistencyProgress * 100).rounded())) percent. \(milestonesCompleted) of 4 milestones completed.")

            Text("\(activeDaysCount) active days in last \(timeRange.days) days")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
        .onAppear {
            updateVisibleProgress(animated: !reduceMotion)
        }
        .onChange(of: consistencyProgress) { _, _ in
            updateVisibleProgress(animated: !reduceMotion)
        }
        .onChange(of: milestonesCompleted) { _, _ in
            updateVisibleProgress(animated: !reduceMotion)
        }
    }

    private func updateVisibleProgress(animated: Bool) {
        let consistency = min(1, max(0, consistencyProgress))
        let milestones = min(1, max(0, Double(milestonesCompleted) / 4.0))

        if animated {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.84)) {
                visibleConsistencyProgress = consistency
                visibleMilestoneProgress = milestones
            }
        } else {
            visibleConsistencyProgress = consistency
            visibleMilestoneProgress = milestones
        }
    }
}
