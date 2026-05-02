import SwiftUI
import SwiftData

struct SubscriptionSettingsView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    let onPresentPaywall: () -> Void

    @Query private var preferences: [AppPreferences]

    private var isPremium: Bool {
        subscriptionManager.isPremium || (preferences.first?.isPremium ?? false)
    }

    var body: some View {
        TimeSettingsSection(title: "") {
            if !isPremium {
                ProUpgradeCard(
                    title: "Full Access",
                    subtitle: "Unlimited planning, routines, and sync across all your devices.",
                    ctaTitle: "Update to Full Access",
                    action: onPresentPaywall,
                    isLoading: subscriptionManager.isLoading
                )
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        AppIconView(size: 60)

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
        .padding(.top, 4)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isPremium {
                HapticManager.shared.lightImpact()
                onPresentPaywall()
            }
        }
    }

    @ViewBuilder
    private func statusChip(title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.primaryAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Theme.primaryAccent.opacity(0.1))
            .clipShape(Capsule())
    }
}

private struct ProUpgradeCard: View {
    let title: String
    let subtitle: String
    let ctaTitle: String
    let footnote: String?
    let action: () -> Void
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                AppIconView(size: 50)
                    .adaptiveShadow(color: Theme.primaryAccent.opacity(0.3), radius: 5, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Button(action: {
                HapticManager.shared.mediumImpact()
                action()
            }) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(ctaTitle)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity)
                .background(Theme.primaryAccent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            
            if let footnote = footnote {
                Text(footnote)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, -4)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.lightImpact()
            action()
        }
    }
}

