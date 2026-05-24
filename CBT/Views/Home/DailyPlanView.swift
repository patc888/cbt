import SwiftUI

struct DailyPlanView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(DailyPlanPersonalizationKeys.goals) private var dailyPlanGoalIDs = ""
    @AppStorage(DailyPlanPersonalizationKeys.interests) private var dailyPlanInterestIDs = ""

    let recommendations: [DailyRecommendation]
    let completionSnapshot: DailyPlanCompletionSnapshot
    let onRecommendationSelected: (DailyRecommendation) -> Void
    let onLogMood: () -> Void
    let onThoughtRecord: () -> Void
    let onBreathingReset: () -> Void
    let onActivityPlanner: () -> Void

    private var primaryRecommendations: [DailyRecommendation] {
        Array(recommendations.prefix(3))
    }

    private var completedPrimaryCount: Int {
        primaryRecommendations.filter { completionState(for: $0).isCompleted }.count
    }

    private var progressTotal: Int {
        max(primaryRecommendations.count, 1)
    }

    private var progressFraction: Double {
        min(1, Double(completedPrimaryCount) / Double(progressTotal))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            DailyPlanRecommendationProgressTrack(
                progress: progressFraction,
                accent: themeManager.selectedColor,
                secondaryAccent: themeManager.secondaryColor
            )

            if primaryRecommendations.isEmpty {
                SupportiveEmptyStateView(
                    systemImage: "list.bullet.clipboard.fill",
                    title: String(localized: "Daily Plan"),
                    message: String(localized: "Daily Plan brings a few small CBT and self-help steps into today, based on what you have used recently."),
                    actionTitle: String(localized: "Add Check-In"),
                    actionSystemImage: "face.smiling"
                ) {
                    onLogMood()
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(primaryRecommendations) { recommendation in
                        DailyRecommendationRow(
                            recommendation: recommendation,
                            completionState: completionState(for: recommendation),
                            isTracked: recommendation.completionItem != nil || recommendation.isCompletedToday
                        ) {
                            onRecommendationSelected(recommendation)
                        }
                    }
                }
            }

            Divider()
                .background(DSTheme.separator.opacity(0.6))

            quickActions
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(DSTheme.cardBackground)
                .overlay {
                    LinearGradient(
                        colors: [
                            themeManager.selectedColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                            themeManager.secondaryColor.opacity(colorScheme == .dark ? 0.14 : 0.06),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(themeManager.selectedColor.opacity(0.16), lineWidth: 1)
                }
        }
        .shadow(
            color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.18 : 0.07),
            radius: colorScheme == .dark ? 18 : 10,
            x: 0,
            y: colorScheme == .dark ? 12 : 6
        )
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                titleBlock
                Spacer(minLength: 12)
                progressRing
            }

            VStack(alignment: .leading, spacing: 12) {
                titleBlock
                progressRing
            }
        }
    }

    private var titleBlock: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [themeManager.selectedColor, themeManager.secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                    .shadow(color: themeManager.selectedColor.opacity(0.28), radius: 10, x: 0, y: 6)

                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Label(String(localized: "Today's Plan"), systemImage: "sparkle")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(subtitleText)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(themeManager.trackBackgroundColor(for: colorScheme), lineWidth: 5)
                .frame(width: 48, height: 48)

            Circle()
                .trim(from: 0, to: CGFloat(progressFraction))
                .stroke(
                    LinearGradient(
                        colors: [themeManager.selectedColor, themeManager.secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progressFraction)

            Text("\(completedPrimaryCount)/\(progressTotal)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(width: 52, height: 52)
        .accessibilityLabel("\(completedPrimaryCount) of \(progressTotal) recommended plan items complete")
    }

    private var subtitleText: String {
        if completedPrimaryCount >= progressTotal {
            return String(localized: "Your plan is complete for today. Take what helps and leave the rest.")
        }
        if completedPrimaryCount == 0 {
            guard !primaryRecommendations.isEmpty else {
                return personalizedEmptySubtitle
            }
            if let primaryGoal {
                return String(localized: "\(primaryRecommendations.count) gentle steps for \(primaryGoal.dailyPlanPhrase).")
            }
            return String(localized: "\(primaryRecommendations.count) gentle steps for today.")
        }
        let remaining = max(progressTotal - completedPrimaryCount, 0)
        return String(localized: "\(remaining) helpful \(remaining == 1 ? "step" : "steps") available when you are ready.")
    }

    private var selectedGoals: [DailyPlanGoal] {
        let ids = Set(dailyPlanGoalIDs.split(separator: ",").map(String.init))
        return DailyPlanGoal.allCases.filter { ids.contains($0.rawValue) }
    }

    private var selectedInterests: [DailyPlanInterest] {
        let ids = Set(dailyPlanInterestIDs.split(separator: ",").map(String.init))
        return DailyPlanInterest.allCases.filter { ids.contains($0.rawValue) }
    }

    private var primaryGoal: DailyPlanGoal? {
        selectedGoals.first
    }

    private var personalizedEmptySubtitle: String {
        if let primaryGoal {
            return String(localized: "Quick actions are ready for \(primaryGoal.dailyPlanPhrase).")
        }
        if selectedInterests.contains(.journaling) {
            return String(localized: "Quick actions are ready, including reflection tools.")
        }
        return String(localized: "Quick actions are ready when you are.")
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Quick Actions"))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 134), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                DailyPlanQuickActionButton(
                    title: String(localized: "Mood Check-In"),
                    icon: "face.smiling",
                    isCompleted: completionSnapshot.state(for: .moodCheckIn).isCompleted,
                    action: onLogMood
                )

                DailyPlanQuickActionButton(
                    title: String(localized: "Thought Record"),
                    icon: "brain.head.profile",
                    isCompleted: completionSnapshot.state(for: .thoughtRecord).isCompleted,
                    action: onThoughtRecord
                )

                DailyPlanQuickActionButton(
                    title: String(localized: "Breathing Reset"),
                    icon: "wind",
                    isCompleted: completionSnapshot.state(for: .breathingReset).isCompleted,
                    action: onBreathingReset
                )

                DailyPlanQuickActionButton(
                    title: String(localized: "Activity Planner"),
                    icon: "calendar.badge.clock",
                    isCompleted: completionSnapshot.state(for: .activityPlanner).isCompleted,
                    action: onActivityPlanner
                )
            }
        }
    }

    private func completionState(for recommendation: DailyRecommendation) -> PlanCardCompletionState {
        if recommendation.isCompletedToday {
            return .completed
        }
        guard let item = recommendation.completionItem else { return .notTracked }
        return completionSnapshot.state(for: item)
    }
}

