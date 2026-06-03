import SwiftUI

struct ContextualHelpButton: View {
    let title: String
    let message: String
    @State private var showingHelp = false
    
    var body: some View {
        Button {
            HapticManager.shared.lightImpact()
            showingHelp = true
        } label: {
            Image(systemName: "info.circle")
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(34), expands: false, tint: Theme.primaryColor, hapticType: nil))
        .accessibilityLabel("Help for \(title)")
        .sheet(isPresented: $showingHelp) {
            FeatureModalPresenter {
                DSFeatureModal(
                    systemImage: "info.circle.fill",
                    title: title,
                    subtitle: message,
                    primaryTitle: String(localized: "Got it"),
                    primaryAction: {
                        HapticManager.shared.lightImpact()
                        showingHelp = false
                    },
                    closeAction: {
                        HapticManager.shared.lightImpact()
                        showingHelp = false
                    }
                )
            }
            .dsSheetPresentation(detents: [.fraction(0.34), .medium])
        }
    }
}

struct NeedHelpNowCard: View {
    @Environment(ThemeManager.self) private var themeManager

    var title: String = String(localized: "Need help now?")
    var message: String = String(localized: "Open your rough patch plan and support resources for harder moments. If you might be in immediate danger, contact local emergency services now. In the U.S. you can call or text 988 for crisis support.")
    var actionTitle: String = String(localized: "Open Rough Patch Plan")
    var actionSystemImage: String = "arrow.up.right.circle.fill"
    let action: () -> Void

    var body: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 30)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(DSTypography.cardTitle)
                            .foregroundStyle(DSTheme.primaryText)

                        Text(message)
                            .font(DSTypography.caption)
                            .foregroundStyle(DSTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    HapticManager.shared.lightImpact()
                    action()
                } label: {
                    Label(actionTitle, systemImage: actionSystemImage)
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, tint: themeManager.selectedColor))
            }
        }
        .accessibilityElement(children: .contain)
    }
}
