import SwiftUI

struct ContinueItemCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let item: ContinueItem
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 44, height: 44)
                        .background(themeManager.selectedColor.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Continue Where You Left Off")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.selectedColor)
                            .textCase(.uppercase)

                        Text(item.title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(item.subtitle)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .layoutPriority(1)

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(themeManager.selectedColor)
                }

                if let progress = item.progressPercentage {
                    ProgressView(value: Double(progress) / 100.0)
                        .tint(themeManager.selectedColor)
                        .accessibilityLabel("Progress")
                        .accessibilityValue("\(progress)%")
                }
            }
            .padding(Theme.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                    .fill(DSTheme.cardBackground)
                    .shadow(
                        color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.16 : 0.06),
                        radius: colorScheme == .dark ? 16 : 8,
                        x: 0,
                        y: colorScheme == .dark ? 10 : 5
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(themeManager.selectedColor.opacity(0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continue-where-left-off-card")
    }

    private var iconName: String {
        switch item.destination {
        case .dailyPlan(let destination):
            switch destination {
            case .moodCheckIn:
                return "face.smiling"
            case .thoughtRecord:
                return "brain.head.profile"
            case .breathingReset:
                return "wind"
            case .guidedJournal:
                return "pencil.and.list.clipboard"
            case .libraryExercise:
                return "figure.mind.and.body"
            case .course, .introToCBT:
                return "graduationcap.fill"
            case .program:
                return "map.fill"
            case .behavioralActivation:
                return "calendar.badge.clock"
            case .weeklyReview:
                return "chart.line.uptrend.xyaxis"
            case .assessments:
                return "checklist"
            case .safetySupport:
                return "cross.case.fill"
            }
        case .thoughtRecord:
            return "brain.head.profile"
        case .guidedJournal:
            return "pencil.and.list.clipboard"
        case .exercise:
            return "figure.mind.and.body"
        case .course:
            return "graduationcap.fill"
        case .cbtPath:
            return "map.fill"
        case .assessment:
            return "checklist"
        case .activityPlanner:
            return "calendar.badge.clock"
        }
    }
}
