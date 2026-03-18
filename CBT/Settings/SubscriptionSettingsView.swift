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
                        subscriptionIcon
                            .frame(width: 60, height: 60)
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
                .padding(.vertical, 8)
            }
        }
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
            .foregroundStyle(themeManager.primaryColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(themeManager.primaryColor.opacity(0.1))
            .clipShape(Capsule())
    }

    private var subscriptionIcon: some View {
        Group {
            #if canImport(UIKit)
            if let brandingImage = UIImage(named: "AppBrandingIcon") {
                 Image(uiImage: brandingImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
               let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
               let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
               let lastIcon = iconFiles.last,
               let image = UIImage(named: lastIcon) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if UIImage(named: "SubscriptionIcon") != nil {
                Image("SubscriptionIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                AppIconView(size: 60)
            }
            #else
            if let brandingImage = NSImage(named: "AppBrandingIcon") {
                Image(nsImage: brandingImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                AppIconView(size: 60)
            }
            #endif
        }
    }
}
