import SwiftUI
import SwiftData

struct SubscriptionSettingsView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Binding var showingSubscription: Bool
    @Environment(ThemeManager.self) private var themeManager
    @Query private var settings: [UserSettings]
    
    private var isPremium: Bool {
        subscriptionManager.isPremium
    }
    
    var body: some View {
        SettingsSection(title: "") {
            if !isPremium {
                ProUpgradeCard(
                    title: "Full Access",
                    subtitle: "Unlimited entries, predictions, advanced trends, and iCloud sync.",
                    ctaTitle: "Update to Full Access",
                    footnote: nil,
                    isFullColorTheme: themeManager.isImmersive,
                    action: {
                        showingSubscription = true
                    },
                    isLoading: subscriptionManager.isLoading
                )
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        AppIconView(size: 60)
                            .cornerRadius(14)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .center, spacing: 8) {
                                Text("Full Access")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.primaryText)
                                
                                statusChip(title: "Activated")
                                    .accessibilityValue("Activated")
                            }
                            
                            Text("You have full access to all features.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isPremium {
                HapticManager.shared.lightImpact()
                showingSubscription = true
            }
        }
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