private struct DailyPlanRecommendationProgressTrack: View {
    @Environment(\.colorScheme) private var colorScheme

    let progress: Double
    let accent: Color
    let secondaryAccent: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.trackBackgroundColor(for: colorScheme).opacity(0.85))
                    .frame(height: 8)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent, secondaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, geo.size.width * CGFloat(progress)), height: 8)
                    .shadow(color: accent.opacity(0.24), radius: 8, x: 0, y: 3)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

private struct DailyRecommendationRow: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let recommendation: DailyRecommendation
    let completionState: PlanCardCompletionState
    let isTracked: Bool
    let action: () -> Void

    private var isCompleted: Bool {
        completionState.isCompleted
    }

    private var leadingSymbol: String {
        if isCompleted {
            return "checkmark.circle.fill"
        }
        return recommendation.icon
    }

    private var leadingColor: Color {
        isCompleted ? Theme.successGreen : themeManager.selectedColor
    }

    private var rowFill: LinearGradient {
        LinearGradient(
            colors: [
                leadingColor.opacity(colorScheme == .dark ? 0.16 : 0.08),
                isCompleted ? Color.secondary.opacity(0.05) : themeManager.secondaryColor.opacity(colorScheme == .dark ? 0.1 : 0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var rowBorder: Color {
        leadingColor.opacity(isCompleted ? 0.22 : 0.16)
    }

    var body: some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: leadingSymbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(leadingColor)
                        .frame(width: 38, height: 38)
                        .background {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            leadingColor.opacity(colorScheme == .dark ? 0.24 : 0.16),
                                            leadingColor.opacity(colorScheme == .dark ? 0.12 : 0.07)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay {
                            Circle()
                                .stroke(leadingColor.opacity(0.2), lineWidth: 1)
                        }
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(recommendation.title)
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .foregroundStyle(isCompleted ? Theme.secondaryText : Theme.primaryText)
                                .strikethrough(isCompleted && isTracked, color: Theme.secondaryText.opacity(0.5))
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)

                            Spacer(minLength: 4)

                            Text(recommendation.actionTitle)
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(themeManager.selectedColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(themeManager.selectedColor.opacity(0.1), in: Capsule())
                        }

                        Text(recommendation.subtitle)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.top, 2)
                    Text(recommendation.why)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.secondaryText.opacity(0.9))
                .padding(.leading, 46)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                    .fill(rowFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                    .stroke(rowBorder, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(String(localized: "Tap to open"))
    }

    private var accessibilityLabel: String {
        if isCompleted && isTracked {
            return "\(recommendation.title), completed. \(recommendation.why)"
        }
        return "\(recommendation.title). \(recommendation.why)"
    }
}

private struct DailyPlanQuickActionButton: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let icon: String
    let isCompleted: Bool
    let action: () -> Void

    private var accent: Color {
        isCompleted ? Theme.successGreen : themeManager.selectedColor
    }

    var body: some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 18)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(colorScheme == .dark ? 0.15 : 0.08),
                                themeManager.secondaryColor.opacity(colorScheme == .dark ? 0.1 : 0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(accent.opacity(0.16), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCompleted ? "\(title), completed" : title)
        .accessibilityHint(String(localized: "Tap to open"))
    }
}
