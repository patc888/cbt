import SwiftUI
import SwiftData
import os

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \Achievement.createdAt) private var achievements: [Achievement]
    @Query(sort: \PersonalValue.createdAt) private var personalValues: [PersonalValue]
    @Query(sort: \ValueActionCompletion.createdAt, order: .reverse) private var valueActionCompletions: [ValueActionCompletion]
    @State private var achievementProgress: [String: AchievementProgress] = [:]
    @State private var monthlyBadgeProgress: MonthlyBadgeProgress?
    @State private var showingValues = false

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: DSSpacing.medium)
    ]

    private let monthlyColumns = [
        GridItem(.adaptive(minimum: 170), spacing: DSSpacing.medium)
    ]

    private var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    private var recentAchievements: [Achievement] {
        Array(
            achievements
                .filter(\.isUnlocked)
                .sorted {
                    ($0.unlockedAt ?? $0.createdAt) > ($1.unlockedAt ?? $1.createdAt)
                }
                .prefix(3)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.large) {
                        TopHeadlineView(
                            title: String(localized: "Profile"),
                            leading: {
                                StreakToolbarButton()
                            },
                            trailing: {
                                NavigationLink {
                                    SettingsView(showsDismissControl: false)
                                } label: {
                                    Image(systemName: "gearshape")
                                        .font(.system(.body, weight: .semibold))
                                        .foregroundStyle(themeManager.selectedColor)
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Open Settings")
                            }
                        )

                        profileSummary
                        copingPlanLink
                        ProfileValuesSection(
                            values: personalValues.filter { !$0.isDeleted },
                            weeklySummary: ValuesService.weeklySummary(completions: valueActionCompletions),
                            onManage: { showingValues = true }
                        )

                        if !recentAchievements.isEmpty {
                            ProfileRecentAchievementsSection(achievements: recentAchievements)
                        }

                        if let monthlyBadgeProgress {
                            monthlyBadgesSection(monthlyBadgeProgress)
                        }

                        if achievements.isEmpty {
                            SupportiveEmptyStateView(
                                systemImage: "rosette",
                                title: "Achievements",
                                message: "Save your first check-in, journal entry, or exercise completion to unlock the first practice milestone.",
                                actionTitle: "Refresh Achievements",
                                actionSystemImage: "arrow.clockwise"
                            ) {
                                refreshAchievements()
                            }
                            .padding(DSSpacing.large)
                            .cardStyle()
                        } else {
                            LazyVGrid(columns: columns, spacing: DSSpacing.medium) {
                                ForEach(achievements) { achievement in
                                    AchievementBadgeView(
                                        achievement: achievement,
                                        progress: achievementProgress[achievement.title]
                                    )
                                }
                            }
                        }
                    }
                    .dsContentLayout()
                    .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + DSSpacing.large)
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .hideNavigationBar()
            .task {
                refreshAchievements()
            }
            .sheet(isPresented: $showingValues) {
                NavigationStack {
                    ValuesSelectionView()
                }
                .dsSheetPresentation()
            }
        }
    }

    private func refreshAchievements() {
        AchievementService.shared.evaluateAchievements(in: modelContext)
        achievementProgress = AchievementService.shared.progressSnapshots(in: modelContext)

        do {
            monthlyBadgeProgress = try AchievementService.shared.monthlyBadgeProgress(in: modelContext)
        } catch {
            AppLogger.make(category: "Profile").error("Failed to load monthly badges: \(error.localizedDescription, privacy: .private)")
            monthlyBadgeProgress = nil
        }
    }

    private var profileSummary: some View {
        DSCardContainer {
            ViewThatFits(in: .horizontal) {
                summaryContent(axis: .horizontal)
                summaryContent(axis: .vertical)
            }
        }
    }

    private var copingPlanLink: some View {
        NavigationLink(destination: SafetyPlanView()) {
            DSCardContainer {
                HStack(alignment: .center, spacing: DSSpacing.medium) {
                    Image(systemName: "lifepreserver.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 48, height: 48)
                        .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rough Patch Plan")
                            .font(DSTypography.cardTitle)
                            .foregroundStyle(Theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Edit your warning signs, helpful actions, trusted contacts, grounding steps, and reminders.")
                            .font(DSTypography.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    SettingsDisclosureIndicator()
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Rough Patch Plan")
    }

    private func summaryContent(axis: Axis) -> some View {
        Group {
            if axis == .horizontal {
                HStack(spacing: DSSpacing.large) {
                    summaryIcon
                    summaryText
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    summaryIcon
                    summaryText
                }
            }
        }
    }

    private var summaryIcon: some View {
        ZStack {
            Circle()
                .fill(themeManager.selectedColor.opacity(0.14))
                .frame(width: 68, height: 68)

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(themeManager.selectedColor)
        }
        .accessibilityHidden(true)
    }

    private var summaryText: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
            Text("Achievements")
                .font(DSTypography.sectionHeader)
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(unlockedCount) of \(achievements.count) unlocked")
                .font(DSTypography.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func monthlyBadgesSection(_ progress: MonthlyBadgeProgress) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.medium) {
            DSSectionHeader(title: "Monthly Badges", subtitle: progress.monthTitle)

            LazyVGrid(columns: monthlyColumns, spacing: DSSpacing.medium) {
                ForEach(progress.badges) { badge in
                    MonthlyBadgeCardView(item: badge)
                }
            }
        }
    }
}

private struct ProfileValuesSection: View {
    @Environment(ThemeManager.self) private var themeManager

    let values: [PersonalValue]
    let weeklySummary: [ValuePracticeSummary]
    let onManage: () -> Void

    private let valueColumns = [
        GridItem(.adaptive(minimum: 118), spacing: 8)
    ]

    private var weeklyCount: Int {
        weeklySummary.map(\.count).reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.medium) {
            DSSectionHeader(
                title: "Values",
                subtitle: weeklyCount == 0 ? "Small actions tied to what matters." : "\(weeklyCount) value-based actions this week."
            )

            DSCardContainer {
                VStack(alignment: .leading, spacing: DSSpacing.medium) {
                    if values.isEmpty {
                        Text("Choose a few values to receive tiny daily actions.")
                            .font(DSTypography.body)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        LazyVGrid(columns: valueColumns, alignment: .leading, spacing: 8) {
                            ForEach(values) { value in
                                Label(value.name, systemImage: value.isCustom ? "sparkle" : "star.fill")
                                    .font(DSTypography.caption.weight(.bold))
                                    .foregroundStyle(themeManager.selectedColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(themeManager.selectedColor.opacity(0.1), in: Capsule())
                            }
                        }

                        if !weeklySummary.isEmpty {
                            Divider()

                            ForEach(weeklySummary.prefix(3)) { summary in
                                HStack {
                                    Text(summary.valueName)
                                        .font(DSTypography.body.weight(.semibold))
                                        .foregroundStyle(Theme.primaryText)
                                    Spacer()
                                    Text("\(summary.count)")
                                        .font(DSTypography.body.weight(.bold))
                                        .foregroundStyle(themeManager.selectedColor)
                                }
                            }
                        }
                    }

                    Button {
                        onManage()
                    } label: {
                        Label(values.isEmpty ? "Choose values" : "Manage values", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, tint: themeManager.selectedColor, hapticType: .light))
                }
            }
        }
    }
}

private struct ProfileRecentAchievementsSection: View {
    @Environment(ThemeManager.self) private var themeManager

    let achievements: [Achievement]

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.medium) {
            DSSectionHeader(
                title: "Recent Achievements",
                subtitle: "Gentle milestones you have already earned."
            )

            VStack(spacing: DSSpacing.small) {
                ForEach(achievements) { achievement in
                    ProfileRecentAchievementRow(achievement: achievement)
                }
            }
        }
    }
}

private struct ProfileRecentAchievementRow: View {
    @Environment(ThemeManager.self) private var themeManager

    let achievement: Achievement

    var body: some View {
        DSCardContainer {
            HStack(alignment: .center, spacing: DSSpacing.medium) {
                Image(systemName: achievement.imageName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 44, height: 44)
                    .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(achievement.title)
                        .font(DSTypography.cardTitle)
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(achievement.achievementDescription)
                        .font(DSTypography.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title). \(achievement.achievementDescription)")
    }
}

private struct MonthlyBadgeCardView: View {
    @Environment(ThemeManager.self) private var themeManager

    let item: MonthlyBadgeProgressItem

    private var accent: Color {
        item.isComplete ? Theme.successGreen : themeManager.selectedColor
    }

    var body: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.medium) {
                HStack(alignment: .top, spacing: DSSpacing.small) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(item.isComplete ? 0.18 : 0.12))
                            .frame(width: 52, height: 52)

                        Image(systemName: item.kind.imageName)
                            .font(.system(size: 24, weight: .bold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(accent)
                    }
                    .accessibilityHidden(true)

                    Spacer(minLength: 0)

                    Text(item.statusLabel)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(item.isComplete ? .white : Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            Capsule()
                                .fill(item.isComplete ? accent : accent.opacity(0.12))
                        }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.kind.title)
                        .font(DSTypography.cardTitle)
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.kind.description)
                        .font(DSTypography.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: item.progress)
                        .tint(accent)

                    Text(item.progressLabel)
                        .font(DSTypography.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 214)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.kind.title). \(item.statusLabel). \(item.progressLabel). \(item.kind.description)")
    }
}

