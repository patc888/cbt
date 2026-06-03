import SwiftUI

struct GroundingPreparationView: View {
    @Environment(ThemeManager.self) private var themeManager

    let title: String
    let message: String
    let continueTitle: String
    let onContinue: () -> Void

    @State private var showingGrounding = false

    var body: some View {
        DSCardContainer {
            VStack(alignment: .leading, spacing: DSSpacing.large) {
                HStack(alignment: .top, spacing: DSSpacing.medium) {
                    Image(systemName: "wind")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 42, height: 42)
                        .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DSSpacing.xSmall) {
                        Text(title)
                            .font(DSTypography.sectionHeader)
                            .foregroundStyle(DSTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(message)
                            .font(DSTypography.body)
                            .foregroundStyle(DSTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: DSSpacing.small) {
                    Button {
                        HapticManager.shared.lightImpact()
                        showingGrounding = true
                    } label: {
                        Label(String(localized: "Ground for 30 Seconds"), systemImage: "timer")
                    }
                    .buttonStyle(DSPrimaryButtonStyle())

                    Button {
                        HapticManager.shared.selection()
                        onContinue()
                    } label: {
                        Label(continueTitle, systemImage: "arrow.right")
                    }
                    .buttonStyle(DSSecondaryButtonStyle())
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingGrounding) {
            groundingSession
        }
        #else
        .sheet(isPresented: $showingGrounding) {
            groundingSession
                .dsSheetPresentation()
        }
        #endif
    }

    private var groundingSession: some View {
        NavigationStack {
            BreathingResetView(
                durationSeconds: 30,
                pattern: .box,
                autoStart: true,
                showsDismissControl: true,
                showControls: true,
                hideBackground: false,
                onComplete: {
                    showingGrounding = false
                    onContinue()
                },
                onDismiss: {
                    showingGrounding = false
                }
            )
        }
    }
}
