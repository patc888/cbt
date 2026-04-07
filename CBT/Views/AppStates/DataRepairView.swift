import SwiftUI

struct DataRepairView: View {
    @Environment(ThemeManager.self) private var themeManager

    let onRetry: () -> Void
    let onResetThisDevice: () -> Void

    var body: some View {
        ZStack {
            ThemedBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    DSCardContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            Label {
                                Text("Data Repair")
                                    .font(DSTypography.sectionTitle)
                                    .foregroundStyle(DSTheme.primaryText)
                            } icon: {
                                Image(systemName: "externaldrive.badge.exclamationmark")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(themeManager.primaryColor)
                            }

                            Text("Something went wrong while opening your data on this device.")
                                .font(DSTypography.body)
                                .foregroundStyle(DSTheme.primaryText)

                            Text("You can try again, or reset local data on this device. Resetting this device does not delete iCloud data.")
                                .font(DSTypography.body)
                                .foregroundStyle(DSTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(spacing: 12) {
                        DSPrimaryButton(title: "Retry", action: onRetry)

                        Button("Reset This Device", action: onResetThisDevice)
                            .font(DSTypography.button)
                            .foregroundStyle(Theme.errorRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DSSpacing.large)
                            .background(Theme.errorRed.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
                            .accessibilityHint("Deletes local app data and preferences on this device only.")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .responsiveMaxWidth(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