private struct AchievementBadgeView: View {
    @Environment(ThemeManager.self) private var themeManager

    let achievement: Achievement
    let progress: AchievementProgress?

    private var badgeColor: Color {
        achievement.isUnlocked ? themeManager.selectedColor : Color.gray
    }

    var body: some View {
        DSCardContainer {
            VStack(spacing: DSSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(badgeColor.opacity(achievement.isUnlocked ? 0.18 : 0.10))
                        .frame(width: 72, height: 72)

                    Image(systemName: achievement.imageName)
                        .font(.system(size: 34, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(badgeColor)
                        .saturation(achievement.isUnlocked ? 1 : 0)
                }
                .accessibilityHidden(true)

                VStack(spacing: 4) {
                    Text(achievement.title)
                        .font(DSTypography.cardTitle)
                        .foregroundStyle(Theme.primaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(achievement.achievementDescription)
                        .font(DSTypography.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let progress, !achievement.isUnlocked {
                    VStack(spacing: 6) {
                        ProgressView(value: progress.fraction)
                            .tint(themeManager.selectedColor)

                        Text(progress.progressText)
                            .font(DSTypography.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(achievement.isUnlocked ? "Unlocked" : "On the way")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(achievement.isUnlocked ? .white : Theme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(achievement.isUnlocked ? badgeColor : Color.gray.opacity(0.14))
                    }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 238)
            .opacity(achievement.isUnlocked ? 1 : 0.78)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [
            achievement.title,
            achievement.isUnlocked ? "unlocked" : "on the way",
            achievement.achievementDescription
        ]

        if let progress, !achievement.isUnlocked {
            parts.append(progress.progressText)
        }

        return parts.joined(separator: ". ")
    }
}
