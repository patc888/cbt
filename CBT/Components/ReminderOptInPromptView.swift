import SwiftUI

struct ReminderOptInPromptView: View {
    @Environment(ThemeManager.self) private var themeManager

    let moment: ReminderOptInMoment
    var isWorking = false
    var onAccept: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 34, height: 34)
                        .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(moment.promptTitle)
                            .font(DSTypography.sectionTitle)
                            .foregroundStyle(DSTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(moment.promptMessage)
                            .font(DSTypography.caption)
                            .foregroundStyle(DSTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(spacing: 8) {
                    Button(action: onAccept) {
                        Label(moment.acceptTitle, systemImage: isWorking ? "clock" : "bell")
                    }
                    .buttonStyle(DSPrimaryButtonStyle(size: .medium))
                    .disabled(isWorking)

                    Button(action: onDismiss) {
                        Text("Not Now")
                    }
                    .buttonStyle(DSSecondaryButtonStyle(size: .medium))
                    .disabled(isWorking)
                }
            }
        }
    }
}
