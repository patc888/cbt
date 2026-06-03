import SwiftUI

struct DailyPlanView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(DailyPlanPersonalizationKeys.goals) private var dailyPlanGoalIDs = ""
    @AppStorage(DailyPlanPersonalizationKeys.interests) private var dailyPlanInterestIDs = ""
    @State private var isMoreForTodayExpanded = false

    let recommendations: [DailyRecommendation]
    let completionSnapshot: DailyPlanCompletionSnapshot
    let loopState: HomeDailyPlanLoopState
    let pickedResetYesterday: Bool
    let onRecommendationSelected: (DailyRecommendation) -> Void
    let onRecommendationFeedback: (DailyRecommendation, DailyPlanFeedbackAction) -> Void
    let onContinueSelected: (HomeContinueItem) -> Void
    let onLogMood: () -> Void
    let onThoughtRecord: () -> Void
    let onBreathingReset: () -> Void
    let onActivityPlanner: () -> Void

    private var primaryRecommendations: [DailyRecommendation] {
        Array(recommendations.prefix(3))
    }

    private var primaryActionRecommendation: DailyRecommendation {
        if loopState.isPlanComplete {
            return loopState.optionalTinyAction ?? loopState.primaryNextStep
        }
        return loopState.primaryNextStep
    }

    private var secondaryRecommendations: [DailyRecommendation] {
        primaryRecommendations.filter { $0.id != loopState.primaryNextStep.id }
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
            if pickedResetYesterday {
                yesterdayResetBanner
            }

            header

            if let recoveryMessage = loopState.recoveryMessage {
                DailyPlanInfoBanner(
                    systemImage: "leaf.circle.fill",
                    text: recoveryMessage,
                    tint: Theme.successGreen
                )
            }

            primaryNextStepCard

            moreForTodaySection
        }
        .onAppear(perform: recordCompletedPlanIfNeeded)
        .onChange(of: completedPrimaryCount) { _, _ in
            recordCompletedPlanIfNeeded()
        }
        .padding(18)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
                    #if canImport(UIKit)
                    .fill(Color(UIColor.systemBackground))
                    #elseif canImport(AppKit)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    #else
                    .fill(Color.black)
                    #endif
                    .shadow(
                        color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.18 : 0.07),
                        radius: colorScheme == .dark ? 18 : 10,
                        x: 0,
                        y: colorScheme == .dark ? 12 : 6
                    )

                RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
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
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
                            .strokeBorder(themeManager.selectedColor.opacity(0.16), lineWidth: 1)
                    }
            }
        }
    }

    private var yesterdayResetBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wind")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(themeManager.selectedColor)
                .accessibilityHidden(true)

            Text(String(localized: "You picked Reset yesterday"))
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            themeManager.selectedColor.opacity(colorScheme == .dark ? 0.18 : 0.1),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .strokeBorder(themeManager.selectedColor.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
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

    private var primaryNextStepCard: some View {
        DailyRecommendationRow(
            recommendation: primaryActionRecommendation,
            completionState: loopState.isPlanComplete
                ? .notTracked
                : completionState(for: loopState.primaryNextStep),
            isTracked: !loopState.isPlanComplete && (
                loopState.primaryNextStep.completionItem != nil || loopState.primaryNextStep.isCompletedToday
            ),
            style: .primary,
            leadingLabel: loopState.isPlanComplete
                ? String(localized: "Plan complete")
                : String(localized: "Next best action"),
            onFeedback: onRecommendationFeedback
        ) {
            onRecommendationSelected(primaryActionRecommendation)
        }
    }

    private var moreForTodaySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    isMoreForTodayExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "More for today"))
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Text(moreForTodaySummary)
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(themeManager.selectedColor)
                        .rotationEffect(.degrees(isMoreForTodayExpanded ? 180 : 0))
                        .frame(width: 30, height: 30)
                        .background(themeManager.selectedColor.opacity(0.1), in: Circle())
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "More for today"))
            .accessibilityValue(isMoreForTodayExpanded ? String(localized: "Expanded") : String(localized: "Collapsed"))
            .accessibilityHint(isMoreForTodayExpanded ? String(localized: "Tap to hide secondary plan items") : String(localized: "Tap to show secondary plan items"))

            if isMoreForTodayExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    whyThisSection

                    todaysProgressSection

                    if let continueItem = loopState.continueItem {
                        continueSection(continueItem)
                    }

                    tomorrowPreviewSection

                    recommendationList

                    Divider()
                        .background(DSTheme.separator.opacity(0.6))

                    quickActions
                }
                .padding(.top, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            themeManager.selectedColor.opacity(colorScheme == .dark ? 0.1 : 0.05),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(themeManager.selectedColor.opacity(0.12), lineWidth: 1)
        }
    }

    private var moreForTodaySummary: String {
        let remaining = max(progressTotal - completedPrimaryCount, 0)
        if loopState.isPlanComplete {
            return String(localized: "Optional tools are tucked away if you want them.")
        }
        if remaining <= 1 {
            return String(localized: "Progress, why this step, and optional tools.")
        }
        return String(localized: "\(remaining) optional plan details and quick tools.")
    }

    private var whyThisSection: some View {
        DailyPlanInfoBanner(
            systemImage: "info.circle.fill",
            text: loopState.whyExplanation,
            tint: themeManager.selectedColor
        )
        .accessibilityLabel("Why this recommendation. \(loopState.whyExplanation)")
    }

    private var todaysProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(String(localized: "Today's Progress"))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Spacer(minLength: 0)
                Text("\(loopState.completedCount)")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(themeManager.selectedColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(themeManager.selectedColor.opacity(0.1), in: Capsule())
            }

            DailyPlanRecommendationProgressTrack(
                progress: progressFraction,
                accent: themeManager.selectedColor,
                secondaryAccent: themeManager.secondaryColor
            )

            if loopState.completedWins.isEmpty {
                Text(loopState.isNewUser
                    ? String(localized: "No wins logged yet. Your first check-in will show up here.")
                    : String(localized: "Nothing logged yet today. One small step will count."))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 132), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(loopState.completedWins) { win in
                        DailyPlanWinChip(win: win)
                    }
                }
            }
        }
        .padding(12)
        .background(themeManager.selectedColor.opacity(colorScheme == .dark ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func continueSection(_ item: HomeContinueItem) -> some View {
        Button {
            HapticManager.shared.selection()
            onContinueSelected(item)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(themeManager.secondaryColor, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Continue Where You Left Off"))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Text(item.title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.subtitle)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(themeManager.selectedColor)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(themeManager.secondaryColor.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Continue where you left off. \(item.title). \(item.subtitle)")
        .accessibilityHint(String(localized: "Tap to continue"))
    }

    private var tomorrowPreviewSection: some View {
        DailyPlanInfoBanner(
            systemImage: "sunrise.fill",
            text: "\(loopState.tomorrowTitle). \(loopState.tomorrowSubtitle)",
            tint: themeManager.secondaryColor
        )
        .accessibilityLabel("\(loopState.tomorrowTitle). \(loopState.tomorrowSubtitle)")
    }

    @ViewBuilder
    private var recommendationList: some View {
        if !secondaryRecommendations.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Optional Next Steps"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.secondaryText)

                VStack(spacing: 10) {
                    ForEach(secondaryRecommendations) { recommendation in
                        DailyRecommendationRow(
                            recommendation: recommendation,
                            completionState: completionState(for: recommendation),
                            isTracked: recommendation.completionItem != nil || recommendation.isCompletedToday,
                            style: .compact,
                            leadingLabel: nil,
                            onFeedback: onRecommendationFeedback
                        ) {
                            onRecommendationSelected(recommendation)
                        }
                    }
                }
            }
        }
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
                    title: String(localized: "Daily Check-In"),
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

    private func recordCompletedPlanIfNeeded() {
        guard !primaryRecommendations.isEmpty, completedPrimaryCount >= progressTotal else { return }
        LocalRetentionEventStore.shared.recordOncePerDay(
            .dailyPlanCompleted,
            sourceScreen: "daily_plan",
            metadata: ["primary_count": "\(primaryRecommendations.count)"]
        )
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

private struct DailyPlanInfoBanner: View {
    @Environment(\.colorScheme) private var colorScheme

    let systemImage: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .padding(.top, 2)
                .accessibilityHidden(true)

            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            tint.opacity(colorScheme == .dark ? 0.15 : 0.08),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct DailyPlanWinChip: View {
    @Environment(ThemeManager.self) private var themeManager

    let win: HomeDailyPlanWin

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: win.systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.successGreen)
                .frame(width: 16)
                .accessibilityHidden(true)

            Text(win.title)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(themeManager.selectedColor.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(win.title), completed today")
    }
}

private struct DailyRecommendationRow: View {
    enum Style: Equatable {
        case primary
        case compact
    }

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let recommendation: DailyRecommendation
    let completionState: PlanCardCompletionState
    let isTracked: Bool
    let style: Style
    let leadingLabel: String?
    let onFeedback: (DailyRecommendation, DailyPlanFeedbackAction) -> Void
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

    private var iconSize: CGFloat {
        style == .primary ? 46 : 38
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                HapticManager.shared.selection()
                action()
            } label: {
                VStack(alignment: .leading, spacing: style == .primary ? 12 : 10) {
                if let leadingLabel {
                    Text(leadingLabel)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(leadingColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: leadingSymbol)
                        .font(.system(size: style == .primary ? 19 : 16, weight: .bold))
                        .foregroundStyle(leadingColor)
                        .frame(width: iconSize, height: iconSize)
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
                                .font(.system(style == .primary ? .title3 : .headline, design: .rounded).weight(.bold))
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
                .padding(.leading, iconSize + 8)
            }
            .padding(style == .primary ? 14 : 12)
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

            feedbackControls
                .padding(.leading, iconSize + 8)
                .padding(.horizontal, style == .primary ? 14 : 12)
                .padding(.bottom, 4)
        }
    }

    private var feedbackControls: some View {
        HStack(spacing: 8) {
            DailyPlanFeedbackButton(
                systemImage: "hand.thumbsup.fill",
                label: String(localized: "This helped"),
                tint: Theme.successGreen
            ) {
                onFeedback(recommendation, .helped)
            }

            DailyPlanFeedbackButton(
                systemImage: "hand.thumbsdown.fill",
                label: String(localized: "Not for me"),
                tint: Theme.secondaryText
            ) {
                onFeedback(recommendation, .notHelpful)
            }

            DailyPlanFeedbackButton(
                systemImage: "minus.circle.fill",
                label: String(localized: "Too much today"),
                tint: themeManager.selectedColor
            ) {
                onFeedback(recommendation, .tooMuchToday)
            }
        }
    }

    private var accessibilityLabel: String {
        if isCompleted && isTracked {
            return "\(recommendation.title), completed. \(recommendation.why)"
        }
        return "\(recommendation.title). \(recommendation.why)"
    }
}

private struct DailyPlanFeedbackButton: View {
    let systemImage: String
    let label: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, tint: accent, hapticType: nil))
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(isCompleted ? "\(title), completed" : title)
        .accessibilityHint(String(localized: "Tap to open"))
    }
}
