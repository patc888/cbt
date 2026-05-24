import SwiftUI
import SwiftData
import os

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \Achievement.createdAt) private var achievements: [Achievement]
    @State private var achievementProgress: [String: AchievementProgress] = [:]
    @State private var monthlyBadgeProgress: MonthlyBadgeProgress?

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: DSSpacing.medium)
    ]

    private let monthlyColumns = [
        GridItem(.adaptive(minimum: 170), spacing: DSSpacing.medium)
    ]

    private var unlockedCount: Int {
        achievements.filter(\.isUnlocked).count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.large) {
                        profileSummary

                        if let monthlyBadgeProgress {
                            monthlyBadgesSection(monthlyBadgeProgress)
                        }

                        if achievements.isEmpty {
                            SupportiveEmptyStateView(
                                systemImage: "rosette",
                                title: "Achievements",
                                message: "Achievements quietly mark practice milestones as you use check-ins, journals, and exercises.",
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
                    .padding(.horizontal, DSSpacing.large)
                    .padding(.top, DSSpacing.large)
                    .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + DSSpacing.large)
                }
            }
            .navigationTitle("Profile")
            .task {
                refreshAchievements()
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
