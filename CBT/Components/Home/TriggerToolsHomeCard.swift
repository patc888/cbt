import SwiftUI

struct TriggerToolsHomeCard: View {
    let snapshot: TriggerLibrarySnapshot
    let onOpenTool: (TriggerToolRecommendation) -> Void
    let onOpenInsights: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    private var recentTriggers: [PersonalizedTriggerSummary] {
        snapshot.commonTriggers(for: .sevenDays, limit: 3)
    }

    private var tools: [TriggerToolRecommendation] {
        snapshot.recentToolRecommendations
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(String(localized: "Tools for your recent triggers"))
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button(action: onOpenInsights) {
                    Image(systemName: "chart.bar.doc.horizontal")
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(34), expands: false, tint: themeManager.selectedColor, hapticType: .light))
                .accessibilityLabel(String(localized: "Open trigger insights"))
            }

            if recentTriggers.isEmpty || tools.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "tag.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 36, height: 36)
                        .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    Text(String(localized: "As check-ins, journals, and thought records build up, local trigger-based tools will appear here."))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ForEach(recentTriggers) { trigger in
                            Text(trigger.category.displayName)
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(themeManager.selectedColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(themeManager.selectedColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    ForEach(tools.prefix(3)) { tool in
                        Button {
                            HapticManager.shared.selection()
                            onOpenTool(tool)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: tool.systemImage)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(themeManager.selectedColor)
                                    .frame(width: 34, height: 34)
                                    .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tool.title)
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundStyle(Theme.primaryText)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text("\(tool.kind.rawValue) - \(tool.subtitle)")
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(Theme.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}
