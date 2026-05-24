import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \Achievement.createdAt) private var achievements: [Achievement]

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: DSSpacing.medium)
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

                        LazyVGrid(columns: columns, spacing: DSSpacing.medium) {
                            ForEach(achievements) { achievement in
                                AchievementBadgeView(achievement: achievement)
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
                AchievementService.shared.evaluateAchievements(in: modelContext)
            }
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
}

private struct AchievementBadgeView: View {
    @Environment(ThemeManager.self) private var themeManager

    let achievement: Achievement

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

                Text(achievement.isUnlocked ? "Unlocked" : "Locked")
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
            .frame(minHeight: 206)
            .grayscale(achievement.isUnlocked ? 0 : 1)
            .opacity(achievement.isUnlocked ? 1 : 0.62)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title), \(achievement.isUnlocked ? "unlocked" : "locked"). \(achievement.achievementDescription)")
    }
}
