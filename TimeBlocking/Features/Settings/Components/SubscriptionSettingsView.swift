import SwiftUI
import SwiftData
import StoreKit

struct SubscriptionSettingsView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    let onPresentPaywall: () -> Void
    @Query private var preferences: [AppPreferences]

    private var isPremium: Bool {
        subscriptionManager.isPremium
    }

    private var hasLifetimeAccess: Bool {
        subscriptionManager.hasLifetimeAccess
    }
    
    private var dynamicFootnote: String {
        guard let product = subscriptionManager.availableProducts.first(where: { $0.id.contains("yearly") }) else {
            return String(localized: "Upgrade for unlimited planning and sync.", comment: "Fallback string when products haven't loaded")
        }
        
        let priceString = product.displayPrice
        
        var billingUnit = String(localized: "year", comment: "Billing unit")
        if let subscription = product.subscription {
            switch subscription.subscriptionPeriod.unit {
            case .day: billingUnit = String(localized: "day", comment: "day")
            case .week: billingUnit = String(localized: "week", comment: "week")
            case .month: billingUnit = String(localized: "month", comment: "month")
            case .year: billingUnit = String(localized: "year", comment: "year")
            @unknown default: break
            }
        }
        
        if let subscription = product.subscription,
           let introOffer = subscription.introductoryOffer,
           introOffer.paymentMode == .freeTrial {
            
            let period = introOffer.period
            let trialValue = period.value
            let trialUnit: String
            
            switch period.unit {
            case .day: trialUnit = String(localized: "day", comment: "day")
            case .week: trialUnit = String(localized: "week", comment: "week")
            case .month: trialUnit = String(localized: "month", comment: "month")
            case .year: trialUnit = String(localized: "year", comment: "year")
            @unknown default: trialUnit = String(localized: "day", comment: "day")
            }
            
            return String(localized: "\(priceString) per \(billingUnit) after \(trialValue)-\(trialUnit) trial.", comment: "Pricing trial")
        } else {
            return String(localized: "\(priceString) per \(billingUnit).", comment: "Pricing no trial")
        }
    }
    
    var body: some View {
        TimeSettingsSection(title: "") {
            if !isPremium {
                ProUpgradeCard(
                    title: String(localized: "Full Access"),
                    subtitle: String(localized: "Unlimited planning, routines, and sync across all your devices."),
                    ctaTitle: String(localized: "Update to Full Access"),
                    footnote: nil,
                    isFullColorTheme: Theme.isImmersive,
                    action: {
                        onPresentPaywall()
                    },
                    isLoading: subscriptionManager.isLoading
                )
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        Image("AppIconLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .cornerRadius(14)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Full Access")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.primaryText)
                            
                            Text(hasLifetimeAccess ? "Lifetime access is active on this account." : "You have full access to all features.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    
                    statusChip(title: hasLifetimeAccess ? "Lifetime" : "Activated")
                    .accessibilityValue(hasLifetimeAccess ? "Lifetime" : "Activated")
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
    var isFullColorTheme: Bool = false
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
