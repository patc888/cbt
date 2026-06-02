import SwiftUI
import SwiftData

struct SubscriptionSettingsView: View {
    @State private var subscriptionManager = SubscriptionManager.shared
    @Environment(ThemeManager.self) private var themeManager
    @Query private var settings: [UserSettings]
    @State private var isShowingPaywall = false
    
    private var isPremium: Bool {
        subscriptionManager.isPremium || (settings.first?.isPremium ?? false)
    }
    
    var body: some View {
        SettingsSection(title: "") {
            if !isPremium {
                ProUpgradeCard(
                    title: String(localized: "CBT Premium"),
                    subtitle: String(localized: "Subscribe to keep Premium access active as new tools roll out."),
                    ctaTitle: String(localized: "View Premium Options"),
                    footnote: nil,
                    isFullColorTheme: themeManager.isImmersive,
                    action: {
                        isShowingPaywall = true
                    },
                    isLoading: subscriptionManager.isLoading
                )
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        AppIconView(size: 60)
                            .cornerRadius(14)

                        VStack(alignment: .leading, spacing: 6) {
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .center, spacing: 8) {
                                    subscriptionTitle
                                    statusChip(title: String(localized: "Activated"))
                                        .accessibilityValue("Activated")
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    subscriptionTitle
                                    statusChip(title: String(localized: "Activated"))
                                        .accessibilityValue("Activated")
                                }
                            }

                            Text(String(localized: "Thanks for keeping Premium active."))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isPremium {
                HapticManager.shared.lightImpact()
                isShowingPaywall = true
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            SubscriptionView()
                .dsSheetPresentation(detents: [.large])
        }
    }

    @ViewBuilder
    private var subscriptionTitle: some View {
        Text(String(localized: "Premium"))
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.primaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func statusChip(title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(themeManager.selectedColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(themeManager.selectedColor.opacity(0.1))
            .clipShape(Capsule())
    }
}
